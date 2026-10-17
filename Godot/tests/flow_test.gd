extends SceneTree
# Scene-by-scene flow: Welcome, Choose Movement, guided setup, Summary, Tutorial.
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func packet(robot: Node, angle: float, force: float, calibration: int, control: int) -> void:
	var sensors = []
	sensors.resize(12)
	sensors.fill(0.0)
	sensors[0] = angle
	sensors[9] = 999
	robot.connected = true
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"sensors": sensors, "force": force, "calibration": calibration, "control_type": control, "limb": 1, "error": 0, "button": 1, "runtime": 1.0, "number": 1, "endpoint": Vector3.ZERO, "plane_endpoint": Vector2.ZERO}

func run() -> void:
	var trial = root.get_node("Trial")
	var robot = root.get_node("Robot")
	var records = root.get_node("Records")
	var nav = root.get_node("Nav")
	var services = root.get_node("Services")
	var Stats = load("res://core/stats.gd")
	var Video = load("res://core/video.gd")
	services.settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/flow-" + str(Time.get_ticks_usec())
	check(trial.configure("flowuser"), "Create user")
	# Reference videos: every clip must load as a playable stream.
	for key in Video.CLIPS:
		check(load(Video.CLIPS[key][0]) is VideoStream, "Reference video loads: " + key)
	# Stats from a saved trial.
	trial.select_game("SS")
	check(trial.begin(), "Begin trial")
	trial.appear(Vector2.ONE / 2)
	trial.resolve(true)
	trial.appear(Vector2.ONE / 3)
	trial.resolve(false)
	check(trial.finish(), "Finish trial")
	var score = Stats.game_scores("SS")
	check(score.today_hits == 1 and score.today_targets == 2 and score.total_hits == 1, "Game scores from history")
	check(Stats.game_scores("PP").total_targets == 0, "Other games have no scores")
	check(Stats.past_days(7).size() == 7, "Seven previous days")
	check(is_equal_approx(Stats.minutes_on(Stats.today()), trial.last_result.seconds / 60.0), "Minutes today")
	var today = Stats.today()
	var start = Stats.date_string(-4)
	records.profile = {"HomerID": "flowuser", "StartDate": start.substr(8, 2) + "-" + start.substr(5, 2) + "-" + start.substr(0, 4) + " 00:00:00", "EndDate": "31-12-2099 23:59:59", "ML": "10", "AP": "5", "MLAP": "0", "TrainingSide": "RIGHT"}
	check(Stats.training_day() == 4, "Day of training counts from start date")
	var left = Stats.remaining_minutes()
	check(left.plan == 15.0 and not left.exceeded and left.minutes == 15, "Time remaining today")
	check(Stats.days_since("ML") == -1 and not Stats.assessment_line("ML").ok, "Missing assessment is N/A")
	records.corners["ML"] = {"DateTime": Stats.date_string(-20) + " 10:00:00"}
	check(Stats.days_since("ML") == 20 and not Stats.assessment_line("ML").ok, "Assessment older than 13 days is flagged")
	records.corners["ML"] = {"DateTime": today + " 10:00:00"}
	check(Stats.days_since("ML") == 0 and Stats.assessment_line("ML").ok, "Fresh assessment is OK")
	records.corners.clear()
	# Welcome.
	var welcome = load("res://core/welcome.gd").new()
	root.add_child(welcome)
	await process_frame
	check(welcome.time_label.text == "15 min left today", "Welcome shows time left: " + welcome.time_label.text)
	check(welcome.day_label.text == "Day of training: 4", "Welcome shows training day")
	welcome.queue_free()
	# Choose Movement gating (device mode requires assessments).
	trial.hardware = true
	var choose = load("res://core/choose_move.gd").new()
	root.add_child(choose)
	await process_frame
	check(choose.move_buttons.has("ML") and choose.move_buttons.has("AP") and not choose.move_buttons.has("MLAP"), "Unprescribed movements are hidden on a device")
	choose.choose("ML")
	await process_frame
	check(choose.needs == "ASSESS" and choose.game_box.get_child_count() == 0, "No games until the assessment exists")
	check(nav.primary.is_valid() and nav.primary_label == "start assessment", "Single press starts the assessment")
	var asked: Array = []
	choose.assess.connect(func(kind): asked.append(kind))
	nav.do_short()
	check(asked == ["ML"], "Primary tap requests the ML assessment")
	records.corners["ML"] = {"DateTime": today + " 09:00:00"}
	choose.choose("ML")
	await process_frame
	check(choose.needs == "" and choose.game_box.get_child_count() > 0, "Games appear once assessed")
	trial.hardware = false
	choose.queue_free()
	await process_frame
	# Guided setup: calibrate -> activate -> attach -> choose plane -> ready.
	trial.hardware = true
	var setup = load("res://core/guided_setup.gd").new()
	root.add_child(setup)
	var results: Array = []
	setup.finished.connect(func(result): results.append(result))
	await process_frame
	check(setup.state == setup.CALIBRATE, "Setup starts at calibration")
	packet(robot, 0, 0, 0, 0)
	setup._process(0.0)
	check(setup.angles_ok(), "IMU angles within limit")
	packet(robot, 0, 0, 1, 0)
	setup._process(0.0)
	check(setup.state == setup.ACTIVATE, "Calibration confirmed moves to activation")
	setup.primary()
	check(setup.state == setup.ACTIVATING, "Press activates")
	packet(robot, -90, 0, 1, 1)
	setup._process(0.0)
	check(setup.state == setup.ATTACH, "Reaching -90 moves to attach")
	setup.primary()
	check(setup.state == setup.ATTACH, "Cannot continue without the arm attached")
	packet(robot, -90, 20, 1, 1)
	setup._process(0.0)
	setup.primary()
	check(setup.state == setup.CHOOSE_PLANE, "Attached arm moves to plane selection")
	setup.plane_slider.value = -60
	packet(robot, -90, 20, 1, 1)
	setup.primary()
	check(setup.state == setup.CHOOSE_PLANE, "Press moves toward the plane first")
	packet(robot, -60, 20, 1, 1)
	setup.primary()
	check(setup.state == setup.READY and is_equal_approx(trial.plane, -60.0), "Reached plane is saved")
	setup.primary()
	check(results == ["ready"], "Ready press finishes setup")
	setup.queue_free()
	# Shutdown branch: hand must be removed before the arm is lowered.
	var off = load("res://core/guided_setup.gd").new()
	off.shutdown = true
	root.add_child(off)
	await process_frame
	packet(robot, 20, 30, 1, 1)
	off._process(0.0)
	off.primary()
	check(off.state == off.REMOVE, "Arm is not lowered while the hand is on MARS")
	robot.recent_commands.clear()
	packet(robot, 20, 5, 1, 1)
	off.primary()
	check(off.state == off.OFF and not robot.connected, "Pressing Lower the arm just drops the connection")
	check(robot.recent_commands.is_empty(), "No control or target command is sent when disconnecting")
	var off_results: Array = []
	off.finished.connect(func(result): off_results.append(result))
	off.primary()
	check(off_results == ["shutdown"], "Final press leaves for the summary")
	off.queue_free()
	robot.last_packet = {}
	robot.connected = false
	trial.hardware = false
	# Assessment mapping: the whole Unity workspace fills the plot, and round-trips.
	var assess = load("res://core/assessment.gd").new()
	assess.kind = "MLAP"
	root.add_child(assess)
	await process_frame
	var W = assess.WORKSPACE
	var P = assess.PLOT
	for corner in [W.position, W.end, Vector2(W.position.x, W.end.y), Vector2(W.end.x, W.position.y)]:
		var at = assess.to_screen(corner)
		check(P.grow(0.5).has_point(at), "Workspace corner lands inside the plot: " + str(corner))
	var probe = Vector2(0.2, 0.4)
	check(assess.to_world(assess.to_screen(probe)).distance_to(probe) < 0.0001, "Screen mapping round-trips")
	for flip in [true, false]:
		assess.mirrored = flip
		for far in [Vector2(-0.3, 0.4), Vector2(0.9, 0.4), Vector2(0.2, -0.5), Vector2(0.2, 1.4)]:
			check(P.grow(0.5).has_point(assess.to_screen(far)), "A reach beyond the workspace stays inside the frame: " + str(far))
	assess.mirrored = true
	# A reach beyond Unity's workspace widens the view instead of being cut off at the edge.
	var far_left = Vector2(0.62, 0.4)
	assess.widen_view(far_left)
	assess._process(5.0)
	check(assess.view.has_point(far_left) and assess.view.size.x > assess.WORKSPACE.size.x, "The view widens to hold a wide reach")
	check(P.grow(0.5).has_point(assess.to_screen(far_left)) and absf(assess.to_screen(far_left).x - P.position.x) > 10.0, "The wide reach is drawn inside the frame, not on its edge")
	assess.reset_view()
	check(assess.to_screen(Vector2(W.position.x, W.position.y)).x > assess.to_screen(Vector2(W.end.x, W.position.y)).x, "Right arm mirrors the horizontal axis")
	check(nav.primary.is_valid() and nav.primary_label == "start recording", "Assessment start is a one-press action")
	assess.primary()
	check(assess.state == assess.RECORD, "Press starts recording")
	assess.queue_free()
	await process_frame
	# Training plane: Unity range -100..0, default -90, assessments valid within 5 degrees.
	var saved_profile_copy = records.profile.duplicate()
	trial.configure("planeuser")
	check(is_equal_approx(trial.plane, -90.0), "A user with no saved plane defaults to -90")
	trial.configure("flowuser")
	records.profile = saved_profile_copy
	check(robot.set_plane(-120) == false and robot.set_plane(10) == false, "Plane outside -100..0 is refused")
	records.save_plane(-60)
	records.corners.clear()
	# An assessment is only valid at the plane it was recorded at; changing the plane resets them all.
	var row: PackedStringArray = [trial.stamp(), "-60.0"]
	for i in 17: row.append("0.1")
	records.append(trial.user_path().path_join("rom/ML-rom.csv"), records.ROM_HEADER, row)
	records.load_assessments()
	check(records.corners.has("ML"), "An assessment at the current plane is valid")
	records.save_plane(-60)
	check(records.corners.has("ML") and not records.assessments_reset, "Saving the same plane keeps the assessments")
	records.save_plane(-55)
	check(records.corners.is_empty() and records.weight.is_empty() and records.assessments_reset, "Changing the plane invalidates every assessment")
	check(records.training_block("ML") != "", "Training is blocked until the assessments are redone")
	trial.plane = -90.0
	# Summary.
	var summary = load("res://core/summary.gd").new()
	root.add_child(summary)
	await process_frame
	check(summary.series.size() > 7, "Chart spans the prescription period")
	summary.scope_movement = "AP"
	summary.build_series()
	check(summary.series[0].plan == 5.0, "Chart shows the movement's prescribed minutes")
	check(summary.total_label.text.contains("★"), "Star counters shown")
	summary.queue_free()
	# Tutorial: practice needs a tap and a hold before it moves on.
	var tutorial = load("res://core/tutorial.gd").new()
	root.add_child(tutorial)
	await process_frame
	var closed: Array = []
	tutorial.closed.connect(func(): closed.append(true))
	tutorial.go(2)
	check(tutorial.PAGES[tutorial.index].kind == "practice", "Practice page")
	nav.do_short()
	check(tutorial.tapped and not tutorial.held and tutorial.index == 2, "A tap alone does not skip practice")
	nav.do_long()
	check(tutorial.held, "Hold recorded")
	tutorial._process(2.0)
	check(tutorial.index == 3, "Practice completes and moves on")
	for page in range(3, tutorial.PAGES.size()):
		tutorial.go(page)
		await process_frame
	nav.do_short()
	check(closed.size() == 1, "Tap on the last page closes the tutorial")
	print("MARS flow: ", failures, " failures")
	quit(failures)
