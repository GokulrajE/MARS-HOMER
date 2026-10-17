extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func capture(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func difference(a: Image,b: Image,rect: Rect2i,orange_only: bool=false) -> int:
	var changed = 0
	for y in range(rect.position.y,rect.end.y,2):
		for x in range(rect.position.x,rect.end.x,2):
			var c = a.get_pixel(x,y)
			var d = b.get_pixel(x,y)
			if orange_only and not (c.r > 0.5 and c.r > c.g*1.3 and c.g > c.b*1.2): continue
			if absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b)>0.09: changed+=1
	return changed
func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/bheem-motion-"+str(Time.get_ticks_usec())
	trial.configure("motion")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.launch("CB")
	root.get_node("Nav").dismiss_tip()
	var game = launcher.game_node
	game.sound_on=false
	await create_timer(0.25).timeout
	var a = await capture(launcher.viewport)
	a.save_png("res://test-output/bheem-motion-a.png")
	var start_clock = game.clock
	await create_timer(0.4).timeout
	var b = await capture(launcher.viewport)
	b.save_png("res://test-output/bheem-motion-b.png")
	var water_changes = difference(a,b,Rect2i(350,150,600,550))
	var fish_changes = difference(a,b,Rect2i(240,80,290,720),true)
	check(water_changes>300,"Water and scrolling scenery visibly change between frames")
	check(fish_changes>30,"Orange fish pixels visibly animate between frames")
	check(game.clock>start_clock,"Live process advances animation clock")
	game.paused=true
	game.queue_redraw()
	await process_frame
	var frozen_clock = game.clock
	var c = await capture(launcher.viewport)
	await create_timer(0.3).timeout
	var d = await capture(launcher.viewport)
	check(is_equal_approx(game.clock,frozen_clock),"Pause freezes animation clock")
	check(difference(c,d,Rect2i(0,80,1600,820))==0,"Water, fish, reef and bubbles all freeze on pause")
	game.paused=false
	await create_timer(0.15).timeout
	check(game.clock>frozen_clock,"Resume restarts animation")
	check(is_equal_approx(game.swim_sprite.material.get_shader_parameter("swim_clock"),game.clock),"Fish shader receives live clock")
	print("Bheem motion: %d failures; changed water samples %d, changed fish samples %d" % [failures,water_changes,fish_changes])
	trial.finish("TEST")
	quit(1 if failures else 0)
