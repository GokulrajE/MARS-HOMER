extends SceneTree
# Real keyboard and mouse events (needs a window): Ctrl+G opens the speed panel, its
# buttons and the arrow keys change the target duration, and Exit is always visible.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func key(code: int, pressed: bool, ctrl: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)

func click(position: Vector2) -> void:
	var move = InputEventMouseMotion.new()
	move.position = position
	move.global_position = position
	Input.parse_input_event(move)
	await process_frame
	var down = InputEventMouseButton.new()
	down.position = position
	down.global_position = position
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	for i in 3: await process_frame

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/speedclick-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	for code in ["SS", "CB", "TW"]:
		launcher.launch(code)
		root.get_node("Nav").dismiss_tip()
		for i in 15: await process_frame
		var exit_button: Button
		for b in launcher.hud.find_children("*", "Button", true, false):
			if b.text == "Exit": exit_button = b
		check(exit_button != null and exit_button.is_visible_in_tree(), code + " has a visible Exit button")
		var start = trial.speed
		key(KEY_CTRL, true, true)
		await process_frame
		key(KEY_G, true, true)
		await process_frame
		key(KEY_G, false, true)
		key(KEY_CTRL, false, false)
		for i in 4: await process_frame
		check(launcher.glass_controls.panel.visible, code + " Ctrl+G opens the speed panel")
		var scale = root.get_final_transform().get_scale()
		await click(launcher.glass_controls.faster.get_global_rect().get_center() * scale)
		check(trial.speed > start + 0.004, code + " clicking Faster raises the speed (%.3f -> %.3f)" % [start, trial.speed])
		var raised = trial.speed
		key(KEY_LEFT, true, false)
		key(KEY_LEFT, false, false)
		await process_frame
		check(trial.speed < raised, code + " the left arrow slows it again")
		await process_frame
		await process_frame
		check(launcher.glass_controls.slower.disabled == (trial.speed <= trial.Rules.MIN_SPEED + 0.0001), code + " Slower is disabled at the minimum")
		await click(exit_button.get_global_rect().get_center() * scale)
		await process_frame
		await process_frame
		check(not trial.running, code + " Exit finishes the trial")
		launcher.show_menu()
		await process_frame
	print("Speed panel and exit: %d failures" % failures)
	quit(1 if failures else 0)
