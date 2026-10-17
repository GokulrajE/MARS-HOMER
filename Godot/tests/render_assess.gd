extends SceneTree

func shot(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/assess-" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/ra-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	records.save_profile({"HomerID":"demo","StartDate":"01-10-2026 00:00:00","EndDate":"31-10-2026 23:59:59","ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"Clinic","Group":"Experimental"})
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.open_assessment("MLAP")
	await process_frame
	var a = launcher.assessment
	a.set_process(false)
	await shot("1-init")
	a.start()
	for i in 160:
		var t = i * TAU / 160
		a.cursor = Vector2(0.25 + 0.2 * sin(t), 0.45 + 0.25 * cos(t))
		a.collect(0.01)
		if i == 90: await shot("2-record")
	a.stop()
	a.retain = 90
	a.refresh()
	a._process(0.0)
	await shot("3-adjust")
	a.save()
	a._process(0.0)
	await shot("4-saved")
	launcher.open_assessment("WEIGHT")
	await process_frame
	a = launcher.assessment
	a.set_process(false)
	print("TARGETS ", a.targets, " corners ", records.corners.has("MLAP"), " plane ", trial.plane)
	a.start()
	a.cursor = a.targets[0]
	for i in 12: a.collect(0.1)
	a._process(0.0)
	await shot("5-weight")
	launcher.open_assessment("ML")
	await process_frame
	a = launcher.assessment
	a.set_process(false)
	await shot("6-ml-init-previous")
	quit()
