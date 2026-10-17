extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	root.get_node("Nav").dismiss_tip()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/rings-" + name + ".png")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rrs-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("FR")
	for i in 15: await process_frame
	var fr = launcher.game_node
	fr.set_process(false)
	var t = fr.target_seconds
	print("FR target seconds ", t, " reach ", trial.reach_time(), " dwell ", fr.dwell_seconds)
	for part in [0.9, 0.5, 0.15]:
		fr.target_remaining = t * part
		fr.queue_redraw()
		await shot("fr-%d" % int(part * 100))
	fr.player = fr.fish
	fr.dwell = 0.5
	fr.queue_redraw()
	await shot("fr-hold")
	quit()
