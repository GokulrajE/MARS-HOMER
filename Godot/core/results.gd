extends Control
## Saved-results card shown after a timed trial.
signal again
signal back
const UITheme = preload("res://core/ui_theme.gd")
var age = 0.0
var sparkles: Array = []
var panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var result = Trial.last_result
	var rate = int(100.0 * result.hits / maxi(1, result.targets))
	var star = Trial.history.size() > 0 and int(Trial.history[-1][21]) > 0
	panel = PanelContainer.new()
	panel.position = Vector2(400, 150)
	panel.size = Vector2(800, 700)
	panel.pivot_offset = Vector2(400, 350)
	var style = UITheme.box(Color("1f2937"), UITheme.ACCENT, 3, 28, 36, 26)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 40
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var medal = TextureRect.new()
	medal.texture = load("res://assets/art/best_score.png")
	medal.custom_minimum_size = Vector2(0, 150)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.modulate = Color("ffd68a") if rate >= 80 else Color("b6c4d6")
	box.add_child(medal)
	var title = UITheme.label("Great work!" if rate >= 80 else "Trial complete", 44, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub = UITheme.label("Saved to your records" + ("  •  ★ daily star earned" if star else ""), 22, UITheme.FOCUS if star else UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var tiles = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	box.add_child(tiles)
	for entry in [["%d" % result.hits, "hits"], ["%d" % result.misses, "misses"], ["%d" % result.targets, "targets"], ["%.0f s" % result.seconds, "active time"]]:
		var tile = UITheme.card(Color("273548"), Color("405169"))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 0)
		tile.add_child(inner)
		var number = UITheme.label(entry[0], 40, Color.WHITE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(number)
		var caption = UITheme.label(entry[1], 18, UITheme.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(caption)
		tiles.add_child(tile)
	box.add_child(UITheme.label("Success rate  %d%%" % rate, 22, UITheme.TEXT))
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	box.add_child(bar)
	var speed_note = "Next reach speed %.4f m/s" % result.next_speed
	if result.next_speed > result.speed + 0.00001: speed_note += "  ▲ faster next time"
	elif result.next_speed < result.speed - 0.00001: speed_note += "  ▼ a little slower next time"
	else: speed_note += "  • unchanged"
	if Trial.game in ["TW","FW","BS"]: speed_note="Patient-paced • finish each target before the next"
	box.add_child(UITheme.label(speed_note, 20, UITheme.MUTED))
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var first: Button
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	for title_text in ["Play again", "Back to games"]:
		var button = Button.new()
		button.text = title_text
		button.custom_minimum_size = Vector2(0, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(func():
			if title_text == "Play again": again.emit()
			else: back.emit())
		buttons.add_child(button)
		if first == null: first = button
	# Focus the likely choice: hold selects it, a tap moves to "Back to games".
	first.grab_focus.call_deferred()
	for i in 90: sparkles.append(Vector3(randf_range(0, 1600), randf_range(-900, 0), randf_range(60, 150)))
	# Pop-in, then the bar fills to the success rate.
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.45)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.chain().tween_property(bar, "value", float(rate), 0.8).set_trans(Tween.TRANS_CUBIC)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1600, 1000), Color(0.01, 0.03, 0.07, minf(0.72, age * 2.0)))
	if age < 9:
		for i in sparkles.size():
			var point = sparkles[i]
			var pos = Vector2(point.x + sin(age * 1.5 + i) * 28, point.y + age * point.z)
			var color = Color.from_hsv(fposmod(float(i) / 14.0, 1.0), 0.55, 1.0, clampf(1.0 - age / 9.0, 0, 1))
			draw_set_transform(pos, age * 2.0 + i, Vector2.ONE)
			draw_rect(Rect2(-6, -3.5, 12, 7), color)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
