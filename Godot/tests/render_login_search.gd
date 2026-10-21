extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rls-" + str(Time.get_ticks_usec())
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await process_frame
	var login = launcher.screen
	login.id_edit.text = "ne"
	login.id_edit.text_changed.emit("ne")
	for i in 25: await process_frame
	root.get_node("Nav").dismiss_tip()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/login-search.png")
	quit()
