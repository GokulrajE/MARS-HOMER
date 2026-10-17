extends Control
## Active-range (ML / AP / MLAP) and arm-weight assessments.
## Flow and mapping follow Unity's MarsAssessAROM: start -> record -> adjust -> save.
## The whole fixed robot workspace is drawn so the full range is always visible.
signal finished
const UITheme = preload("res://core/ui_theme.gd")
const VideoCard = preload("res://core/video.gd")
## Unity MarsDefs EPMINZ..EPMAXZ (horizontal) and EPMINY..EPMAXY (reach), in metres.
const WORKSPACE = Rect2(0.010, 0.145, 0.480, 0.620)
## The area shown. It starts as Unity's workspace and widens smoothly if the arm reaches past
## it, so the whole range always fits on the screen instead of being cut off at one side.
var view = WORKSPACE
var view_goal = WORKSPACE
const VIEW_MARGIN = 0.02
const PLOT = Rect2(40, 150, 1000, 700)
enum { INIT, RECORD, ADJUST, SAVED }
var kind = "MLAP"
var state = INIT
var recording = false
var review = false
var saved = false
var retain = 100.0
var points: Array[Vector2] = []
var raw_file: FileAccess
var raw_name = ""
var extrema: Array[Vector2] = []
var weight_samples: Array[Vector3] = []
var weight_rows: Array = []
var target_index = 0
var hold = 0.0
var last_sample_time = 0.0
var cursor = Vector2.ZERO
var targets: Array[Vector2] = []
var previous: Dictionary = {}
var sampled = 0
var mirrored = true
var instruction: Label
var readout: Label
var detail: Label
var steps: Label
var primary_button: Button
var redo_button: Button
var less_button: Button
var more_button: Button
var back_button: Button
var reference: PanelContainer

func is_weight() -> bool:
	return kind == "WEIGHT"

func _ready() -> void:
	Trial.movement = "MLAP" if is_weight() else kind
	mirrored = str(Records.profile.get("TrainingSide", "RIGHT")).to_upper() == "RIGHT"
	previous = Records.corners.get(kind, {}) if not is_weight() else {}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = "Arm weight assessment" if is_weight() else "%s range assessment" % kind
	add_child(label(title, Vector2(40, 22), 24, UITheme.MUTED))
	instruction = label("", Vector2(40, 58), 34, UITheme.FOCUS)
	instruction.custom_minimum_size = Vector2(1500, 0)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(instruction)
	var panel = VBoxContainer.new()
	panel.position = Vector2(1070, 150)
	panel.size = Vector2(490, 700)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)
	steps = UITheme.label("", 22, UITheme.MUTED)
	panel.add_child(steps)
	readout = UITheme.label("", 26, Color.WHITE, true)
	panel.add_child(readout)
	# The same guided clip as on the movement screen, so the patient sees how to move.
	reference = VideoCard.new()
	reference.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(reference)
	if not is_weight(): reference.play(kind)
	else: reference.hide()
	detail = UITheme.label("", 20, UITheme.MUTED, true)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(detail)
	var retain_row = HBoxContainer.new()
	retain_row.add_theme_constant_override("separation", 10)
	panel.add_child(retain_row)
	less_button = button("Reduce range −5%", func(): adjust_retain(-5), retain_row, 240)
	more_button = button("+5%", func(): adjust_retain(5), retain_row, 110)
	redo_button = button("Redo assessment", redo, panel, 0)
	primary_button = button("", primary, panel, 0)
	primary_button.custom_minimum_size.y = 76
	primary_button.add_theme_font_size_override("font_size", 28)
	back_button = button("◂ Back", func(): finished.emit(), self, 150)
	back_button.position = Vector2(40, 880)
	var bounds = Records.limits("MLAP")
	targets = [Vector2(bounds.position.x, bounds.get_center().y), Vector2(bounds.end.x, bounds.get_center().y), Vector2(bounds.get_center().x, bounds.end.y), Vector2(bounds.get_center().x, bounds.position.y), bounds.get_center()]
	if Records.corners.has("MLAP"):
		var row = Records.corners.MLAP
		var center = Vector2.ZERO
		var names = ["Left", "Right", "Top", "Bottom"]
		for i in 4:
			targets[i] = Vector2(float(row[names[i] + "AdjustedX"]), float(row[names[i] + "AdjustedY"]))
			center += targets[i]
		targets[4] = center / 4
	Robot.sample_received.connect(on_sample)
	refresh()
	Nav.tip("assess", "Press the MARS button to start. Move through your full comfortable range, press it again to review, then once more to save.")

func label(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var node = UITheme.label(text, size, color)
	node.position = pos
	return node

func button(text: String, action: Callable, parent: Node, width: float) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(width, 56)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

## The MARS button: one press advances to the next step, as in Unity.
func primary() -> void:
	match state:
		INIT: start()
		RECORD: stop()
		ADJUST: save()
		SAVED: finished.emit()

func redo() -> void:
	reset_view()
	if recording: stop_recording()
	state = INIT
	review = false
	saved = false
	retain = 100.0
	points.clear()
	extrema.clear()
	weight_rows.clear()
	weight_samples.clear()
	target_index = 0
	refresh()

func adjust_retain(step: float) -> void:
	retain = clampf(retain + step, 50, 100)
	refresh()

func start() -> void:
	if recording: return
	if Trial.hardware and not Robot.ready_for_training():
		instruction.text = "Connect, calibrate and activate MARS first."
		return
	if is_weight() and not Records.corners.has("MLAP"):
		instruction.text = "Complete the MLAP range assessment first."
		return
	reset_view()
	points.clear()
	extrema.clear()
	weight_rows.clear()
	weight_samples.clear()
	target_index = 0
	hold = 0
	sampled = 0
	review = false
	saved = false
	raw_name = ("armweightraw-" if is_weight() else "romraw-" + kind + "-") + Trial.stamp().replace(" ", "_").replace(":", "-") + "-" + str(Time.get_ticks_msec()) + ".csv"
	raw_file = FileAccess.open(Trial.user_path().path_join("rawdata/" + raw_name), FileAccess.WRITE)
	if raw_file == null:
		instruction.text = "Could not create the assessment raw file."
		return
	raw_file.store_line(":Device  : MARS")
	raw_file.store_line(":Location: " + str(Records.profile.get("Location","")))
	raw_file.store_line(":User    : " + Trial.user_id)
	raw_file.store_line(":Movement: " + ("MLAP" if is_weight() else kind))
	raw_file.store_line(":TrialType: " + ("Assessment" if Trial.hardware else "SimulationAssessment"))
	raw_file.store_line(Trial.RAW_HEADER + ",Angle1,Angle2,Angle3,Angle4")
	recording = true
	state = RECORD
	last_sample_time = Time.get_ticks_msec() / 1000.0
	refresh()

func on_sample(_packet: Dictionary) -> void:
	if recording and Trial.hardware:
		var now = Time.get_ticks_msec() / 1000.0
		collect(clampf(now - last_sample_time, 0, 0.1))
		last_sample_time = now

func collect(delta: float) -> void:
	if not recording or raw_file == null: return
	if Trial.hardware and not Robot.ready_for_training():
		hold = 0
		weight_samples.clear()
		return
	var value = Robot.last_packet.plane_endpoint if Trial.hardware else cursor
	cursor = value
	points.append(value)
	widen_view(value)
	var row: PackedStringArray = []
	row.resize(36)
	row.fill("")
	row[0] = str(Time.get_ticks_msec() / 1000.0)
	row[1] = str(sampled)
	row[15] = str(value.y)
	row[16] = str(value.x)
	row[26] = "ASSESSING"
	row[30] = kind + ";Target=" + str(target_index)
	row[31] = "MARS" if Trial.hardware else "SIMULATION"
	if Trial.hardware: Trial.fill_telemetry(row, Robot.last_packet)
	raw_file.store_csv_line(row)
	sampled += 1
	if sampled % 100 == 0: raw_file.flush()
	if is_weight() and target_index < targets.size():
		if value.distance_to(targets[target_index]) <= 0.025:
			hold += delta
			weight_samples.append(Vector3(value.x, value.y, Robot.last_packet.force if Trial.hardware else 20.0))
			if hold >= 2:
				var average = Vector3.ZERO
				for sample in weight_samples: average += sample
				average /= weight_samples.size()
				weight_rows.append([targets[target_index].x, targets[target_index].y, average.x, average.y, average.z])
				weight_samples.clear()
				hold = 0
				target_index += 1
				if target_index == 5: stop()
		else:
			hold = 0
			weight_samples.clear()

func stop_recording() -> void:
	recording = false
	if raw_file != null:
		raw_file.flush()
		raw_file.close()
		raw_file = null

func stop() -> void:
	if not recording: return
	stop_recording()
	if is_weight():
		review = weight_rows.size() == 5
		detail.text = "" if review else "Not all five targets were recorded. Press Redo to try again."
		state = ADJUST if review else INIT
		refresh()
		return
	if points.size() < 20:
		state = INIT
		refresh()
		detail.text = "Not enough movement was recorded. Start again and move through your full range."
		return
	var by_x = points.duplicate()
	var by_y = points.duplicate()
	by_x.sort_custom(func(a, b): return a.x < b.x)
	by_y.sort_custom(func(a, b): return a.y < b.y)
	var count = maxi(1, int(points.size() * 0.05))
	for selection in [by_y.slice(-count), by_y.slice(0, count), by_x.slice(0, count), by_x.slice(-count)]:
		var mean = Vector2.ZERO
		for point in selection: mean += point
		extrema.append(mean / selection.size())
	review = true
	state = ADJUST
	refresh()

## Extremes pulled towards their centre by the "retain" percentage.
func adjusted() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if extrema.size() < 4: return result
	var center = (extrema[0] + extrema[1] + extrema[2] + extrema[3]) / 4
	for point in extrema: result.append(center + (point - center) * (float(retain) / 100.0))
	return result

func save() -> void:
	if recording or not review: return
	var row: PackedStringArray = [Trial.stamp(), str(Trial.plane)]
	var result = false
	if is_weight():
		for values in weight_rows:
			for value in values: row.append(str(value))
		row.append(raw_name)
		result = Records.append(Trial.user_path().path_join("armweight/armweight.csv"), Records.WEIGHT_HEADER, row)
	else:
		var center = (extrema[0] + extrema[1] + extrema[2] + extrema[3]) / 4
		var width = extrema[3].x - extrema[2].x
		var height = extrema[0].y - extrema[1].y
		if (kind != "AP" and width <= 0.001) or (kind != "ML" and height <= 0.001):
			detail.text = "The measured range is too small. Press Redo and move through your full range."
			return
		for point in extrema:
			row.append(str(point.x))
			row.append(str(point.y))
		for point in extrema:
			var moved = center + (point - center) * (float(retain) / 100.0)
			row.append(str(moved.x))
			row.append(str(moved.y))
		row.append(raw_name)
		result = Records.append(Trial.user_path().path_join("rom/" + kind + "-rom.csv"), Records.ROM_HEADER, row)
	if result:
		Records.load_assessments()
		Records.log_event("Saved " + kind + " assessment; " + raw_name)
		review = false
		saved = true
		state = SAVED
		refresh()
	else: detail.text = Records.error

## World (robot plane, metres) <-> screen. Like Unity, each axis spans the plot;
## a right arm mirrors the horizontal axis.
func widen_view(point: Vector2) -> void:
	var needed = Rect2(point - Vector2(VIEW_MARGIN, VIEW_MARGIN), Vector2(VIEW_MARGIN, VIEW_MARGIN) * 2.0)
	view_goal = view_goal.merge(needed)

func reset_view() -> void:
	view = WORKSPACE
	view_goal = WORKSPACE

func to_screen(point: Vector2) -> Vector2:
	# Anything beyond the robot's workspace is pinned to the frame, never drawn outside it.
	var nx = clampf((point.x - view.position.x) / view.size.x, 0.0, 1.0)
	var ny = clampf((point.y - view.position.y) / view.size.y, 0.0, 1.0)
	if mirrored: nx = 1.0 - nx
	return Vector2(PLOT.position.x + nx * PLOT.size.x, PLOT.end.y - ny * PLOT.size.y)

func to_world(screen: Vector2) -> Vector2:
	var nx = clampf((screen.x - PLOT.position.x) / PLOT.size.x, 0, 1)
	var ny = clampf((PLOT.end.y - screen.y) / PLOT.size.y, 0, 1)
	if mirrored: nx = 1.0 - nx
	return Vector2(view.position.x + nx * view.size.x, view.position.y + ny * view.size.y)

func refresh() -> void:
	var names = ["Start", "Record", "Review", "Saved"]
	var parts: Array = []
	for i in names.size(): parts.append(("●  " if i == state else "○  ") + names[i])
	steps.text = "   ".join(parts)
	less_button.visible = state == ADJUST and not is_weight()
	more_button.visible = less_button.visible
	redo_button.visible = state == RECORD or state == ADJUST
	match state:
		INIT:
			instruction.text = "Press the MARS button to start the assessment."
			primary_button.text = "Start recording"
			if not detail.text.begins_with("Not "): detail.text = intro_text()
		RECORD:
			instruction.text = "Reach each target and hold still for 2 seconds." if is_weight() else record_text()
			primary_button.text = "Done — review" if not is_weight() else "Stop"
			detail.text = ""
		ADJUST:
			instruction.text = "Five targets recorded. Press the MARS button to save." if is_weight() else "Check the range. Reduce it if needed, then press the MARS button to save."
			primary_button.text = "Save assessment"
		SAVED:
			var next_weight = kind == "MLAP" and Records.weight.is_empty()
			instruction.text = "Saved. Press the MARS button to continue." + (" The arm-weight assessment is next." if next_weight else "")
			primary_button.text = "Continue ▸"
			detail.text = ""
	var editing = state == RECORD or state == ADJUST
	Nav.set_scope(self, primary, primary_button.text.to_lower(), redo if editing else func(): finished.emit(), "redo" if editing else "go back")

func intro_text() -> String:
	if is_weight(): return "MARS measures the arm's weight at five points: left, right, top, bottom and centre. Move to each target and keep still while it fills."
	return {"ML": "Move left and right as far as is comfortable.", "AP": "Move forward and back as far as is comfortable.", "MLAP": "Draw the largest comfortable circle you can with your hand."}[kind] + " The frame shows the whole area MARS can reach."

func record_text() -> String:
	return "Move through your full comfortable range. Press the MARS button when you are done."

func range_text() -> String:
	var moved = adjusted()
	if moved.size() < 4: return ""
	# Shown in centimetres; stored and computed in metres.
	var width = (moved[3].x - moved[2].x) * 100.0
	var height = (moved[0].y - moved[1].y) * 100.0
	match kind:
		"ML": return "Range: %.1f cm" % width
		"AP": return "Range: %.1f cm" % height
	return "ML %.1f cm  •  AP %.1f cm" % [width, height]

func _process(delta: float) -> void:
	var blend = 1.0 - exp(-7.0 * delta)
	view = Rect2(view.position.lerp(view_goal.position, blend), view.size.lerp(view_goal.size, blend))
	if not Trial.hardware:
		var mouse = get_local_mouse_position()
		if PLOT.has_point(mouse): cursor = to_world(mouse)
		elif cursor == Vector2.ZERO: cursor = view.get_center()
	elif Robot.last_packet.has("plane_endpoint"): cursor = Robot.last_packet.plane_endpoint
	if recording:
		if not Trial.hardware: collect(delta)
		if is_weight() and target_index < 5:
			var names = ["left", "right", "top", "bottom", "centre"]
			readout.text = "Target %d of 5: %s\nHold %.1f / 2.0 s" % [target_index + 1, names[target_index], hold]
		else: readout.text = "Recording…  %d samples" % points.size()
		if Trial.hardware and not Robot.ready_for_training(): readout.text = "Recording held: waiting for healthy robot telemetry."
	elif state == ADJUST and not is_weight(): readout.text = range_text() + ("   (%d%% kept)" % int(retain) if retain < 100 else "")
	elif state == SAVED: readout.text = "✔ Assessment saved"
	else: readout.text = "Position  %.1f cm, %.1f cm" % [cursor.x * 100.0, cursor.y * 100.0]
	queue_redraw()

## Shape of a saved or measured range: a diamond for MLAP, a band for ML or AP.
func outline(corners: Array[Vector2], fill: Color, edge: Color, width: float) -> void:
	# corners order: top, bottom, left, right
	var top = to_screen(corners[0])
	var bottom = to_screen(corners[1])
	var left = to_screen(corners[2])
	var right = to_screen(corners[3])
	match kind:
		"ML":
			var a = minf(left.x, right.x)
			var b = maxf(left.x, right.x)
			draw_rect(Rect2(a, PLOT.position.y, b - a, PLOT.size.y), fill)
			draw_line(Vector2(a, PLOT.position.y), Vector2(a, PLOT.end.y), edge, width)
			draw_line(Vector2(b, PLOT.position.y), Vector2(b, PLOT.end.y), edge, width)
		"AP":
			var c = minf(top.y, bottom.y)
			var d = maxf(top.y, bottom.y)
			draw_rect(Rect2(PLOT.position.x, c, PLOT.size.x, d - c), fill)
			draw_line(Vector2(PLOT.position.x, c), Vector2(PLOT.end.x, c), edge, width)
			draw_line(Vector2(PLOT.position.x, d), Vector2(PLOT.end.x, d), edge, width)
		_:
			var shape = PackedVector2Array([left, bottom, right, top])
			if Geometry2D.triangulate_polygon(shape).size() > 0: draw_colored_polygon(shape, fill)
			draw_polyline(PackedVector2Array([left, bottom, right, top, left]), edge, width)

func _draw() -> void:
	var font = ThemeDB.fallback_font
	draw_rect(PLOT, Color("111827"))
	for i in range(0, 11):
		var gx = PLOT.position.x + PLOT.size.x * i / 10.0
		var gy = PLOT.position.y + PLOT.size.y * i / 10.0
		draw_line(Vector2(gx, PLOT.position.y), Vector2(gx, PLOT.end.y), Color("14364d"), 1)
		draw_line(Vector2(PLOT.position.x, gy), Vector2(PLOT.end.x, gy), Color("14364d"), 1)
	draw_rect(PLOT, Color("405169"), false, 3)
	draw_string(font, Vector2(PLOT.position.x, PLOT.end.y + 28), "◂ " + ("Right" if mirrored else "Left"), HORIZONTAL_ALIGNMENT_LEFT, 200, 20, UITheme.MUTED)
	draw_string(font, Vector2(PLOT.end.x - 200, PLOT.end.y + 28), ("Left" if mirrored else "Right") + " ▸", HORIZONTAL_ALIGNMENT_RIGHT, 200, 20, UITheme.MUTED)
	draw_string(font, Vector2(PLOT.position.x + 10, PLOT.position.y + 26), "Far", HORIZONTAL_ALIGNMENT_LEFT, 100, 20, UITheme.MUTED)
	draw_string(font, Vector2(PLOT.position.x + 10, PLOT.end.y - 10), "Near", HORIZONTAL_ALIGNMENT_LEFT, 100, 20, UITheme.MUTED)
	if not previous.is_empty() and state != SAVED and not is_weight():
		var old: Array[Vector2] = [Vector2(float(previous.TopAdjustedX), float(previous.TopAdjustedY)), Vector2(float(previous.BottomAdjustedX), float(previous.BottomAdjustedY)), Vector2(float(previous.LeftAdjustedX), float(previous.LeftAdjustedY)), Vector2(float(previous.RightAdjustedX), float(previous.RightAdjustedY))]
		outline(old, Color(0.6, 0.7, 0.8, 0.08), Color(0.7, 0.8, 0.9, 0.55), 2)
		draw_string(font, Vector2(PLOT.position.x + 10, PLOT.position.y + 52), "grey: previous assessment", HORIZONTAL_ALIGNMENT_LEFT, 300, 17, UITheme.MUTED)
	var stride = maxi(1, points.size() / 1500)
	for i in range(0, points.size(), stride): draw_circle(to_screen(points[i]), 2.5, Color("3c9bb8"))
	if is_weight():
		var names = ["L", "R", "T", "B", "C"]
		for i in targets.size():
			var color = Color("5dd6a2") if i < target_index else UITheme.FOCUS if i == target_index and recording else Color("5b6b78")
			var at = to_screen(targets[i])
			draw_circle(at, 30, color)
			draw_string(font, at + Vector2(-30, 8), names[i], HORIZONTAL_ALIGNMENT_CENTER, 60, 22, Color.BLACK)
		if recording and target_index < 5: draw_arc(to_screen(targets[target_index]), 40, -PI / 2, -PI / 2 + TAU * clampf(hold / 2.0, 0, 1), 48, UITheme.FOCUS, 6)
	elif extrema.size() == 4:
		outline(adjusted(), Color(0.85, 0.3, 0.2, 0.25), Color("ff7a5c"), 4)
		for point in extrema: draw_circle(to_screen(point), 9, Color("ffb199"))
	var beyond = not view.grow(0.002).has_point(cursor)
	var cursor_screen = to_screen(cursor)
	if beyond:
		# Past the reachable area: keep the marker on the frame and show it in amber.
		draw_circle(cursor_screen, 22, Color(1, 0.7, 0.25, 0.25))
	draw_circle(cursor_screen, 14, Color("ffb23d") if beyond else Color("5dd66f"))
	draw_arc(cursor_screen, 14, 0, TAU, 24, Color.WHITE, 2)

func _exit_tree() -> void:
	if raw_file != null:
		raw_file.flush()
		raw_file.close()

