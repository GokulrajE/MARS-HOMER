extends SceneTree
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var trial=root.get_node("Trial")
	var services=root.get_node("Services")
	var saved=services.settings.get_value("flight","character","bheem")
	services.settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/cast-preview-"+str(Time.get_ticks_usec())
	trial.configure("cast-preview")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for id in load("res://core/flight_characters.gd").CAST:
		services.settings.set_value("flight","character",id)
		launcher.launch("CB")
		root.get_node("Nav").dismiss_tip()
		var game=launcher.game_node
		game.set_process(false)
		trial.speed=.18
		game.step_game(.01,Vector2(380,450))
		for frame in 90:
			var dt=1.0/30.0
			game.clock+=dt
			game.step_game(dt,game.player.lerp(Vector2(380,game.target.y),.12))
			game.GameArt.tick(game,dt)
			trial.advance(dt,false,game.player/Vector2(1600,900),game.target/Vector2(1600,900))
			await process_frame
		trial.finish("TEST")
		await process_frame
		await process_frame
		launcher.show_menu()
		await process_frame
	services.settings.set_value("flight","character",saved)
	services.save()
	quit()
