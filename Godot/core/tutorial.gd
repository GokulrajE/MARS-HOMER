extends Control
## First-use guide. Shown automatically once, and from Help & tutorial at any time.
## Tap = next page, hold = skip; the practice page teaches both gestures first.
signal closed
const UITheme = preload("res://core/ui_theme.gd")
const VideoCard = preload("res://core/video.gd")
const PAGES = [
	{"title": "Welcome to MARS HOMER", "kind": "text", "art": "flow", "body": "MARS HOMER guides you through robot-assisted arm training with short games.

Every day follows the same four steps, shown on the right.

This short guide shows you how to move around. It takes about a minute."},
	{"title": "Your MARS button", "kind": "demo", "body": "One button controls the whole application.\n\nTAP  (a quick press)  →  go to the next item, or the main action of the screen.\nHOLD  (keep pressing)  →  select the highlighted item.\n\nThe yellow outline shows what a hold will select. The bar at the bottom of the screen always tells you what tap and hold do right now."},
	{"title": "Try it", "kind": "practice", "body": "Press your MARS button now.\n\nFirst give it one quick TAP, then press and HOLD until the bar fills.\nNo MARS button connected? Press F2 on the keyboard, or use the mouse."},
	{"title": "Getting set up", "kind": "video", "video": "SETUP", "second": "ATTACH", "body": "On the setup screen MARS asks you to calibrate, activate and then attach your arm. Each step shows one instruction; press the MARS button once to continue.\n\nWatch how the arm is activated and attached. Remove your hand from the strap before switching off."},
	{"title": "Choosing a movement", "kind": "video", "video": "MLAP", "second": "ML", "body": "Orange cards still have time left today; green cards are complete.\n\nTap to move between movements, hold to choose one. A short video shows how to move. If the range has not been assessed yet, MARS will ask you to do that first, then you pick a game."},
	{"title": "During a game", "kind": "text", "art": "hud", "body": "Each game lasts 60 active seconds.\n\nTAP  →  pause or resume\nHOLD  →  finish early and save\n\nMove the robot arm to reach the targets. Your score, hits and speed are shown at the top. Everything is saved automatically, and a summary card appears when the time is up."},
	{"title": "You are ready", "kind": "text", "art": "ready", "body": "You can open this guide again at any time from Help & tutorial on the first screen.\n\nShort tips also appear the first time you visit each screen.\n\nTap the MARS button to start."}
]
var index = 0
var title_label: Label
var body_label: Label
var stage: Control
var video_a: PanelContainer
var video_b: PanelContainer
var demo: Control
var practice_box: VBoxContainer
var progress_label: Label
var next_button: Button
var prev_button: Button
var tapped = false
var held = false
var age = 0.0
var advance_at = -1.0
var stage_cycle = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.03, 0.07, 0.12, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 80)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	progress_label = UITheme.label("", 20, UITheme.MUTED)
	page.add_child(progress_label)
	title_label = UITheme.label("", 46, UITheme.ACCENT)
	page.add_child(title_label)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 36)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	body_label = UITheme.label("", 26, UITheme.TEXT, true)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body.add_child(body_label)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(620, 420)
	body.add_child(stage)
	video_a = VideoCard.new()
	video_a.hide_when_idle = true
	video_a.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage.add_child(video_a)
	demo = Control.new()
	demo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo.draw.connect(draw_demo)
	stage.add_child(demo)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	prev_button = make_button("◂ Previous", func(): go(index - 1), 200)
	row.add_child(prev_button)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(make_button("Skip tutorial", close, 220))
	next_button = make_button("Next ▸", func(): go(index + 1), 220)
	row.add_child(next_button)
	go(0)

func make_button(title: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width, 58)
	button.pressed.connect(action)
	return button

func close() -> void:
	video_a.stop()
	closed.emit()

func go(target: int) -> void:
	if target >= PAGES.size():
		close()
		return
	index = clampi(target, 0, PAGES.size() - 1)
	var item = PAGES[index]
	title_label.text = item.title
	body_label.text = item.body
	progress_label.text = "Step %d of %d" % [index + 1, PAGES.size()]
	prev_button.disabled = index == 0
	next_button.text = "Start ▸" if index == PAGES.size() - 1 else "Next ▸"
	tapped = false
	held = false
	advance_at = -1.0
	video_a.visible = item.kind == "video"
	demo.visible = item.kind == "demo" or item.kind == "practice" or item.has("art")
	if item.kind == "video":
		video_a.play(item.video)
		stage_cycle = 0.0
	else: video_a.stop()
	apply_nav()


func practice_tap() -> void:
	tapped = true
	check_practice()

func practice_hold() -> void:
	held = true
	check_practice()

func next_page() -> void:
	go(index + 1)

func apply_nav() -> void:
	if PAGES[index].kind == "practice":
		# Practice: the gestures are recorded here instead of navigating.
		Nav.set_scope(self, practice_tap, "tap (practice)", practice_hold, "hold (practice)")
	else:
		Nav.set_scope(self, next_page, "next page", close, "skip tutorial")

func check_practice() -> void:
	if tapped and held and advance_at < 0: advance_at = age + 1.2

func _process(delta: float) -> void:
	age += delta
	if advance_at > 0 and age >= advance_at:
		advance_at = -1.0
		go(index + 1)
	var item = PAGES[index]
	# Alternate the two clips so both movements are seen.
	if item.kind == "video" and item.has("second"):
		stage_cycle += delta
		if stage_cycle > 9.0:
			stage_cycle = 0.0
			video_a.play(item.second if video_a.current == item.video else item.video)
	demo.queue_redraw()

func draw_art(art: String) -> void:
	var font = ThemeDB.fallback_font
	match art:
		"flow":
			var steps = [["1", "Set up & activate MARS", "Calibrate, activate, attach the arm"], ["2", "Choose a movement", "Assessment first if needed"], ["3", "Play a 60-second game", "Move the arm to reach targets"], ["4", "Review your progress", "Scores, stars and minutes"]]
			for i in steps.size():
				var top = 10 + i * 100
				demo.draw_style_box(UITheme.box(UITheme.BUTTON, UITheme.ACCENT, 2, 16), Rect2(0, top, stage.size.x, 78))
				demo.draw_string(font, Vector2(18, top + 52), steps[i][0], HORIZONTAL_ALIGNMENT_LEFT, 40, 40, UITheme.FOCUS)
				demo.draw_string(font, Vector2(70, top + 34), steps[i][1], HORIZONTAL_ALIGNMENT_LEFT, stage.size.x - 80, 26, Color.WHITE)
				demo.draw_string(font, Vector2(70, top + 62), steps[i][2], HORIZONTAL_ALIGNMENT_LEFT, stage.size.x - 80, 19, UITheme.MUTED)
				if i < steps.size() - 1: demo.draw_string(font, Vector2(stage.size.x / 2 - 20, top + 98), "▼", HORIZONTAL_ALIGNMENT_CENTER, 40, 20, UITheme.ACCENT)
		"hud":
			demo.draw_style_box(UITheme.box(Color("111827"), UITheme.ACCENT, 2, 12), Rect2(0, 20, stage.size.x, 70))
			demo.draw_string(font, Vector2(16, 62), "Space Shooter • ML   |   42 s   |   Hits 5 / 7", HORIZONTAL_ALIGNMENT_LEFT, stage.size.x - 20, 22, Color.WHITE)
			demo.draw_style_box(UITheme.box(Color("1f2937"), Color("405169"), 1, 12), Rect2(0, 110, stage.size.x, 230))
			demo.draw_circle(Vector2(stage.size.x * 0.28, 260), 26, Color("c0634a"))
			demo.draw_rect(Rect2(stage.size.x * 0.66, 230, 14, 70), UITheme.FOCUS)
			demo.draw_string(font, Vector2(0, 372), "The bar at the bottom tells you what the button does", HORIZONTAL_ALIGNMENT_CENTER, stage.size.x, 20, UITheme.MUTED)
			demo.draw_style_box(UITheme.box(Color(0.03, 0.08, 0.13, 0.94), Color("405169"), 1, 6, 12, 4), Rect2(0, 388, stage.size.x, 30))
			demo.draw_string(font, Vector2(10, 410), "tap: pause  •  hold 1.5 s: finish & save", HORIZONTAL_ALIGNMENT_LEFT, stage.size.x - 20, 17, Color.WHITE)
		"ready":
			demo.draw_circle(Vector2(stage.size.x / 2, 190), 120, Color("1d6b3a"))
			demo.draw_polyline(PackedVector2Array([Vector2(stage.size.x / 2 - 55, 190), Vector2(stage.size.x / 2 - 15, 232), Vector2(stage.size.x / 2 + 62, 140)]), Color.WHITE, 16)

func draw_demo() -> void:
	var font = ThemeDB.fallback_font
	if PAGES[index].has("art"):
		draw_art(PAGES[index].art)
		return
	var center = Vector2(stage.size.x / 2, 190)
	var practice = PAGES[index].kind == "practice"
	var phase = fmod(age, 6.0)
	var pressed = false
	var fill = 0.0
	var caption = ""
	if practice:
		pressed = Nav.holding
		fill = clampf((Time.get_ticks_msec() / 1000.0 - Nav.started) / Nav.hold_time(), 0, 1) if Nav.holding else 0.0
		caption = "Waiting for your press…"
	elif phase < 1.2:
		pressed = phase > 0.3 and phase < 0.6
		caption = "TAP  →  next"
	elif phase > 2.0 and phase < 5.0:
		pressed = true
		fill = clampf((phase - 2.0) / 2.0, 0, 1)
		caption = "HOLD  →  select" if fill < 1.0 else "Selected ✔"
	else: caption = ""
	demo.draw_circle(center + Vector2(0, 10), 112, Color("06121c"))
	demo.draw_circle(center + Vector2(0, 14 if pressed else 4), 100, Color("7a1f2b") if pressed else Color("c0392b"))
	demo.draw_arc(center + Vector2(0, 14 if pressed else 4), 118, -PI / 2, -PI / 2 + TAU * fill, 64, UITheme.FOCUS, 10)
	demo.draw_string(font, center + Vector2(-120, 12), "MARS", HORIZONTAL_ALIGNMENT_CENTER, 240, 36, Color.WHITE)
	demo.draw_string(font, Vector2(0, 360), caption, HORIZONTAL_ALIGNMENT_CENTER, stage.size.x, 34, UITheme.FOCUS)
	if practice:
		demo.draw_string(font, Vector2(0, 405), "%s Tap     %s Hold" % ["✔" if tapped else "○", "✔" if held else "○"], HORIZONTAL_ALIGNMENT_CENTER, stage.size.x, 28, Color("7be08a") if tapped and held else Color.WHITE)
