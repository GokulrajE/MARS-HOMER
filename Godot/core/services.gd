extends Node
signal session_checked(allowed,message)
var settings = ConfigFile.new()
var session_lost = false
var agent_enabled = false
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
	settings.load("user://application.cfg")
	agent_enabled=bool(settings.get_value("services","agent",false))
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

func request_agent(path: String) -> Array:
	var request=HTTPRequest.new()
	request.timeout=5
	add_child(request)
	var code=request.request("http://127.0.0.1:5055/"+path)
	if code!=OK:
		request.queue_free()
		return [-1,{}]
	var response=await request.request_completed
	request.queue_free()
	var json=JSON.parse_string(response[3].get_string_from_utf8())
	return [int(response[1]),json if json is Dictionary else {}]

func login(id: String) -> void:
	if login_pending: return
	session_lost=false
	if not agent_enabled:
		session_checked.emit(true,"")
		return
	login_pending=true
	var reply=await request_agent("start?patient="+id.uri_encode())
	login_pending=false
	var allowed=reply[0] in [-1,0,200]
	session_checked.emit(allowed,str(reply[1].get("message","Session agent denied login.")) if not allowed else "")

func trial_ended() -> void:
	if agent_enabled:
		agent_busy=true
		var reply=await request_agent("trial-ended")
		session_lost=reply[0]==200 and reply[1].get("lost") is Dictionary
		agent_busy=false
		if session_lost: Records.log_event("Session transferred to another laptop; further trials blocked.")
	if uploads_enabled: mark_upload()

func logout() -> void:
	if agent_enabled: await request_agent("stop")
	session_lost=false

func mark_upload() -> bool:
	DirAccess.make_dir_recursive_absolute(upload_status.get_base_dir())
	var file=FileAccess.open(upload_status,FileAccess.WRITE)
	if file==null:
		message="Cannot update upload status. Local trial data is safe."
		return false
	file.store_line("%s,upload_needed,Mars,%s,%s" % [ProjectSettings.globalize_path(Trial.data_root.path_join(Trial.user_id)),Trial.user_id,Records.profile.get("Location","")])
	file.close()
	message="Upload pending"
	return true

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

func neurodash(login_mode: bool) -> void:
	if not FileAccess.file_exists(sender):
		message="NeuroDash sender is not installed at the configured path."
		return
	var pid=OS.create_process(python_path,[sender,"--login" if login_mode else "--upload"],false)
	message="NeuroDash sender started" if pid>0 else "Could not start NeuroDash sender"

func _process(_delta: float) -> void:
	if upload_pid>0 and not OS.is_process_running(upload_pid):
		upload_pid=-1
		var status=FileAccess.get_file_as_string(upload_status) if FileAccess.file_exists(upload_status) else ""
		message="Upload acknowledged" if ",no_upload," in status else "Uploader exited without success acknowledgement; retry available."
