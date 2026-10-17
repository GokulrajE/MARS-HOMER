extends SceneTree
# Screenshots of the styled non-game screens, the in-game HUD and the results card.

func shot(name: String, frames: int = 25) -> void:
	root.get_node("Nav").dismiss_tip()
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/ui-" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/ru-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	records.save_profile({"HomerID":"demo","StartDate":"01-10-2026 00:00:00","EndDate":"31-10-2026 23:59:59","ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"Clinic","Group":"Experimental"})
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await shot("1-welcome", 40)
	launcher.show_choose()
	await shot("2-choose", 30)
	launcher.screen.choose("ML")
	await shot("3-choose-mlap", 60)
	launcher.launch("SS")
	await process_frame
	var game = launcher.game_node
	game.set_process(false)
	for i in 90:
		game.clock += 1.0 / 60.0
		game.step_game(1.0 / 60.0, Vector2(800 + sin(i * 0.05) * 400, 730))
		game.fx.update(1.0 / 60.0)
		if i % 3 == 0: await process_frame
	trial.duration = 22.0
	trial.hits = 3
	await shot("4-hud", 3)
	game.paused = true
	await shot("5-paused", 3)
	trial.hits = 6
	trial.targets = 7
	trial.advance(60, false, Vector2.ZERO, Vector2.ZERO)
	await shot("6-results", 70)
	launcher.show_menu()
	await process_frame
	launcher.open_workflow()
	await shot("7-patient", 30)
	launcher.workflow.tabs.current_tab = 1
	await shot("8-device", 10)
	launcher.workflow.tabs.current_tab = 2
	await shot("9-summary-tab", 10)
	launcher.workflow.closed.emit()
	await process_frame
	launcher.show_summary()
	await shot("10-summary", 30)
	quit()
