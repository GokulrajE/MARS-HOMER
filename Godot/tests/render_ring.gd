extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rr-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	records.save_profile({"HomerID":"demo","StartDate":"01-10-2026 00:00:00","EndDate":"31-12-2026 23:59:59","ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"","Group":"Experimental"})
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	# Two finished 60 s trials today in ML.
	for i in 2:
		trial.select_game("SS")
		trial.begin()
		trial.advance(60, false, Vector2.ZERO, Vector2.ZERO)
	for i in 5: await process_frame
	launcher.show_menu()
	await process_frame
	launcher.launch("MC")
	root.get_node("Nav").dismiss_tip()
	trial.duration = 30.0
	for i in 12: await process_frame
	var ring = launcher.hud.get_child(launcher.hud.get_child_count() - 1)
	print("RING ", ring.trial_number, "/", ring.trial_total, " fraction ", snappedf(ring.fraction, 0.001), " visible ", ring.visible)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/ring.png")
	quit()
