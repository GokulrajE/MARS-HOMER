extends SceneTree
# The built-in NeuroDash client against a fake server that speaks sender.py's protocol:
# patient list sync, session + assessment upload, and the one-laptop-per-patient lock.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func wait_for(signal_source: Signal, seconds: float = 20.0):
	var box: Array = []
	var handler = func(result = null): box.append(result)
	signal_source.connect(handler)
	var deadline = Time.get_ticks_msec() + int(seconds * 1000.0)
	while box.is_empty() and Time.get_ticks_msec() < deadline: await create_timer(0.05).timeout
	signal_source.disconnect(handler)
	return box[0] if not box.is_empty() else null

func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	var dash = root.get_node("NeuroDash")
	# The test must never leave its fake-server settings in the real application.cfg.
	var settings = root.get_node("Services").settings
	var saved_section: Dictionary = {}
	if settings.has_section("neurodash"):
		for key in settings.get_section_keys("neurodash"): saved_section[key] = settings.get_value("neurodash", key)
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	var base = ProjectSettings.globalize_path("res://test-output/nd-" + str(Time.get_ticks_usec()))
	var received = base.path_join("server")
	DirAccess.make_dir_recursive_absolute(received)
	var port = randi_range(30000, 45000)
	var pid = OS.create_process("python", [ProjectSettings.globalize_path("res://tests/fake_neurodash_server.py"), str(port), received])
	var ready = false
	for i in 100:
		await create_timer(0.1).timeout
		if FileAccess.file_exists(received.path_join("ready")):
			ready = true
			break
	check(ready and pid > 0, "The fake server starts (needs Python 3)")
	if not ready:
		print("NeuroDash: %d failures (server not started)" % (failures + 1))
		quit(1)
		return
	dash.set_value("server_ip", "127.0.0.1")
	dash.set_value("server_port", port)
	dash.set_value("device_id", "MARS")
	dash.set_value("client_id", "TEST-LAPTOP")
	dash.set_value("patients_file", base.path_join("patients.json"))
	dash.set_value("assessment_root", base.path_join("assessments"))
	dash.set_value("assessment_state", base.path_join("sent.json"))
	# ---- patient list
	dash.sync_patients()
	var sync = await wait_for(dash.sync_finished)
	check(sync != null and sync.ok and sync.changed and sync.count == 4, "The patient list is fetched: " + str(sync))
	var stored = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("patients.json")))
	check(stored is Dictionary and int(stored.version) == 3 and stored.view == "abc123", "patients.json is written with version and view")
	var ids = dash.assigned_patients().map(func(p): return p.id)
	check(ids == ["AG1", "AG4"], "Only active MARS patients are offered: " + str(ids))
	check(dash.assigned_side("AG1") == "LEFT", "The assigned side is known")
	dash.sync_patients()
	var again = await wait_for(dash.sync_finished)
	check(again != null and again.ok and not again.changed, "A second sync is up to date")
	# ---- upload of the current patient and a finished assessment
	trial.data_root = "res://test-output/nd-data-" + str(Time.get_ticks_usec())
	trial.configure("tdash")
	records.save_profile({"HomerID": "tdash", "StartDate": "01-10-2026 00:00:00", "EndDate": "31-12-2099 23:59:59", "TotalTime": "30", "ML": "10", "AP": "10", "MLAP": "10", "ForeArmLength": "0.291", "UpperArmLength": "0.475", "TrainingSide": "LEFT", "Location": "", "Group": "Experimental"})
	var assessments = base.path_join("assessments")
	write_text(assessments.path_join("pt1/left/T0/summary.csv"), "a,b\n1,2\n")
	write_text(assessments.path_join("pt1/left/T0/raw-trial.csv"), "raw\n")
	write_text(assessments.path_join("pt1/T0.locked"), "done")
	write_text(assessments.path_join("pt2/left/T1/notes.txt"), "unfinished: no lock marker")
	dash.upload_session()
	var upload = await wait_for(dash.upload_finished, 30.0)
	check(upload != null and upload.ok, "The upload succeeds: " + str(upload))
	check(FileAccess.file_exists(received.path_join("csv-sessions.csv")) and FileAccess.file_exists(received.path_join("csv-configdata.csv")), "sessions.csv and configdata.csv reach the server")
	check(FileAccess.get_file_as_string(received.path_join("csv-configdata.csv")).contains("tdash"), "The uploaded config is the patient's")
	var zip = received.path_join("assessment-pt1-left-T0.zip")
	check(FileAccess.file_exists(zip), "The finished assessment is sent")
	var reader = ZIPReader.new()
	reader.open(zip)
	var names = Array(reader.get_files())
	reader.close()
	check(names.has("summary.csv") and names.has("T0.locked") and not names.has("raw-trial.csv"), "Raw files are left out, the lock marker is included: " + str(names))
	check(not FileAccess.file_exists(received.path_join("assessment-pt2-left-T1.zip")), "An unfinished (unlocked) assessment is not sent")
	DirAccess.remove_absolute(zip)
	dash.upload_session()
	var second = await wait_for(dash.upload_finished, 30.0)
	check(second != null and second.assessments.sent.is_empty() and second.assessments.skipped >= 1, "An unchanged assessment is not sent again")
	# ---- patient lock
	var box: Array = []
	dash.claim("busy-patient", func(result): box.append(result))
	while box.is_empty(): await create_timer(0.05).timeout
	check(not box[0].granted and box[0].holder.get("client") == "OTHER-LAPTOP", "A patient held by another laptop is refused")
	check(dash.holder_text("busy-patient", box[0].holder).contains("PLUTO") and dash.holder_text("busy-patient", box[0].holder).contains("OTHER-LAPTOP"), "The refusal names who has the patient")
	check(dash.holding_patient == "", "Nothing is held after a refusal")
	box.clear()
	dash.claim("free-patient", func(result): box.append(result))
	while box.is_empty(): await create_timer(0.05).timeout
	check(box[0].granted and dash.holding_patient == "free-patient" and not dash.heartbeat.is_stopped(), "A free patient is claimed and the heartbeat starts")
	dash.release()
	await create_timer(0.5).timeout
	check(dash.holding_patient == "" and dash.heartbeat.is_stopped(), "Release stops the heartbeat")
	var requests = FileAccess.get_file_as_string(received.path_join("requests.log"))
	check(requests.contains("\"client_id\": \"TEST-LAPTOP\"") and requests.contains("\"device_id\": \"MARS\"") or requests.contains("\"client_id\":\"TEST-LAPTOP\""), "Requests carry the device and laptop identity")
	# ---- unreachable server
	dash.set_value("server_port", port + 1)
	dash.sync_patients()
	var down = await wait_for(dash.sync_finished, 30.0)
	check(down != null and not down.ok and down.message.contains("Could not reach"), "An unreachable server gives a clear message")
	box.clear()
	dash.claim("anyone", func(result): box.append(result))
	while box.is_empty(): await create_timer(0.05).timeout
	check(box[0].granted, "Therapy is never blocked when the server is unreachable")
	dash.release()
	OS.kill(pid)
	if settings.has_section("neurodash"): settings.erase_section("neurodash")
	for key in saved_section: settings.set_value("neurodash", key, saved_section[key])
	root.get_node("Services").save()
	print("NeuroDash: %d failures" % failures)
	quit(1 if failures else 0)
