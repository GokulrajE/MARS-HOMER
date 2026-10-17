extends SceneTree
# Per-trial lighting/scenery rotation, and a new target the moment one is achieved.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	var cycle = load("res://core/visual_cycle.gd")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/instant-" + str(Time.get_ticks_usec())
	trial.configure("instant")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	# Lighting and scenery change on every new trial of the same game and cover all combinations.
	for code in ["SS", "MC", "PP", "DC", "TW", "TT", "CB", "FR", "BS", "FW"]:
		var combos: Dictionary = {}
		var last = ""
		for i in 9:
			trial.game = code
			cycle.note_trial(code)
			var key = "%d/%d" % [int(cycle.lighting_time()), cycle.look()]
			check(key != last, code + " differs from the previous trial")
			last = key
			combos[key] = true
		check(combos.size() == (3 if code=="FW" else 9), code + " uses every lighting/scenery combination over nine trials")
	# A hit brings the next target at once.
	var legacy = {"MC": 1.0, "DC": 0.5, "SS": 0.0, "TT": 0.0, "CB": 0.0}
	for code in legacy:
		launcher.launch(code)
		await process_frame
		var game = launcher.game_node
		game.set_process(false)
		game.sound_on = false
		game.spawn()
		var before = trial.targets
		game.resolve(true)
		check(not trial.target_open, code + " target closes on a hit")
		game.step_game(0.001, game.player)
		check(trial.target_open and trial.targets == before + 1, code + " next target appears on the very next frame")
		trial.finish("TEST")
		await process_frame
		launcher.show_menu()
		await process_frame
	# Fireworks pacing is covered by patient_pacing_test: wait for the display to finish.
	# Bubble Sparkle: the next bubble grows in straight away at a new place.
	launcher.launch("BS")
	await process_frame
	var bs = launcher.game_node
	bs.sound_on = false
	bs._process(0.01)
	var old_position = bs.target
	bs.pop_bubble()
	check(bs.cooldown == 0.0 and bs.target != old_position, "Bubble Sparkle places the next bubble immediately")
	bs._process(0.01)
	check(trial.target_open, "Bubble Sparkle opens the next target")
	trial.finish("TEST")
	await process_frame
	launcher.show_menu()
	await process_frame
	# Fish Rescue: the rescued fish swims home while the next one is already waiting.
	launcher.launch("FR")
	await process_frame
	var fr = launcher.game_node
	fr.player = fr.fish
	var fr_before = trial.targets
	fr.resolve_player(fr.dwell_seconds)
	check(trial.hits == 1 and fr.fish_state == "waiting" and trial.targets == fr_before + 1, "Fish Rescue shows the next fish at once")
	check(fr.escape_active, "The rescued fish keeps swimming home")
	trial.finish("TEST")
	await process_frame
	print("Instant targets and variety: %d failures" % failures)
	quit(1 if failures else 0)
