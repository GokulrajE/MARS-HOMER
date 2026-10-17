extends SceneTree
# Screenshots of the native games during play and just after a success, for visual review.

func shot(name: String, frames: int = 3) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/game-" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rg-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	var codes = ["SS", "MC", "PP", "TT", "DC", "TW"]
	if OS.get_cmdline_user_args().size() > 0: codes = OS.get_cmdline_user_args()
	for code in codes:
		launcher.show_menu()
		await process_frame
		launcher.launch(code)
		await process_frame
		var game = launcher.game_node
		game.set_process(false)
		game.sound_on = false
		var t = 0.0
		for frame in 140:
			t += 1.0 / 60.0
			game.clock += 1.0 / 60.0
			game.pop_clock += 1.0 / 60.0
			var pos = game.player
			match code:
				"SS": pos = Vector2(800 + sin(t * 1.6) * 520, 730)
				"MC": pos = Vector2(800 + sin(t * 1.3) * 420, 730)
				"PP": pos = Vector2(120, 450 + sin(t * 2.0) * 220)
				"TT": pos = Vector2(120, 450 + sin(t * 1.4) * 240)
				"TW": pos = Vector2(800 + sin(t * 4.0) * 160, 450 + cos(t * 5.0) * 110) if frame > 40 else game.player
				_: pos = game.target if trial.target_open and frame > 60 else game.player.lerp(Vector2(800, 450), 0.05)
			game.step_game(1.0 / 60.0, pos)
			game.fx.update(1.0 / 60.0)
			if frame % 2 == 0: await process_frame
		game.queue_redraw()
		await shot(code + "-a")
		if trial.target_open:
			game.resolve(true)
		elif code == "PP":
			game.fx.celebrate(Vector2(150, 400), "Returned!", Color("7fffff"))
		for k in 14:
			game.fx.update(1.0 / 60.0)
			game.clock += 1.0 / 60.0
		game.queue_redraw()
		await shot(code + "-b")
		trial.finish("TEST")
		await process_frame
	quit()
