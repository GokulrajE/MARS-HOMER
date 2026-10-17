extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func snap(name:String)->void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/glass-"+name+".png")
func run()->void:
	var trial=root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/glass-"+str(Time.get_ticks_usec())
	trial.configure("glass")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await snap("home")
	var cycle=load("res://core/visual_cycle.gd")
	for code in trial.Rules.GAMES:
		launcher.launch(code)
		root.get_node("Nav").dismiss_tip()
		var g=launcher.game_node
		g.set_process(false)
		trial.rom=Vector2(.4,.2)
		trial.speed=.05
		var expected=.4 if trial.movement=="ML" else .2 if trial.movement=="AP" else .3
		check(is_equal_approx(trial.reach_time(),expected/.05),code+" uses physical ROM / speed")
		var light=cycle.lighting_time()
		trial.duration=45
		check(light==cycle.lighting_time(),code+" lighting remains fixed")
		trial.duration=5
		if code in ["TW","FW","BS"]:
			launcher.glass_controls.change_speed(.005)
			check(is_equal_approx(trial.speed,.05),code+" is patient paced")
		else:
			launcher.glass_controls.change_speed(.005)
			check(is_equal_approx(trial.speed,.055),code+" Unity manual step")
			launcher.glass_controls.change_speed(9)
			check(trial.speed==.25,code+" upper speed bound")
			launcher.glass_controls.change_speed(-9)
			check(trial.speed==.025,code+" lower speed bound")
		check(launcher.game_view.position==Vector2.ZERO,code+" full bleed")
		check(is_instance_valid(launcher.hud.stars_label),code+" compact stars HUD")
		if code in ["TT","FR"]: await snap(code)
		if code=="MC":
			var event=InputEventKey.new()
			event.ctrl_pressed=true
			event.keycode=KEY_G
			event.pressed=true
			launcher.glass_controls._input(event)
			check(launcher.glass_controls.panel.visible,"Ctrl+G opens shared panel")
			await snap("speed")
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	print("Glass and physical speed: %d failures" % failures)
	quit(1 if failures else 0)
