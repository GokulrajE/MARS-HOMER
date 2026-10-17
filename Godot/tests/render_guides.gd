extends SceneTree
# Reference videos with the guide overlay, captured at several moments of each clip.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rg2-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_choose()
	await process_frame
	var shot_index = 0
	for movement in ["ML", "AP", "MLAP"]:
		launcher.screen.choose(movement)
		for i in 20: await process_frame
		for k in 3:
			await create_timer(1.1 if movement == "AP" else 2.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/guide-%s-%d.png" % [movement, k])
	quit()
