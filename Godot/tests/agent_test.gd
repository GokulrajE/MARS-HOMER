extends SceneTree
# The app detects agent.py by itself and talks to it: /start at login, /trial-ended after a trial,
# /stop at logout; a refused patient (409) cannot log in.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func requests(path: String) -> Array:
	if not FileAccess.file_exists(path): return []
	return Array(FileAccess.get_file_as_string(path).replace("\r", "").split("\n", false))

func run() -> void:
	var services = root.get_node("Services")
	var trial = root.get_node("Trial")
	var dash = root.get_node("NeuroDash")
	var base = ProjectSettings.globalize_path("res://test-output/ag-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(base)
	var log_path = base.path_join("agent.log")
	var port = randi_range(30000, 45000)
	var pid = OS.create_process("python", [ProjectSettings.globalize_path("res://tests/fake_agent.py"), str(port), log_path])
	services.agent_port = port
	services.agent_enabled = false
	services.agent_available = false
	trial.hardware = true
	trial.data_root = "res://test-output/ag-data-" + str(Time.get_ticks_usec())
	trial.configure("agentuser")
	var started = false
	for i in 50:
		await create_timer(0.2).timeout
		await services.probe_agent()
		if services.agent_available:
			started = true
			break
	check(started, "agent.py is detected automatically (no switch needed)")
	var cfg = dash.config()
	check(cfg.device == "NOARK" and cfg.client == "fake", "Uploads use the agent's own device and laptop names: " + str([cfg.device, cfg.client]))
	var results: Array = []
	services.session_checked.connect(func(allowed, message): results.append([allowed, message]))
	services.login("agentuser")
	for i in 40:
		await create_timer(0.1).timeout
		if not results.is_empty(): break
	check(not results.is_empty() and results[0][0], "A free patient may log in")
	check(requests(log_path).has("/start?patient=agentuser"), "Login sends /start: " + str(requests(log_path)))
	results.clear()
	services.login("busy-patient")
	for i in 40:
		await create_timer(0.1).timeout
		if not results.is_empty(): break
	check(not results.is_empty() and not results[0][0] and results[0][1].contains("another device"), "A patient in use elsewhere is refused: " + str(results))
	# A refused patient stays blocked; a re-check of a "lost" flag clears it when the server agrees.
	check(services.session_lost, "A refusal keeps the session blocked")
	services.session_lost = true
	results.clear()
	services.login("agentuser")
	for i in 40:
		await create_timer(0.1).timeout
		if not results.is_empty(): break
	check(not services.session_lost and results[0][0], "A false 'lost' flag is cleared by re-checking with the server")
	await services.trial_ended()
	check(requests(log_path).has("/trial-ended"), "A finished trial sends /trial-ended")
	await services.logout()
	check(requests(log_path).has("/stop"), "Logout sends /stop")
	check(dash.holding_patient == "", "The built-in lock client stayed out of it")
	OS.kill(pid)
	services.agent_port = 5055
	services.agent_available = false
	trial.hardware = false
	print("Agent: %d failures" % failures)
	quit(1 if failures else 0)
