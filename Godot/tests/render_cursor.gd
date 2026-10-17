extends SceneTree
# Sweeps a synthetic mouse across the home screen to capture the shooting-star trail.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rc-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for i in 18:
		var t = i / 17.0
		var pos = Vector2(260 + 760 * t, 640 - 360 * sin(t * PI * 0.9))
		var event = InputEventMouseMotion.new()
		event.position = pos
		event.global_position = pos
		launcher.glass_controls._input(event)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/cursor-trail.png")
	quit()
