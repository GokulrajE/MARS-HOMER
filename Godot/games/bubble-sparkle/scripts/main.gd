extends Control
const DayCycle=preload("res://core/visual_cycle.gd")

const INK = Color("e5f5fb")
const MUTED = Color("8caabd")
const AQUA = Color("7ce7cf")
var elapsed := 0.0
var hits := 0
var target_age := 0.0
var target_sequence := 0
var goal := 12
var next_goal := 12
var discoveries: Array[Dictionary] = []
var reveal_age := 10.0
var reveal_origin := Vector2.ZERO
var session_variant := 0
var surprise_age := 20.0
var surprise_kind := 0
var secret_found := false
var celebration_age := 20.0
const DIRECTIONS = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN,
    Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN,
    Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const COLORS = [Color("68f4d4"), Color("c5a0ff"), Color("ffc879")]
const STAGES = ["FIRST GLOW", "BRIGHTER STEPS", "FULL OF WONDER"]
const THEME_NAMES = ["Ocean", "Twilight garden", "Starry sky"]
const THEME_TOP = [Color("08182b"), Color("19182c"), Color("10132c")]
const THEME_BOTTOM = [Color("193348"), Color("30304b"), Color("26274f")]
const THEME_BOARD = [Color("10283e"), Color("22243b"), Color("161d3c")]
var theme_index := 0
var keep_theme := false
var persist_preferences := true
var bubble_visual: ColorRect
var reward_age := 10.0
var reward_origin := Vector2.ZERO
var reward_text := ""
var previous_target := Vector2.ZERO
var arrival := 1.0
var ambient_color := Color("68f4d4")
var reach := 1
var paused := true
var has_started := false
var settings_visible := false
var sound_on := true
var reduced := false
var complete := false
var target := Vector2.ZERO
var target_scale := 1.0
var cooldown := 0.0
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var displayed_score := 0.0
var pointer_position := Vector2.ZERO
var pointer_visible := false
var pointer_down := false
var pointer_touch := false
var pause_button: Button
var reach_buttons: Array[Button] = []
var player: AudioStreamPlayer
# One typeface everywhere (Atkinson); Titan One only for the reward text.
const UITheme = preload("res://core/ui_theme.gd")
var font: Font = UITheme.FONT
var heading_font: Font = UITheme.FONT
var reward_font: Font = UITheme.DISPLAY
var board := Rect2()
var last_size := Vector2.ZERO

func _ready() -> void:
	rng.randomize()
	session_variant = rng.randi_range(0, 2)
	if persist_preferences:
		var config := ConfigFile.new()
		if config.load("user://preferences.cfg") == OK:
			keep_theme = bool(config.get_value("visuals", "keep_theme", false))
			theme_index = clampi(int(config.get_value("visuals", "theme", 0)), 0, 2)
			if not keep_theme: theme_index = (theme_index + 1) % 3
		save_preferences()
	get_window().mouse_exited.connect(func(): pointer_visible = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	player = AudioStreamPlayer.new()
	add_child(player)
	build_ui()
	resized.connect(layout_target)
	layout_target()

func label_at(text: String, pos: Vector2, size_px: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func style(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s

func button(text: String, pos: Vector2, sz: Vector2, action: Callable, selected: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", heading_font)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("disabled", style(Color("142736"), Color("263d4b")))
	b.add_theme_color_override("font_color", AQUA if selected else INK)
	b.add_theme_stylebox_override("normal", style(Color("163c43") if selected else Color("132c40"), Color("407d78") if selected else Color("294356")))
	b.add_theme_stylebox_override("hover", style(Color("214856"), AQUA))
	b.add_theme_stylebox_override("pressed", style(Color("2c5d64"), AQUA))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), AQUA))
	b.pressed.connect(action)
	add_child(b)
	b.hide() # Only the shared Play/Pause and Exit controls are shown.
	return b

func build_ui() -> void:
	for child in get_children():
		if child != player:
			remove_child(child)
			child.queue_free()
	reach_buttons.clear()
	var start_button := button("Start", Vector2(size.x - 312, 30), Vector2(128, 54), start_game, true)
	start_button.disabled = not paused and not complete
	pause_button = button("Stop", Vector2(size.x - 172, 30), Vector2(128, 54), stop_game)
	pause_button.disabled = paused or complete
	if settings_visible:
		var right := size.x - 330.0
		label_at("Settings", Vector2(right, 121), 22)
		label_at("Comfortable reach", Vector2(right, 165), 16, MUTED)
		for i in 3:
			var index := i
			reach_buttons.append(button(["Small", "Medium", "Wide"][i], Vector2(right + i * 92, 195), Vector2(86, 44), func(): reach = index; layout_target(); build_ui(), reach == i))
		button("Sound  " + ("on" if sound_on else "off"), Vector2(right, 254), Vector2(130, 44), func(): sound_on = not sound_on; build_ui())
		button("Motion  " + ("low" if reduced else "full"), Vector2(right + 140, 254), Vector2(130, 44), func(): reduced = not reduced; build_ui())
		button("Keep theme: " + ("on" if keep_theme else "off"), Vector2(right, 313), Vector2(270, 44), toggle_keep_theme, keep_theme)
		label_at("MARS trial: 60 active seconds", Vector2(right, 380), 16, MUTED)
	bubble_visual = ColorRect.new()
	bubble_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://games/bubble-sparkle/shaders/bubble.gdshader")
	bubble_visual.material = mat
	add_child(bubble_visual)
	update_bubble_visual()
	if complete:
		var card := Control.new()
		card.name = "EndCard"
		card.set_script(load("res://games/bubble-sparkle/scripts/end_card.gd"))
		card.size = size
		add_child(card)
	var overlay := Control.new()
	overlay.set_script(load("res://games/bubble-sparkle/scripts/game_overlay.gd"))
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func stage_index() -> int:
	return mini(hits / 4, 2)

func update_bubble_visual() -> void:
	if not is_instance_valid(bubble_visual): return
	var touching := cooldown > 0 and reward_age < 0.18
	bubble_visual.visible = (not complete and cooldown <= 0) or touching
	var scale_factor := target_scale
	if touching: scale_factor = 1.0 - smoothstep(0.0, 0.18, reward_age) * 0.65
	bubble_visual.size = Vector2.ONE * 170 * scale_factor
	bubble_visual.position = target - bubble_visual.size / 2
	bubble_visual.material.set_shader_parameter("clock", 0.0 if reduced else elapsed)
	bubble_visual.material.set_shader_parameter("tint", COLORS[stage_index()])
	bubble_visual.material.set_shader_parameter("visibility", 0.35 if paused else 1.0)

func layout_target() -> void:
	board = Rect2(Vector2.ZERO, size)
	var distance := [0.48, 0.73, 1.0][reach] as float
	var direction: Vector2 = DIRECTIONS[target_sequence % DIRECTIONS.size()]
	var center := board.get_center() + Vector2(0, 18)
	var extent := Vector2(board.size.x * 0.5 - 130, board.size.y * 0.5 - 190)
	target = center + direction * extent * distance
	update_bubble_visual()
	queue_redraw()

func save_preferences() -> void:
	if not persist_preferences: return
	var config := ConfigFile.new()
	config.set_value("visuals", "keep_theme", keep_theme)
	config.set_value("visuals", "theme", theme_index)
	config.save("user://preferences.cfg")

func toggle_keep_theme() -> void:
	keep_theme = not keep_theme
	save_preferences()
	build_ui()

func restart() -> void:
	if Trial.running: return
	if not keep_theme: theme_index = (theme_index + 1) % THEME_NAMES.size()
	save_preferences()
	hits = 0
	displayed_score = 0.0
	goal = next_goal
	discoveries.clear()
	session_variant = (session_variant + rng.randi_range(1, 2)) % 3
	surprise_age = 20.0
	celebration_age = 20.0
	secret_found = false
	reveal_age = 10.0
	reward_age = 10.0
	ambient_color = COLORS[0]
	arrival = 1.0
	complete = false
	paused = false
	has_started = true
	particles.clear()
	rings.clear()
	cooldown = 0
	target_scale = 1
	layout_target()
	build_ui()

func start_game() -> void:
	if complete:
		restart()
		return
	if not paused: return
	has_started = true
	paused = false
	build_ui()
	queue_redraw()

func stop_game() -> void:
	if paused or complete: return
	paused = true
	player.stop()
	build_ui()
	queue_redraw()

func toggle_pause() -> void:
	if paused: start_game()
	else: stop_game()

func _input(event: InputEvent) -> void:
	if Trial.hardware: return
	if event is InputEventMouseMotion:
		pointer_position = event.position
		pointer_visible = true
		pointer_touch = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif event is InputEventMouseButton:
		pointer_position = event.position
		pointer_visible = true
		pointer_down = event.pressed
	elif event is InputEventScreenTouch:
		pointer_position = event.position
		pointer_visible = event.pressed
		pointer_down = event.pressed
		pointer_touch = true
	elif event is InputEventScreenDrag:
		pointer_position = event.position
		pointer_visible = true
		pointer_touch = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_X:
			settings_visible = false
			build_ui()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			stop_game()
			return
	var point := Vector2(-999, -999)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	if not paused and not settings_visible and not secret_found and point.distance_to(Vector2(size.x - 72, 145)) < 45:
		secret_found = true
		surprise_age = 0.0
		surprise_kind = 3
		queue_redraw()
		return
	if not paused and not complete and cooldown <= 0 and target_scale >= 0.9 and point.distance_to(target) <= 73:
		pop_bubble()

func pop_bubble() -> void:
	if not Trial.running or not Trial.target_open: return
	Trial.resolve(true)
	target_sequence += 1
	target_age = 0.0
	var old_stage := stage_index()
	previous_target = target
	reward_origin = target
	reward_age = 0.0
	hits += 1
	discoveries.append({"born": elapsed, "special": hits % 4 == 0, "variant": (hits + session_variant) % 3})
	if hits % 4 == 0:
		reveal_age = 0.0
		reveal_origin = target
		surprise_age = 0.0
		surprise_kind = (hits / 4 + session_variant) % 3
	reward_text = ["Wonderful!", "You made it glow!", "Lovely reach!", "Pure magic!"][hits % 4]
	if hits % 4 == 0: reward_text = STAGES[old_stage].capitalize() + " complete!"
	# The reward plays on by itself while the next bubble grows in at once.
	cooldown = 0.0
	target_scale = 0.0
	var palette := [Color("83f5d1"), Color("b5abff"), Color("ffdca0"), Color("8cdfff")]
	var color: Color = palette[(hits - 1) % palette.size()]
	var amount := 24 if reduced else (130 if hits % 4 == 0 else 85)
	var pattern := hits % 3
	for i in amount:
		var angle := rng.randf_range(0, TAU)
		var speed := rng.randf_range(45, 210)
		if pattern == 1: angle = TAU * float(i) / float(amount)
		if pattern == 2:
			angle = -PI / 2 + rng.randf_range(-0.8, 0.8)
			speed *= 1.4
		particles.append({"p": reward_origin + Vector2.from_angle(angle) * rng.randf_range(0, 35), "v": Vector2.from_angle(angle) * speed, "life": rng.randf_range(0.65, 1.6), "max": 1.6, "s": rng.randf_range(2, 6), "c": color, "star": i % 3 == 0, "drop": i % 3 == 1, "angle": angle})
	rings.append({"p": reward_origin, "age": 0.0, "c": color})
	if sound_on: play_chime()
	if not Trial.running:
		complete = true
		celebration_age = 0.0
	else:
		layout_target()
		arrival = 0.0
	build_ui()

func play_chime() -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	var finale := hits >= goal
	var length_samples := 33075 if finale else 15435
	data.resize(length_samples * 2)
	var melody := [523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 783.99, 880.0, 783.99, 659.25, 523.25]
	var pitch: float = melody[(hits - 1) % melody.size()]
	for i in length_samples:
		var t := float(i) / 22050.0
		var envelope := minf(t * 90, 1.0) * exp(-t * (3.5 if finale else 7.0))
		var tone := sin(TAU * pitch * t) + 0.22 * sin(TAU * pitch * 2 * t)
		if finale: tone = (sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) + sin(TAU * 783.99 * t)) * 0.45
		data.encode_s16(i * 2, int(tone * envelope * 4200))
	wav.data = data
	player.stream = wav
	player.play()

func _process(delta: float) -> void:
	if Trial.hardware:
		pointer_position = Trial.input_position(Vector2.ZERO)*size
		pointer_visible = true
	Trial.advance(delta, paused, pointer_position / size, target / size)
	if not Trial.running or Trial.held(): return
	if not paused and cooldown <= 0:
		if not Trial.target_open: Trial.appear(target / size)
		target_age += delta
		if pointer_visible and pointer_position.distance_to(target) <= 73 and target_scale >= 0.9:
			pop_bubble()
	if last_size != size:
		last_size = size
		layout_target()
		build_ui()
	if paused: return
	displayed_score = move_toward(displayed_score, hits * 10.0, delta * 35.0)
	ambient_color = ambient_color.lerp(COLORS[stage_index()], minf(delta * 1.7, 1.0))
	elapsed += delta
	reward_age += delta
	reveal_age += delta
	surprise_age += delta
	celebration_age += delta
	arrival = minf(arrival + delta * 1.5, 1.0)
	if cooldown > 0:
		cooldown -= delta
		if cooldown <= 0 and not complete:
			layout_target()
			arrival = 0.0
	if cooldown <= 0:
		target_scale = move_toward(target_scale, 1.0, delta * 2.8)
	for p in particles:
		p.p += p.v * delta * (0.35 if reduced else 1.0)
		p.v *= exp(-1.7 * delta)
		p.v.y += delta * 32
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0)
	for r in rings: r.age += delta
	rings = rings.filter(func(r): return r.age < 1.3)
	update_bubble_visual()
	queue_redraw()

func star(pos: Vector2, radius: float, color: Color) -> void:
	if radius < 0.1 or color.a <= 0.0: return
	var points := PackedVector2Array()
	for i in 8:
		points.append(pos + Vector2.from_angle(i * PI / 4) * (radius if i % 2 == 0 else radius * 0.25))
	draw_colored_polygon(points, color)

func _draw() -> void:
	var accent: Color = ambient_color
	var time := 0.0 if reduced else elapsed
	for y in range(0, int(size.y), 4):
		var color: Color = DayCycle.palette(Color("477d9a"),Color("8e6685"),THEME_TOP[theme_index]).lerp(DayCycle.palette(Color("82a9b0"),Color("a5798d"),THEME_BOTTOM[theme_index]), float(y) / size.y)
		draw_rect(Rect2(0, y, size.x, 4), color)
	draw_rect(board, Color(THEME_BOARD[theme_index], 0.35))
	draw_atmosphere(time)
	if theme_index == 0:
		# Soft shafts of light, layered currents, and a growing reef.
		for i in 5:
			var x := board.position.x + 65 + i * (board.size.x - 260) / 4
			var sway := sin(time * 0.22 + i) * 25
			draw_colored_polygon(PackedVector2Array([Vector2(x,board.position.y + 2), Vector2(x + 36,board.position.y + 2), Vector2(minf(x + 170 + sway, board.end.x - 3),board.end.y - 3), Vector2(minf(x + 60 + sway, board.end.x - 4),board.end.y - 3)]), Color(accent, 0.025))
		for layer in 4:
			var points := PackedVector2Array()
			for x in range(0, int(board.size.x) + 1, 6):
				var y := board.end.y - 30 - layer * 21 + sin(x * 0.008 + time * 0.25 + layer) * 12
				points.append(Vector2(board.position.x + x, y))
			points.append(Vector2(board.end.x - 1,board.end.y - 3))
			points.append(Vector2(board.position.x + 1,board.end.y - 3))
			draw_colored_polygon(points, Color(accent.lerp(Color("193a63"),0.65), 0.12))
		for i in 18:
			var base := Vector2(board.position.x + 30 + i * (board.size.x - 60) / 17, board.end.y - 24)
			var height := 22 + (i * 17 % 42) + mini(hits, 12) * 2
			var stem := PackedVector2Array()
			for j in 13:
				var u := float(j) / 12
				stem.append(base + Vector2(sin(u * 2.8 + time * 0.6 + i) * 12 * u, -height * u))
			draw_polyline(stem, Color(COLORS[i % 3], 0.2), 3, true)
			for j in [5, 8, 11]:
				var point: Vector2 = stem[j]
				draw_line(point, point + Vector2(9 if j % 2 == 0 else -9, -8), Color(COLORS[i % 3], 0.3), 3, true)
		for i in 26:
			var px := board.position.x + 24 + fmod(i * 139.7, board.size.x - 48)
			var py := board.position.y + 94 + fposmod(i * 87.3 - time * (3 + i % 4), board.size.y - 125)
			var pos := Vector2(px + sin(time * 0.4 + i) * 3, py)
			if i % 4 == 0:
				draw_arc(pos, 4 + i % 7, 0, TAU, 24, Color(accent, 0.13), 1, true)
			else:
				star(pos, 2 + sin(time + i) * 0.8, Color(accent, 0.22))
	else:
		draw_landscape(time)
	var center := board.get_center() + Vector2(0,18)
	if theme_index == 0:
		# A cheerful little jellyfish companion, away from the reaching area.
		var jelly := Vector2(board.end.x - 64, board.position.y + 145 + sin(time * 1.2) * 5 - (0.0 if reduced else sin(clampf(reward_age, 0, 1) * PI) * 20))
		for i in 4:
			var tail := PackedVector2Array()
			for j in 12:
				tail.append(jelly + Vector2(-18 + i * 12 + sin(time * 2 + j * 0.4 + i) * 3, 10 + j * 2))
			draw_polyline(tail, Color(accent, 0.4), 2, true)
		draw_circle(jelly, 25, Color(accent, 0.16))
		draw_arc(jelly, 25, PI, TAU, 32, Color(accent,0.8), 2, true)
		draw_circle(jelly + Vector2(-8,2), 2.3, INK)
		draw_circle(jelly + Vector2(8,2), 2.3, INK)
		draw_arc(jelly + Vector2(0,5), 4, 0, PI, 12, INK, 1.5, true)
	draw_discoveries(time)
	draw_surprise(time)
	if settings_visible:
		draw_style_box(style(Color("102332"), Color("355264"), 18), Rect2(size.x - 350, 105, 310, 372))
	if not complete and cooldown <= 0:
		if (hits + 1) % 4 == 0:
			draw_arc(target, 94, 0, TAU, 80, Color("ffe3a0"), 2, true)
			for i in 4:
				star(target + Vector2.from_angle(i * PI / 2 + time * 0.25) * 94, 7, Color("ffe3a0"))
		for i in 6:
			draw_arc(target, 78 + i * 3, 0, TAU, 80, Color(accent, 0.025), 2, true)
		for i in 3:
			var angle := time * 0.5 + i * TAU / 3
			star(target + Vector2.from_angle(angle) * 83, 4 + sin(time * 2 + i), Color(accent,0.65))
		if arrival < 1 and not reduced and hits > 0:
			var point := previous_target.lerp(target, smoothstep(0.0,1.0,arrival))
			star(point, 8 * (1-arrival), INK)
	for r in rings:
		var c: Color = r.c
		c.a = (1 - r.age / 1.3) * 0.6
		for band in 1:
			var age: float = r.age - band * 0.085
			if age >= 0:
				var radius: float = 61 + age * (24 if reduced else 104)
				draw_arc(r.p, radius, 0, TAU, 96, Color(c, c.a * 0.10), 10, true)
				draw_arc(r.p, radius, 0, TAU, 96, Color(c, c.a * 0.75), 2.5, true)
	for p in particles:
		var c: Color = p.c
		c.a = clampf(p.life / 0.7, 0, 1)
		if p.star: star(p.p, p.s * 1.7, c)
		elif p.drop: droplet(p.p, p.s * 1.8, p.angle, c)
		else: draw_circle(p.p, p.s * 0.55, c)
	if reward_age < 1.8:
		preload("res://core/reward_star.gd").celebrate(self,reward_origin,reward_age,reduced)
		var fade := clampf(1.8 - reward_age, 0, 1)
		var text_width := reward_font.get_string_size(reward_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		var pos := Vector2(clampf(reward_origin.x - text_width / 2, board.position.x + 24, board.end.x - text_width - 24), reward_origin.y + 48 - (0 if reduced else reward_age * 12))
		draw_string(reward_font, pos, reward_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(INK,fade))
		draw_string(reward_font, pos + Vector2(text_width / 2 - 42, 30), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(accent,fade))
		if not reduced:
			for i in 7:
				var t := clampf((reward_age - i * 0.045) / 1.25, 0, 1)
				var destination := Vector2(473, 48)
				var point := reward_origin.lerp(destination, t) + Vector2(0, -sin(t * PI) * 90)
				star(point, (6 - i * 0.55) * sin(t * PI), Color(accent,0.8))

func droplet(pos: Vector2, radius: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var t := float(i) / 24 * TAU
		var local := Vector2(cos(t) * radius, sin(t) * radius * 0.48 * (0.75 - cos(t) * 0.25))
		points.append(pos + local.rotated(angle))
	draw_colored_polygon(points, Color(color, color.a * 0.6))
	points.append(points[0])
	draw_polyline(points, Color(Color("bcefff"), color.a * 0.8), 1, true)
	draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.13).rotated(angle), radius * 0.15, Color(INK,color.a * 0.8))

func draw_landscape(time: float) -> void:
	var garden := theme_index == 1
	var moon := Vector2(board.end.x - 95, board.position.y + 91)
	for i in range(8, 0, -1):
		draw_circle(moon, 27 + i * 6, Color(0.7,0.7,1,0.008))
	draw_circle(moon, 26, Color("b8bfdc"))
	draw_circle(moon + Vector2(12,-7), 24, THEME_BOARD[theme_index])
	for i in 45:
		var pos := Vector2(board.position.x + 30 + fmod(i * 137.3, board.size.x - 60), board.position.y + 110 + fmod(i * 71.7, board.size.y - 170))
		var glow := 0.13 + (sin(time * 0.7 + i) + 1) * 0.07
		if garden:
			pos += Vector2(sin(time * 0.2 + i),cos(time * 0.3 + i)) * 5
			draw_circle(pos, 5, Color(0.9,0.85,0.4,glow * 0.15))
			draw_circle(pos, 1.5, Color(0.95,0.9,0.55,glow))
		else: star(pos, 1.6 + i % 3, Color(0.8,0.85,1,glow))
	for layer in 3:
		var ridge := PackedVector2Array()
		for x in range(0, int(board.size.x)+1, 6):
			var y := board.end.y - 34 - layer * 24 + sin(x * 0.008 + layer * 2) * 15
			ridge.append(Vector2(board.position.x + x, y))
		ridge.append(Vector2(board.end.x - 1,board.end.y - 3))
		ridge.append(Vector2(board.position.x + 1,board.end.y - 3))
		draw_colored_polygon(ridge, Color(Color("6d5988") if garden else Color("6577aa"),0.1))
	if garden:
		for i in 15:
			var base := Vector2(board.position.x + 30 + i * (board.size.x - 60) / 14,board.end.y - 25)
			var head := base + Vector2(sin(time * 0.45 + i) * 3,-24 - i * 13 % 38)
			draw_line(base,head,Color("526c76"),2,true)
			for petal in 5:
				draw_circle(head + Vector2.from_angle(petal * TAU / 5) * 4, 3.5, Color(COLORS[i % 3],0.35))
			draw_circle(head,2,Color("d9cfa4"))
	else:
		var planet := Vector2(board.position.x + 78, board.end.y - 72)
		draw_circle(planet,25,Color("44476e"))
		var orbit := PackedVector2Array()
		for i in 65:
			var angle := i * TAU / 64
			orbit.append(planet + Vector2(cos(angle)*44,sin(angle)*10).rotated(-0.3))
		draw_polyline(orbit,Color("8a7caa"),2,true)



func discovery_position(index: int) -> Vector2:
	var fraction := float(index % 16 + 1) / 17.0
	if theme_index == 2:
		return Vector2(160 + fraction * (size.x - 320), 140 + sin(fraction * TAU * 1.5) * 42)
	return Vector2(110 + fraction * (size.x - 220), size.y - 145 - sin(fraction * PI * 3) * 25)

func draw_discoveries(time: float) -> void:
	for i in discoveries.size():
		var item: Dictionary = discoveries[i]
		var age: float = elapsed - item.born
		var growth := 1.0 if reduced else smoothstep(0, 0.8, age)
		var pos := discovery_position(i)
		var col: Color = COLORS[(i + session_variant) % 3]
		if theme_index == 0:
			pos.y += sin(time * 1.1 + i) * (0 if reduced else 7)
			draw_set_transform(pos, 0, Vector2.ONE * maxf(growth, 0.01))
			draw_colored_polygon(PackedVector2Array([Vector2(-22,0),Vector2(-40,-16),Vector2(-40,16)]), Color(col,0.65))
			draw_set_transform(pos, 0, Vector2(1.4,0.8) * maxf(growth, 0.01))
			draw_circle(Vector2.ZERO, 19, Color(col,0.6))
			draw_set_transform(pos, 0, Vector2.ONE * maxf(growth, 0.01))
			draw_circle(Vector2(13,-3),3,INK)
			draw_circle(Vector2(14,-3),1.5,Color("132538"))
		elif theme_index == 1:
			draw_line(pos + Vector2(0,75),pos,Color("65988e"),3,true)
			for petal in 7:
				var angle := petal * TAU / 7
				draw_circle(pos + Vector2.from_angle(angle) * 15 * growth, 10 * growth, Color(col,0.7))
			draw_circle(pos,8 * growth,Color("ffe4a2"))
			for leaf in [-1,1]:
				draw_set_transform(pos + Vector2(leaf*8,35), leaf*0.6, Vector2(1.5,0.6))
				draw_circle(Vector2.ZERO,7,Color("669c92"))
			draw_set_transform(Vector2.ZERO)
		else:
			if i > 0: draw_line(discovery_position(i-1),pos,Color(col,0.3),2,true)
			draw_circle(pos,20 * growth,Color(col,0.06))
			star(pos,11 * growth,col)
		draw_set_transform(Vector2.ZERO)
		if item.special:
			star(pos + Vector2(0,-35), 7 * growth, Color("ffe4a2"))
	# Each fourth touch releases a themed surprise into the growing scene.
	if reveal_age < 2.2 and not discoveries.is_empty():
		var progress := smoothstep(0,2.2,reveal_age)
		var destination := discovery_position(discoveries.size()-1)
		var pos := destination if reduced else reveal_origin.lerp(destination,progress) + Vector2(0,-sin(progress*PI)*110)
		var col := Color("ffe4a2")
		if theme_index == 1:
			var wing: float = 12.0 if reduced else 10 + abs(sin(time*8))*12
			draw_circle(pos + Vector2(-wing/2,-5),wing,Color("d6adff"))
			draw_circle(pos + Vector2(wing/2,-5),wing,Color("ffbde3"))
			draw_line(pos+Vector2(0,-12),pos+Vector2(0,12),INK,3,true)
		else:
			star(pos,20,col)
			if not reduced: draw_line(pos,pos+Vector2(-45,20),Color(col,0.35),3,true)
	# A small companion for garden and sky, with a happy bounce on every touch.
	if theme_index != 0:
		var pos := Vector2(size.x-80,145)
		if not reduced: pos.y -= sin(clampf(reward_age,0,1)*PI)*20
		draw_circle(pos,26,Color(COLORS[theme_index],0.2))
		star(pos,24,COLORS[theme_index])
		draw_circle(pos+Vector2(-6,-2),2,Color("132538"))
		draw_circle(pos+Vector2(6,-2),2,Color("132538"))
		draw_arc(pos+Vector2(0,3),5,0,PI,16,Color("132538"),2,true)


func draw_atmosphere(time: float) -> void:
	# Slow, low-contrast ribbons add depth behind the stationary target.
	var tint: Color = [Color("52cbbb"),Color("bc83c9"),Color("768bdd")][theme_index]
	for band in 3:
		var points := PackedVector2Array()
		for x in range(0,int(size.x)+1,16):
			var y := size.y * 0.28 + band * 35 + sin(x * 0.003 + time * 0.12 + band + session_variant) * 70
			points.append(Vector2(x,y))
		draw_polyline(points,Color(tint,0.018),40,true)
		draw_polyline(points,Color(tint,0.025),12,true)
	for i in 10:
		var x := fposmod(i * 217.3 + time * (3 + i % 3),size.x + 80)-40
		var pos := Vector2(x, size.y * 0.70 + sin(i * 2.1 + time * 0.18)*95)
		if theme_index == 0:
			draw_set_transform(pos,0,Vector2(1.5,0.6))
			draw_circle(Vector2.ZERO,8,Color(tint,0.10))
			draw_set_transform(Vector2.ZERO)
			draw_colored_polygon(PackedVector2Array([pos+Vector2(-8,0),pos+Vector2(-19,-6),pos+Vector2(-19,6)]),Color(tint,0.1))
		else:
			draw_circle(pos,12,Color(tint,0.025))
			star(pos,2.5,Color(tint,0.25))

func draw_surprise(time: float) -> void:
	if surprise_age < 4.5:
		var fade := minf(surprise_age*3,1.0)*clampf(4.5-surprise_age,0,1)
		var center := Vector2(size.x * 0.5, size.y - 215)
		if surprise_kind == 3:
			# An optional companion tap reveals a pearl constellation, without score or reach changes.
			for i in 9:
				var pos := center + Vector2((i-4)*35,-sin(float(i)/8*PI)*60)
				draw_circle(pos,7,Color(COLORS[i%3],fade*0.65))
				star(pos,4,Color(INK,fade))
		else:
			for i in 7:
				var pos := center + Vector2((i-3)*63, sin(i+time)* (0 if reduced else 14))
				var col := Color(COLORS[(i+session_variant)%3],fade*0.8)
				if surprise_kind == 0:
					draw_arc(pos,16,PI,TAU,24,col,2,true)
					for tail in 3: draw_line(pos+Vector2((tail-1)*9,0),pos+Vector2((tail-1)*9,22),col,2,true)
				elif surprise_kind == 1:
					var wing: float = 10 if reduced else 7+absf(sin(time*4+i))*7
					draw_circle(pos+Vector2(-8,0),wing,col)
					draw_circle(pos+Vector2(8,0),wing,col)
					draw_line(pos+Vector2(0,-8),pos+Vector2(0,8),Color(INK,fade),2,true)
				else:
					star(pos,13,col)
					if not reduced: draw_line(pos,pos+Vector2(-30,12),Color(col,fade*0.25),2,true)
	if complete and celebration_age < 3.0:
		var fade := clampf(3.0-celebration_age,0,1)
		for i in (12 if reduced else 36):
			var angle := i*TAU/(12 if reduced else 36)
			var radius := 190.0 if reduced else 100 + celebration_age*110
			star(size/2 + Vector2.from_angle(angle)*radius,4+i%3,Color(COLORS[i%3],fade*0.6))
	# Earned companion crown and a gentle halo remain as a keepsake for this game.
	if secret_found:
		var crown := Vector2(size.x-72,108)
		draw_colored_polygon(PackedVector2Array([crown+Vector2(-18,5),crown+Vector2(-22,-10),crown+Vector2(-7,-3),crown+Vector2(0,-18),crown+Vector2(7,-3),crown+Vector2(22,-10),crown+Vector2(18,5)]),Color("e8ce91"))

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
