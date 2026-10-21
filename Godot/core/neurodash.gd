extends Node
## Built-in NeuroDash client: everything C:\sender.py does, without Python.
##   * sync_patients    pull the patient list assigned to this device (sender.py --login)
##   * upload_session   send sessions.csv and configdata.csv of the current patient, then any
##                      finished assessments (sender.py --upload)
##   * claim / release  the one-laptop-per-patient lock, renewed by a heartbeat while a session runs
##   * UDP nudges       the server tells this laptop when the patient list or presence changed
## The wire protocol is the one sender.py speaks: a 4-byte big-endian length, a JSON header, then the
## payload; replies are length-prefixed JSON (except the plain CSV upload, which gets raw JSON back).
## Network work runs on threads, so the screens never freeze. Settings live in application.cfg under
## [neurodash]: enabled, server_ip, server_port, device_id, client_id, patients_file, assessment_root.
signal sync_finished(result)
signal upload_finished(result)
signal lock_lost(holder)
signal status_changed
const DEFAULT_SERVER = "192.168.0.104"
const DEFAULT_PORT = 5000
const DEFAULT_DEVICE = "MARS"
const NUDGE_PORT = 5001
const HEARTBEAT_SECONDS = 30.0
const BUFFER = 64 * 1024
var status = ""
var syncing = false
var uploading = false
var holding_patient = ""
var threads: Array = []
var heartbeat: Timer
var nudge: PacketPeerUDP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	heartbeat = Timer.new()
	heartbeat.wait_time = HEARTBEAT_SECONDS
	heartbeat.timeout.connect(renew_claim)
	add_child(heartbeat)
	lock_lost.connect(func(_holder): Services.session_lost = true)
	status_changed.connect(func(): Services.message = "NeuroDash: " + status)
	if "--script" in OS.get_cmdline_args(): return
	if enabled(): start_nudge_listener()

func _exit_tree() -> void:
	for thread in threads: thread.wait_to_finish()

# ---------------------------------------------------------------- settings

func value(key: String, fallback):
	return Services.settings.get_value("neurodash", key, fallback)

func enabled() -> bool:
	return bool(value("enabled", false))

func set_value(key: String, new_value) -> void:
	Services.settings.set_value("neurodash", key, new_value)
	Services.save()
	if key == "enabled":
		if new_value: start_nudge_listener()
		else: stop_nudge_listener()

var cached_hostname = ""

## The laptop's name exactly as Python's socket.gethostname() (what sender.py and agent.py report) gives it:
## COMPUTERNAME is always upper-case, which the server would take for a different laptop.
func computer_name() -> String:
	if cached_hostname != "": return cached_hostname
	var output: Array = []
	if OS.execute("hostname", [], output) == 0 and output.size() > 0 and str(output[0]).strip_edges() != "":
		cached_hostname = str(output[0]).strip_edges()
		return cached_hostname
	for key in ["COMPUTERNAME", "HOSTNAME"]:
		var found = OS.get_environment(key)
		if found != "": return found
	return "mars-laptop"

## Everything a worker thread needs, copied up front so no thread touches the settings object.
func config() -> Dictionary:
	return {
		"ip": str(OS.get_environment("NEURODASH_SERVER_IP") if OS.get_environment("NEURODASH_SERVER_IP") != "" else value("server_ip", DEFAULT_SERVER)),
		"port": int(OS.get_environment("NEURODASH_SERVER_PORT") if OS.get_environment("NEURODASH_SERVER_PORT") != "" else value("server_port", DEFAULT_PORT)),
		"device": str(Services.agent_identity.get("device", "")) if Services.agent_available and str(Services.agent_identity.get("device", "")) != "" else str(value("device_id", DEFAULT_DEVICE)),
		"client": str(Services.agent_identity.get("client", "")) if Services.agent_available and str(Services.agent_identity.get("client", "")) != "" else (str(value("client_id", "")) if str(value("client_id", "")) != "" else computer_name()),
		"patients_file": patients_file(),
		"assessment_root": str(value("assessment_root", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("HomerPlutoData/fullassessment"))),
		"assessment_state": str(value("assessment_state", home().path_join(".neurodash_assessments_sent.json"))),
		"send_raw": OS.get_environment("NEURODASH_SEND_RAW") == "1",
		"patient_dir": ProjectSettings.globalize_path(Trial.user_path()) if Trial.user_id != "" else "",
		"last_patient_dir": str(value("last_patient_dir", ""))
	}

func home() -> String:
	var found = OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	return found if found != "" else ProjectSettings.globalize_path("user://")

## The shared patients.json: C:\NeuroDash\ where this user may write, else the user's own folder.
func patients_file() -> String:
	var chosen = str(value("patients_file", ""))
	if chosen != "": return chosen
	var env = OS.get_environment("NEURODASH_PATIENTS_FILE")
	if env != "": return env
	var shared = "C:/NeuroDash/patients.json"
	if OS.get_name() == "Windows" and (FileAccess.file_exists(shared) or can_write_dir(shared.get_base_dir())): return shared
	var personal = home().path_join("NeuroDash/patients.json")
	if can_write_dir(personal.get_base_dir()) or FileAccess.file_exists(personal): return personal
	return ProjectSettings.globalize_path("user://neurodash/patients.json")

static func can_write_dir(folder: String) -> bool:
	DirAccess.make_dir_recursive_absolute(folder)
	var probe = folder.path_join(".neurodash_probe")
	var file = FileAccess.open(probe, FileAccess.WRITE)
	if file == null: return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true

# ---------------------------------------------------------------- wire protocol (thread safe)

static func be32(number: int) -> PackedByteArray:
	return PackedByteArray([(number >> 24) & 255, (number >> 16) & 255, (number >> 8) & 255, number & 255])

static func from_be32(bytes: PackedByteArray) -> int:
	return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]

static func open_connection(cfg: Dictionary, timeout: float) -> StreamPeerTCP:
	var peer = StreamPeerTCP.new()
	if peer.connect_to_host(cfg.ip, cfg.port) != OK: return null
	var deadline = Time.get_ticks_msec() + int(timeout * 1000.0)
	while true:
		peer.poll()
		var state = peer.get_status()
		if state == StreamPeerTCP.STATUS_CONNECTED: return peer
		if state == StreamPeerTCP.STATUS_ERROR or state == StreamPeerTCP.STATUS_NONE: return null
		if Time.get_ticks_msec() > deadline:
			peer.disconnect_from_host()
			return null
		OS.delay_msec(15)
	return null

static func read_exact(peer: StreamPeerTCP, size: int, timeout: float) -> PackedByteArray:
	var data = PackedByteArray()
	var deadline = Time.get_ticks_msec() + int(timeout * 1000.0)
	while data.size() < size:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() == 0: return PackedByteArray()
		var available = peer.get_available_bytes()
		if available > 0:
			var chunk = peer.get_data(mini(available, size - data.size()))
			if chunk[0] == OK: data.append_array(chunk[1])
		elif Time.get_ticks_msec() > deadline: return PackedByteArray()
		else: OS.delay_msec(10)
	return data

static func send_header(peer: StreamPeerTCP, header: Dictionary) -> void:
	var body = JSON.stringify(header).to_utf8_buffer()
	peer.put_data(be32(body.size()))
	peer.put_data(body)

static func read_reply(peer: StreamPeerTCP, timeout: float) -> Dictionary:
	var length = read_exact(peer, 4, timeout)
	if length.size() < 4: return {}
	var size = from_be32(length)
	if size <= 0 or size > 64 * 1024 * 1024: return {}
	var body = read_exact(peer, size, timeout)
	if body.size() < size: return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

## One request/response, as sender.py's _ask_server / sync: {} when the server cannot be reached.
static func ask(cfg: Dictionary, header: Dictionary, timeout: float) -> Dictionary:
	var peer = open_connection(cfg, timeout)
	if peer == null: return {}
	send_header(peer, header)
	var reply = read_reply(peer, timeout)
	peer.disconnect_from_host()
	return reply

# ---------------------------------------------------------------- patient list (sender.py --login)

static func local_patients(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## HomerID values from configdata.csv of the patient last uploaded (what the server is told this laptop holds).
static func read_homer_ids(cfg: Dictionary) -> Array:
	var folder = cfg.patient_dir if cfg.patient_dir != "" else cfg.last_patient_dir
	var found: Array = []
	var path = str(folder).path_join("configdata.csv")
	if folder == "" or not FileAccess.file_exists(path): return found
	var file = FileAccess.open(path, FileAccess.READ)
	var header = file.get_csv_line()
	var column = Array(header).find("HomerID")
	while column >= 0 and not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() > column and row[column] != "" and not found.has(row[column]): found.append(row[column])
	return found

## Returns {ok, message, changed, count, version}.
static func sync_task(cfg: Dictionary) -> Dictionary:
	var local = local_patients(cfg.patients_file)
	var header = {"action": "sync", "device_id": cfg.device, "patients_version": int(local.get("version", 0)), "client_id": cfg.client, "view": str(local.get("view", "")), "homer_ids": read_homer_ids(cfg)}
	var reply = ask(cfg, header, 12.0)
	if reply.is_empty(): return {"ok": false, "message": "Could not reach the server at %s:%d." % [cfg.ip, cfg.port]}
	if not reply.get("success", false): return {"ok": false, "message": "Server: " + str(reply.get("message", "sync refused"))}
	if reply.get("up_to_date", false):
		return {"ok": true, "changed": false, "version": int(reply.get("version", 0)), "count": local.get("patients", []).size(), "message": "Patient list is up to date (v%d)." % int(reply.get("version", 0))}
	var payload = {"version": reply.get("version"), "updated_at": reply.get("updated_at"), "view": reply.get("view"), "patients": reply.get("patients", [])}
	DirAccess.make_dir_recursive_absolute(str(cfg.patients_file).get_base_dir())
	# Written beside the real file and swapped in, so a reader never sees half a file.
	var temp = str(cfg.patients_file) + ".tmp"
	var out = FileAccess.open(temp, FileAccess.WRITE)
	var wrote = false
	if out != null:
		out.store_string(JSON.stringify(payload, "  "))
		out.close()
		wrote = DirAccess.rename_absolute(temp, cfg.patients_file) == OK
	if not wrote:
		out = FileAccess.open(cfg.patients_file, FileAccess.WRITE)
		if out == null: return {"ok": false, "message": "Cannot write " + str(cfg.patients_file)}
		out.store_string(JSON.stringify(payload, "  "))
		out.close()
		DirAccess.remove_absolute(temp)
	var count = payload.patients.size()
	return {"ok": true, "changed": true, "version": int(reply.get("version", 0)), "count": count, "message": "Patient list updated: %d patients (v%d)." % [count, int(reply.get("version", 0))]}

## Patients this device may train: active and allowed on MARS (as Unity's login filtered them).
func assigned_patients() -> Array:
	var found: Array = []
	for patient in local_patients(patients_file()).get("patients", []):
		if not patient is Dictionary: continue
		if str(patient.get("status", "")).to_lower() != "active": continue
		var devices = Array(patient.get("devices", [])).map(func(d): return str(d).to_upper())
		if not devices.has(str(value("device_id", DEFAULT_DEVICE)).to_upper()): continue
		found.append({"id": str(patient.get("user_id", "")), "side": str(patient.get("side", ""))})
	return found

func assigned_side(id: String) -> String:
	for patient in assigned_patients():
		if patient.id == id: return patient.side.to_upper()
	return ""

func sync_patients() -> void:
	if syncing: return
	syncing = true
	set_status("Fetching the patient list…")
	var cfg = config()
	run(func(): return sync_task(cfg), func(result):
		syncing = false
		set_status(result.message)
		sync_finished.emit(result))

# ---------------------------------------------------------------- uploads (sender.py --upload)

## Plain CSV upload: header, file bytes, then raw JSON back. Returns {ok, message}.
static func send_file_task(cfg: Dictionary, path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "message": "File not found: " + path}
	var size = FileAccess.get_file_as_bytes(path).size()
	var peer = open_connection(cfg, 30.0)
	if peer == null: return {"ok": false, "message": "Server not reachable."}
	send_header(peer, {"device_id": cfg.device, "client_id": cfg.client, "filename": path.get_file(), "file_size": size})
	var file = FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var block = file.get_buffer(BUFFER)
		if block.size() > 0: peer.put_data(block)
	var deadline = Time.get_ticks_msec() + 30000
	var raw = PackedByteArray()
	while Time.get_ticks_msec() < deadline and raw.size() == 0:
		peer.poll()
		var available = peer.get_available_bytes()
		if available > 0: raw = peer.get_data(available)[1]
		elif peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: break
		else: OS.delay_msec(15)
	peer.disconnect_from_host()
	var reply = JSON.parse_string(raw.get_string_from_utf8())
	if not reply is Dictionary: return {"ok": false, "message": "No confirmation from the server."}
	if reply.get("success", false): return {"ok": true, "message": path.get_file() + " sent."}
	return {"ok": false, "message": "Server: " + str(reply.get("message", "unknown error"))}

static func upload_task(cfg: Dictionary) -> Dictionary:
	var folder = str(cfg.patient_dir)
	var lines: Array = []
	var failed = 0
	if folder != "":
		for relative in ["sessions/sessions.csv", "configdata.csv"]:
			var result = send_file_task(cfg, folder.path_join(relative))
			lines.append(result.message)
			if not result.ok: failed += 1
	var assessments = send_new_assessments(cfg)
	lines.append(assessments.message)
	failed += assessments.failed.size()
	return {"ok": failed == 0, "message": " ".join(lines), "assessments": assessments}

func upload_session() -> void:
	if uploading: return
	uploading = true
	set_status("Sending session data…")
	set_value("last_patient_dir", ProjectSettings.globalize_path(Trial.user_path()))
	var cfg = config()
	run(func(): return upload_task(cfg), func(result):
		uploading = false
		set_status(("Uploaded. " if result.ok else "Upload problem. ") + result.message)
		upload_finished.emit(result))

# ---------------------------------------------------------------- finished assessments

const TIMEPOINT = "^[A-Za-z][0-9]{1,2}$"
const LIMBS = ["left", "right", "both"]
const SUFFIXES = ["csv", "json", "locked", "txt"]

static func is_raw_trial_file(name: String) -> bool:
	return RegEx.create_from_string("(?i)(^|[_-])raw[-_]").search(name) != null

static func lock_marker(patient_dir: String, limb_dir: String, timepoint_dir: String) -> String:
	var wanted = timepoint_dir.get_file().to_lower() + ".locked"
	for folder in [patient_dir, limb_dir, timepoint_dir]:
		var directory = DirAccess.open(folder)
		if directory == null: continue
		for entry in directory.get_files():
			if entry.to_lower() == wanted: return folder.path_join(entry)
	return ""

static func find_assessments(root: String, require_lock: bool = true) -> Array:
	var found: Array = []
	var pattern = RegEx.create_from_string(TIMEPOINT)
	var top = DirAccess.open(root)
	if top == null: return found
	var patients = Array(top.get_directories())
	patients.sort()
	for patient in patients:
		for limb in LIMBS:
			var limb_dir = root.path_join(patient).path_join(limb)
			var limb_access = DirAccess.open(limb_dir)
			if limb_access == null: continue
			var timepoints = Array(limb_access.get_directories())
			timepoints.sort()
			for timepoint in timepoints:
				if pattern.search(timepoint) == null: continue
				var folder = limb_dir.path_join(timepoint)
				var lock = lock_marker(root.path_join(patient), limb_dir, folder)
				if require_lock and lock == "": continue
				found.append({"patient": patient, "limb": limb, "timepoint": timepoint.to_upper(), "folder": folder, "lock": lock})
	return found

static func walk_files(folder: String, prefix: String = "") -> Array:
	var found: Array = []
	var directory = DirAccess.open(folder)
	if directory == null: return found
	var names = Array(directory.get_files())
	names.sort()
	for name in names: found.append(prefix + name)
	var subs = Array(directory.get_directories())
	subs.sort()
	for sub in subs: found.append_array(walk_files(folder.path_join(sub), prefix + sub + "/"))
	return found

## [[archive name, path], ...]: the timepoint folder's files (not raw streams unless asked) plus its lock marker.
static func assessment_files(assessment: Dictionary, include_raw: bool) -> Array:
	var files: Array = []
	for relative in walk_files(assessment.folder):
		var name = relative.get_file()
		if name.begins_with(".") or not SUFFIXES.has(name.get_extension().to_lower()): continue
		if not include_raw and is_raw_trial_file(name): continue
		files.append([relative, str(assessment.folder).path_join(relative)])
	var lock = str(assessment.lock)
	if lock != "":
		var present = false
		for pair in files:
			if pair[0] == lock.get_file(): present = true
		if not present: files.append([lock.get_file(), lock])
	return files

static func fingerprint(files: Array) -> String:
	var overall = HashingContext.new()
	overall.start(HashingContext.HASH_SHA256)
	for pair in files:
		var bytes = FileAccess.get_file_as_bytes(pair[1])
		var content = HashingContext.new()
		content.start(HashingContext.HASH_SHA256)
		content.update(bytes)
		overall.update(("%s\t%d\t%s\n" % [pair[0], bytes.size(), content.finish().hex_encode()]).to_utf8_buffer())
	return overall.finish().hex_encode()

static func build_zip(files: Array, target: String) -> bool:
	var packer = ZIPPacker.new()
	if packer.open(target) != OK: return false
	for pair in files:
		packer.start_file(pair[0])
		packer.write_file(FileAccess.get_file_as_bytes(pair[1]))
		packer.close_file()
	packer.close()
	return true

## "sent", "unchanged" or an error text starting with "error:".
static func send_assessment(cfg: Dictionary, assessment: Dictionary, files: Array, print_value: String) -> String:
	var package = OS.get_user_data_dir().path_join("assessment-upload.zip")
	if not build_zip(files, package): return "error: could not build the archive"
	var size = FileAccess.get_file_as_bytes(package).size()
	var peer = open_connection(cfg, 60.0)
	if peer == null:
		DirAccess.remove_absolute(package)
		return "error: server not reachable"
	send_header(peer, {"action": "assessment", "device_id": cfg.device, "client_id": cfg.client, "patient_id": assessment.patient, "limb": assessment.limb, "timepoint": assessment.timepoint, "fingerprint": print_value, "file_size": size})
	var offer = read_reply(peer, 60.0)
	var outcome = ""
	if not offer.get("success", false): outcome = "error: " + str(offer.get("message", "the server refused the assessment"))
	elif not offer.get("send", false): outcome = "unchanged"
	else:
		var file = FileAccess.open(package, FileAccess.READ)
		while not file.eof_reached():
			var block = file.get_buffer(BUFFER)
			if block.size() > 0: peer.put_data(block)
		var done = read_reply(peer, 60.0)
		outcome = "sent" if done.get("success", false) else "error: " + str(done.get("message", "the server could not store the assessment"))
	peer.disconnect_from_host()
	DirAccess.remove_absolute(package)
	return outcome

## Sends every finished timepoint that is new or changed since it was last sent.
static func send_new_assessments(cfg: Dictionary) -> Dictionary:
	var result = {"sent": [], "unchanged": [], "skipped": 0, "failed": [], "message": ""}
	var state = {}
	if FileAccess.file_exists(cfg.assessment_state):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(cfg.assessment_state))
		if parsed is Dictionary: state = parsed
	for assessment in find_assessments(cfg.assessment_root):
		var label = "%s %s %s" % [assessment.patient, assessment.limb, assessment.timepoint]
		var key = "%s|%s|%s" % [assessment.patient, assessment.limb, assessment.timepoint]
		var files = assessment_files(assessment, cfg.send_raw)
		if files.is_empty():
			result.skipped += 1
			continue
		var print_value = fingerprint(files)
		if state.get(key, "") == print_value:
			result.skipped += 1
			continue
		var outcome = send_assessment(cfg, assessment, files, print_value)
		if outcome.begins_with("error:"):
			result.failed.append(label + " (" + outcome.trim_prefix("error: ") + ")")
			continue
		state[key] = print_value
		DirAccess.make_dir_recursive_absolute(str(cfg.assessment_state).get_base_dir())
		var out = FileAccess.open(cfg.assessment_state, FileAccess.WRITE)
		if out != null:
			out.store_string(JSON.stringify(state, "  "))
			out.close()
		if outcome == "sent": result.sent.append(label)
		else: result.unchanged.append(label)
	if result.sent.is_empty() and result.unchanged.is_empty() and result.failed.is_empty(): result.message = "No new assessments."
	else: result.message = "Assessments: %d sent, %d already there, %d failed." % [result.sent.size(), result.unchanged.size(), result.failed.size()]
	return result

# ---------------------------------------------------------------- patient lock

## True when the patient is yours (or the server cannot be reached: therapy is never blocked by the network).
static func claim_task(cfg: Dictionary, user_id: String) -> Dictionary:
	var reply = ask(cfg, {"action": "claim_user", "device_id": cfg.device, "client_id": cfg.client, "user_id": user_id}, 3.0)
	if reply.is_empty() or not reply.get("success", false) or reply.get("claimed", false): return {"granted": true, "holder": {}}
	return {"granted": false, "holder": reply.get("in_use_by", {})}

static func release_task(cfg: Dictionary, user_id: String) -> bool:
	var reply = ask(cfg, {"action": "release", "device_id": cfg.device, "client_id": cfg.client, "user_id": user_id}, 3.0)
	return bool(reply.get("released", false))

## "<id> is being trained on <device> (laptop <client>)".
static func holder_text(user_id: String, holder: Dictionary) -> String:
	var text = "%s is being trained on %s" % [user_id, holder.get("device", "another device")]
	if holder.get("client", "") != "": text += " (laptop %s)" % holder.client
	return text

## Called at login. Emits through `done` with {granted, holder}. Starts the heartbeat when granted.
func claim(user_id: String, done: Callable) -> void:
	var cfg = config()
	run(func(): return claim_task(cfg, user_id), func(result):
		if result.granted:
			holding_patient = user_id
			heartbeat.start()
		done.call(result))

func release() -> void:
	heartbeat.stop()
	if holding_patient == "": return
	var user_id = holding_patient
	holding_patient = ""
	var cfg = config()
	run(func(): return release_task(cfg, user_id), func(_result): pass)

func renew_claim() -> void:
	if holding_patient == "": return
	var user_id = holding_patient
	var cfg = config()
	run(func(): return claim_task(cfg, user_id), func(result):
		if not result.granted and holding_patient == user_id:
			heartbeat.stop()
			holding_patient = ""
			set_status(holder_text(user_id, result.holder))
			lock_lost.emit(result.holder))

# ---------------------------------------------------------------- UDP nudges

func start_nudge_listener() -> void:
	if nudge != null: return
	nudge = PacketPeerUDP.new()
	nudge.set_broadcast_enabled(true)
	if nudge.bind(NUDGE_PORT) != OK: nudge = null

func stop_nudge_listener() -> void:
	if nudge != null: nudge.close()
	nudge = null

func _process(_delta: float) -> void:
	if nudge == null: return
	while nudge.get_available_packet_count() > 0:
		var parsed = JSON.parse_string(nudge.get_packet().get_string_from_utf8())
		if not parsed is Dictionary: continue
		var kind = str(parsed.get("type", ""))
		if kind == "presence_changed" or (kind == "patients_changed" and int(parsed.get("version", 0)) > int(local_patients(patients_file()).get("version", 0))):
			sync_patients()

# ---------------------------------------------------------------- plumbing

func set_status(text: String) -> void:
	status = text
	status_changed.emit()

## Runs `task` on a thread and calls `done` with its result on the main thread.
func run(task: Callable, done: Callable) -> void:
	var thread = Thread.new()
	threads.append(thread)
	thread.start(func():
		var result = task.call()
		call_deferred("finish_task", thread, done, result))

func finish_task(thread: Thread, done: Callable, result) -> void:
	thread.wait_to_finish()
	threads.erase(thread)
	done.call(result)
