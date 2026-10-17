extends Node2D
const Sfx = preload("res://core/sfx.gd")
const UITheme = preload("res://core/ui_theme.gd")
var sfx_player: AudioStreamPlayer

enum InputMode { MOUSE, KEYBOARD, SENSOR }
@export var input_mode: InputMode = InputMode.MOUSE
@export_range(50, 600) var player_speed: float = 260.0
@export_range(5, 160) var rival_speed: float = 65.0
@export_range(20, 65) var pickup_radius: float = 48.0
@export_range(1.0, 8.0) var dwell_seconds: float = 1.0
@export_range(20.0, 240.0) var day_cycle_seconds: float = 60.0
@export_range(1, 32) var session_goal: int = 8
@export var reduced_motion: bool = false
@export var rival_enabled: bool = true
@export_range(0.0, 1.0) var background_saturation: float = 0.42
@export_range(0.0, 1.0) var background_ambience: float = 0.6
@export_range(5.0, 60.0) var target_seconds: float = 15.0
@export_range(200.0, 1500.0) var shark_rush_speed: float = 700.0

const ARENA = Rect2(65, 150, 1150, 500)
const HOME = Vector2(640, 380)
const CAVE = Vector2(1100, 210)
const TARGETS = [Vector2(640, 190), Vector2(1070, 400), Vector2(640, 610), Vector2(200, 400), Vector2(320, 220), Vector2(940, 580), Vector2(320, 580), Vector2(950, 230)]
var player := HOME
var rival := Vector2(980, 510)
var fish := Vector2.ZERO
var fish_state := "waiting"
var rescued := 0
var dwell := 0.0
var target_remaining := 15.0
var target_index := 0
var disappearance_age := 0.0
var background_index := -1
var session_title: Label
var timer_label: Label
var inactivity := 0.0
var elapsed := 0.0
var paused := false
var finished := false
var facing := 1.0
var tilt := 0.0
var thrust := 0.0
var rival_clock := 0.0
var rival_facing := 1.0
var patrol_index := 0
var rival_bank := 0.0
var roaming_time := 0.0
var fish_sprite: Sprite2D
var home_fish: Array[Sprite2D] = []
var distant_fish: Array[Sprite2D] = []
var lighting_mode := 0
var lighting_clock := 0.0
var night_amount := 0.0
var flight_from := Vector2.ZERO
var flight_age := 0.0
var flight_duration := 1.0
# A rescued fish swims home on its own while the next one is already waiting.
var escape_active := false
var escape_from := Vector2.ZERO
var escape_age := 0.0
var escape_duration := 1.0
var escape_pos := Vector2.ZERO
var escape_sprite: Sprite2D
var hold_label: Label
var delivery_from := Vector2.ZERO
var delivery_age := 10.0
var celebration_age := 10.0
var bubble_timer := 0.0
var bubbles: Array[Dictionary] = []
var blooms: Array[float] = []
var shark_sprite: Sprite2D
var water_sprite: Sprite2D
var tracking := Vector2.ZERO
var tracking_time := -1000
var tracking_valid := false
var instruction: Label
var progress: Label
var pause_button: Button
var overlay: Label
const BACKGROUNDS = [preload("res://games/fish-rescue/assets/quiet-lagoon.png"), preload("res://games/fish-rescue/assets/pearl-cove.png")]
const BACKGROUND_NAMES = ["Quiet Lagoon", "Pearl Cove"]
const SUB_ART = preload("res://games/fish-rescue/assets/submarine.png")
const FISH_ART = preload("res://games/fish-rescue/assets/fish.png")
const SHARK_ART = preload("res://games/fish-rescue/assets/shark.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	build_animation_layers()
	build_ui()
	restart()

func label_at(text: String, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e6faff"))
	label.add_theme_color_override("font_shadow_color", Color("062f42"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("083247"))
	add_child(label)
	return label

func button_at(text: String, position: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.custom_minimum_size = Vector2(150, 54)
	button.add_theme_font_size_override("font_size", 22)
	var base := Color("157ca2")
	if text == "Finish":
		base = Color("21876e")
	elif text == "Restart":
		base = Color("285269")
	button.add_theme_stylebox_override("normal", panel_style(base))
	button.add_theme_stylebox_override("hover", panel_style(base.lightened(0.18)))
	button.add_theme_stylebox_override("pressed", panel_style(base.darkened(0.16)))
	button.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), Color("ffe3a0")))
	button.pressed.connect(action)
	add_child(button)
	return button

func build_ui() -> void:
	var heading := label_at("REEF RESCUE", Vector2(40, 14), 36)
	heading.add_theme_color_override("font_color", Color("ffe2a0"))
	label_at("Explore  •  Hold  •  Save", Vector2(42, 64), 18)
	instruction = label_at("", Vector2(410, 30), 22)
	progress = label_at("", Vector2(1060, 30), 21)
	label_at("STEERING", Vector2(40, 697), 16)
	var modes := OptionButton.new()
	modes.position = Vector2(40, 725)
	modes.custom_minimum_size = Vector2(245, 45)
	for title in ["Mouse · any direction", "Keyboard · arrows / WASD", "Sensor · external tracker"]:
		modes.add_item(title)
	modes.add_theme_font_size_override("font_size", 17)
	modes.add_theme_stylebox_override("normal", panel_style(Color("153f54")))
	modes.add_theme_stylebox_override("hover", panel_style(Color("245970")))
	modes.selected = input_mode
	modes.item_selected.connect(func(index: int): input_mode = index as InputMode; inactivity = 1.0)
	add_child(modes)
	var motion := CheckButton.new()
	motion.text = "Reduced motion"
	motion.position = Vector2(305, 695)
	motion.button_pressed = reduced_motion
	motion.toggled.connect(func(value: bool): reduced_motion = value)
	add_child(motion)
	var competition := CheckButton.new()
	competition.text = "Active shark"
	competition.position = Vector2(305, 735)
	competition.button_pressed = rival_enabled
	competition.toggled.connect(set_rival_enabled)
	add_child(competition)
	var lighting := OptionButton.new()
	lighting.position = Vector2(520, 726)
	lighting.custom_minimum_size = Vector2(165, 45)
	for title in ["Day / night cycle", "Daylight", "Night glow"]:
		lighting.add_item(title)
	lighting.item_selected.connect(func(index: int): lighting_mode = index; update_lighting(0.0))
	add_child(lighting)
	label_at("LIGHTING", Vector2(530, 697), 16)
	hold_label = label_at("", Vector2.ZERO, 18)
	pause_button = button_at("Pause", Vector2(710, 711), toggle_pause)
	button_at("Finish", Vector2(880, 711), finish)
	# Trial restart is owned by the MARS menu, so no unsaved in-game reset.
	overlay = label_at("", Vector2(310, 106), 22)
	label_at("HOME REEF", HOME + Vector2(-57, 104), 18)
	session_title = label_at("", Vector2(40, 108), 18)
	timer_label = label_at("", Vector2(945, 108), 20)
	label_at("F11 Fullscreen  /  F10 4K window", Vector2(43, 660), 15)

func restart() -> void:
	if Trial.running and Trial.targets > 0: return
	select_next_background()
	player = HOME
	rival = Vector2(980, 510)
	rescued = 0
	target_index = 0
	disappearance_age = 0.0
	escape_active = false
	paused = false
	finished = false
	inactivity = 1.0
	elapsed = 0.0
	rival_clock = 0.0
	lighting_clock = 0.0
	night_amount = 0.0
	flight_age = 0.0
	patrol_index = 0
	roaming_time = 0.0
	rival_bank = 0.0
	tilt = 0.0
	thrust = 0.0
	delivery_age = 10.0
	celebration_age = 10.0
	bubble_timer = 0.0
	bubbles.clear()
	blooms.clear()
	pause_button.text = "Pause"
	spawn_fish()
	update_ui()
	sync_animation_layers()
	queue_redraw()

func spawn_fish() -> void:
	# Same clock as Diamond Catcher: one reach duration to arrive, then a one-second hold.
	target_seconds = Trial.reach_time()
	fish = TARGETS[target_index % TARGETS.size()]
	fish_state = "waiting"
	dwell = 0.0
	target_remaining = target_seconds
	Trial.appear(fish / Vector2(1280,800))

func toggle_pause() -> void:
	if not finished:
		paused = not paused
		pause_button.text = "Resume" if paused else "Pause"

func finish() -> void:
	Trial.finish()
	celebration_age = 0.0
	finished = true
	paused = false
	update_ui()

# Main-thread adapter: normalized continuous 2D position, not directional bins.
func submit_tracking(position: Vector2, confidence: float) -> void:
	tracking_valid = position.is_finite() and is_finite(confidence) and confidence >= 0.7
	if tracking_valid:
		tracking = position.clamp(Vector2(-1, -1), Vector2.ONE)
		tracking_time = Time.get_ticks_msec()

func tracking_lost() -> bool:
	return input_mode == InputMode.SENSOR and (not tracking_valid or Time.get_ticks_msec() - tracking_time > 500)

func _process(delta: float) -> void:
	if Trial.hardware:
		input_mode = InputMode.SENSOR
		submit_tracking(Trial.input_position(Vector2.ZERO)*2-Vector2.ONE,1.0 if not Trial.held() else 0.0)
	Trial.advance(delta, paused or tracking_lost(), player / Vector2(1280,800), fish / Vector2(1280,800))
	if not Trial.running or Trial.held(): return
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()
	if not paused and not finished and not tracking_lost():
		var desired := player
		if input_mode == InputMode.MOUSE:
			var mouse := get_global_mouse_position()
			if ARENA.has_point(mouse):
				desired = mouse
		elif input_mode == InputMode.KEYBOARD:
			var direction := Vector2(
				float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
				float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			desired += direction.limit_length() * player_speed * delta
		else:
			desired = HOME + tracking * Vector2(540, 230)
		var previous := player
		player = player.move_toward(desired, player_speed * delta).clamp(ARENA.position, ARENA.end)
		if player.distance_to(previous) > 0.1:
			inactivity = 0.0
			if absf(player.x - previous.x) > 0.01:
				facing = signf(player.x - previous.x)
		else:
			inactivity += delta
		var velocity := (player - previous) / maxf(delta, 0.0001)
		thrust = velocity.length() / player_speed
		var target_tilt := clampf(velocity.y / player_speed, -1, 1) * 0.22 * facing
		tilt = lerpf(tilt, target_tilt, 1.0 - exp(-8.0 * delta))
		resolve_player(delta)
		if fish_state == "waiting" and rival_enabled:
			# The countdown is frozen while the player rests on the fish, as in Diamond Catcher.
			if dwell <= 0.0: target_remaining = maxf(0.0, target_remaining - delta)
		if not finished and rival_enabled:
			rival_clock += delta
			advance_rival(delta)
	if not paused and not tracking_lost():
		advance_effects(delta)
		if not finished:
			update_lighting(delta)
	sync_animation_layers()
	update_ui()
	queue_redraw()

func resolve_player(delta: float) -> void:
	if fish_state == "gone":
		disappearance_age += delta
		if disappearance_age >= 1.0:
			target_index += 1
			spawn_fish()
	elif fish_state == "safe_flight":
		flight_age = minf(flight_duration, flight_age + delta)
		var t := smoothstep(0.0, flight_duration, flight_age)
		fish = flight_from.lerp(HOME, t)
		if not reduced_motion:
			fish.y -= sin(t * PI) * 35
		if flight_age >= flight_duration:
			fish_state = "delivered"
			delivery_from = HOME
			delivery_age = 0.0
			blooms.append(0.0)
			rescued += 1
			if not Trial.running:
				finish()
			else:
				target_index += 1
				spawn_fish()
	elif fish_state == "waiting":
		if player.distance_to(fish) <= pickup_radius:
			dwell = minf(dwell_seconds, dwell + delta)
			if dwell >= dwell_seconds:
				Trial.resolve(true)
				play_effect(Sfx.capture("FR"))
				popup("Rescued!", fish, Color("9df5d0"))
				# Hand the fish to the escape animation and show the next one right away.
				escape_active = true
				escape_from = fish
				escape_pos = fish
				escape_age = 0.0
				escape_duration = maxf(0.8, fish.distance_to(HOME) / 190.0)
				dwell = 0.0
				target_index += 1
				spawn_fish()
		else:
			dwell = 0.0

func play_effect(stream: AudioStream, volume: float = -10.0) -> void:
	if sfx_player == null:
		sfx_player = AudioStreamPlayer.new()
		add_child(sfx_player)
	sfx_player.volume_db = volume
	sfx_player.stream = stream
	sfx_player.play()

## Big friendly feedback text in Titan One that floats up and fades.
func popup(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UITheme.DISPLAY)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.16, 0.9))
	label.add_theme_constant_override("outline_size", 10)
	label.position = at + Vector2(-90, -70)
	label.z_index = 50
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)

func set_rival_enabled(value: bool) -> void:
	rival_enabled = value

func advance_rival(delta: float) -> void:
	var previous := rival
	roaming_time += delta
	if fish_state == "waiting" and target_remaining <= 0.0:
		rival = rival.move_toward(fish, shark_rush_speed * delta)
		if rival.distance_to(fish) < 16:
			# Atomic removal. No animation callback can award or remove twice.
			Trial.resolve(false)
			play_effect(Sfx.miss("FR"), -14.0)
			popup("Missed", fish, Color("ffb4a2"))
			fish_state = "gone"
			disappearance_age = 0.0
			dwell = 0.0
	else:
		var patrol := [Vector2(810, 575), Vector2(250, 520), Vector2(300, 235), Vector2(930, 245)]
		var destination: Vector2 = patrol[patrol_index]
		rival = rival.move_toward(destination, rival_speed * delta)
		if rival.distance_to(destination) < 35:
			patrol_index = (patrol_index + 1) % patrol.size()
	var travel := rival - previous
	if absf(travel.x) > 0.01:
		rival_facing = signf(travel.x)
	if travel.length_squared() > 0.001:
		var bank_target := clampf(travel.normalized().y * rival_facing, -0.65, 0.65)
		rival_bank = lerpf(rival_bank, bank_target, 1.0 - exp(-5.0 * delta))

func update_ui() -> void:
	progress.text = "%d rescued" % rescued
	instruction.text = "Fish swimming to safety!" if fish_state == "safe_flight" else "Reach the fish · hold for %.0f seconds" % dwell_seconds
	hold_label.text = ""
	hold_label.position = fish + Vector2(-43, 51)
	if fish_state == "gone":
		instruction.text = "The shark got this fish · next one coming"
	timer_label.text = ""
	if rival_enabled and fish_state == "waiting" and target_remaining <= 0:
		timer_label.text = "Shark incoming!"
	if finished:
		timer_label.text = ""
	overlay.text = ""
	if finished:
		instruction.text = "Thank you for helping the reef!"
		overlay.text = "Session complete · %d fish rescued. Play again with Restart." % rescued
	elif paused:
		overlay.text = "Paused · take your time"
	elif tracking_lost():
		overlay.text = "Waiting for a valid tracker signal · game held"

func _draw() -> void:
	draw_environment_effects()
	if rival_enabled:
		draw_set_transform(rival, rival_bank, Vector2(1.5, 0.75))
		draw_glow(Vector2.ZERO, 66, Color(1.0, 0.68, 0.25, 0.018 + night_amount * 0.012))
		draw_set_transform(Vector2.ZERO)
	draw_glow(HOME, 125, Color(0.3, 1.0, 0.8, 0.018 + night_amount * 0.026))
	# Native interface stays separate from the moving playfield.
	pass # Unified floating HUD
	pass # Full-bleed playfield
	if not overlay.text.is_empty():
		draw_style_box(panel_style(Color("123e51")), Rect2(290, 101, 910, 40))
	# Soft light rings preserve the readable home and pickup zones.
	if escape_active:
		for radius in range(84, 100, 3):
			draw_arc(HOME, radius, 0, TAU, 80, Color(0.8, 1.0, 0.7, 0.12), 3, true)
		draw_arc(HOME, 85, 0, TAU, 80, Color("efffc1"), 2, true)
	if fish_state == "waiting" and rival_enabled and target_remaining <= 0.0:
		var distance := rival.distance_to(fish)
		for i in range(int(distance / 22)):
			var point := rival.move_toward(fish, i * 22)
			draw_circle(point, 5, Color(0.3, 0.1, 0.45, 0.25))
			draw_circle(point, 3, Color("ecc0ff"))
	if not finished and fish_state != "gone":
		draw_glow(fish, 64, Color(0.7, 1.0, 0.75, 0.03 + night_amount * 0.065))
		if fish_state == "waiting":
			preload("res://core/target_feedback.gd").draw(self,fish,46,target_remaining,target_seconds,dwell/dwell_seconds)
	for bubble in bubbles:
		var alpha: float = maxf(0, 1.0 - bubble.age / 1.4)
		draw_arc(bubble.position, bubble.radius, 0, TAU, 18, Color(0.85, 0.98, 1, alpha * 0.6), 1.3, true)
	# Keep the position exact while banking the artwork toward travel.
	var bank := 0.0 if reduced_motion else tilt
	draw_set_transform(player, bank, Vector2(facing, 1))
	draw_texture_rect(SUB_ART, Rect2(-76, -51, 152, 101), false)
	if not reduced_motion and thrust > 0.02 and not finished:
		var blade := Vector2(3 * cos(elapsed * 35), 17 * sin(elapsed * 35))
		draw_line(Vector2(-66, 5) - blade, Vector2(-66, 5) + blade, Color("ffe4a3"), 3, true)
		draw_circle(Vector2(-66, 5), 3, Color("b58b43"))
	draw_set_transform(Vector2.ZERO)
	if delivery_age < 1.6 and not reduced_motion:
		for i in range(8):
			var angle := i * TAU / 8
			var point := HOME + Vector2.from_angle(angle) * (30 + delivery_age * 25)
			draw_arc(point, 3, 0, TAU, 16, Color(0.7, 1.0, 0.85, (1 - delivery_age / 1.6) * 0.65), 1.5, true)
	if celebration_age < 2.5 and not reduced_motion:
		for i in range(16):
			var angle := i * TAU / 16
			var point := HOME + Vector2.from_angle(angle) * (45 + celebration_age * 32)
			draw_circle(point, 3, Color(1, 0.88, 0.5, (1 - celebration_age / 2.5) * 0.7))

func panel_style(color: Color, border: Color = Color("38778b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = border
	style.shadow_color = Color(0.01, 0.08, 0.13, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func build_animation_layers() -> void:
	water_sprite = Sprite2D.new()
	water_sprite.texture = BACKGROUNDS[0]
	water_sprite.position = Vector2(640, 400)
	water_sprite.scale = Vector2(1280.0, 800.0) / BACKGROUNDS[0].get_size()
	water_sprite.z_index = -1
	var water_material := ShaderMaterial.new()
	water_material.shader = load("res://games/fish-rescue/shaders/water.gdshader")
	water_sprite.material = water_material
	add_child(water_sprite)
	shark_sprite = Sprite2D.new()
	shark_sprite.texture = SHARK_ART
	shark_sprite.scale = Vector2(160.0, 105.0) / SHARK_ART.get_size()
	var shark_material := ShaderMaterial.new()
	shark_material.shader = load("res://games/fish-rescue/shaders/shark.gdshader")
	shark_sprite.material = shark_material
	add_child(shark_sprite)
	fish_sprite = make_fish_sprite(78.0)
	escape_sprite = make_fish_sprite(78.0)
	escape_sprite.visible = false
	for i in range(session_goal):
		home_fish.append(make_fish_sprite(35.0))
	for i in range(18):
		var creature := make_fish_sprite(12.0 + i % 3 * 3.0)
		creature.modulate = Color(0.45, 0.65, 0.72, 0.23)
		distant_fish.append(creature)

func sync_animation_layers() -> void:
	water_sprite.material.set_shader_parameter("saturation", background_saturation)
	water_sprite.material.set_shader_parameter("ambience", background_ambience)
	for i in range(distant_fish.size()):
		var creature := distant_fish[i]
		var drift := 0.0 if reduced_motion else fmod(elapsed * 3.0, 380.0)
		var side := 90.0 if i % 2 == 0 else 1180.0
		creature.position = Vector2(side + sin(i * 1.7 + (0.0 if reduced_motion else elapsed * 0.3)) * 25, 200 + fmod(i * 31.0 + drift, 380))
		creature.flip_h = i % 2 == 1
		creature.material.set_shader_parameter("clock", elapsed + i)
		creature.material.set_shader_parameter("motion", not reduced_motion)
	water_sprite.material.set_shader_parameter("night", night_amount)
	water_sprite.material.set_shader_parameter("clock", elapsed)
	water_sprite.material.set_shader_parameter("motion", not reduced_motion)
	smooth_facing(shark_sprite, rival_facing < 0)
	shark_sprite.modulate = Color.WHITE.lerp(Color("8aafd2"), night_amount * 0.55)
	shark_sprite.position = rival
	shark_sprite.visible = rival_enabled
	shark_sprite.material.set_shader_parameter("clock", rival_clock)
	shark_sprite.material.set_shader_parameter("rush", fish_state == "waiting" and target_remaining <= 0.0)
	shark_sprite.material.set_shader_parameter("motion", not reduced_motion)
	shark_sprite.rotation = rival_bank if reduced_motion else rival_bank + sin(rival_clock * 5.0) * 0.035
	fish_sprite.visible = not finished and fish_state != "gone"
	fish_sprite.position = fish
	fish_sprite.material.set_shader_parameter("clock", elapsed)
	fish_sprite.material.set_shader_parameter("motion", not reduced_motion)
	var greeting := fish_state == "waiting" and player.distance_to(fish) < 110.0
	fish_sprite.rotation = 0.0 if reduced_motion else sin(elapsed * (4.0 if greeting else 2.4)) * (0.09 if greeting else 0.04)
	var greeting_scale := 1.0 if reduced_motion or not greeting else 1.0 + sin(elapsed * 4.0) * 0.035
	fish_sprite.scale = Vector2.ONE * 78.0 / FISH_ART.get_width() * greeting_scale
	smooth_facing(fish_sprite, fish_state == "safe_flight" and flight_from.x > HOME.x)
	escape_sprite.visible = escape_active and not finished
	escape_sprite.position = escape_pos
	escape_sprite.material.set_shader_parameter("clock", elapsed)
	escape_sprite.material.set_shader_parameter("motion", not reduced_motion)
	escape_sprite.scale = Vector2.ONE * 78.0 / FISH_ART.get_width()
	smooth_facing(escape_sprite, escape_from.x > HOME.x)
	for i in range(home_fish.size()):
		var sprite := home_fish[i]
		sprite.visible = i < rescued
		var orbit := i * 2.4 + (0.0 if reduced_motion else elapsed * 0.12)
		sprite.position = HOME + Vector2.from_angle(orbit) * (22 + i % 3 * 13)
		smooth_facing(sprite, sin(orbit) > 0)
		sprite.material.set_shader_parameter("clock", elapsed + i)
		sprite.material.set_shader_parameter("motion", not reduced_motion)
	progress.pivot_offset = progress.size * 0.5
	var bump := 0.0 if reduced_motion else sin(clampf(delivery_age / 0.65, 0, 1) * PI) * 0.12
	progress.scale = Vector2.ONE * (1.0 + bump)

func advance_effects(delta: float) -> void:
	# A single simulation clock freezes every effect on pause/tracking loss.
	# Completion allows its short final delivery/celebration to settle.
	if finished and celebration_age >= 2.5:
		return
	elapsed += delta
	if escape_active:
		escape_age = minf(escape_duration, escape_age + delta)
		var u := smoothstep(0.0, escape_duration, escape_age)
		escape_pos = escape_from.lerp(HOME, u)
		if not reduced_motion:
			escape_pos.y -= sin(u * PI) * 35
		if escape_age >= escape_duration:
			escape_active = false
			delivery_from = HOME
			delivery_age = 0.0
			blooms.append(0.0)
			rescued += 1
	delivery_age += delta
	celebration_age += delta
	for i in range(blooms.size()):
		blooms[i] += delta
	if reduced_motion:
		bubbles.clear()
		return
	for i in range(bubbles.size() - 1, -1, -1):
		bubbles[i].age += delta
		bubbles[i].position += bubbles[i].velocity * delta
		if bubbles[i].age >= 1.4:
			bubbles.remove_at(i)
	if thrust > 0.02 and not finished:
		bubble_timer += delta
		if bubble_timer >= 0.07:
			bubble_timer = fmod(bubble_timer, 0.07)
			bubbles.append({"position": player + Vector2(-66 * facing, 5).rotated(tilt), "velocity": Vector2(-facing * 24, -18), "age": 0.0, "radius": 2.0 + fmod(elapsed * 7, 3.0)})

func draw_environment_effects() -> void:
	# One quiet ray passes at the perimeter, then leaves a long clear interval.
	var visit := fmod(elapsed, 36.0)
	if not reduced_motion and visit > 8.0 and visit < 22.0:
		var t := (visit - 8.0) / 14.0
		var opacity := sin(t * PI) * 0.35
		var side := 95.0 if background_index == 0 else 1185.0
		var center := Vector2(side, lerpf(610.0, 185.0, t))
		var wing := sin(elapsed * 1.7) * 6.0
		draw_set_transform(center)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(13, -8), Vector2(39, 13 + wing), Vector2(15, 17), Vector2(0, 26), Vector2(-15, 17), Vector2(-39, 13 + wing), Vector2(-13, -8)]), Color(0.25, 0.43, 0.5, opacity))
		draw_polyline(PackedVector2Array([Vector2(0, 20), Vector2(3, 39), Vector2(8, 54)]), Color(0.25, 0.43, 0.5, opacity), 2, true)
		draw_set_transform(Vector2.ZERO)
	if not reduced_motion:
		for i in range(18):
			var x := 95 + fmod(i * 73.7 + sin(elapsed * 0.3 + i) * 12, 1100)
			var y := 655 - fmod(i * 41.3 + elapsed * (3 + i % 4), 490)
			draw_circle(Vector2(x, y), 1.2 + i % 3 * 0.4, Color(0.72, 0.85, 0.88, 0.14))
	for i in range(blooms.size()):
		var growth := 1.0 if reduced_motion else smoothstep(0.15, 1.4, blooms[i])
		var base := HOME + Vector2.from_angle(i * TAU / session_goal) * 108
		var tint := Color("f7a3c5") if i % 2 == 0 else Color("ffd67b")
		for branch in range(4):
			var sway := 0.0 if reduced_motion else sin(elapsed * 1.4 + i + branch) * 2
			var tip := base + Vector2((branch - 1.5) * 7 + sway, -18 - (branch % 2) * 10) * growth
			draw_line(base, tip, tint.darkened(0.18), 4 * growth + 0.1, true)
			draw_circle(tip, 3.5 * growth, tint)
		if blooms[i] < 1.4 and not reduced_motion:
			draw_arc(base, 10 + blooms[i] * 20, 0, TAU, 32, Color(1, 0.9, 0.6, (1 - blooms[i] / 1.4) * 0.4), 2, true)

func update_lighting(delta: float) -> void:
	if lighting_mode == 1:
		night_amount = 0.0
	elif lighting_mode == 2:
		night_amount = 1.0
	elif not reduced_motion:
		lighting_clock += delta
		night_amount = smoothstep(35.0, 42.0, preload("res://core/visual_cycle.gd").lighting_time())

func draw_glow(center: Vector2, radius: float, tint: Color) -> void:
	var soft_tint := Color(tint, tint.a * 10.0 / 32.0)
	for i in range(32, 0, -1):
		draw_circle(center, radius * i / 32.0, soft_tint)

func make_fish_sprite(width: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FISH_ART
	sprite.scale = Vector2.ONE * width / FISH_ART.get_width()
	var swim := ShaderMaterial.new()
	swim.shader = load("res://games/fish-rescue/shaders/fish.gdshader")
	sprite.material = swim
	add_child(sprite)
	return sprite

func select_next_background() -> void:
	# Persist across launches as well as Restart; never repeat consecutively.
	var settings := ConfigFile.new()
	settings.load("user://reef_settings.cfg")
	background_index = (int(settings.get_value("appearance", "last_background", -1)) + 1) % BACKGROUNDS.size()
	settings.set_value("appearance", "last_background", background_index)
	settings.save("user://reef_settings.cfg")
	water_sprite.texture = BACKGROUNDS[background_index]
	water_sprite.scale = Vector2(1280.0, 800.0) / water_sprite.texture.get_size()
	session_title.text = BACKGROUND_NAMES[background_index]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.keycode == KEY_F10:
			get_window().mode = Window.MODE_WINDOWED
			get_window().size = Vector2i(3840, 2160)

# Preserve the authored sprite size while turning through a short side profile.
# This is cosmetic: target positions and rescue timing are unchanged.
func smooth_facing(sprite: Sprite2D, left: bool) -> void:
	var goal := -1.0 if left else 1.0
	var base: float = sprite.get_meta("turn_base", absf(sprite.scale.x))
	sprite.set_meta("turn_base", base)
	var facing: float = sprite.get_meta("turn_value", goal)
	facing = goal if reduced_motion else move_toward(facing, goal, get_process_delta_time() * 10.0)
	sprite.set_meta("turn_value", facing)
	sprite.flip_h = false
	sprite.scale.x = base * facing




