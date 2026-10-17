extends SceneTree
# One-button (MARS handle button / F2) navigation across menu, trial and results.
var failures = 0
var shorts = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func tap(nav: Node, source: String = "key") -> void:
	nav.press(source)
	nav.started -= 0.1
	nav.release(source)

func hold(nav: Node, source: String = "key") -> void:
	nav.press(source)
	nav.started -= 5.0
	nav._process(0.0)
	nav.release(source)

func focus_text() -> String:
	var owner = root.gui_get_focus_owner()
	return str(owner.get_meta("label", owner.text)) if owner is BaseButton else ""

func run() -> void:
	var trial = root.get_node("Trial")
	var nav = root.get_node("Nav")
	var robot = root.get_node("Robot")
	var rules = load("res://core/rules.gd")
	trial.data_root = "res://test-output/nav-" + str(Time.get_ticks_usec())
	check(trial.configure("navuser"), "Create user")
	nav.short_press.connect(func(): shorts += 1)
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	check(nav.scope == launcher.menu and not nav.in_game(), "Welcome is the navigation scope")
	check(nav.primary.is_valid(), "Welcome has a primary action, like Unity's one-press start")
	# A quick bounce is ignored entirely.
	nav.press("key")
	nav.release("key")
	check(shorts == 0, "Contact bounce is ignored")
	# Tap = primary action: start training -> Choose Movement (simulation skips robot setup).
	tap(nav)
	await process_frame
	var choose = launcher.screen
	check(choose != null and choose.get_script().resource_path.ends_with("choose_move.gd"), "Tap on Welcome opens Choose Movement")
	check(nav.scope == choose, "Choose Movement is the navigation scope")
	tap(nav)
	var first = focus_text()
	check(first != "", "First tap focuses an item")
	tap(nav)
	check(focus_text() != first, "Second tap moves on")
	for i in 30:
		if focus_text().begins_with("ML  "): break
		tap(nav)
	check(focus_text().begins_with("ML  "), "Scan reaches the ML movement")
	hold(nav)
	await process_frame
	check(choose.selected == "ML" and choose.game_box.get_child_count() > 0, "Hold selects a movement and lists games")
	var target = rules.GAMES["SS"].title
	for i in 40:
		if focus_text().begins_with(target): break
		tap(nav)
	check(focus_text().begins_with(target), "Scan reaches the game button")
	hold(nav)
	await process_frame
	check(trial.running and nav.in_game(), "Hold selects and enters the trial")
	check(nav.scope == null, "Menu scope is released during a trial")
	# In a trial: tap pauses and resumes.
	var game = launcher.game_node
	await process_frame
	var was_paused = game.paused
	tap(nav)
	check(game.paused != was_paused, "Tap pauses the trial")
	tap(nav)
	check(game.paused == was_paused, "Tap resumes the trial")
	# Hold finishes and saves, returning to Choose Movement.
	hold(nav)
	await process_frame
	await process_frame
	check(not trial.running and trial.history.size() == 1, "Hold finishes and saves the trial")
	check(not nav.in_game() and launcher.screen != null and nav.scope == launcher.screen, "Choose Movement restored after the trial")
	# Back to Welcome, then hold = secondary action: the patient/setup workflow.
	launcher.show_menu()
	await process_frame
	nav.advanced = true
	nav.advanced_changed.emit()
	hold(nav)
	await process_frame
	check(nav.scope == launcher.workflow, "Hold on Welcome opens the workflow")
	var labels: Array = []
	for button in nav.items(): labels.append(button.text)
	check(labels.has("Next section ▸") and labels.has("Back to games"), "Workflow navigation buttons are reachable")
	var tab_before = launcher.workflow.tabs.current_tab
	for i in 60:
		if focus_text() == "Next section ▸": break
		tap(nav)
	hold(nav)
	check(launcher.workflow.tabs.current_tab != tab_before, "Hold on Next section changes the tab")
	for i in 60:
		if focus_text() == "Back to games": break
		tap(nav)
	hold(nav)
	await process_frame
	check(nav.scope == launcher.menu, "Back to games restores the Welcome scope")
	# Device button edges (active-low) with a robot error present must still count.
	shorts = 0
	var number = 0
	var send = func(button: int, error: int):
		number += 1
		robot.accept_packet({"button":button,"error":error,"runtime":number * 0.01,"number":number})
	send.call(1, 0)
	send.call(0, 0)
	check(nav.holding and nav.source == "device", "Device press starts a gesture")
	send.call(0, 5)
	send.call(0, 5)
	check(nav.holding, "A robot error does not reset a held button")
	nav.started -= 5.0
	nav._process(0.0)
	check(nav.fired, "Hold still fires while the robot reports an error")
	send.call(1, 5)
	check(not nav.holding and shorts == 0, "Release after a hold does not also tap")
	send.call(0, 0)
	var before = shorts
	robot.cancel_button()
	send.call(1, 0)
	check(not nav.holding and shorts == before, "Link loss cancels a press instead of tapping")
	print("MARS navigation: ", failures, " failures")
	quit(failures)
