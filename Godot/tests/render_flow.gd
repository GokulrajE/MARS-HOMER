extends SceneTree
# Screenshots of the scene-by-scene flow, for visual review.

func shot(name: String, frames: int = 20) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/flow-" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func fake(robot: Node, angle: float, force: float, calibration: int, control: int) -> void:
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[0] = angle
	sensors[9] = 999
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"sensors": sensors, "force": force, "calibration": calibration, "control_type": control, "limb": 1, "error": 0, "button": 1, "runtime": 1.0, "number": 1}

func run() -> void:
	var trial = root.get_node("Trial")
	var robot = root.get_node("Robot")
	var records = root.get_node("Records")
	var services = root.get_node("Services")
	services.settings.set_value("ui", "tutorial_done", false)
	trial.data_root = "res://test-output/rflow-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await shot("0-tutorial-first-run", 30)
	var tutorial = launcher.tutorial
	for page in range(1, tutorial.PAGES.size()):
		tutorial.go(page)
		await shot("0-tutorial-%d" % page, 45)
	tutorial.close()
	await process_frame
	# Prescription and some history so the data views are populated.
	var stamp = trial.stamp().left(10)
	records.save_profile({"HomerID":"demo","StartDate":"01-10-2026 00:00:00","EndDate":"31-10-2026 23:59:59","ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"Clinic","Group":"Experimental"})
	for code in ["SS", "MC", "PP"]:
		trial.select_game(code)
		trial.begin()
		trial.appear(Vector2.ONE / 2)
		trial.resolve(true)
		trial.appear(Vector2.ONE / 3)
		trial.resolve(true)
		trial.advance(60, false, Vector2.ZERO, Vector2.ZERO)
	await shot("pre", 5)
	launcher.show_menu()
	await shot("1-welcome")
	launcher.show_choose()
	await shot("2-choose")
	launcher.screen.choose("ML")
	await shot("3-choose-ml", 60)
	launcher.show_summary()
	await shot("4-summary")
	trial.hardware = true
	launcher.show_setup(false)
	await process_frame
	fake(robot, 0, 0, 0, 0)
	await shot("5-setup-calibrate", 5)
	fake(robot, 0, 0, 1, 0)
	launcher.screen.state = launcher.screen.ACTIVATE
	fake(robot, 0, 0, 1, 0)
	await shot("6-setup-activate", 60)
	launcher.screen.state = launcher.screen.ATTACH
	fake(robot, -90, 0, 1, 1)
	await shot("7-setup-attach", 60)
	launcher.screen.state = launcher.screen.CHOOSE_PLANE
	fake(robot, -90, 20, 1, 1)
	await shot("8-setup-plane", 5)
	quit()
