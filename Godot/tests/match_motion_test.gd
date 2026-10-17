extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func capture(view:SubViewport)->Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func difference(a:Image,b:Image,rect:Rect2i)->int:
	var count=0
	for y in range(rect.position.y,rect.end.y,3):
		for x in range(rect.position.x,rect.end.x,3):
			var c=a.get_pixel(x,y)
			var d=b.get_pixel(x,y)
			if absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b)>.09: count+=1
	return count
func run()->void:
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/match-motion-"+str(Time.get_ticks_usec())
	trial.configure("match-motion")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("MC")
	root.get_node("Nav").dismiss_tip()
	var game=launcher.game_node
	game.sound_on=false
	await create_timer(.2).timeout
	game.set_process(false)
	game.player=Vector2(800,730)
	game.visual_tilt=0.0
	game.balls.assign([Vector2(320,350),Vector2(640,420),Vector2(960,300),Vector2(1280,380)])
	game.queue_redraw()
	var a=await capture(launcher.viewport)
	a.save_png("res://test-output/match-updated.png")
	game.clock+=.7
	game.visual_tilt=.22
	game.queue_redraw()
	var b=await capture(launcher.viewport)
	check(difference(a,b,Rect2i(0,180,1600,520))>100,"Garden and ball highlights animate")
	check(difference(a,b,Rect2i(680,630,240,175))>80,"Basket visibly leans during movement")
	var caught=game.color_index
	game.resolve(true)
	check(game.match_caught_color==caught,"Catch animation retains captured colour")
	game.catch_pose=.32
	game.queue_redraw()
	var c=await capture(launcher.viewport)
	c.save_png("res://test-output/match-catch.png")
	check(difference(b,c,Rect2i(680,630,240,175))>100,"Catch visibly compresses basket and drops ball")
	game.set_process(true)
	game.paused=true
	game.queue_redraw()
	var d=await capture(launcher.viewport)
	var frozen=game.clock
	await create_timer(.25).timeout
	var e=await capture(launcher.viewport)
	check(game.clock==frozen,"Pause freezes clock")
	check(difference(d,e,Rect2i(0,80,1600,820))==0,"Pause freezes scenery and effects")
	trial.finish("TEST")
	print("Match animation: %d failures" % failures)
	quit(1 if failures else 0)

