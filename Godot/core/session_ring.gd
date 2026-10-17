extends Control
## Bottom-right progress of today's prescription for the movement being trained: a small ring
## that fills as trials are completed, with "trial 3 / 10". Each trial is a 60-second round,
## so a prescription of 10 minutes is 10 trials. Hidden for users without a prescription.
const UITheme = preload("res://core/ui_theme.gd")
const Stats = preload("res://core/stats.gd")
var fraction = 0.0
var trial_number = 1
var trial_total = 0
var minutes_done = 0.0
var minutes_plan = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(148, 66)

## Completed minutes today plus the trial in progress.
static func measure(movement: String, running_seconds: float) -> Dictionary:
	var plan = Stats.prescribed(movement)
	var done = Stats.today_minutes(movement)
	var finished = 0
	var today = Stats.today()
	for row in Trial.history:
		if row[7] == movement and str(row[4]).begins_with(today): finished += 1
	return {"plan": plan, "done": done + running_seconds / 60.0, "finished": finished}

func _process(_delta: float) -> void:
	var m = measure(Trial.movement, Trial.duration)
	minutes_plan = m.plan
	minutes_done = m.done
	trial_total = ceili(m.plan)
	trial_number = mini(m.finished + 1, maxi(trial_total, 1))
	fraction = clampf(m.done / maxf(m.plan, 0.001), 0, 1) if m.plan > 0 else 0.0
	visible = Stats.has_prescription() and m.plan > 0
	queue_redraw()

func _draw() -> void:
	var panel = UITheme.box(Color(0.035, 0.065, 0.15, 0.78), Color("9c9bff", 0.5), 1, 22, 0, 0)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var centre = Vector2(36, size.y / 2.0)
	draw_arc(centre, 21, 0, TAU, 48, Color(0.3, 0.32, 0.5, 0.45), 6, true)
	if fraction > 0.005: draw_arc(centre, 21, -PI / 2, -PI / 2 + TAU * fraction, 48, Color("7be8c0") if fraction >= 1.0 else Color("8fb4ff"), 6, true)
	var font = ThemeDB.fallback_font
	draw_string(font, centre + Vector2(-20, 5), "%d%%" % int(fraction * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)
	draw_string(font, Vector2(68, 24), "Trial", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c7d7ef"))
	draw_string(font, Vector2(68, 44), "%d / %d" % [trial_number, trial_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe293"))
	draw_string(font, Vector2(68, 59), "%.1f/%.0f min" % [minutes_done, minutes_plan], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9db0cc"))
