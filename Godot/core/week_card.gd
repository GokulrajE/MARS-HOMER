extends Control
## Welcome-screen dashboard: today's progress as a large ring, each movement's share of
## the prescription, and the last seven days as bars with the daily target marked.
const UITheme = preload("res://core/ui_theme.gd")
const Stats = preload("res://core/stats.gd")
const MOVEMENTS = [["ML", "Left-right", Color("fdba74")], ["AP", "Forward-back", Color("7dd3fc")], ["MLAP", "Combined", Color("a78bfa")]]
var days: Array = []
var today_done = 0.0
var today_plan = 0.0
var per_move: Array = []
var streak = 0
var week_total = 0.0
var stars_today = 0
var has_plan = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(640, 440)

func refresh() -> void:
	has_plan = Stats.has_prescription()
	var info = Stats.remaining_minutes()
	today_done = info.done
	today_plan = info.plan
	per_move.clear()
	for m in MOVEMENTS: per_move.append({"name": m[1], "code": m[0], "color": m[2], "done": Stats.today_minutes(m[0]), "plan": Stats.prescribed(m[0])})
	days.clear()
	week_total = 0.0
	for i in range(6, -1, -1):
		var date = Stats.date_string(-i)
		var unix = Time.get_unix_time_from_datetime_string(date + "T00:00:00")
		var weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][Time.get_date_dict_from_unix_time(unix).weekday]
		var minutes = Stats.minutes_on(date)
		days.append({"day": weekday, "minutes": minutes, "today": i == 0})
		week_total += minutes
	streak = 0
	for i in range(days.size() - 1, -1, -1):
		if days[i].minutes > 0.05: streak += 1
		elif i == days.size() - 1: continue
		else: break
	stars_today = 0
	for code in load("res://core/rules.gd").GAMES:
		if Stats.game_scores(code).star_today: stars_today += 1
	queue_redraw()

func text(font: Font, at: Vector2, value: String, size_px: int, color: Color, width: float = -1, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at, value, align, width, size_px, color)

func _draw() -> void:
	var font = UITheme.FONT
	var w = size.x
	# ---- Hero: today's ring
	var centre = Vector2(112, 118)
	var fraction = clampf(today_done / maxf(today_plan, 0.001), 0, 1) if has_plan else 0.0
	for k in 4: draw_circle(centre, 96 - k * 3, Color(0.2, 0.9, 0.8, 0.03 + k * 0.012))
	draw_arc(centre, 78, 0, TAU, 72, Color(1, 1, 1, 0.08), 16, true)
	if fraction > 0.003:
		var color = Color("6ee7a0") if fraction >= 1.0 else Color("38d2c0")
		draw_arc(centre, 78, -PI / 2, -PI / 2 + TAU * fraction, 72, Color(color, 0.22), 24, true)
		draw_arc(centre, 78, -PI / 2, -PI / 2 + TAU * fraction, 72, color, 14, true)
		draw_circle(centre + Vector2.from_angle(-PI / 2 + TAU * fraction) * 78, 8, Color.WHITE)
	if has_plan:
		text(font, centre + Vector2(-60, 4), "%d" % int(today_done), 46, Color.WHITE, 120, HORIZONTAL_ALIGNMENT_CENTER)
		text(font, centre + Vector2(-60, 34), "of %d min" % int(today_plan), 19, UITheme.MUTED, 120, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		text(font, centre + Vector2(-60, 10), "%d min" % int(today_done), 30, Color.WHITE, 120, HORIZONTAL_ALIGNMENT_CENTER)
	text(font, Vector2(24, 232), "TODAY", 17, UITheme.MUTED, 176, HORIZONTAL_ALIGNMENT_CENTER)
	# ---- Movement bars
	var x0 = 246.0
	var bar_w = w - x0 - 8
	for i in per_move.size():
		var m = per_move[i]
		var y = 46.0 + i * 62.0
		var finished = m.plan > 0 and m.done >= m.plan
		text(font, Vector2(x0, y), m.name + ("  ✓" if finished else ""), 21, Color("6ee7a0") if finished else Color.WHITE)
		var tag = "%d / %d min" % [int(m.done), int(m.plan)] if has_plan else "%d min" % int(m.done)
		text(font, Vector2(x0, y), tag, 19, UITheme.MUTED, bar_w, HORIZONTAL_ALIGNMENT_RIGHT)
		var track = Rect2(x0, y + 12, bar_w, 14)
		draw_rect(track, Color(1, 1, 1, 0.07))
		var f = clampf(m.done / maxf(m.plan, 0.001), 0, 1) if m.plan > 0 else 0.0
		if f > 0.003:
			draw_rect(Rect2(track.position, Vector2(track.size.x * f, track.size.y)), Color(m.color, 0.95))
			draw_rect(Rect2(track.position, Vector2(track.size.x * f, 4)), Color(1, 1, 1, 0.25))
	# ---- Facts
	var facts = [["%d" % streak, "day streak"], ["%d" % int(week_total), "min this week"], ["%d" % stars_today, "stars today"]]
	var cell = (w - 8) / 3.0
	for i in facts.size():
		var r = Rect2(i * cell + 4, 262, cell - 10, 58)
		var style = UITheme.box(Color(1, 1, 1, 0.055), Color(1, 1, 1, 0.10), 1, 14, 0, 0)
		draw_style_box(style, r)
		text(font, r.position + Vector2(0, 30), facts[i][0], 30, Color("ffe293"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		text(font, r.position + Vector2(0, 50), facts[i][1], 15, UITheme.MUTED, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# ---- Last seven days
	text(font, Vector2(4, 350), "LAST 7 DAYS", 16, UITheme.MUTED)
	var chart = Rect2(4, 362, w - 8, maxf(78.0, size.y - 366.0))
	var daily = today_plan if has_plan else 0.0
	var top = maxf(1.0, maxf(daily, 1.0))
	for d in days: top = maxf(top, d.minutes)
	var slot = chart.size.x / 7.0
	for i in days.size():
		var d = days[i]
		var height = (chart.size.y - 34) * clampf(d.minutes / top, 0, 1)
		var bar = Rect2(chart.position.x + i * slot + slot * 0.22, chart.position.y + chart.size.y - 22 - height, slot * 0.56, maxf(height, 3))
		var hit = daily > 0 and d.minutes >= daily
		var color = Color("6ee7a0") if hit else Color("38d2c0") if d.today else Color("5b7aa6")
		draw_style_box(UITheme.box(Color(color, 0.95 if d.minutes > 0 else 0.25), Color.TRANSPARENT, 0, 6, 0, 0), bar)
		text(font, Vector2(chart.position.x + i * slot, chart.position.y + chart.size.y - 4), d.day, 15, Color.WHITE if d.today else UITheme.MUTED, slot, HORIZONTAL_ALIGNMENT_CENTER)
		if d.minutes > 0: text(font, Vector2(chart.position.x + i * slot, bar.position.y - 4), "%d" % int(d.minutes), 14, Color(1, 1, 1, 0.85), slot, HORIZONTAL_ALIGNMENT_CENTER)
	if daily > 0:
		var y_target = chart.position.y + chart.size.y - 22 - (chart.size.y - 34) * clampf(daily / top, 0, 1)
		for x in range(int(chart.position.x), int(chart.end.x), 14): draw_line(Vector2(x, y_target), Vector2(minf(x + 7, chart.end.x), y_target), Color(1, 0.89, 0.58, 0.55), 1.5)
		text(font, Vector2(chart.position.x, y_target - 4), "daily target", 13, Color(1, 0.89, 0.58, 0.8))
