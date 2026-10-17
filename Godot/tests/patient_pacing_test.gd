extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var trial=root.get_node("Trial")
	trial.data_root="res://test-output/pacing-"+str(Time.get_ticks_usec())
	trial.configure("pacing")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("SS")
	var g=launcher.game_node
	g.set_process(false)
	g.sound_on=false
	g.spawn()
	g.player=Vector2(600,730)
	for i in 20: g.step_game(.02,g.player+Vector2(2,0))
	check(g.bullets.is_empty(),"Moving ship never fires")
	for i in 10: g.step_game(.02,g.player)
	check(g.bullets.is_empty(),"Brief stop does not fire")
	for i in 6: g.step_game(.02,g.player)
	check(g.bullets.size()==1,"Stable hold fires once")
	for i in 15: g.step_game(.02,g.player)
	check(g.bullets.size()==1,"Shots are spaced by at least 0.65 seconds")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	launcher.launch("PP")
	g=launcher.game_node
	g.set_process(false)
	g.sound_on=false
	g.spawn()
	g.target=Vector2(800,173)
	g.pong_velocity=Vector2(-100,-60)
	g.advance_pong(.01)
	check(g.pong_velocity.y>0,"Top contact reflects inward")
	g.advance_pong(.01)
	check(g.pong_velocity.y>0,"Next frame does not reflect or sound again")
	g.player=Vector2(120,400)
	g.target=Vector2(141,495)
	g.pong_velocity=Vector2(-100,0)
	g.pong_easy=true
	g.advance_pong(.02)
	check(trial.hits==1,"Easy paddle catches beyond normal paddle range")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	launcher.launch("FW")
	g=launcher.game_node
	g.set_process(false)
	g.sound_on=false
	var speed=trial.speed
	launcher.glass_controls.change_speed(.05)
	check(trial.speed==speed,"Fireworks has no speed adjustment")
	g.target_age=100
	g.player_x=100
	g.desired_x=100
	g.target_x=1200
	g._process(.01)
	check(trial.target_open and trial.misses==0,"Patient-paced firework never times out")
	var before=trial.targets
	g.kind=1
	g.ignite()
	check(not trial.target_open and trial.targets==before,"Ignition does not spawn overlapping targets")
	for i in 60: g._process(.04)
	check(not trial.target_open,"Fountain finishes before another target appears")
	for i in 200: g._process(.04)
	check(trial.target_open and trial.targets==before+1,"Exactly one next target after effects finish")
	check(g.particles.size()<=650,"Firework particle budget is bounded")
	trial.finish("TEST")
	check(trial.history[-1][10]=="0","Fireworks stores zero reach speed")
	await process_frame
	launcher.show_menu()
	launcher.launch("TW")
	g=launcher.game_node
	g.set_process(false)
	g.spawn()
	speed=trial.speed
	launcher.glass_controls.change_speed(.05)
	check(trial.speed==speed,"Table Wiping has no speed adjustment")
	before=trial.targets
	g.step_game(20,g.player)
	check(trial.targets==before and trial.target_open,"Unfinished stain stays until cleaned")
	var dirt=load("res://core/dirt_sprites.gd")
	check(dirt.make(0).get_data()!=dirt.make(1).get_data() and dirt.make(1).get_data()!=dirt.make(2).get_data(),"Three distinct dirt silhouettes")
	trial.finish("TEST")
	print("Patient pacing: %d failures" % failures)
	quit(1 if failures else 0)
