extends SceneTree
# Target durations measured against Unity's formulas (others.cs and the game controllers).
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func near(value: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(value - expected) <= tolerance, "%s: %.3f, expected %.3f ±%.3f" % [message, value, expected, tolerance])

## Seconds from the target opening until it closes, with the player standing at `at` (or moving).
func run_until_closed(trial: Node, game: Node, at: Callable) -> float:
	var elapsed = 0.0
	var step = 0.005
	while trial.target_open and elapsed < 60.0:
		game.step_game(step, at.call(elapsed))
		elapsed += step
	return elapsed

func setup_game(trial: Node, code: String) -> Node:
	trial.select_game(code)
	trial.rom = Vector2(0.4, 0.3)
	trial.speed = 0.05
	trial.begin()
	var game = load("res://core/legacy_game.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.sound_on = false
	return game

func run() -> void:
	var trial = root.get_node("Trial")
	trial.data_root = "res://test-output/timing-" + str(Time.get_ticks_usec())
	trial.configure("timing")
	# With ROM 0.4 x 0.3 m at 0.05 m/s: ML 8 s, AP 6 s, MLAP 7 s (Unity GetReachDuration).
	var cases = {"SS": 8.0, "MC": 8.0, "PP": 6.0, "TT": 6.0, "CB": 6.0, "DC": 7.0}
	for code in cases:
		var game = setup_game(trial, code)
		near(trial.reach_time(), cases[code], 0.0001, code + " reach duration = range / speed")
		var reach = cases[code]
		match code:
			"SS":
				game.spawn()
				var t = run_until_closed(trial, game, func(n): return Vector2(200 + fposmod(n * 900.0, 1200.0), 730))
				near(t / reach, 1.0, 0.01, "Space Shooter asteroid is missed exactly one reach duration after spawning")
				check(trial.misses == 1, "Space Shooter miss recorded")
			"MC":
				game.spawn()
				var t2 = 0.0
				# Keep the basket clear of every ball: the miss comes at one full reach duration.
				var clear = Vector2(-500, game.MC_BASKET_Y)
				t2 = run_until_closed(trial, game, func(n): return clear)
				near(t2 / reach, 1.0, 0.01, "Match Catch ball reaches the bottom exactly one reach duration after spawning")
				game.delay = 0
				game.step_game(0.01, clear)
				game.spawn()
				var catch_time = 0.0
				var column = Vector2(game.balls[game.match_index].x, game.MC_BASKET_Y)
				catch_time = run_until_closed(trial, game, func(n): return column)
				check(catch_time / reach > 0.80 and catch_time / reach < 0.89, "Match Catch ball meets the basket at about 0.83-0.89 of the reach duration (%.3f)" % (catch_time / reach))
			"PP":
				game.spawn()
				game.player = Vector2(120, 450)
				game.target = Vector2(1460, 450)
				game.pong_velocity = Vector2(-1, 0) * game.PONG_SPEED / reach
				var leg = 0.0
				while game.target.x > 141 and leg < 20.0:
					game.advance_pong(0.005)
					leg += 0.005
				near(leg / reach, 13.0 / 14.0, 0.01, "Ping Pong leg takes 13/14 of the reach duration")
			"TT", "CB":
				game.spawn()
				var gate_y = game.target.y
				var t3 = run_until_closed(trial, game, func(n): return Vector2(380, gate_y))
				near(t3 / reach, 16.0 / 14.82, 0.01, code + " gate reaches the player after 16/14.82 reach durations")
				check(trial.hits == 1, code + " hit recorded when aligned")
			"DC":
				game.spawn()
				var t4 = run_until_closed(trial, game, func(n): return Vector2(-300, -300))
				near(t4, 0.5 + reach, 0.02, "Diamond Catcher: 0.5 s appearance delay then one reach duration")
		trial.finish("TEST")
		game.queue_free()
		await process_frame
	# Gates spawn across (almost) the whole vertical range, as in Unity (-2.5..5.5 of -3..6).
	var game2 = setup_game(trial, "TT")
	var low = 900.0
	var high = 0.0
	for i in 300:
		game2.spawn()
		low = minf(low, game2.target.y)
		high = maxf(high, game2.target.y)
		trial.resolve(true)
	check(low < 120 and high > 780, "Reef Runner gates use the full vertical range (%.0f..%.0f)" % [low, high])
	trial.finish("TEST")
	print("Unity timing: %d failures" % failures)
	quit(1 if failures else 0)
