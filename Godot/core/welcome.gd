extends Control
## Unity MAIN/welcome scene: who is training, today's time left, and the past week.
signal start
signal settings
signal guide
signal logout
signal exit_app
signal mode_changed(device)
signal user_changed
const UITheme = preload("res://core/ui_theme.gd")
const Stats = preload("res://core/stats.gd")
var user_edit: LineEdit
var saved_button: Button
var summary_box: VBoxContainer
var status: Label
var week: Control
var name_label: Label
var time_label: Label
var day_label: Label
var date_label: Label
var plan_label: Label
var role_label: Label
var side_label: Label
var end_label: Label
var avatar: Control
var sim_button: Button
var dev_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)
	var emblem = TextureRect.new()
	emblem.texture = load("res://assets/art/mars_icon.png")
	emblem.custom_minimum_size = Vector2(64, 64)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.modulate = UITheme.ACCENT
	header.add_child(emblem)
	header.add_child(UITheme.label("MARS HOMER", 52, Color.WHITE))
	var grow = Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	var plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.box(Color(0.96, 0.97, 0.99), Color.TRANSPARENT, 0, 16, 16, 8))
	header.add_child(plate)
	var logos = HBoxContainer.new()
	logos.add_theme_constant_override("separation", 14)
	plate.add_child(logos)
	for entry in [["logo_lab", 190], ["logo_iit", 46], ["logo_cmc", 46]]:
		var logo = TextureRect.new()
		logo.texture = load("res://assets/art/%s.png" % entry[0])
		logo.custom_minimum_size = Vector2(entry[1], 46)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logos.add_child(logo)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left = UITheme.card()
	left.custom_minimum_size.x = 520
	body.add_child(left)
	var left_box = VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 14)
	left.add_child(left_box)
	# Header: avatar with initials, patient ID and who is logged in.
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	left_box.add_child(head)
	avatar = Control.new()
	avatar.custom_minimum_size = Vector2(76, 76)
	avatar.draw.connect(draw_avatar)
	head.add_child(avatar)
	var who = VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 2)
	head.add_child(who)
	name_label = UITheme.label("", 34, Color.WHITE)
	name_label.clip_text = true
	who.add_child(name_label)
	role_label = UITheme.label("", 19, UITheme.MUTED)
	who.add_child(role_label)
	user_edit = LineEdit.new()
	user_edit.placeholder_text = "Patient ID"
	user_edit.text = Trial.user_id
	user_edit.custom_minimum_size.y = 48
	user_edit.select_all_on_focus = true
	user_edit.text_submitted.connect(func(_text): user_changed.emit())
	user_edit.focus_exited.connect(func(): user_changed.emit())
	left_box.add_child(user_edit)
	# Today's time, as the main call-out.
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.box(Color(0.22, 0.74, 0.97, 0.10), Color(0.22, 0.74, 0.97, 0.38), 1, 20, 20, 14))
	left_box.add_child(pill)
	var pill_box = VBoxContainer.new()
	pill_box.add_theme_constant_override("separation", 2)
	pill.add_child(pill_box)
	pill_box.add_child(UITheme.label("TODAY", 15, UITheme.MUTED))
	time_label = UITheme.label("", 34, UITheme.FOCUS)
	pill_box.add_child(time_label)
	plan_label = UITheme.label("", 18, UITheme.MUTED, true)
	pill_box.add_child(plan_label)
	# Facts.
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	left_box.add_child(grid)
	day_label = fact(grid, "Plan progress")
	side_label = fact(grid, "Training arm")
	end_label = fact(grid, "Plan ends")
	date_label = fact(grid, "Date")
	# Simulation / device switch.
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(spacer)
	left_box.add_child(UITheme.label("Input", 15, UITheme.MUTED))
	var switch = HBoxContainer.new()
	switch.add_theme_constant_override("separation", 0)
	left_box.add_child(switch)
	var group = ButtonGroup.new()
	sim_button = segment("Mouse simulation", group, true)
	dev_button = segment("MARS device", group, false)
	switch.add_child(sim_button)
	switch.add_child(dev_button)
	sim_button.set_pressed_no_signal(not Trial.hardware)
	dev_button.set_pressed_no_signal(Trial.hardware)
	sim_button.pressed.connect(func(): mode_changed.emit(false))
	dev_button.pressed.connect(func(): mode_changed.emit(true))
	var right = UITheme.card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 10)
	right.add_child(right_box)
	right_box.add_child(UITheme.label("Your training", 26, Color.WHITE))
	week = preload("res://core/week_card.gd").new()
	week.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	week.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(week)
	status = UITheme.label("", 20, UITheme.FOCUS, true)
	page.add_child(status)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	page.add_child(buttons)
	var begin = add_button(buttons, "Start training  ▸", func(): start.emit(), 300)
	begin.add_theme_stylebox_override("normal", UITheme.box(Color("0f766e"), UITheme.ACCENT, 1, 12, 20, 10))
	begin.add_theme_stylebox_override("hover", UITheme.box(UITheme.ACCENT, UITheme.SKY, 2, 12, 20, 10))
	begin.tooltip_text = "Same as pressing the MARS button on this screen"
	add_button(buttons, "Patient, setup & records", func(): settings.emit(), 320)
	add_button(buttons, "Help & tutorial", func(): guide.emit(), 240)
	saved_button = add_button(buttons, "Open saved data", func(): OS.shell_open(ProjectSettings.globalize_path(Trial.data_root)), 240)
	saved_button.visible = Nav.advanced
	Nav.advanced_changed.connect(func(): saved_button.visible = Nav.advanced)
	add_button(buttons, "Log out", func(): logout.emit(), 160)
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	var leave = add_button(buttons, "Exit", func(): exit_app.emit(), 150)
	leave.tooltip_text = "Save any running trial and close MARS HOMER"
	leave.add_theme_stylebox_override("normal", UITheme.box(Color("5a2430"), Color("c4566b"), 1, 10, 18, 8))
	leave.add_theme_stylebox_override("hover", UITheme.box(Color("7a2f3f"), Color("ff8aa0"), 2, 10, 18, 8))
	refresh()

## A small tile: caption above a value. Returns the value label.
func fact(parent: Node, caption: String) -> Label:
	var tile = PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.10), 1, 16, 16, 10))
	parent.add_child(tile)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	column.add_child(UITheme.label(caption, 15, UITheme.MUTED))
	var value = UITheme.label("", 22, Color.WHITE)
	value.clip_text = true
	column.add_child(value)
	return value

## One half of the simulation / device switch.
func segment(title: String, group: ButtonGroup, left_side: bool) -> Button:
	var node = Button.new()
	node.text = title
	node.toggle_mode = true
	node.button_group = group
	node.custom_minimum_size = Vector2(0, 52)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var radius_left = 26 if left_side else 0
	var radius_right = 0 if left_side else 26
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var on = state in ["pressed", "hover_pressed"]
		var style = UITheme.box(Color("0f766e") if on else Color(1, 1, 1, 0.06), UITheme.FOCUS if state == "focus" else (UITheme.ACCENT if on else Color(1, 1, 1, 0.18)), 3 if state == "focus" else 1, 26, 20, 8)
		style.corner_radius_top_left = radius_left if left_side else 0
		style.corner_radius_bottom_left = radius_left if left_side else 0
		style.corner_radius_top_right = radius_right if not left_side else 0
		style.corner_radius_bottom_right = radius_right if not left_side else 0
		if state == "focus": style.bg_color = Color.TRANSPARENT
		node.add_theme_stylebox_override(state, style)
	return node

func draw_avatar() -> void:
	var centre = avatar.size / 2.0
	for k in 4: avatar.draw_circle(centre, 40 - k * 2, Color(0.22, 0.8, 0.75, 0.05 + k * 0.02))
	avatar.draw_circle(centre, 33, Color("0f766e"))
	avatar.draw_arc(centre, 33, 0, TAU, 48, Color(0.6, 1, 0.95, 0.7), 2.5, true)
	var initials = name_label.text.strip_edges().substr(0, 2).to_upper() if name_label != null else ""
	avatar.draw_string(UITheme.FONT, centre + Vector2(-33, 11), initials, HORIZONTAL_ALIGNMENT_CENTER, 66, 30, Color.WHITE)

func add_button(parent: Node, title: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width, 58)
	button.pressed.connect(action)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func refresh() -> void:
	if not is_inside_tree(): return
	var weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][Time.get_date_dict_from_system().weekday]
	var today = Stats.today()
	date_label.text = "%s, %s-%s-%s" % [weekday, today.substr(8, 2), today.substr(5, 2), today.substr(0, 4)]
	name_label.text = str(Records.profile.get("HomerID", user_edit.text))
	user_edit.visible = user_edit.editable
	role_label.text = ("Logged in" if not user_edit.editable else "Patient") + "  •  " + ("MARS device" if Trial.hardware else "Mouse simulation")
	side_label.text = str(Records.profile.get("TrainingSide", "–")).capitalize() if Stats.has_prescription() else "–"
	var plan_end = str(Records.profile.get("EndDate", ""))
	end_label.text = plan_end.substr(0, 10) if plan_end.length() >= 10 else "–"
	avatar.queue_redraw()
	if Stats.has_prescription():
		var left = Stats.remaining_minutes()
		if left.exceeded:
			time_label.text = "Done +%d min" % left.minutes
			time_label.add_theme_color_override("font_color", Color("5dd66f"))
		else:
			time_label.text = "%d min left today" % left.minutes
			time_label.add_theme_color_override("font_color", UITheme.FOCUS)
		plan_label.text = "Prescribed today: ML %s • AP %s • MLAP %s min" % [Stats.prescribed("ML"), Stats.prescribed("AP"), Stats.prescribed("MLAP")]
		day_label.text = "Day of training: %d" % Stats.training_day()
	else:
		time_label.text = "Practice mode"
		plan_label.text = "No prescription saved for this user. Add one under Patient, setup & records."
		day_label.text = "–"
	week.refresh()

## The status line only takes room while it has something to say (an error, a finished session).
func _process(_delta: float) -> void:
	status.visible = status.text != ""
