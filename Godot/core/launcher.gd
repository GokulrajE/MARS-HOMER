extends Control
## Scene router. The flow follows the Unity application:
## Welcome -> (device) Calibrate/Activate/Attach -> Choose Movement ->
## Assessment or Game -> Results -> Choose Movement -> (device) Deactivate -> Summary.
const Rules = preload("res://core/rules.gd")
const UITheme = preload("res://core/ui_theme.gd")
const Backdrop = preload("res://core/backdrop.gd")
var menu: Control
var user_edit: LineEdit
var status: Label
var screen: Control
var game_view: SubViewportContainer
var viewport: SubViewport
var game_node: Node
var hud: Control
var hud_text: Label
var hud_title: Label
var hud_timer: ProgressBar
var hud_clock: Label
var backdrop: Control
var pause_button: Button
var active_code = ""
var workflow: Control
var login_approved = ""
var pending_code = ""
var results: Control
var tutorial: Control
var signed_account = ""
var assessment: Control
var glass_controls:Control

func _ready() -> void:
	get_tree().auto_accept_quit = false
	theme = UITheme.build()
	backdrop = Backdrop.new()
	add_child(backdrop)
	Trial.ended.connect(on_ended)
	Robot.fault.connect(on_fault)
	Services.session_checked.connect(on_login_checked)
	glass_controls=load("res://core/glass_controls.gd").new()
	glass_controls.launcher=self
	add_child(glass_controls)
	# Scripted test runs (--script) start signed in; a normal launch begins at the login screen.
	if "--script" in OS.get_cmdline_args(): show_menu()
	else: show_login()
	if not Services.settings.get_value("ui", "tutorial_done", false): show_tutorial.call_deferred()

func make_button(title: String, action: Callable, parent: Node, tip: String = "") -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(250, 56)
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## Free everything on screen except the launcher itself.
func clear_screens() -> void:
	for node in [results, menu, screen, workflow, assessment, tutorial]:
		if is_instance_valid(node): node.queue_free()
	results = null
	menu = null
	screen = null
	workflow = null
	assessment = null
	tutorial = null
	if is_instance_valid(game_view):
		remove_child(game_view)
		game_view.queue_free()
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
	game_node = null
	if is_instance_valid(backdrop): backdrop.show()
	Nav.set_scope(null)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_screen(node: Control) -> void:
	clear_screens()
	screen = node
	add_child(node)
	fade_in(node)

## Screens ease in: a short fade with a small upward slide.
func fade_in(node: Control) -> void:
	node.modulate.a = 0.0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.28)
	var start = node.position.y + 18.0
	node.position.y = start
	tween.tween_property(node, "position:y", start - 18.0, 0.28)

## First screen of a normal launch.
func show_login() -> void:
	clear_screens()
	var login = load("res://core/login.gd").new()
	screen = login
	add_child(login)
	fade_in(login)
	login.diagnostics.connect(show_diagnostics)
	login.signed_in.connect(func(account):
		Trial.session_started = ""
		Trial.user_id = account
		signed_account = account
		if ensure_user() and Records.profile.is_empty(): show_plan_setup()
		else: show_menu())

## Connection check before login: shows everything the robot reports.
func show_diagnostics() -> void:
	clear_screens()
	var page = load("res://core/diagnostics.gd").new()
	screen = page
	add_child(page)
	fade_in(page)
	page.closed.connect(show_login)

## A patient with no saved profile must set up their plan before anything else.
func show_plan_setup() -> void:
	clear_screens()
	var setup = load("res://core/workflows.gd").new()
	setup.setup_mode = true
	workflow = setup
	add_child(setup)
	fade_in(setup)
	Nav.set_scope(setup)
	setup.completed.connect(show_menu)
	setup.closed.connect(func():
		Trial.session_started = ""
		signed_account = ""
		show_login())

## Welcome scene (Unity MAIN). Kept under the name `menu` for the tests and Nav.
func show_menu() -> void:
	clear_screens()
	var welcome = load("res://core/welcome.gd").new()
	menu = welcome
	add_child(welcome)
	fade_in(welcome)
	user_edit = welcome.user_edit
	if signed_account != "":
		# The logged-in patient; switching patients means logging out.
		user_edit.text = signed_account
		user_edit.editable = false
		user_edit.tooltip_text = "Logged in as this patient. Log out to switch."
	status = welcome.status
	welcome.start.connect(begin_flow)
	welcome.settings.connect(open_workflow)
	welcome.guide.connect(show_tutorial)
	welcome.mode_changed.connect(on_mode_changed)
	welcome.user_changed.connect(func():
		if ensure_user(): menu.refresh())
	welcome.exit_app.connect(quit_app)
	welcome.logout.connect(func():
		Services.logout()
		Robot.disconnect_port()
		Trial.session_started=""
		login_approved=""
		show_login())
	status.text = ""
	if ensure_user(): welcome.refresh()
	Nav.set_scope(welcome, begin_flow, "start training", open_workflow, "patient & setup")
	Nav.fade_bar_after(6.0)
	Nav.tip("welcome", "Press the MARS button (or F2) to start training. Hold it to open patient and setup records. Help & tutorial explains everything.")

func on_mode_changed(value: bool) -> void:
	Trial.hardware=value
	Trial.data_root="user://data" if value else "user://simulation-data"
	Trial.session_started=""
	Trial.history.clear()
	Records.profile.clear()
	Records.corners.clear()
	Records.weight.clear()
	login_approved=""
	status.text = ""
	if ensure_user(): menu.refresh()

func show_tutorial() -> void:
	if is_instance_valid(tutorial): return
	tutorial = load("res://core/tutorial.gd").new()
	add_child(tutorial)
	tutorial.closed.connect(func():
		Services.settings.set_value("ui", "tutorial_done", true)
		Services.save()
		tutorial.queue_free()
		tutorial = null
		if is_instance_valid(menu): Nav.set_scope(menu, begin_flow, "start training", open_workflow, "patient & setup"))

## Start button on Welcome: Unity went to calibration, then setup, then movements.
func begin_flow() -> void:
	if not ensure_user(): return
	if Trial.hardware and not Robot.ready_for_training(): show_setup(false)
	else: show_choose()

func show_setup(shutdown: bool) -> void:
	var setup = load("res://core/guided_setup.gd").new()
	setup.shutdown = shutdown
	show_screen(setup)
	setup.finished.connect(func(result):
		if result == "ready": show_choose()
		else: show_summary())
	setup.cancelled.connect(func():
		if shutdown: show_choose()
		else: show_menu())

func show_choose() -> void:
	var choose = load("res://core/choose_move.gd").new()
	show_screen(choose)
	choose.back.connect(show_menu)
	choose.summary.connect(finish_session)
	choose.play.connect(launch)
	choose.assess.connect(open_assessment)
	choose.change_plane.connect(open_training_plane)

## Device sessions deactivate the robot first, as Unity's MARSSETUP did.
func finish_session() -> void:
	if Trial.hardware and Robot.healthy(): show_setup(true)
	else: show_summary()

func show_summary() -> void:
	var summary = load("res://core/summary.gd").new()
	show_screen(summary)
	summary.back.connect(show_choose)
	summary.finish.connect(func():
		Services.logout()
		Robot.disconnect_port()
		Trial.session_started=""
		login_approved=""
		show_menu()
		status.text = "Session finished. Thank you!")

func open_training_plane() -> void:
	if Trial.running: return
	var editor=load("res://core/training_plane.gd").new()
	show_screen(editor)
	var notice=[""]
	editor.saved.connect(func(angle): notice[0]="✓ Training plane saved: %.0f°" % angle + ("  •  The plane changed, so please redo all assessments." if Records.assessments_reset else ""))
	editor.closed.connect(func():
		show_choose()
		if notice[0]!="": Nav.tip_now(notice[0]))

func open_assessment(kind: String) -> void:
	if not ensure_user(): return
	clear_screens()
	assessment = load("res://core/assessment.gd").new()
	assessment.kind = kind
	add_child(assessment)
	var current = assessment
	assessment.finished.connect(func():
		# Unity continues from the MLAP range straight into the arm-weight assessment.
		if current.saved and current.kind == "MLAP" and Records.weight.is_empty(): open_assessment("WEIGHT")
		else: show_choose())

func open_workflow() -> void:
	if not ensure_user(): return
	menu.hide()
	workflow=load("res://core/workflows.gd").new()
	add_child(workflow)
	Nav.set_scope(workflow)
	workflow.closed.connect(func():
		workflow.queue_free()
		workflow=null
		user_edit.text=Trial.user_id
		menu.show()
		menu.refresh()
		Nav.set_scope(menu, begin_flow, "start training", open_workflow, "patient & setup"))

func ensure_user() -> bool:
	var wanted = user_edit.text if is_instance_valid(user_edit) else Trial.user_id
	if Trial.session_started=="" or wanted!=Trial.user_id:
		if not Trial.configure(wanted):
			if is_instance_valid(status): status.text=Trial.error
			return false
	return true

func notify(message: String) -> void:
	if is_instance_valid(status): status.text = message
	Nav.tip_now(message)

func on_login_checked(allowed: bool,message: String) -> void:
	if allowed:
		login_approved=Trial.user_id
		if pending_code!="":
			var code=pending_code
			pending_code=""
			launch(code)
	else:
		pending_code=""
		notify(message)

func on_fault(message: String) -> void:
	Records.log_event(message)
	Records.log_error(message)
	if not Trial.hardware or not is_instance_valid(game_node): return
	if active_code=="FW": game_node.pause_session()
	elif active_code=="BS": game_node.stop_game()
	else: game_node.paused=true
	Trial.annotation="DEVICE_FAULT: "+message
	Trial.paused=true

func launch(code: String) -> void:
	if not ensure_user(): return
	if Services.session_lost or Services.agent_busy:
		notify("Session unavailable or awaiting server ownership check.")
		return
	if Trial.hardware and Services.agent_enabled and login_approved!=Trial.user_id:
		pending_code=code
		Services.login(Trial.user_id)
		return
	Trial.select_game(code)
	if not Trial.begin():
		notify(Trial.error)
		return
	active_code = code
	load("res://core/visual_cycle.gd").note_trial(code)
	clear_screens()
	backdrop.hide()
	game_view = SubViewportContainer.new()
	# Every game is full-bleed under the compact glass HUD.
	game_view.position = Vector2.ZERO
	game_view.scale=Vector2(1,1000.0/900.0)
	game_view.size = Vector2(1600, 900)
	game_view.stretch = true
	add_child(game_view)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600,900)
	viewport.handle_input_locally = true
	game_view.add_child(viewport)
	if Rules.GAMES[code].has("scene"):
		game_node = load("res://games/" + Rules.GAMES[code].scene).instantiate()
	else:
		game_node = load("res://core/legacy_game.gd").new()
	viewport.add_child(game_node)
	if code in ["FW","BS"]:
		for child in game_node.get_children():
			if child is Label or child is Button or child is HBoxContainer: child.hide()
	if code=="FR":
		for child in game_node.get_children():
			if child is Control and child not in [game_node.hold_label,game_node.overlay]: child.hide()
	var cycle=load("res://core/visual_cycle.gd").new()
	cycle.game=game_node
	viewport.add_child(cycle)
	if code == "FR":
		game_node.scale = Vector2(1.25,1.125)
	elif code == "BS":
		game_node.start_game()
	elif code == "FW":
		game_node.scale = Vector2.ONE
		game_node.start_session()
	Nav.enter_game(toggle_pause, finish_game)
	hud=load("res://core/game_hud.gd").new()
	add_child(hud)
	hud_text=hud.score_label
	hud_clock=hud.clock_label
	pause_button=hud.pause
	# The speed panel must sit above the game view or the view swallows its clicks.
	move_child(glass_controls, get_child_count() - 1)


func toggle_pause() -> void:
	if not is_instance_valid(game_node): return
	if Trial.held(): return
	if active_code == "FW":
		if game_node.active: game_node.pause_session()
		else: game_node.start_session()
	elif active_code == "BS": game_node.toggle_pause()
	elif active_code == "FR": game_node.toggle_pause()
	else: game_node.paused = not game_node.paused

func finish_game() -> void:
	if not Trial.finish(): hud_text.text = Trial.error

func on_ended() -> void:
	Nav.leave_game()
	if is_instance_valid(game_node): game_node.process_mode = Node.PROCESS_MODE_DISABLED
	Records.log_event("Trial saved: "+Trial.raw_name)
	if Trial.hardware: Services.trial_ended()
	# Deferred because trial end may be emitted inside the game's update.
	if Trial.last_result.get("reason")=="COMPLETED" and is_instance_valid(game_node):
		if active_code=="FW":
			game_node.process_mode=Node.PROCESS_MODE_INHERIT
			game_node.active=true
			game_node.finale_time=0
		call_deferred("show_results")
	else: call_deferred("show_choose")

func show_results() -> void:
	results=load("res://core/results.gd").new()
	add_child(results)
	Nav.set_scope(results)
	results.back.connect(show_choose)
	results.again.connect(func():
		var code=active_code
		show_choose()
		launch(code))

func _process(_delta: float) -> void:
	if not is_instance_valid(game_node) or not Trial.running: return
	if Trial.held(): hud_text.text="Held"

func quit_app() -> void:
	if not Trial.finish("WINDOW_CLOSED"):
		notify(Trial.error)
		return
	Robot.disconnect_port()
	await Services.logout()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_app()
