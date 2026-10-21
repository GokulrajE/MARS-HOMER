extends Node
signal session_checked(allowed,message)
var settings = ConfigFile.new()
var session_lost = false
var agent_enabled = false
## Set by probing http://127.0.0.1:5055/status: the always-running agent.py is detected automatically,
## so the "Use local session agent" switch is no longer needed for it to be used.
var agent_available = false
var agent_port = 5055
## The agent's own device and laptop names (from /status). Uploads must use the same ones, or the
## server sees two different laptops for one patient and refuses the lock.
var agent_identity: Dictionary = {}
var uploads_enabled = false
var python_path = "python"
var uploader = "C:/pythonscripts/uploadToAWSM.pyw"
var sender = "C:/sender.py"
var upload_status = "C:/DeviceSetups/Mars/uploadStatus.txt"
var message = "Uploads disabled"
var upload_pid = -1
var agent_busy = false
var login_pending = false

func _ready() -> void:
	if not "--script" in OS.get_cmdline_args(): probe_agent.call_deferred()
	settings.load("user://application.cfg")
	agent_enabled=bool(settings.get_value("services","agent",false))
	agent_port=int(settings.get_value("services","agent_port",5055))
	uploads_enabled=bool(settings.get_value("services","uploads",false))
	python_path=str(settings.get_value("services","python","python"))
	uploader=str(settings.get_value("services","uploader",uploader))
	sender=str(settings.get_value("services","sender",sender))
	upload_status=str(settings.get_value("services","upload_status",upload_status))
	var config=FileAccess.open("C:/lapconfig.json",FileAccess.READ)
	if config!=null:
		var parsed=JSON.parse_string(config.get_as_text())
		if parsed is Dictionary and parsed.get("mars") is Dictionary:
			if not settings.has_section_key("device","port"): settings.set_value("device","port",str(parsed.mars.get("comport","")))
			if not settings.has_section_key("services","python"): python_path=str(parsed.mars.get("pythonpath","python"))

func save() -> void:
	settings.set_value("services","agent",agent_enabled)
	settings.set_value("services","uploads",uploads_enabled)
	settings.set_value("services","python",python_path)
	settings.set_value("services","uploader",uploader)
	settings.set_value("services","sender",sender)
	settings.set_value("services","upload_status",upload_status)
	settings.save("user://application.cfg")

func agent_in_use() -> bool:
	return agent_enabled or agent_available

func probe_agent() -> void:
	var reply=await request_agent("status")
	agent_available=reply[0]==200
	agent_identity={"device":str(reply[1].get("device","")),"client":str(reply[1].get("client",""))} if agent_available and reply[1].has("client") else {}

## Scripted test runs must never reach the real agent, server or uploader on this computer.
static func scripted() -> bool:
	return "--script" in OS.get_cmdline_args()

func request_agent(path: String) -> Array:
	if scripted() and agent_port==5055: return [-1,{}]
	var request=HTTPRequest.new()
	request.timeout=5
	add_child(request)
	var code=request.request("http://127.0.0.1:%d/%s" % [agent_port,path])
	if code!=OK:
		request.queue_free()
		return [-1,{}]
	var response=await request.request_completed
	request.queue_free()
	var body: String=response[3].get_string_from_utf8()
	var json=JSON.parse_string(body) if body.strip_edges()!="" else null
	return [int(response[1]),json if json is Dictionary else {}]

func login(id: String) -> void:
	if login_pending: return
	session_lost=false
	# The local agent (agent.py, always running on the device) is the only thing that talks to the
	# server when it is switched on; the built-in client takes over only when it is off.
	if NeuroDash.enabled() and not agent_in_use():
		# Built-in NeuroDash client: one laptop per patient.
		login_pending=true
		var box: Array = []
		NeuroDash.claim(id,func(result): box.append(result))
		while box.is_empty(): await get_tree().process_frame
		login_pending=false
		var granted=bool(box[0].granted)
		if not granted: session_lost=true
		session_checked.emit(granted,"" if granted else NeuroDash.holder_text(id,box[0].holder))
		return
	if not agent_in_use():
		session_checked.emit(true,"")
		return
	login_pending=true
	var reply=await request_agent("start?patient="+id.uri_encode())
	login_pending=false
	var allowed=reply[0] in [-1,0,200]
	if not allowed: session_lost=true
	session_checked.emit(allowed,str(reply[1].get("message","Session agent denied login.")) if not allowed else "")

func trial_ended() -> void:
	# Like Unity's neurodash.OnSessionEnd(): sessions.csv and configdata.csv (and finished assessments)
	# go to the NeuroDash server after every trial. The agent only tracks the patient lock.
	if NeuroDash.enabled() or agent_in_use(): NeuroDash.upload_session()
	# Built-in NeuroDash lock (no agent): confirm after every trial that the patient is still ours.
	if NeuroDash.enabled() and not agent_in_use(): NeuroDash.renew_claim()
	if agent_in_use():
		agent_busy=true
		var reply=await request_agent("trial-ended")
		session_lost=reply[0]==200 and reply[1].get("lost") is Dictionary
		agent_busy=false
		if session_lost: Records.log_event("Session transferred to another laptop; further trials blocked.")
	if uploads_enabled: mark_upload()

func logout() -> void:
	NeuroDash.release()
	if agent_in_use(): await request_agent("stop")
	session_lost=false

func mark_upload() -> bool:
	if scripted() and upload_status.begins_with("C:/"):
		message="Upload marking is skipped in scripted runs."
		return false
	DirAccess.make_dir_recursive_absolute(upload_status.get_base_dir())
	var file=FileAccess.open(upload_status,FileAccess.WRITE)
	if file==null:
		message="Cannot update upload status. Local trial data is safe."
		return false
	file.store_line("%s,upload_needed,Mars,%s,%s" % [ProjectSettings.globalize_path(Trial.data_root.path_join(Trial.user_id)),Trial.user_id,Records.profile.get("Location","")])
	file.close()
	message="Upload pending"
	return true

## The Summary screen's "Upload data now". Two parts, as in Unity: sessions.csv, configdata.csv and
## finished assessments go to the NeuroDash server (the LAN server only accepts those CSVs), and the
## installed MARS uploader (uploadToAWSM.pyw) uploads every file and folder of the patient. Returns what was started.
func upload_all() -> String:
	var started: Array = []
	if NeuroDash.enabled() or agent_in_use():
		NeuroDash.upload_session()
		started.append("sessions, config and assessments to the NeuroDash server")
	if FileAccess.file_exists(uploader):
		upload_now()
		if upload_pid>0: started.append("all data files and folders with the MARS uploader")
	if started.is_empty(): return "Nothing to upload with: switch on NeuroDash or install the MARS uploader (Patient & setup > Uploads & services)."
	return "Uploading " + " and ".join(started) + "…"

func upload_now() -> void:
	if upload_pid>0 and OS.is_process_running(upload_pid):
		message="Uploader already running"
		return
	if not FileAccess.file_exists(uploader):
		message="Configure the installed MARS uploader script first."
		return
	if not mark_upload(): return
	upload_pid=OS.create_process(python_path,[uploader],false)
	message="Uploader started; awaiting upload-status acknowledgement." if upload_pid>0 else "Could not start uploader. Check the Python executable."

## The built-in client does what C:\sender.py did: --login fetches the patient list, --upload sends data.
func neurodash(login_mode: bool) -> void:
	if login_mode: NeuroDash.sync_patients()
	else: NeuroDash.upload_session()
	message="NeuroDash: working…"

func _process(_delta: float) -> void:
	if upload_pid>0 and not OS.is_process_running(upload_pid):
		upload_pid=-1
		var status=FileAccess.get_file_as_string(upload_status) if FileAccess.file_exists(upload_status) else ""
		message="Upload acknowledged" if ",no_upload," in status else "Uploader exited without success acknowledgement; retry available."
