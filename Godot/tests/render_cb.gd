extends SceneTree
func shot(name: String) -> void:
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/cb-" + name + ".png")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rcb-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for n in 3:
		launcher.launch("CB")
		root.get_node("Nav").dismiss_tip()
		if n == 2: launcher.glass_controls.panel.show()
		await shot(str(n + 1))
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	quit()
