extends Node
# One-button navigation. The MARS handle button (or F2 in simulation) produces
# two gestures that every screen understands:
#   tap  -> next item   (in a trial: pause / resume)
#   hold -> select item (in a trial: finish & save)
# Screens register a scope (menu, workflow, results); a running trial installs
# game_short / game_long instead.
signal short_press
signal long_press
signal advanced_changed
## Ctrl+Shift+X reveals the technical sections (device, assessments, diagnostics, uploads).
var advanced = false
const UITheme = preload("res://core/ui_theme.gd")
const SIM_KEY = KEY_F2
const MENU_HOLD = 1.0
const GAME_HOLD = 1.5
const MIN_TAP = 0.03
var scope: Control
var game_short: Callable
var game_long: Callable
var primary: Callable
var primary_label = ""
var secondary: Callable
var secondary_label = ""
var toast: PanelContainer
var toast_label: Label
var toast_left = 0.0
var arrivals: Array = []
var capsule: PanelContainer
var capsule_dot: Control
var capsule_label: Label
var capsule_state = 0
var holding = false
var fired = false
var source = ""
var started = 0.0
var layer: CanvasLayer
var bar: PanelContainer
var hint: Label
var device: Label
var progress: ProgressBar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Robot.button_changed.connect(func(down):
		if down: press("device")
		else: release("device"))
	Robot.button_cancelled.connect(cancel)
	Robot.sample_received.connect(func(_packet): arrivals.append(Time.get_ticks_msec()))
	build_bar()

func build_bar() -> void:
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	bar = PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0
	bar.anchor_right = 1
	bar.anchor_top = 1
	bar.anchor_bottom = 1
	bar.offset_top = -36
	bar.offset_bottom = 0
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.08, 0.13, 0.94), Color("405169"), 1, 0, 24, 3))
	layer.add_child(bar)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	bar.add_child(row)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 17)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(240, 14)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(progress)
	device = Label.new()
	device.add_theme_font_size_override("font_size", 17)
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(device)
	build_capsule()
	toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -520
	toast.offset_right = 520
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.offset_top = -220
	toast.offset_bottom = -120
	toast.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.FOCUS, 1, 14, 24, 14))
	toast_label = UITheme.label("", 22, Color.WHITE, true)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(toast_label)
	toast.hide()
	layer.add_child(toast)

func hold_time() -> float:
	return GAME_HOLD if in_game() else MENU_HOLD

func in_game() -> bool:
	return game_short.is_valid() or game_long.is_valid()

## Screens that mirror a one-press Unity scene pass a primary action: a tap then
## performs it directly. A hold runs the optional secondary action, else selects.
func set_scope(node: Control, on_primary: Callable = Callable(), primary_text: String = "", on_secondary: Callable = Callable(), secondary_text: String = "") -> void:
	game_short = Callable()
	game_long = Callable()
	primary = on_primary
	primary_label = primary_text
	secondary = on_secondary
	secondary_label = secondary_text
	scope = node
	bar_left = -1.0
	bar.modulate.a = 1.0
	var owner = get_viewport().gui_get_focus_owner()
	if owner != null: owner.release_focus()

## The bar is shown on every screen; a calm screen (Welcome) lets it fade away after a few
## seconds. It returns the moment the button is pressed, so the hold progress is never hidden.
var bar_left = -1.0
func fade_bar_after(seconds: float) -> void:
	bar_left = seconds

func enter_game(on_short: Callable, on_long: Callable) -> void:
	scope = null
	primary = Callable()
	secondary = Callable()
	game_short = on_short
	game_long = on_long
	var owner = get_viewport().gui_get_focus_owner()
	if owner != null: owner.release_focus()

func leave_game() -> void:
	game_short = Callable()
	game_long = Callable()

func press(from: String) -> void:
	if holding: return
	holding = true
	fired = false
	source = from
	started = Time.get_ticks_msec() / 1000.0

func release(from: String) -> void:
	if not holding or source != from: return
	var elapsed = Time.get_ticks_msec() / 1000.0 - started
	holding = false
	if fired or elapsed < MIN_TAP: return
	do_short()

func cancel() -> void:
	holding = false
	fired = false

func do_short() -> void:
	short_press.emit()
	dismiss_tip()
	if game_short.is_valid(): game_short.call()
	elif primary.is_valid(): primary.call()
	else: scan(1)

func do_long() -> void:
	long_press.emit()
	dismiss_tip()
	if game_long.is_valid(): game_long.call()
	elif secondary.is_valid(): secondary.call()
	else: activate()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X and event.ctrl_pressed and event.shift_pressed:
		advanced = not advanced
		advanced_changed.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == SIM_KEY and not event.echo:
		get_viewport().set_input_as_handled()
		if event.pressed: press("key")
		else: release("key")

## One-time spoken-style tip for a screen; shown on first visit only.
func tip(key: String, text: String) -> void:
	if Services.settings.get_value("ui", "seen_" + key, false): return
	Services.settings.set_value("ui", "seen_" + key, true)
	Services.save()
	toast_label.text = text
	toast.show()
	toast_left = 12.0

## Same toast, for messages that must be shown every time (errors, denials).
func tip_now(text: String) -> void:
	toast_label.text = text
	toast.show()
	toast_left = 8.0

func dismiss_tip() -> void:
	toast_left = 0.0
	toast.hide()

func reset_tips() -> void:
	for key in Services.settings.get_section_keys("ui") if Services.settings.has_section("ui") else PackedStringArray():
		if key.begins_with("seen_"): Services.settings.set_value("ui", key, false)
	Services.save()

func _process(delta: float) -> void:
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0: toast.hide()
	if bar_left >= 0.0:
		if holding: bar_left = 3.0
		else: bar_left = maxf(0.0, bar_left - delta)
		var wanted = 1.0 if bar_left > 0.5 or holding else 0.0
		bar.modulate.a = move_toward(bar.modulate.a, wanted, delta * 2.0)
	var elapsed = Time.get_ticks_msec() / 1000.0 - started
	if holding and not fired and elapsed >= hold_time():
		fired = true
		do_long()
	progress.value = clampf(elapsed / hold_time(), 0, 1) if holding and not fired else 0.0
	refresh_bar()

## Top-right capsule: whether MARS is connected and how fast it is streaming.
func build_capsule() -> void:
	capsule = PanelContainer.new()
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.anchor_left = 1
	capsule.anchor_right = 1
	capsule.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.08, 0.13, 0.88), Color(1, 1, 1, 0.22), 1, 20, 11, 1))
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	capsule.add_child(row)
	capsule_dot = Control.new()
	capsule_dot.custom_minimum_size = Vector2(14, 14)
	capsule_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	capsule_dot.draw.connect(func():
		var c = Color("5de08a") if capsule_state == 2 else Color("ffbf5c") if capsule_state == 1 else Color("8793a6")
		if capsule_state == 2: capsule_dot.draw_circle(Vector2(8, 8), 8.0 + sin(Time.get_ticks_msec() / 180.0) * 1.5, Color(c, 0.25))
		capsule_dot.draw_circle(Vector2(8, 8), 5.5, c))
	row.add_child(capsule_dot)
	capsule_label = UITheme.label("", 16, Color.WHITE)
	capsule_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(capsule_label)
	layer.add_child(capsule)
	capsule.z_index = 100

func refresh_capsule() -> void:
	var now = Time.get_ticks_msec()
	arrivals = arrivals.filter(func(t): return now - t <= 1000)
	capsule_state = 2 if Robot.healthy() else 1 if Robot.connected else 0
	capsule_label.text = "%d Hz" % arrivals.size()
	capsule_label.add_theme_color_override("font_color", Color.WHITE if capsule_state == 2 else Color("b6c4d6"))
	capsule_dot.queue_redraw()
	# Always the topmost thing in the top-right corner, above the game bar as well.
	capsule.reset_size()
	capsule.offset_right = -10
	capsule.offset_left = -10 - capsule.size.x
	capsule.offset_top = 2
	capsule.offset_bottom = 2 + capsule.size.y

func refresh_bar() -> void:
	refresh_capsule()
	bar.visible=not Trial.running
	var game = in_game()
	var pause_text = "resume" if Trial.paused else "pause"
	if game:
		hint.text = "MARS button  •  tap: %s  •  hold %.1f s: finish & save" % [pause_text, GAME_HOLD]
	elif primary.is_valid():
		var second = secondary_label if secondary.is_valid() else "select"
		hint.text = "MARS button  •  tap: %s  •  hold %.1f s: %s    (F2 simulates the button)" % [primary_label, MENU_HOLD, second]
	else:
		hint.text = "MARS button  •  tap: next item  •  hold %.1f s: select    (F2 simulates the button)" % MENU_HOLD
	if Trial.hardware:
		device.text = "● " + Robot.message if Robot.healthy() else "○ " + Robot.message
		device.add_theme_color_override("font_color", UITheme.ACCENT if Robot.healthy() else Color("ff8a65"))
	else:
		device.text = "Simulation"
		device.add_theme_color_override("font_color", UITheme.MUTED)
	# While a trial is running the bar stays out of the way until it is needed.
	var wanted = 1.0 if (not game or holding or Trial.paused or Trial.held()) else 0.0
	bar.modulate.a = move_toward(bar.modulate.a, wanted, 0.1)

func controls(root: Node, found: Array) -> void:
	for child in root.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		if child is BaseButton and not child.disabled and child.focus_mode != Control.FOCUS_NONE: found.append(child)
		controls(child, found)

func items() -> Array:
	var found: Array = []
	if scope != null and is_instance_valid(scope): controls(scope, found)
	return found

func scan(step: int) -> void:
	var list = items()
	if list.is_empty(): return
	var owner = get_viewport().gui_get_focus_owner()
	var index = list.find(owner)
	index = 0 if index < 0 else posmod(index + step, list.size())
	var target: Control = list[index]
	target.grab_focus()
	var parent = target.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(target)
			break
		parent = parent.get_parent()

func activate() -> void:
	var owner = get_viewport().gui_get_focus_owner()
	var list = items()
	if owner == null or not list.has(owner):
		scan(1)
		return
	var button: BaseButton = owner
	if button.toggle_mode: button.button_pressed = not button.button_pressed
	else: button.pressed.emit()


