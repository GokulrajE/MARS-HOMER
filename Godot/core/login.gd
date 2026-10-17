extends Control
## First screen: enter the patient ID to log in. An ID that has no records yet is a new
## patient and is created automatically, as in the Unity application.
signal signed_in(name)
signal diagnostics
const UITheme = preload("res://core/ui_theme.gd")
var id_edit: LineEdit
var note: Label
var error: Label
var recent_box: HFlowContainer

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
	column.add_theme_constant_override("separation", 14)
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
	brand.add_child(UITheme.label("MARS HOMER", 44, Color.WHITE))
	var title = UITheme.label("Patient login", 30, UITheme.SKY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(UITheme.label("Patient ID", 18, UITheme.MUTED))
	id_edit = LineEdit.new()
	id_edit.custom_minimum_size = Vector2(0, 56)
	id_edit.placeholder_text = "Enter your patient ID"
	id_edit.text_changed.connect(func(_text): update_note())
	id_edit.text_submitted.connect(func(_text): go())
	column.add_child(id_edit)
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
	var known = known_patients()
	if known.size() > 0:
		column.add_child(UITheme.label("Patients on this computer", 18, UITheme.MUTED))
		recent_box = HFlowContainer.new()
		recent_box.add_theme_constant_override("h_separation", 10)
		recent_box.add_theme_constant_override("v_separation", 10)
		column.add_child(recent_box)
		for id in known.slice(0, 8):
			var chip = Button.new()
			chip.text = id
			chip.custom_minimum_size = Vector2(0, 46)
			chip.pressed.connect(func():
				id_edit.text = id
				go())
			recent_box.add_child(chip)
	update_note()
	id_edit.grab_focus.call_deferred()
	Nav.set_scope(self)

func update_note() -> void:
	var id = id_edit.text.strip_edges()
	error.text = ""
	if id == "": note.text = "New patient? Enter a new ID and a profile is created for you."
	elif not valid_id(id): note.text = "Use letters, numbers, dashes or underscores."
	elif known_patients().has(id): note.text = "Welcome back."
	else: note.text = "New patient: a profile will be created when you log in."

func go() -> void:
	var id = id_edit.text.strip_edges()
	if not valid_id(id):
		error.text = "Enter a patient ID using letters, numbers, dashes or underscores."
		return
	signed_in.emit(id)
