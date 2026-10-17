extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rt2-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("PP")
	root.get_node("Nav").dismiss_tip()
	for i in 10: await process_frame
	var g = launcher.game_node
	g.set_process(false)
	g.sound_on = false
	g.spawn()
	g.pong_velocity = Vector2(-700, 260)
	g.target = Vector2(1000, 300)
	for i in 40:
		g.advance_pong(1.0/60.0)
		g.trail.append(g.target)
		if g.trail.size() > 24: g.trail.pop_front()
	g.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/pp-tail.png")
	quit()
