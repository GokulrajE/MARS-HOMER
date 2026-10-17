extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rpl-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_choose()
	launcher.open_training_plane()
	await process_frame
	var editor = launcher.screen
	editor.angle.value = -70
	editor.apply_plane()
	await create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/plane-saved.png")
	editor.closed.emit()
	for i in 12: await process_frame
	var shown = root.get_node("Nav").toast.visible
	print("TOAST ", shown, " ", root.get_node("Nav").toast_label.text)
	quit()
