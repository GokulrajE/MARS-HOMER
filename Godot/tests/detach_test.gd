extends SceneTree
# In the arm-detachment scene the MARS button only ever disconnects, even if telemetry is
# unhealthy (stale or error flag); it must never start a new connection.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var robot = root.get_node("Robot")
	var trial = root.get_node("Trial")
	trial.hardware = true
	for case in ["stale telemetry", "robot error flag", "link already gone"]:
		var setup = load("res://core/guided_setup.gd").new()
		setup.shutdown = true
		root.add_child(setup)
		await process_frame
		var sensors = []
		sensors.resize(12)
		sensors.fill(0.0)
		sensors[9] = 999
		robot.last_packet = {"sensors": sensors, "force": 0.0, "calibration": 1, "control_type": 1, "limb": 1, "error": 1 if case == "robot error flag" else 0, "button": 1, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}
		robot.connected = case != "link already gone"
		robot.last_seen = Time.get_ticks_msec() - (5000 if case == "stale telemetry" else 0)
		robot.enabled = false
		setup.state = setup.REMOVE
		setup._process(0.0)
		check(not setup.connect_row.visible, case + ": no connect row while lowering the arm")
		setup.primary()
		check(setup.state == setup.OFF and not robot.enabled and not robot.connected, case + ": the button only disconnects")
		setup.queue_free()
		await process_frame
	trial.hardware = false
	print("Detach: %d failures" % failures)
	quit(1 if failures else 0)
