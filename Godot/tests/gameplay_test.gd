extends SceneTree
var failures=0
var trial: Node

func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	trial=root.get_node("Trial")
	trial.data_root="res://test-output/gameplay-"+str(Time.get_ticks_usec())
	trial.configure("gameplay")
	for code in ["DC","TW","PP","MC","TT","CB","SS"]:
		trial.select_game(code)
		trial.begin()
		var game=load("res://core/legacy_game.gd").new()
		root.add_child(game)
		game.set_process(false)
		game.sound_on=false
		game.spawn()
		game.age=0.5
		if code in ["DC"]:
			var point=game.target
			game.step_game(0.5,point)
			check(trial.hits==0,code+" cannot succeed before hold completes")
			game.step_game(0.01,Vector2.ZERO)
			check(game.hold==0,code+" leaving resets hold")
			for i in 110: game.step_game(0.01,point)
			check(trial.hits==1,code+" continuous hold awards one hit")
		elif code=="TW":
			var origin=game.wipe_origin
			var wipe_w=game.wipe_image.get_width()
			for y in range(0,game.wipe_image.get_height(),10): game.erase_stain(origin+Vector2(0,y),origin+Vector2(wipe_w-1,y))
			check(float(game.wipe_erased)/game.wipe_total>0.95,"Stain alpha erasure >95 percent")
			game.step_game(0.01,game.player)
			check(trial.hits==1,"Cleaned stain awards hit")
		elif code=="PP":
			game.player=Vector2(120,400)
			game.target=Vector2(141,400)
			game.pong_velocity=Vector2(-100,0)
			game.advance_pong(0.02)
			check(trial.hits==1 and game.pong_returning,"Paddle collision returns ball")
			game.target=Vector2(1459,400)
			game.pong_velocity=Vector2(100,0)
			game.advance_pong(0.02)
			check(trial.targets==2 and not game.pong_returning,"Opponent return creates next target")
		elif code=="MC":
			game.age=trial.reach_time()*0.84
			game.step_game(0.01,Vector2(game.balls[game.match_index].x,game.MC_BASKET_Y))
			check(trial.hits==1,"Matching colour caught")
		elif code in ["TT","CB"]:
			var gate_kind=game.visual_variant
			var y=game.target.y
			game.age=trial.reach_time()*game.GATE_TRAVEL-0.01
			game.step_game(0.01,Vector2(120,y))
			check(trial.hits==1,"Opening passed")
			check(game.player.x==380.0,"Reef fish is forward in the camera")
			check(game.passed_reefs.size()==1,"Scored reef stays visible after passing")
			check(game.passed_reefs[0].kind==gate_kind,"Passed gate preserves its appearance")
			var old_x=game.passed_reefs[0].x
			game.advance_passed_reefs(0.1)
			check(game.passed_reefs[0].x<old_x,"Passed reef continues left")
			check(trial.hits==1,"Decorative passed reef cannot score twice")
			game.advance_passed_reefs(100.0)
			check(game.passed_reefs.is_empty(),"Off-camera obstacles are removed")
			game.spawn()
			check(game.visual_variant!=gate_kind,"Next gate changes appearance")
		elif code=="SS":
			game.player=Vector2(500,730)
			for i in 5: game.step_game(0.1,Vector2(500,730))
			check(game.bullets.size()>0,"Stationary ship fires")
		if code == "DC":
			game.facing = 1.0
			game.previous = Vector2(900,400)
			game.player = Vector2(800,400)
			game.GameArt.tick(game, 1.0 / 60.0)
			check(game.facing < 1.0 and game.facing > -1.0, "Direction change interpolates")
			game.previous = game.player
			for frame in 20: game.GameArt.tick(game, 1.0 / 60.0)
			check(is_equal_approx(game.facing, -1.0), "Idle character retains left facing")
		trial.finish("TEST")
		game.queue_free()
		await process_frame
	print("MARS gameplay: %d failures" % failures)
	quit(1 if failures else 0)

