extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/capsule-" + name + ".png")
func run() -> void:
	var robot = root.get_node("Robot")
	var nav = root.get_node("Nav")
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rc2-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await shot("off")
	var ok = nav.capsule_label.text == "0 Hz"
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"sensors": [], "error": 0, "calibration": 1, "control_type": 1}
	for i in 100: nav.arrivals.append(Time.get_ticks_msec())
	await shot("on")
	ok = ok and nav.capsule_label.text == "100 Hz"
	robot.last_seen = Time.get_ticks_msec() - 5000
	nav.arrivals.clear()
	for i in 3: await process_frame
	ok = ok and nav.capsule_state == 1
	robot.last_seen = Time.get_ticks_msec()
	for i in 100: nav.arrivals.append(Time.get_ticks_msec())
	launcher.launch("MC")
	nav.dismiss_tip()
	trial.hits = 3
	trial.targets = 10
	trial.duration = 22.0
	await shot("game")
	print("Capsule: ", "PASS" if ok else "FAIL")
	quit()
