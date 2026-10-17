extends SceneTree
# Holding on a target in Fish Rescue, Diamond Catcher and Fireworks (rings / progress).
func shot(name: String) -> void:
	root.get_node("Nav").dismiss_tip()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/hold-" + name + ".png")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rh3-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("FR")
	for i in 20: await process_frame
	var fr = launcher.game_node
	fr.player = fr.fish
	fr.dwell = 1.4
	fr.set_process(false)
	fr.queue_redraw()
	await shot("FR")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	await process_frame
	launcher.launch("DC")
	for i in 20: await process_frame
	var dc = launcher.game_node
	dc.set_process(false)
	dc.sound_on = false
	dc.age = 3.0
	dc.hold = 0.55
	dc.queue_redraw()
	await shot("DC")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	await process_frame
	launcher.launch("FW")
	for i in 20: await process_frame
	var fw = launcher.game_node
	fw.player_x = fw.target_x
	fw.desired_x = fw.target_x
	fw.charge = 0.5
	await shot("FW")
	quit()
