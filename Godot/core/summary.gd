extends Control
## Unity SUMMARY scene: today's scores, stars and the minutes-per-day chart.
signal back
signal finish
const UITheme = preload("res://core/ui_theme.gd")
const Stats = preload("res://core/stats.gd")
const Rules = preload("res://core/rules.gd")
const ORDER = ["ML", "AP", "MLAP"]
var chart: Control
var scope_movement = "ALL"
var hover = -1
var series: Array = []
var total_label: Label
var scores_box: VBoxContainer
var message: Label
var title_label: Label

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
	page.add_child(UITheme.label("Unlock your potential through play", 40, UITheme.ACCENT))
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left = UITheme.card()
	left.custom_minimum_size.x = 600
	body.add_child(left)
	var left_scroll = ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	var left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_box)
	total_label = UITheme.label("", 30, UITheme.FOCUS)
	left_box.add_child(total_label)
	scores_box = VBoxContainer.new()
	scores_box.add_theme_constant_override("separation", 4)
	left_box.add_child(scores_box)
	var right = UITheme.card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right.add_child(right_box)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right_box.add_child(tabs)
	for kind in ["ALL", "ML", "AP", "MLAP"]:
		var button = Button.new()
		button.text = kind
		button.custom_minimum_size = Vector2(110, 50)
		button.pressed.connect(func():
			scope_movement = kind
			build_series())
		tabs.add_child(button)
	title_label = UITheme.label("", 22, UITheme.MUTED)
	right_box.add_child(title_label)
	chart = Control.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.custom_minimum_size = Vector2(700, 380)
	chart.draw.connect(draw_chart)
	chart.gui_input.connect(on_chart_input)
	chart.mouse_exited.connect(func():
		hover = -1
		chart.queue_redraw())
	right_box.add_child(chart)
	message = UITheme.label("", 20, UITheme.FOCUS, true)
	page.add_child(message)
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	page.add_child(bottom)
	bottom.add_child(button_for("◂ Back to games", func(): back.emit(), 260))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	bottom.add_child(button_for("Upload data now", upload, 260))
	bottom.add_child(button_for("Finish session ▸", func(): finish.emit(), 260))
	build_scores()
	build_series()
	Nav.set_scope(self)
	Nav.tip("summary", "This is your progress. Tap to move between buttons, hold to select. Finish session when you are done.")

func button_for(title: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width, 56)
	button.pressed.connect(action)
	return button

func upload() -> void:
	if not Services.uploads_enabled:
		message.text = "Uploads are turned off. Enable them under Patient, setup & records > Uploads & services."
		return
	Services.upload_now()
	message.text = Services.message

func build_scores() -> void:
	var stars_today = 0
	var before = 0
	for child in scores_box.get_children(): child.queue_free()
	for movement in ORDER:
		scores_box.add_child(UITheme.label("%s movements" % movement, 20, UITheme.MUTED))
		for code in Rules.GAMES:
			if Rules.GAMES[code].movement != movement: continue
			var score = Stats.game_scores(code)
			if score.star_today: stars_today += 1
			before += score.stars_before_today
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var star = UITheme.label("★", 28, UITheme.FOCUS if score.star_today else Color("3a4651"))
			star.custom_minimum_size.x = 34
			row.add_child(star)
			var game_name = UITheme.label(Rules.GAMES[code].title, 22)
			game_name.custom_minimum_size.x = 190
			row.add_child(game_name)
			var today = UITheme.label("%03d / %03d" % [score.today_hits, score.today_targets], 22, Color.WHITE)
			today.custom_minimum_size.x = 130
			row.add_child(today)
			row.add_child(UITheme.label("total %04d" % score.total_hits, 20, UITheme.MUTED))
			scores_box.add_child(row)
	total_label.text = "Stars today  ★ %03d      Until yesterday  %03d →" % [stars_today, before]

func build_series() -> void:
	series.clear()
	var first = Stats.day_number(Stats.today()) - 13
	var last = Stats.day_number(Stats.today())
	var start = str(Records.profile.get("StartDate", ""))
	var end = str(Records.profile.get("EndDate", ""))
	if start.length() >= 10 and end.length() >= 10:
		first = Stats.day_number(start.substr(6, 4) + "-" + start.substr(3, 2) + "-" + start.substr(0, 2))
		last = Stats.day_number(end.substr(6, 4) + "-" + end.substr(3, 2) + "-" + end.substr(0, 2))
		# Keep the chart legible for long prescriptions: show the 31 days around today.
		var today = Stats.day_number(Stats.today())
		if last - first > 30:
			first = clampi(today - 15, first, last - 30)
			last = first + 30
	var plan = 0.0
	if Stats.has_prescription():
		plan = Stats.remaining_minutes().plan if scope_movement == "ALL" else Stats.prescribed(scope_movement)
	for day in range(first, last + 1):
		var date = Time.get_date_string_from_unix_time(day * 86400)
		var minutes = Stats.minutes_on(date, "" if scope_movement == "ALL" else scope_movement)
		series.append({"label": date.substr(8, 2) + "/" + date.substr(5, 2), "value": minutes if day <= Stats.day_number(Stats.today()) else -1.0, "plan": plan})
	title_label.text = "Minutes per day • " + ("all movements" if scope_movement == "ALL" else scope_movement) + ("   (dashed line = prescribed)" if plan > 0 else "")
	chart.queue_redraw()

func plot_rect() -> Rect2:
	return Rect2(64, 16, chart.size.x - 84, chart.size.y - 64)

func point_at(index: int, value: float, top: float) -> Vector2:
	var area = plot_rect()
	var x = area.position.x + (area.size.x * (index + 0.5) / maxi(1, series.size()))
	return Vector2(x, area.end.y - area.size.y * clampf(value / top, 0, 1))

func on_chart_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not series.is_empty():
		var area = plot_rect()
		var index = clampi(int((event.position.x - area.position.x) / area.size.x * series.size()), 0, series.size() - 1)
		if index != hover:
			hover = index
			chart.queue_redraw()

func draw_chart() -> void:
	var area = plot_rect()
	var font = ThemeDB.fallback_font
	var top = 10.0
	for item in series: top = maxf(top, maxf(item.value, item.plan))
	top = ceilf(top / 5.0) * 5.0
	chart.draw_rect(area, Color("111827"))
	for i in range(0, 6):
		var y = area.end.y - area.size.y * i / 5.0
		chart.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("1d4259"), 1)
		chart.draw_string(font, Vector2(0, y + 6), "%d" % int(top * i / 5.0), HORIZONTAL_ALIGNMENT_RIGHT, area.position.x - 8, 18, UITheme.MUTED)
	if series.is_empty(): return
	var every = maxi(1, int(ceil(series.size() / 12.0)))
	for i in series.size():
		if i % every == 0:
			var x = point_at(i, 0, top).x
			chart.draw_string(font, Vector2(x - 30, area.end.y + 26), series[i].label, HORIZONTAL_ALIGNMENT_CENTER, 60, 16, UITheme.MUTED)
	if series[0].plan > 0:
		var y = point_at(0, series[0].plan, top).y
		for x in range(int(area.position.x), int(area.end.x), 14):
			chart.draw_line(Vector2(x, y), Vector2(minf(x + 7, area.end.x), y), UITheme.FOCUS, 2)
	var previous = Vector2.INF
	for i in series.size():
		if series[i].value < 0:
			previous = Vector2.INF
			continue
		var p = point_at(i, series[i].value, top)
		if previous != Vector2.INF: chart.draw_line(previous, p, UITheme.ACCENT, 3)
		previous = p
	for i in series.size():
		if series[i].value < 0: continue
		var p = point_at(i, series[i].value, top)
		chart.draw_circle(p, 7 if i == hover else 5, Color.WHITE if i == hover else UITheme.ACCENT)
	if hover >= 0 and hover < series.size() and series[hover].value >= 0:
		var p = point_at(hover, series[hover].value, top)
		var text = "%s • %.1f min" % [series[hover].label, series[hover].value]
		var box = Rect2(clampf(p.x - 80, area.position.x, area.end.x - 160), maxf(area.position.y, p.y - 44), 160, 32)
		chart.draw_rect(box, Color("0f3a52"))
		chart.draw_rect(box, UITheme.FOCUS, false, 2)
		chart.draw_string(font, box.position + Vector2(0, 23), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 18, Color.WHITE)
