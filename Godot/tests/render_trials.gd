extends SceneTree
# Same game played three times in a row, to see the scenery and lighting change.
func shot(name: String) -> void:
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/trial-" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rt-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await shot("welcome")
	for code in ["MC", "TW"]:
		for n in 1:
			launcher.launch(code)
			root.get_node("Nav").dismiss_tip()
			await shot("%s-%d" % [code, n + 1])
			trial.finish("TEST")
			await process_frame
			launcher.show_menu()
			await process_frame
	var cast = load("res://core/flight_characters.gd")
	for id in cast.CAST:
		cast.forced = id
		launcher.launch("CB")
		root.get_node("Nav").dismiss_tip()
		await shot("CB-" + id)
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	quit()
