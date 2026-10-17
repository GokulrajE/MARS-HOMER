extends SceneTree
func shot(name: String) -> void:
	root.get_node("Nav").dismiss_tip()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/new-" + name + ".png")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rn-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await shot("login")
	launcher.screen.set_mode(true)
	launcher.screen.error.text = "The two passwords do not match."
	await shot("create")
	launcher.show_menu()
	launcher.launch("PP")
	for i in 15: await process_frame
	var g = launcher.game_node
	g.set_process(false)
	g.sound_on = false
	g.pong_easy = true
	g.spawn()
	g.target = Vector2(1000, 640)
	g.pong_velocity = Vector2(-700, -260)
	g.queue_redraw()
	await shot("pp-easy")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	launcher.launch("DC")
	for i in 15: await process_frame
	var dc = launcher.game_node
	dc.set_process(false)
	dc.age = 0.5 + trial.reach_time() * 0.6
	dc.queue_redraw()
	await shot("dc-time")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	launcher.launch("FR")
	for i in 15: await process_frame
	var fr = launcher.game_node
	fr.set_process(false)
	fr.target_remaining = fr.target_seconds * 0.55
	fr.queue_redraw()
	await shot("fr-time")
	quit()
