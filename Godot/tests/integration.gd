extends SceneTree
var failures = 0
var trial: Node

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	trial = root.get_node("Trial")
	trial.data_root = "res://test-output/" + str(Time.get_ticks_usec())
	check(trial.configure("integration"),"Create test user")
	var rules = load("res://core/rules.gd")
	check(is_equal_approx(rules.reach_duration("ML",0.1,Vector2(0.4,0.2)),4),"ML timing")
	check(is_equal_approx(rules.reach_duration("AP",0.1,Vector2(0.4,0.2)),2),"AP timing")
	check(is_equal_approx(rules.reach_duration("MLAP",0.1,Vector2(0.4,0.2)),3),"MLAP timing")
	check(rules.adapt(0.1,79)<0.1,"Reduce below 80 percent")
	check(rules.adapt(0.1,80)==0.1 and rules.adapt(0.1,90)==0.1,"Keep speed within success band")
	check(rules.adapt(0.1,91)>0.1,"Increase above 90 percent")
	check(rules.adapt(0.025,0)==0.025 and rules.adapt(0.25,100)==0.25,"Speed clamps")
	trial.select_game("FR")
	check(trial.begin(),"Begin persistence test")
	trial.appear(Vector2.ONE/2)
	trial.resolve(true)
	trial.resolve(true)
	check(trial.hits==1,"Resolve once")
	trial.advance(5,true,Vector2.ZERO,Vector2.ONE)
	check(trial.duration==0,"Pause freezes trial")
	trial.advance(61,false,Vector2.ZERO,Vector2.ONE)
	check(not trial.running and trial.duration==60,"Trial ends exactly at 60 seconds")
	check(trial.history.size()==1,"One summary row")
	check(trial.finish() and trial.history.size()==1,"Finish idempotent")
	var last_speed = trial.speed
	check(trial.configure("integration"),"Reload user")
	trial.select_game("FR")
	check(is_equal_approx(trial.speed,last_speed),"Adapted speed restored from CSV")
	check(trial.session==2,"Session numbering survives restart")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for code in rules.GAMES:
		launcher.launch(code)
		await process_frame
		check(trial.running,"Launch " + code)
		var game = launcher.game_node
		game.set_process(false)
		for frame in 120: game._process(1.0/60.0)
		check(trial.targets>0,"Target registered " + code)
		var before = trial.duration
		launcher.toggle_pause()
		game._process(1.0)
		check(is_equal_approx(trial.duration,before),"Pause " + code)
		launcher.toggle_pause()
		if code == "FR":
			game.player = game.fish
			game.resolve_player(game.dwell_seconds)
			check(trial.hits==1,"Fish rescue hold records a hit")
			game.spawn_fish()
			game.target_remaining = 0
			game.rival = game.fish
			game.advance_rival(0.01)
			check(trial.misses==1,"Shark removal records one miss")
			game.advance_rival(0.01)
			check(trial.misses==1,"Shark miss cannot be counted twice")
		elif code == "BS":
			game.sound_on = false
			game.pop_bubble()
			check(trial.hits==1,"Bubble hit registered")
			game.cooldown = 0
			game.pointer_visible = false
			game.target_age = trial.reach_time()
			game._process(0.01)
			check(trial.misses==0 and trial.target_open,"Bubble waits for collection without timeout")
		elif code == "FW":
			game.sound_on = false
			game.ignite()
			check(trial.hits==1,"Firework ignition registered")
			game.spawn_target()
			game.cooldown = 0
			game.target_age = trial.reach_time()
			game._process(0.01)
			check(trial.misses==0 and trial.target_open,"Fireworks waits for patient completion without a speed timeout")
		trial.advance(100,false,Vector2.ZERO,Vector2.ONE)
		check(not trial.running,"Timed completion " + code)
		await process_frame
		await process_frame
		launcher.show_menu()
		await process_frame
	check(trial.history.size()==rules.GAMES.size()+1,"Every game saved once")
	var file = FileAccess.open(trial.user_path().path_join("sessions/sessions.csv"),FileAccess.READ)
	for i in 3: file.get_line()
	check(file.get_csv_line().size()==24,"Session header width")
	var rows = 0
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size()==1 and row[0]=="": continue
		check(row.size()==24,"Session row width")
		rows += 1
		var raw = FileAccess.open(trial.user_path().path_join("rawdata/"+row[23]),FileAccess.READ)
		check(raw!=null,"Raw file exists")
		if raw:
			for i in 10: raw.get_line()
			check(raw.get_csv_line().size()==36,"Raw header width")
			check(raw.get_csv_line().size()==36,"Raw row width")
	check(rows==rules.GAMES.size()+1,"CSV row count")
	launcher.queue_free()
	await process_frame
	print("MARS integration: %d failures" % failures)
	quit(1 if failures else 0)
