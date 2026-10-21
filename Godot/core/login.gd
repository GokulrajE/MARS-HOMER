extends Control
## First screen: enter the patient ID to log in. An ID that has no records yet is a new
## patient and is created automatically, as in the Unity application.
signal signed_in(name)
signal diagnostics
## True = MARS device, False = mouse simulation. The switch is hidden until Ctrl+Shift+X.
signal mode_changed(device)
const UITheme = preload("res://core/ui_theme.gd")
var id_edit: LineEdit
var note: Label
var error: Label
var suggestions: VBoxContainer
var sync_label: Label
var refresh_button: Button
var mode_box: VBoxContainer
var sim_button: Button
var dev_button: Button
const MAX_SUGGESTIONS = 5

static func known_patients() -> PackedStringArray:
	var found = PackedStringArray()
	for root_path in ["user://data", "user://simulation-data"]:
		var directory = DirAccess.open(root_path)
		if directory == null: continue
		for folder in directory.get_directories():
			if not found.has(folder): found.append(folder)
	found.sort()
	return found

static func valid_id(id: String) -> bool:
	return id != "" and id.length() <= 40 and id == id.validate_filename() and id not in [".", ".."]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.13, 0.72), Color(1, 1, 1, 0.16), 1, 28, 40, 34))
	center.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	card.add_child(column)
	var brand = HBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation", 14)
	column.add_child(brand)
	var icon = TextureRect.new()
	icon.texture = load("res://assets/art/mars_icon.png")
	icon.custom_minimum_size = Vector2(54, 54)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = UITheme.ACCENT
	brand.add_child(icon)
	brand.add_child(UITheme.label("MARS", 44, Color.WHITE))
	var title = UITheme.label("Patient login", 30, UITheme.SKY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UITheme.label("Patient ID", 18, UITheme.MUTED))
	id_edit = LineEdit.new()
	id_edit.custom_minimum_size = Vector2(0, 56)
	id_edit.placeholder_text = "Search or enter a patient ID"
	id_edit.clear_button_enabled = true
	id_edit.text_changed.connect(func(_text):
		update_note()
		rebuild_suggestions())
	id_edit.gui_input.connect(on_field_key)
	id_edit.text_submitted.connect(func(_text): go())
	column.add_child(id_edit)
	var sync_row = HBoxContainer.new()
	sync_row.add_theme_constant_override("separation", 10)
	column.add_child(sync_row)
	sync_label = UITheme.label("", 16, UITheme.MUTED, true)
	sync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sync_row.add_child(sync_label)
	refresh_button = Button.new()
	refresh_button.text = "↻  Refresh patient list"
	refresh_button.custom_minimum_size = Vector2(0, 40)
	refresh_button.tooltip_text = "Fetch the newest patient IDs for this device from the NeuroDash server"
	refresh_button.pressed.connect(refresh_patients)
	sync_row.add_child(refresh_button)
	NeuroDash.sync_finished.connect(on_sync_finished)
	suggestions = VBoxContainer.new()
	suggestions.add_theme_constant_override("separation", 6)
	column.add_child(suggestions)
	note = UITheme.label("", 19, UITheme.MUTED, true)
	note.custom_minimum_size.y = 28
	column.add_child(note)
	error = UITheme.label("", 19, Color("ff8a7a"), true)
	column.add_child(error)
	var submit = Button.new()
	submit.text = "Log in"
	submit.custom_minimum_size = Vector2(0, 60)
	submit.add_theme_font_size_override("font_size", 25)
	submit.pressed.connect(go)
	var bright = UITheme.box(Color("2fd0ee"), Color("a8f0ff"), 1, 30, 24, 8)
	bright.shadow_color = Color(0.2, 0.85, 1.0, 0.4)
	bright.shadow_size = 12
	submit.add_theme_stylebox_override("normal", bright)
	submit.add_theme_stylebox_override("hover", UITheme.box(Color("5de0f7"), Color.WHITE, 2, 30, 24, 8))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: submit.add_theme_color_override(state, Color("04283b"))
	column.add_child(submit)
	var check = Button.new()
	check.text = "Diagnostics  •  connect MARS and view its data"
	check.custom_minimum_size = Vector2(0, 56)
	check.add_theme_font_size_override("font_size", 22)
	check.add_theme_stylebox_override("normal", UITheme.box(Color(0.12, 0.19, 0.25, 0.55), UITheme.SKY, 2, 28, 24, 8))
	check.add_theme_color_override("font_color", UITheme.SKY)
	check.pressed.connect(func(): diagnostics.emit())
	column.add_child(check)
	var version = UITheme.label("Version " + Updater.current_version(), 16, UITheme.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version)
	mode_box = VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 6)
	column.add_child(mode_box)
	mode_box.add_child(UITheme.label("Input", 16, UITheme.MUTED))
	var switch = HBoxContainer.new()
	switch.add_theme_constant_override("separation", 0)
	mode_box.add_child(switch)
	var group = ButtonGroup.new()
	sim_button = segment("Mouse simulation", group, true)
	dev_button = segment("MARS device", group, false)
	switch.add_child(sim_button)
	switch.add_child(dev_button)
	sim_button.set_pressed_no_signal(not Trial.hardware)
	dev_button.set_pressed_no_signal(Trial.hardware)
	sim_button.pressed.connect(func(): mode_changed.emit(false))
	dev_button.pressed.connect(func(): mode_changed.emit(true))
	mode_box.visible = Nav.advanced
	Nav.advanced_changed.connect(func(): mode_box.visible = Nav.advanced)
	build_update_banner()
	rebuild_suggestions()
	update_note()
	id_edit.grab_focus.call_deferred()
	# Like Unity, a normal start fetches the newest patient list when NeuroDash is switched on.
	if NeuroDash.enabled() and not "--script" in OS.get_cmdline_args(): refresh_patients()
	Nav.set_scope(self)

var update_box: PanelContainer
var update_label: Label
var install_button: Button
var later_button: Button
var countdown = -1.0

## Top-of-screen banner while an update downloads or waits. When one is ready it installs by itself
## after a short countdown (nobody is logged in here); "Later" keeps the app as it is for now.
func build_update_banner() -> void:
	update_box = PanelContainer.new()
	update_box.anchor_left = 0.5
	update_box.anchor_right = 0.5
	update_box.offset_left = -430
	update_box.offset_right = 430
	update_box.offset_top = 18
	update_box.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.1, 0.16, 0.92), UITheme.SKY, 2, 20, 22, 12))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	update_box.add_child(row)
	update_label = UITheme.label("", 21, Color.WHITE, true)
	update_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(update_label)
	install_button = Button.new()
	install_button.text = "Install now"
	install_button.pressed.connect(func(): Updater.apply())
	row.add_child(install_button)
	later_button = Button.new()
	later_button.text = "Later"
	later_button.pressed.connect(func():
		Updater.postponed = true
		refresh_update())
	row.add_child(later_button)
	add_child(update_box)
	Updater.state_changed.connect(refresh_update)
	refresh_update()

func refresh_update() -> void:
	if not is_instance_valid(update_box): return
	var ready = Updater.state == Updater.READY
	update_box.visible = ready or Updater.state == Updater.DOWNLOADING or (Updater.state == Updater.FAILED and Updater.checking_manually)
	install_button.visible = ready
	later_button.visible = ready and not Updater.postponed
	countdown = 20.0 if ready and not Updater.postponed else -1.0
	update_label.text = Updater.status_text()

func _process(delta: float) -> void:
	if countdown < 0.0 or not visible: return
	countdown -= delta
	update_label.text = "Version %s is ready. Installing in %d s…" % [Updater.latest_version, ceili(maxf(countdown, 0.0))]
	if countdown <= 0.0:
		countdown = -1.0
		Updater.apply()

## Patients that match what is typed (prefix matches first), then "create" when the text is a
## new, valid ID. With nothing typed it lists the patients on this computer. A click logs in.
static func suggest(query: String, known: PackedStringArray) -> Array:
	var wanted = query.strip_edges().to_lower()
	var starts: Array = []
	var contains: Array = []
	for id in known:
		var lower = id.to_lower()
		if wanted == "" or lower.begins_with(wanted): starts.append(id)
		elif lower.contains(wanted): contains.append(id)
	var found = starts + contains
	return found.slice(0, MAX_SUGGESTIONS)

## Local patient folders plus the patients the server assigned to this device.
func all_patients() -> PackedStringArray:
	var found = known_patients()
	for patient in NeuroDash.assigned_patients():
		if patient.id != "" and not found.has(patient.id): found.append(patient.id)
	found.sort()
	return found

func refresh_patients() -> void:
	if NeuroDash.syncing: return
	refresh_button.disabled = true
	refresh_button.text = "Refreshing…"
	sync_label.text = ""
	NeuroDash.sync_patients()

func on_sync_finished(result: Dictionary) -> void:
	if not is_instance_valid(refresh_button): return
	refresh_button.disabled = false
	refresh_button.text = "↻  Refresh patient list"
	sync_label.text = str(result.get("message", ""))
	sync_label.add_theme_color_override("font_color", Color("9df5d0") if result.get("ok", false) else Color("ff8a7a"))
	rebuild_suggestions()
	update_note()

func rebuild_suggestions() -> void:
	for child in suggestions.get_children():
		suggestions.remove_child(child)
		child.queue_free()
	var query = id_edit.text.strip_edges()
	var known = all_patients()
	var matches = suggest(query, known)
	if matches.size() > 0:
		suggestions.add_child(UITheme.label("Patients on this computer" if query == "" else "Matching patients", 17, UITheme.MUTED))
	for id in matches: suggestions.add_child(suggestion_button(id, false))
	if query != "" and valid_id(query) and not known.has(query):
		suggestions.add_child(suggestion_button(query, true))

func suggestion_button(id: String, create: bool) -> Button:
	var button = Button.new()
	button.text = ("＋  Create new patient  “%s”" % id) if create else "%s    •    log in" % id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	if create:
		button.add_theme_stylebox_override("normal", UITheme.box(Color(0.05, 0.25, 0.22, 0.6), UITheme.ACCENT, 2, 14, 18, 8))
		button.add_theme_color_override("font_color", Color("9df5d0"))
	button.pressed.connect(func():
		id_edit.text = id
		go())
	return button

## Down arrow moves from the field into the suggestions.
func on_field_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_DOWN:
		for child in suggestions.get_children():
			if child is Button:
				child.grab_focus()
				id_edit.accept_event()
				return

func show_checking() -> void:
	error.text = ""
	note.text = "Checking with the server…"

func update_note() -> void:
	var id = id_edit.text.strip_edges()
	error.text = ""
	if id == "": note.text = "New patient? Enter a new ID and a profile is created for you."
	elif not valid_id(id): note.text = "Use letters, numbers, dashes or underscores."
	elif known_patients().has(id): note.text = "Welcome back."
	elif all_patients().has(id): note.text = "Assigned to this device. A profile will be created when you log in."
	else: note.text = "New patient: a profile will be created when you log in."

func go() -> void:
	var id = id_edit.text.strip_edges()
	if not valid_id(id):
		error.text = "Enter a patient ID using letters, numbers, dashes or underscores."
		return
	signed_in.emit(id)

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

