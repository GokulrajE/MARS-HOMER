extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/bheem-preview-"+str(Time.get_ticks_usec())
	trial.configure("preview")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("CB")
	root.get_node("Nav").dismiss_tip()
	var game=launcher.game_node
	game.set_process(false)
	game.sound_on=false
	trial.speed=.09
	game.step_game(.01,Vector2(380,450))
	for frame in 210:
		var dt=1.0/30.0
		game.clock+=dt
		var desired:Vector2=game.player.lerp(Vector2(380,game.target.y),.075)
		game.step_game(dt,desired)
		game.GameArt.tick(game,dt)
		trial.advance(dt,false,game.player/Vector2(1600,900),game.target/Vector2(1600,900))
		await process_frame
	trial.finish("TEST")
	quit()
