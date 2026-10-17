extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var cast=load("res://core/flight_characters.gd")
	var motion=load("res://core/flight_animation.gd")
	var trial=root.get_node("Trial")
	var services=root.get_node("Services")
	var previous=services.settings.get_value("flight","character","bheem")
	services.settings.set_value("ui","tutorial_done",true)
	trial.data_root="res://test-output/characters-"+str(Time.get_ticks_usec())
	trial.configure("cast")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_choose()
	launcher.screen.pick_character()
	await process_frame
	var picker=launcher.screen.get_child(launcher.screen.get_child_count()-1)
	root.get_node("Nav").dismiss_tip()
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/characters-picker.png")
	check(picker.buttons.size()==6,"Six selectable characters")
	picker.select("bean")
	check(picker.selected=="bean","Selection works")
	picker.cancelled.emit()
	await process_frame
	for id in cast.CAST:
		cast.forced=id
		launcher.launch("CB")
		var game=launcher.game_node
		await create_timer(.15).timeout
		check(game.character_id==id,"Selected character loaded: "+id)
		var base=motion.pose(id,2.0,0,0,cast.CAST[id])
		var success=motion.pose(id,2.0,.5,0,cast.CAST[id])
		check(base!=success,"Distinct success pose: "+id)
		game.paused=true
		await create_timer(.05).timeout
		await create_timer(.1).timeout
		game.paused=false
		await create_timer(.05).timeout
		game.set_process(false)
		game.clock=3.2
		game.player=Vector2(380,450)
		game.target=Vector2(1100,450)
		game.catch_pose=.5
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-output/character-"+id+".png")
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	cast.forced=""
	var seen=[]
	var last_id=""
	for i in 40:
		var id=cast.next_character()
		check(id!=last_id,"Random pilot never repeats back to back")
		last_id=id
		if not seen.has(id): seen.append(id)
	check(seen.size()==6,"Every pilot appears at random")
	var kinds=[]
	for id in cast.CAST: kinds.append(cast.CAST[id].target)
	for kind in kinds: check(kinds.count(kind)==1,"Each pilot has their own collectible: "+kind)
	services.settings.set_value("flight","character",previous)
	services.save()
	print("Character tests: %d failures" % failures)
	quit(1 if failures else 0)
