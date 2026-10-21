extends SceneTree
# An angle-limit (or any non-heartbeat) error, or a lost link, raises the panel; the MARS button is
# locked while it is up; it clears itself; hold / Close finishes and saves.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func packet(error: int) -> Dictionary:
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[9] = 999
	return {"status": 19, "command_status": 0, "sensors": sensors, "force": 20.0, "calibration": 1, "control_type": 1, "limb": 1, "error": error, "button": 1, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}

func run() -> void:
	var trial = root.get_node("Trial")
	var robot = root.get_node("Robot")
	var nav = root.get_node("Nav")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/ep-" + str(Time.get_ticks_usec())
	trial.configure("errorpanel")
	trial.hardware = true
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	var panel = launcher.error_panel
	var closed: Array = []
	panel.close_requested.connect(func(): closed.append(true))
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = packet(0)
	panel._process(0.1)
	check(not panel.shown, "No panel while the robot is fine")
	robot.last_packet = packet(1)
	panel._process(0.1)
	check(not panel.shown, "A lone NOHEARTBEAT does not raise the panel (as in Unity)")
	robot.last_packet = packet(32) # ANG1LIMITERR
	panel._process(0.1)
	check(panel.shown and panel.title.text == "Device has issue" and panel.body.text.contains("engineers"), "An angle-limit error raises the panel")
	check(panel.detail.text.contains("ANG1LIMITERR"), "The panel names the error")
	var before = nav.primary
	nav.do_short()
	check(nav.lock.is_valid(), "The MARS button is locked while the panel is up")
	robot.last_packet = packet(0)
	panel._process(0.5)
	check(panel.shown, "It stays briefly after the error clears")
	panel._process(0.6)
	check(not panel.shown and not nav.lock.is_valid(), "It clears itself once the error is gone")
	robot.last_packet = packet(32)
	panel._process(0.1)
	nav.do_long()
	check(closed.size() == 1 and not panel.shown, "Holding the button closes the panel and asks to finish")
	robot.last_packet = packet(0)
	robot.link_lost = true
	panel._process(0.1)
	check(panel.shown and panel.title.text == "MARS disconnected", "A lost link raises the panel")
	robot.accept_packet(packet(0))
	check(not robot.link_lost, "A fresh packet clears the lost-link state")
	panel.hide_panel()
	trial.hardware = false
	panel._process(0.1)
	check(not panel.shown, "Simulation mode never shows the panel")
	print("Error panel: %d failures" % failures)
	quit(1 if failures else 0)
