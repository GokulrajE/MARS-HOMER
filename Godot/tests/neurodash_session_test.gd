extends SceneTree
# The server hears: login -> claim, trial start -> claim renewed, trial end -> upload (+ renewed claim),
# logout -> release; a patient held by another laptop cannot log in.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func events(path: String) -> Array:
	var found: Array = []
	if not FileAccess.file_exists(path): return found
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary: found.append(parsed)
	return found

func actions(path: String) -> Array:
	return events(path).map(func(e): return str(e.get("action", "upload:" + str(e.get("filename", "?")))))

func run() -> void:
	var dash = root.get_node("NeuroDash")
	var services = root.get_node("Services")
	var trial = root.get_node("Trial")
	var settings = services.settings
	# Never touch the real uploader or its status file.
	services.uploader = "Z:/none/uploader.pyw"
	services.upload_status = "user://test-upload-status.txt"
	var saved_section: Dictionary = {}
	if settings.has_section("neurodash"):
		for key in settings.get_section_keys("neurodash"): saved_section[key] = settings.get_value("neurodash", key)
	var base = ProjectSettings.globalize_path("res://test-output/ns-" + str(Time.get_ticks_usec()))
	var received = base.path_join("server")
	DirAccess.make_dir_recursive_absolute(received)
	var port = randi_range(30000, 45000)
	var pid = OS.create_process("python", [ProjectSettings.globalize_path("res://tests/fake_neurodash_server.py"), str(port), received])
	for i in 100:
		await create_timer(0.1).timeout
		if FileAccess.file_exists(received.path_join("ready")): break
	check(FileAccess.file_exists(received.path_join("ready")), "The fake server starts")
	settings.set_value("neurodash", "server_ip", "127.0.0.1")
	settings.set_value("neurodash", "server_port", port)
	settings.set_value("neurodash", "device_id", "MARS")
	settings.set_value("neurodash", "client_id", "TEST-LAPTOP")
	settings.set_value("neurodash", "enabled", true)
	settings.set_value("neurodash", "patients_file", base.path_join("patients.json"))
	settings.set_value("neurodash", "assessment_root", base.path_join("none"))
	settings.set_value("neurodash", "assessment_state", base.path_join("sent.json"))
	services.settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/ns-data-" + str(Time.get_ticks_usec())
	trial.hardware = true
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await process_frame
	var login = launcher.screen
	var log_path = received.path_join("requests.log")
	# A patient held by another laptop cannot log in.
	login.signed_in.emit("busy-patient")
	for i in 60:
		await create_timer(0.1).timeout
		if login.error.text != "": break
	check(login.error.text.contains("PLUTO") and launcher.menu == null and launcher.workflow == null, "A patient held elsewhere is refused at login: " + login.error.text)
	# A free patient: login -> claim.
	trial.configure("tsession")
	root.get_node("Records").save_profile({"HomerID": "tsession", "StartDate": "01-10-2026 00:00:00", "EndDate": "31-12-2099 23:59:59", "TotalTime": "30", "ML": "10", "AP": "10", "MLAP": "10", "ForeArmLength": "0.291", "UpperArmLength": "0.475", "TrainingSide": "RIGHT", "Location": "", "Group": "Experimental"})
	login.signed_in.emit("tsession")
	for i in 60:
		await create_timer(0.1).timeout
		if launcher.menu != null: break
	check(launcher.menu != null and dash.holding_patient == "tsession", "Login claims the patient and opens the session")
	var after_login = actions(log_path)
	check(after_login.count("claim_user") >= 2 and after_login.has("claim_user"), "The server received the login claims: " + str(after_login))
	# A healthy robot with assessments, so a device trial can really start.
	var robot = root.get_node("Robot")
	var records = root.get_node("Records")
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[0] = -90.0
	sensors[9] = 999
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec() + 3600000
	robot.last_packet = {"status": 19, "command_status": 0, "sensors": sensors, "force": 25.0, "calibration": 1, "control_type": 1, "limb": 1, "error": 0, "button": 1, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}
	records.corners["MLAP"] = {"LeftAdjustedX": "-0.2", "BottomAdjustedY": "0.1", "RightAdjustedX": "0.2", "TopAdjustedY": "0.4"}
	records.weight = {"LeftForce": "10", "RightForce": "10", "TopForce": "10", "BottomForce": "10", "CenterForce": "10"}
	trial.plane = -90.0
	var before_trial = actions(log_path).size()
	# Trial start -> renewed claim.
	trial.hardware = true
	launcher.launch("BS")
	await create_timer(1.0).timeout
	var after_start = actions(log_path)
	check(after_start.size() > before_trial and after_start[after_start.size() - 1] == "claim_user", "Trial start renews the claim: " + str(after_start))
	var marker = after_start.size()
	# Trial end -> renewed claim and upload.
	trial.finish("TEST")
	await create_timer(2.0).timeout
	var after_end = actions(log_path).slice(marker)
	check(after_end.has("claim_user") and after_end.any(func(a): return a.begins_with("upload:")), "Trial end checks the lock and uploads: " + str(after_end))
	# Logout -> release.
	var before_logout = actions(log_path).size()
	await services.logout()
	await create_timer(1.0).timeout
	var after_logout = actions(log_path).slice(before_logout)
	check(after_logout.has("release") and dash.holding_patient == "", "Logout releases the patient: " + str(after_logout))
	# With the local agent switched on, the app talks only to the agent: nothing goes to the server directly.
	var server_calls = actions(log_path).size()
	services.agent_enabled = true
	services.agent_port = 59999 # nothing listens here: the agent is "offline"
	var agent_box: Array = []
	services.session_checked.connect(func(allowed, _message): agent_box.append(allowed))
	services.login("agent-patient")
	for i in 80:
		await create_timer(0.1).timeout
		if not agent_box.is_empty(): break
	check(not agent_box.is_empty() and agent_box[0], "With the agent on (and offline) login is not blocked")
	services.trial_ended()
	await create_timer(2.0).timeout
	var agent_mode_calls = actions(log_path).slice(server_calls)
	check(agent_mode_calls.size() > 0 and agent_mode_calls.all(func(c): return c.begins_with("upload:")), "With the agent on, the app still sends the CSVs (no lock calls) after a trial: " + str(agent_mode_calls))
	check(agent_mode_calls.has("upload:sessions.csv") and agent_mode_calls.has("upload:configdata.csv"), "sessions.csv and configdata.csv go to the server at every trial end")
	# Summary screen: "Upload data now".
	var summary = load("res://core/summary.gd").new()
	root.add_child(summary)
	await process_frame
	var before_summary = actions(log_path).size()
	summary.upload()
	await create_timer(2.0).timeout
	check(summary.message.text.contains("NeuroDash") or summary.message.text.contains("Server upload"), "The Summary button reports the upload: " + summary.message.text)
	check(actions(log_path).size() > before_summary and actions(log_path).slice(before_summary).has("upload:sessions.csv"), "The Summary button uploads to the server")
	summary.queue_free()
	services.agent_enabled = false
	services.agent_port = 5055
	OS.kill(pid)
	if settings.has_section("neurodash"): settings.erase_section("neurodash")
	for key in saved_section: settings.set_value("neurodash", key, saved_section[key])
	services.save()
	trial.hardware = false
	print("NeuroDash session: %d failures" % failures)
	quit(1 if failures else 0)
