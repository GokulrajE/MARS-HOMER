extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rw-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	records.save_profile({"HomerID":"demo","StartDate":"01-10-2026 00:00:00","EndDate":"31-12-2026 23:59:59","ML":"10","AP":"8","MLAP":"12","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"","Group":"Experimental"})
	# A week of history: copy a saved row and re-date it.
	var stats = load("res://core/stats.gd")
	trial.select_game("SS")
	trial.begin()
	trial.advance(60, false, Vector2.ZERO, Vector2.ZERO)
	var template = trial.history[-1].duplicate()
	trial.history.clear()
	var plan = [[6, 14], [5, 28], [4, 0], [3, 31], [2, 22], [1, 36], [0, 14]]
	for entry in plan:
		if entry[1] == 0: continue
		var row = template.duplicate()
		row[4] = stats.date_string(-entry[0]) + " 10:00:00"
		row[1] = row[4]
		row[7] = "ML" if entry[0] % 2 == 0 else "MLAP"
		row[14] = str(entry[1] * 60.0)
		trial.history.append(row)
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for i in 6: await process_frame
	launcher.show_menu()
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/welcome-new.png")
	var w = launcher.menu.week
	print("WEEK today ", w.today_done, "/", w.today_plan, " streak ", w.streak, " week ", w.week_total)
	quit()
