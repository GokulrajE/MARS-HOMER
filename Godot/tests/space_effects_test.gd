extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/space-effects-"+str(Time.get_ticks_usec())
	trial.configure("space-effects")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("SS")
	root.get_node("Nav").dismiss_tip()
	var game=launcher.game_node
	game.set_process(false)
	if not trial.target_open: game.spawn()
	check(game.space_blasts.size()==3,"All explosion variants load")
	check(game.shot_sound.stream.get_length()>.05,"Laser audio loads")
	for variant in 3:
		if not trial.target_open: game.spawn()
		game.target=Vector2(800,400)
		game.visual_variant=variant
		var hits=trial.hits
		game.resolve(true)
		check(trial.hits==hits+1,"Destruction scores exactly once")
		check(game.sound.playing,"Explosion audio starts on destruction")
		check(game.sound.stream==game.space_blasts[variant],"Audio matches asteroid variant")
		check(game.fx.list.filter(func(e): return e.kind=="space_fragment").size()==14,"Fourteen debris fragments")
		for frame in 35:
			game.fx.update(1.0/30)
			game.clock+=1.0/30
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if variant==0 and frame==4:
				launcher.viewport.get_texture().get_image().save_png("res://test-output/space-destruction.png")
		check(game.fx.list.is_empty(),"Explosion particles expire completely")
	game.sound.play()
	game.shot_sound.play()
	game.paused=true
	game._process(0)
	check(game.sound.stream_paused and game.shot_sound.stream_paused,"Pause freezes both audio players")
	game.paused=false
	game.sound_on=false
	game._process(0)
	check(game.sound.stream_paused and game.shot_sound.stream_paused,"Mute affects both audio players")
	game.sound_on=true
	game._process(0)
	check(not game.sound.stream_paused,"Resume restores audio")
	trial.finish("TEST")
	check(not game.sound.playing and not game.shot_sound.playing,"Trial end stops audio")
	print("Space effects: %d failures" % failures)
	quit(1 if failures else 0)

