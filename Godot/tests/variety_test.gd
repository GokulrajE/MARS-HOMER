extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1; push_error(message)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var cycle=load("res://core/visual_cycle.gd")
	check(cycle.stage(0)==0 and cycle.stage(20)==1 and cycle.stage(40)==2,"Three lighting stages")
	for i in 15: check(cycle.variant(i)!=cycle.variant(i+1),"No adjacent visual repeat")
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/variety-"+str(Time.get_ticks_usec())
	trial.configure("variety")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for code in load("res://core/rules.gd").GAMES:
		launcher.launch(code)
		root.get_node("Nav").dismiss_tip()
		var game=launcher.game_node
		game.set_process(false)
		for seconds in [5.0,25.0,45.0]:
			trial.duration=seconds
			if code in ["TT","CB","SS","MC","PP","TW","DC"]:
				game.clock=seconds
				game.visual_variant=int(seconds/20)%3
				if not trial.target_open: game.spawn()
				game.visual_variant=int(seconds/20)%3
				game.player=Vector2(380,450) if code in ["TT","CB"] else game.player
				game.target=Vector2(1050,450) if code in ["TT","CB"] else game.target
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-output/variety-%s-%d.png" % [code,seconds])
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	print("Variety checks: %d failures" % failures)
	quit(1 if failures else 0)
