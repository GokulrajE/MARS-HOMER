extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	var robot = root.get_node("Robot")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rep-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	trial.hardware = true
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[9] = 999
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"status": 19, "sensors": sensors, "force": 20.0, "calibration": 1, "control_type": 1, "limb": 1, "error": 32, "button": 1, "runtime": 1.0, "number": 1, "kind": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}
	for i in 20: await process_frame
	root.get_node("Nav").dismiss_tip()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/error-panel.png")
	quit()
