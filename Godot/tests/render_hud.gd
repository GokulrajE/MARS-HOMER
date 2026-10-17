extends SceneTree
# One screenshot per game with the shared compact HUD, to check for overlaps.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rh-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for code in trial.Rules.GAMES:
		launcher.show_menu()
		await process_frame
		launcher.launch(code)
		root.get_node("Nav").dismiss_tip()
		for i in 50: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/hud-" + code + ".png")
		trial.finish("TEST")
		await process_frame
	quit()
