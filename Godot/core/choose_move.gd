extends Control
## Unity CHOOSEMOVE scene: pick a movement, pass its assessment gate, pick a game.
signal back
signal summary
signal play(code)
signal assess(kind)
signal change_plane
const UITheme = preload("res://core/ui_theme.gd")
const Stats = preload("res://core/stats.gd")
const Rules = preload("res://core/rules.gd")
const VideoCard = preload("res://core/video.gd")
const GameCard = preload("res://core/game_card.gd")
const Glyph = preload("res://core/glyph.gd")
const NAMES = {"ML": "Left-right", "AP": "Forward-back", "MLAP": "Combined"}
const BLURBS = {
	"SS": "Steer the ship and shoot asteroids.",
	"MC": "Catch the ball that matches your basket.",
	"FW": "Launch fireworks at glowing targets.",
	"PP": "Return the ball past the opponent.",
	"CB": "A random pilot flies through glowing passages.",
	"TT": "Swim through the openings in the reef.",
	"DC": "Catch diamonds at the corners.",
	"TW": "Wipe the stain off the table.",
	"FR": "Rescue fish from the sharks.",
	"BS": "Touch the sparkling bubbles."
}
# Left and right colours of each game's card.
const TINTS = {
	"SS": ["2a1456", "7a35b8"], "MC": ["b0601a", "f1ac4c"], "FW": ["1d2468", "4a45b5"],
	"PP": ["0f4f57", "1f8c91"], "CB": ["8f431c", "e58b3b"], "TT": ["0e4a6e", "1c8fb3"],
	"DC": ["3a1f6e", "6b3fc2"], "TW": ["64421f", "b07a42"], "FR": ["0b3d6b", "1b72b8"],
	"BS": ["1c2f6b", "3f5fd0"]
}
const ASSESSMENTS = [["ML", "ML AROM", "ml"], ["AP", "AP AROM", "ap"], ["MLAP", "MLAP AROM", "mlap"], ["WEIGHT", "Arm Weight", "weight"]]
var selected = ""
var needs = ""
var message: Label
var extra: Label
var movement_box: VBoxContainer
var game_box: VBoxContainer
var game_title: Label
var assess_box: GridContainer
var video: PanelContainer
var move_buttons: Dictionary = {}
var assess_button: Button
var weight_button: Button
var how_label: Label
const HOW = {
	"ML": "Move your hand left and right along the glowing line, smoothly and without hurrying. Keep your shoulder relaxed and your elbow supported.",
	"AP": "Slide your hand forward, away from your body, and back again along the glowing line. Keep each movement slow and steady.",
	"MLAP": "Trace the whole loop in a steady, comfortable circle, following the ring as it travels around the line."
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 50)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	message = UITheme.label("", 44, Color("8db4ff"))
	page.add_child(message)
	extra = UITheme.label("", 21, UITheme.MUTED, true)
	extra.custom_minimum_size.y = 28
	page.add_child(extra)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	left.add_child(UITheme.label("1  Movement", 22, Color.WHITE))
	movement_box = VBoxContainer.new()
	movement_box.add_theme_constant_override("separation", 10)
	left.add_child(movement_box)
	for movement in Stats.MOVEMENTS:
		if Trial.hardware and Stats.prescribed(movement) <= 0: continue
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 88)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose.bind(movement))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		movement_box.add_child(button)
		move_buttons[movement] = button
	var assessments = UITheme.card(Color(0.04, 0.08, 0.12, 0.62), Color(1, 1, 1, 0.12))
	assessments.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.62), Color(1, 1, 1, 0.12), 1, 22, 16, 14))
	left.add_child(assessments)
	var assessments_column = VBoxContainer.new()
	assessments_column.add_theme_constant_override("separation", 10)
	assessments.add_child(assessments_column)
	assessments_column.add_child(UITheme.label("Assessments at plane %.0f°" % Trial.plane, 20, Color.WHITE))
	var plane_button=Button.new()
	plane_button.text="Training plane · %.0f°  →" % Trial.plane
	plane_button.custom_minimum_size.y=50
	plane_button.pressed.connect(func(): change_plane.emit())
	assessments_column.add_child(plane_button)
	assess_box = GridContainer.new()
	assess_box.columns = 2
	assess_box.add_theme_constant_override("h_separation", 10)
	assess_box.add_theme_constant_override("v_separation", 10)
	assessments_column.add_child(assess_box)
	var middle = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	body.add_child(middle)
	game_title = UITheme.label("2  Game", 22, Color.WHITE)
	middle.add_child(game_title)
	var game_scroll = ScrollContainer.new()
	game_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(game_scroll)
	game_box = VBoxContainer.new()
	game_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_box.add_theme_constant_override("separation", 14)
	game_scroll.add_child(game_box)
	var side_panel = PanelContainer.new()
	side_panel.custom_minimum_size.x = 500
	side_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.12, 0.62), Color(1, 1, 1, 0.12), 1, 22, 14, 14))
	body.add_child(side_panel)
	var side_column = VBoxContainer.new()
	side_column.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_column)
	side_column.add_child(UITheme.label("Patient Reference video", 22, Color.WHITE))
	video = VideoCard.new()
	video.idle_text = "Choose a movement to watch how it is performed."
	video.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side_column.add_child(video)
	how_label = UITheme.label("", 20, Color("d7e3f1"), true)
	side_column.add_child(how_label)
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	page.add_child(bottom)
	var back_button = add_button(bottom, "‹  Back", func(): back.emit(), 150)
	round_button(back_button)
	assess_button = add_button(bottom, "Assess range", func(): start_assessment(), 240)
	round_button(assess_button)
	weight_button = add_button(bottom, "Assess arm weight", func(): assess.emit("WEIGHT"), 270)
	round_button(weight_button)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var finish = add_button(bottom, "Finish session & summary  ›", func(): summary.emit(), 400)
	# The one bright call to action on the screen.
	var bright = UITheme.box(Color("2fd0ee"), Color("a8f0ff"), 1, 30, 24, 8)
	bright.shadow_color = Color(0.2, 0.85, 1.0, 0.45)
	bright.shadow_size = 14
	finish.add_theme_stylebox_override("normal", bright)
	finish.add_theme_stylebox_override("hover", UITheme.box(Color("5de0f7"), Color.WHITE, 2, 30, 24, 8))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: finish.add_theme_color_override(state, Color("04283b"))
	video.stop()
	refresh()
	Nav.tip("choose", "Tap the MARS button to move between items. Hold it to select. Pick a movement, then a game.")

func add_button(parent: Node, title: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width, 58)
	button.pressed.connect(action)
	button.add_theme_font_size_override("font_size", 23)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func round_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", UITheme.box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.28), 1, 30, 24, 8))
	button.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.6), 2, 30, 24, 8))
	button.add_theme_stylebox_override("disabled", UITheme.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.10), 1, 30, 24, 8))

## Mirrors Unity's gate: an assessment must exist for the training plane. In
## simulation the gate is advisory so practice is never blocked.
func gate(movement: String) -> String:
	if not Records.corners.has(movement): return "ASSESS"
	if movement == "MLAP" and Records.weight.is_empty(): return "WEIGHT"
	return ""

func style_movement(button: Button, movement: String, complete: bool) -> void:
	var active = movement == selected
	var fill = Color(0.05, 0.27, 0.34, 0.88) if active else Color(0.10, 0.34, 0.30, 0.6) if complete else Color(0.09, 0.12, 0.17, 0.55)
	var edge = Color("38bdf8") if active else Color("34d399") if complete else Color(1, 1, 1, 0.10)
	var normal = UITheme.box(fill, edge, 3 if active else 1, 24, 22, 10)
	if active:
		normal.shadow_color = Color(0.22, 0.74, 0.97, 0.45)
		normal.shadow_size = 12
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", UITheme.box(fill.lightened(0.12), Color(1, 1, 1, 0.5), 2, 24, 22, 10))
	var ink = Color.WHITE if active else Color("c3d2e2") if complete else Color("8b9bb0")
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: button.add_theme_color_override(state, ink)
	button.add_theme_font_size_override("font_size", 24)

func refresh() -> void:
	for movement in move_buttons:
		var button: Button = move_buttons[movement]
		var plan = Stats.prescribed(movement)
		var done = Stats.today_minutes(movement)
		var complete = plan > 0 and done >= plan
		var timing = "%d / %d min today" % [int(done), int(plan)] if Stats.has_prescription() else "%d min today • free practice" % int(done)
		button.text = "%s%s  %s\n%s%s" % ["• " if movement == selected else "", movement, NAMES[movement], timing, "   ✔ complete" if complete else ""]
		style_movement(button, movement, complete)
	for child in assess_box.get_children(): child.queue_free()
	for entry in ASSESSMENTS: assess_box.add_child(assessment_tile(entry[0], entry[1], entry[2]))
	assess_button.disabled = selected == ""
	assess_button.text = "Assess %s range" % selected if selected != "" else "Assess range"
	weight_button.disabled = selected != "MLAP"
	rebuild_games()
	apply_state()

## One tile of the assessment grid: icon, name and a status pill (N/A or its age).
func assessment_tile(kind: String, title: String, icon: String) -> Control:
	var line = Stats.assessment_line(kind)
	var days = Stats.days_since(kind)
	var good = line.ok
	var tint = Color("5eead4") if good else Color("fdba74")
	var tile = PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, 92)
	tile.add_theme_stylebox_override("panel", UITheme.box(Color(tint.r, tint.g, tint.b, 0.10), Color(tint.r, tint.g, tint.b, 0.32), 1, 18, 12, 8))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	tile.add_child(column)
	var top = HBoxContainer.new()
	column.add_child(top)
	var glyph = Glyph.new()
	glyph.kind = icon
	glyph.color = tint
	glyph.custom_minimum_size = Vector2(40, 40)
	top.add_child(glyph)
	var grow = Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(grow)
	var pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.box(Color(tint.r, tint.g, tint.b, 0.22), Color.TRANSPARENT, 0, 14, 10, 1))
	var pill_text = "N/A" if days < 0 else "today" if days == 0 else "%d d ago" % days
	pill.add_child(UITheme.label(pill_text, 17, tint))
	pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(pill)
	column.add_child(UITheme.label(title, 21, Color("e8eef6") if good else Color("fed7aa")))
	return tile

func rebuild_games() -> void:
	for child in game_box.get_children(): child.queue_free()
	var show = selected != "" and (not Trial.hardware or needs == "")
	game_title.text = "2  Game" if show else "2  Game  (choose a movement first)" if selected == "" else "2  Game  (assessment needed first)"
	if not show: return
	for code in Rules.GAMES:
		if Rules.GAMES[code].movement != selected: continue
		game_box.add_child(game_card(code))

func game_card(code: String) -> Button:
	var tint: Array = TINTS.get(code, ["1d2468", "4a45b5"])
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 148)
	button.set_meta("label", Rules.GAMES[code].title)
	button.tooltip_text = Rules.GAMES[code].title
	button.pressed.connect(func(): play.emit(code))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# The Button's own focus outline would be hidden by the card, so the card draws its own.
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var backdrop = GameCard.new()
	backdrop.button = button
	backdrop.left = Color(tint[0])
	backdrop.right = Color(tint[1])
	backdrop.replay = Stats.game_scores(code).today_targets > 0
	button.add_child(backdrop)
	var content = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	content.offset_right = -118
	content.add_theme_constant_override("separation", 16)
	var thumb = TextureRect.new()
	thumb.texture = load("res://assets/art/bheem_fly.png" if code == "CB" else "res://assets/art/reef_fish.png" if code == "TT" else "res://assets/art/card_%s.png" % code)
	thumb.custom_minimum_size = Vector2(156, 110)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(thumb)
	var words = VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading = UITheme.label(Rules.GAMES[code].title, 29, Color.WHITE)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(heading)
	var blurb = UITheme.label(BLURBS.get(code, ""), 21, Color(1, 1, 1, 0.82), true)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(blurb)
	content.add_child(words)
	button.add_child(content)
	return button

func choose(movement: String) -> void:
	selected = movement
	needs = gate(movement)
	video.play(movement)
	how_label.text = HOW.get(movement, "")
	refresh()
	if needs == "" or not Trial.hardware:
		if game_box.get_child_count() > 0: game_box.get_child(0).grab_focus.call_deferred()
	else: assess_button.grab_focus.call_deferred()

func start_assessment() -> void:
	if selected == "": return
	assess.emit("WEIGHT" if needs == "WEIGHT" else selected)

func deselect() -> void:
	selected = ""
	needs = ""
	video.stop()
	how_label.text = ""
	refresh()
	if move_buttons.size() > 0: move_buttons.values()[0].grab_focus.call_deferred()

func apply_state() -> void:
	if selected == "":
		message.text = "Please select the movement"
		extra.text = "Today's prescribed time is shown on each movement."
		Nav.set_scope(self)
	elif needs != "" and Trial.hardware:
		message.text = "Press the MARS button to start the %s" % ("weight assessment" if needs == "WEIGHT" else "assessment")
		extra.text = "No previous %s found for this training plane. It will be done first." % ("weight assessment" if needs == "WEIGHT" else "assessment")
		# Like Unity, the single press proceeds; a hold goes back to the movement list.
		Nav.set_scope(self, start_assessment, "start assessment", deselect, "change movement")
	else:
		message.text = "Please choose the game"
		extra.text = "" if needs == "" else "No %s on record for this plane yet – optional in simulation." % ("weight assessment" if needs == "WEIGHT" else "assessment")
		Nav.set_scope(self)

func pick_character() -> void:
	var picker=load("res://core/character_picker.gd").new()
	add_child(picker)
	picker.chosen.connect(func():
		picker.queue_free()
		play.emit("CB"))
	picker.cancelled.connect(func():
		remove_child(picker)
		picker.queue_free()
		Nav.set_scope(self))

