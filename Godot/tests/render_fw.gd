extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rfw-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("FW")
	root.get_node("Nav").dismiss_tip()
	for i in 10: await process_frame
	var fw = launcher.game_node
	fw.sound_on = false
	fw.spawn_target()
	fw.kind = 1
	fw.variant = 1
	fw.target_x = 1280.0
	fw.ignite()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/fw-lit.png")
	print("lit at ", fw.lit_fountains.size(), " new target x ", fw.target_x)
	quit()
