extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rbs-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("BS")
	root.get_node("Nav").dismiss_tip()
	for i in 20: await process_frame
	var bs = launcher.game_node
	bs.sound_on = false
	bs.pop_bubble()
	for k in 3:
		for i in 14: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/bs-pop-%d.png" % k)
	quit()
