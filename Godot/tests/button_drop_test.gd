extends SceneTree
# A button release that lowers the arm (drops the link) while its own packet is still being
# handled must not crash accept_packet.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func packet(button: int) -> Dictionary:
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[9] = 999
	return {"sensors": sensors, "force": 20.0, "calibration": 1, "control_type": 1, "limb": 1, "error": 0, "button": button, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}

func run() -> void:
	var robot = root.get_node("Robot")
	robot.connected = true
	robot.enabled = true
	robot.accept_packet(packet(0))
	robot.button_changed.connect(func(down):
		if not down: robot.disconnect_port(false))
	robot.accept_packet(packet(1))
	check(not robot.connected and robot.last_packet.is_empty(), "The link is dropped by the release")
	robot.accept_packet(packet(1))
	print("Button drop: %d failures" % failures)
	quit(1 if failures else 0)
