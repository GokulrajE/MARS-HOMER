extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/journey-"+str(Time.get_ticks_usec())
	trial.configure("journey")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("CB")
	root.get_node("Nav").dismiss_tip()
	var game=launcher.game_node
	game.set_process(false)
	game.sound_on=false
	game.step_game(.1,Vector2(380,450))
	game.target=Vector2(1050,450)
	for time in [10.0,26.0,46.0]:
		game.clock=time
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/bheem-flight-%d.png" % time)
	trial.finish("TEST")
	quit()
