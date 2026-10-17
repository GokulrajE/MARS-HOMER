extends SceneTree
# Changing the training plane on a device must move the robot first, even for a small change,
# and only save once the robot has really arrived.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fake(robot: Node, angle: float) -> void:
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[0] = angle
	sensors[9] = 999
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"sensors": sensors, "force": 20.0, "calibration": 1, "control_type": 1, "limb": 1, "error": 0, "button": 1, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}

func run() -> void:
	var trial = root.get_node("Trial")
	var robot = root.get_node("Robot")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/pm-" + str(Time.get_ticks_usec())
	trial.configure("planemove")
	trial.hardware = true
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	fake(robot, -90.0)
	launcher.show_choose()
	launcher.open_training_plane()
	var editor = launcher.screen
	editor.angle.value = -85
	robot.recent_commands.clear()
	var before = trial.plane
	editor.apply_plane()
	check(trial.plane == before, "A small change is not saved before the robot has moved")
	check(robot.recent_commands.any(func(c): return c.size() > 0 and c[0] == 7), "The robot is commanded to the new plane")
	editor._process(0.0)
	check(editor.apply.text.begins_with("Moving"), "The button shows that it is moving")
	fake(robot, -85.5)
	editor._process(0.0)
	check(editor.apply.text.begins_with("Save plane"), "Once it has arrived the button offers to save")
	editor.apply_plane()
	check(is_equal_approx(trial.plane, -85.0), "The plane is saved after arrival")
	print("Plane move: %d failures" % failures)
	quit(1 if failures else 0)
