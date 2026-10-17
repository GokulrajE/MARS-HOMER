extends Node2D
const GameArt = preload("res://core/game_art.gd")
const GameFx = preload("res://core/game_fx.gd")
## Native Godot gameplay ports. Visual/robot parity is tracked in MIGRATION.md.
const Cast = preload("res://core/flight_characters.gd")
const Sfx = preload("res://core/sfx.gd")
var character_id = "bheem"
var character_data: Dictionary
const REEF_PLAYER_X = 380.0
## Timing and geometry taken from the Unity project (others.cs, the game controllers).
## Ping Pong: the ball covers 14 units per reach duration; the paddles are 13 units apart.
const PONG_SPEED = 1320.0 * 14.0 / 13.0
## Tuk Tuk gates spawn 16 units ahead of the bird and scroll 14.82 units per reach duration.
const GATE_TRAVEL = 16.0 / 14.82
## Space Shooter asteroid path 5.19 -> -3 and Match Catch ball path 5 -> -5 (units), in screen pixels.
const SS_START = -156.6
const SS_END = 800.6
const MC_START = -116.9
const MC_SPAN = 1016.9
const MC_BASKET_Y = 783.0
var visual_variant=0
var passed_reefs: Array = []
var reef_water: Sprite2D
var swim_sprite: Sprite2D
var swim_tilt = 0.0
var facing = 1.0
var facing_goal = 1.0
var visual_tilt = 0.0
var paused = false
var player = Vector2(800,700)
var target = Vector2.ZERO
var previous = Vector2.ZERO
var age = 0.0
var delay = 0.05
var hold = 0.0
var shot_clock = 0.0
var still_time = 0.0
var pong_impact = 0.0
var bounce_gap = 0.0
var pong_easy = false
var wipe_progress = 0.0
var bullets: Array[Vector2] = []
var stains: Array[Vector2] = []
var cleared: Array[bool] = []
var balls: Array[Vector2] = []
var match_index = 0
var match_caught_color = 0
var color_index = 0
var pong_velocity=Vector2.ZERO
var pong_returning=false
var last_selection=[1,0,0,0]
var wipe_image: Image
var wipe_texture: ImageTexture
var wipe_total=0
var wipe_erased=0
var wipe_origin=Vector2.ZERO
var artwork: Dictionary={}
var sound: AudioStreamPlayer
var shot_sound: AudioStreamPlayer
var space_blasts: Array[AudioStream] = []
var sound_on=true
var clock=0.0
var colors = [Color.CORAL, Color.AQUAMARINE, Color.GOLD, Color.MEDIUM_PURPLE]
var feedback = ""
var font = ThemeDB.fallback_font
var fx = GameFx.new()
var trail: Array[Vector2] = []
var opp_y = 450.0
var exhaust = 0.0
var catch_pose = 0.0
var pop_clock = 0.0
var target_hit_wrong = false
var suds_clock = 0.0

func _ready() -> void:
	pong_easy = bool(Services.settings.get_value("pong","easy",false))
	previous = player
	character_id = Cast.next_character()
	character_data = Cast.CAST[character_id]
	if Trial.game in ["TT","CB"]:
		reef_water = Sprite2D.new()
		var scene_index=preload("res://core/visual_cycle.gd").look()
		var scenes=["res://assets/art/bheem_world.png","res://assets/art/tt_background.png","res://assets/legacy/flight-background.png"] if Trial.game=="CB" else ["res://assets/art/reef_world.png","res://assets/art/reef_forest.png","res://games/fish-rescue/assets/pearl-cove.png"]
		if not ResourceLoader.exists(scenes[scene_index]): scenes[scene_index]="res://assets/art/reef_world.png"
		reef_water.texture = load(scenes[scene_index])
		reef_water.centered = false
		reef_water.scale = Vector2(1600,900)/reef_water.texture.get_size()
		reef_water.z_index = -1
		var water_material = ShaderMaterial.new()
		water_material.shader = load("res://core/bheem_sky.gdshader" if Trial.game=="CB" else "res://core/reef_water.gdshader")
		water_material.set_shader_parameter("next_scene",load("res://assets/art/reef_forest.png"))
		water_material.set_shader_parameter("lighting_time",preload("res://core/visual_cycle.gd").lighting_time())
		water_material.set_shader_parameter("look",preload("res://core/visual_cycle.gd").look())
		reef_water.material = water_material
		reef_water.modulate = [Color.WHITE, Color(0.86, 1.0, 0.95), Color(1.0, 0.9, 1.0)][preload("res://core/visual_cycle.gd").look()] if Trial.game=="TT" else Color.WHITE
		add_child(reef_water)
		swim_sprite = Sprite2D.new()
		swim_sprite.show_behind_parent = true
		swim_sprite.texture = load("res://assets/art/"+character_data.file+".png" if Trial.game=="CB" else "res://assets/art/reef_fish.png")
		var material = ShaderMaterial.new()
		material.shader = load("res://core/bheem_fly.gdshader" if Trial.game=="CB" else "res://core/reef_swim.gdshader")
		swim_sprite.material = material
		add_child(swim_sprite)
	for asset in ["ship","asteroid","stain","bird","flight-background"]:
		artwork[asset]=load("res://assets/legacy/"+asset+".png")
	sound=AudioStreamPlayer.new()
	sound.volume_db=-15
	add_child(sound)
	if Trial.game=="SS":
		for i in 3: space_blasts.append(load("res://assets/sounds/space_blast_%d.wav" % i))
		sound.max_polyphony=3
		shot_sound=AudioStreamPlayer.new()
		shot_sound.volume_db=-25
		shot_sound.stream=load("res://assets/sounds/space_shot.wav")
		add_child(shot_sound)
		Trial.ended.connect(func(): sound.stop(); shot_sound.stop())
	if Trial.game=="CB":
		Records.log_event("Character Flight: "+character_id+"; raw="+Trial.raw_name)

func spawn() -> void:
	visual_variant=posmod(Trial.targets+Trial.trial_session,3)
	age = 0
	hold = 0
	target = Vector2(randf_range(30,1570),randf_range(210,690))
	if Trial.game in ["DC","TW"]: target=reach_target()
	match Trial.game:
		"SS": target.y = SS_START
		"MC": target.y = MC_START
		"PP", "TT", "CB":
			trail.clear()
			target.x = 1480
			if Trial.game in ["TT","CB"]: target.y = randf_range(50.0,850.0)
			if Trial.game=="PP":
				pong_velocity=return_direction()*PONG_SPEED/Trial.reach_time()
				pong_returning=false
		"TW":
			stains.clear()
			cleared.clear()
			for y in range(-5,6):
				for x in range(-5,6):
					if Vector2(x,y).length() <= 5:
						stains.append(target + Vector2(x,y)*12)
						cleared.append(false)
			create_stain()
	if Trial.game == "MC":
		balls.clear()
		for i in 4:
			var x=0.0
			for attempt in 100:
				x=randf_range(20,1580)
				var separated=true
				for ball in balls:
					if absf(ball.x-x)<213: separated=false
				if separated: break
			balls.append(Vector2(x,MC_START))
		match_index = color_index
		target = balls[match_index]
	Trial.appear(target / Vector2(1600,900))
	feedback = ""

func resolve(success: bool) -> void:
	if Trial.game in ["TT","CB"] and Trial.target_open:
		passed_reefs.append({"x":target.x,"y":target.y,"speed":(1480-REEF_PLAYER_X)/(Trial.reach_time()*GATE_TRAVEL),"kind":visual_variant})
	Trial.resolve(success)
	# The next target appears at once after a hit; its feedback plays on independently.
	delay = 0.0 if success else 0.05
	feedback = "Great work!" if success else "Next target"
	GameArt.on_resolve(self,success)
	if Trial.game=="SS" and success:
		if sound_on:
			sound.stream=space_blasts[visual_variant]
			sound.pitch_scale=randf_range(.96,1.04)
			sound.play()
	elif success: play_stream(Sfx.capture(Trial.game),-11.0)
	else: play_stream(Sfx.miss(Trial.game),-14.0)
	if success and Trial.game == "MC": color_index = randi_range(0,3)
	bullets.clear()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"): paused = not paused
	if Trial.game=="SS":
		sound.stream_paused=paused or Trial.held() or not Trial.running or not sound_on
		shot_sound.stream_paused=sound.stream_paused
	if not paused and Trial.running and not Trial.held(): GameArt.tick(self,delta)
	Trial.advance(delta,paused,player/Vector2(1600,900),target/Vector2(1600,900))
	if not Trial.running or paused or Trial.held(): return
	clock+=delta
	var mouse = get_global_mouse_position().clamp(Vector2(70,160),Vector2(1530,800))
	mouse=Trial.input_position(mouse/Vector2(1600,900))*Vector2(1600,900)
	step_game(delta,mouse)

func step_game(delta: float,position: Vector2) -> void:
	if not Trial.running or paused or Trial.held(): return
	previous=player
	player=position
	if Trial.movement == "ML": player.y = MC_BASKET_Y if Trial.game=="MC" else 730
	if Trial.movement == "AP": player.x = REEF_PLAYER_X if Trial.game in ["TT","CB"] else 120
	if Trial.game in ["TT","CB"]: advance_passed_reefs(delta)
	if Trial.game=="PP" and pong_returning:
		advance_pong(delta)
		queue_redraw()
		return
	if not Trial.target_open:
		delay -= delta
		if delay <= 0: spawn()
		queue_redraw()
		return
	age += delta
	var reach = Trial.reach_time()
	match Trial.game:
		"DC":
			if age >= 0.5:
				if player.distance_to(target) < 50:
					hold += delta
					age -= delta # Legacy reach countdown stops during the hold.
					if hold >= 1: resolve(true)
				else:
					hold = 0
					if age >= reach + 0.5: resolve(false)
		"TW":
			if age >= 0.5:
				erase_stain(previous,player)
				if float(wipe_erased)/maxi(1,wipe_total)>0.95: resolve(true)
		"SS":
			target.y = lerpf(SS_START, SS_END, age / reach)
			shot_clock -= delta
			var physical_speed = absf(player.x-previous.x)/1600 * Trial.rom.x / maxf(delta,0.0001)
			still_time = still_time + delta if physical_speed < 0.002 else 0.0
			if still_time >= 0.3 and shot_clock <= 0:
				bullets.append(player - Vector2(0,40))
				if sound_on and is_instance_valid(shot_sound): shot_sound.play()
				shot_clock = 0.65
			for i in range(bullets.size()-1,-1,-1):
				bullets[i].y -= 800*delta
				if bullets[i].distance_to(target) < 40:
					resolve(true)
					break
				if bullets[i].y < 0: bullets.remove_at(i)
			if Trial.target_open and age >= reach: resolve(false)
		"MC":
			for i in balls.size(): balls[i].y = MC_START + MC_SPAN * age / reach
			target = balls[match_index]
			for i in balls.size():
				if player.distance_to(balls[i]) < 55:
					target_hit_wrong = i != match_index
					resolve(i == match_index)
					break
			if Trial.target_open and age >= reach: resolve(false)
		"PP": advance_pong(delta)
		"TT", "CB":
			target.x = 1480 - (1480 - REEF_PLAYER_X) * age / (reach * GATE_TRAVEL)
			if age >= reach * GATE_TRAVEL: resolve(absf(player.y-target.y) < (72 if Trial.game in ["TT","CB"] else 58))
	queue_redraw()

func reach_target() -> Vector2:
	# Same non-overlapping convex-corner selection as DCPlayer/TWPlayer.
	var selection=[0,0,0,0]
	for attempt in 100:
		var overlap=0
		for i in 4:
			selection[i]=randi_range(0,1)
			overlap+=selection[i]*last_selection[i]
		if overlap<float(maxi(1,last_selection.count(1))) and selection.count(1)>0: break
	last_selection=selection.duplicate()
	var weights=[]
	var total=0.0
	for i in 4:
		weights.append(selection[i]+randf_range(0,0.25))
		total+=weights[-1]
	var vertices=[Vector2(800,190),Vector2(1450,450),Vector2(150,450),Vector2(800,740)]
	if Trial.hardware and Records.corners.has(Trial.movement):
		var row=Records.corners[Trial.movement]
		var names=["Top","Right","Left","Bottom"]
		var bounds=Records.limits(Trial.movement)
		for i in 4:
			var ep=Vector2(float(row[names[i]+"AdjustedX"]),float(row[names[i]+"AdjustedY"]))
			var normalized=(ep-bounds.position)/Vector2(maxf(0.001,bounds.size.x),maxf(0.001,bounds.size.y))
			if Records.profile.get("TrainingSide","RIGHT")=="RIGHT": normalized.x=1-normalized.x
			normalized.y=1-normalized.y
			vertices[i]=normalized*Vector2(1600,900)
	var point=Vector2.ZERO
	for i in 4: point+=vertices[i]*weights[i]/total
	return point.clamp(Vector2(60,110),Vector2(1540,830))

const EASY_CHIP = Rect2(1010, 104, 238, 44)

## Easy mode (Unity's trajectory toggle): shows where the incoming ball will reach the paddle.
func toggle_easy() -> void:
	pong_easy = not pong_easy
	Services.settings.set_value("pong","easy",pong_easy)
	Services.save()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if Trial.game != "PP": return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and not event.ctrl_pressed:
		toggle_easy()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and EASY_CHIP.has_point(get_global_mouse_position()):
		toggle_easy()

## Predicted path of the ball back to the player's paddle line, with wall bounces.
func predicted_path() -> PackedVector2Array:
	var points = PackedVector2Array()
	if not Trial.target_open or pong_velocity.x >= -1.0: return points
	var p = target
	var v = pong_velocity
	points.append(p)
	for i in 12:
		var t_wall = INF
		if v.y > 0.01: t_wall = (786.0 - p.y) / v.y
		elif v.y < -0.01: t_wall = (174.0 - p.y) / v.y
		var t_paddle = (140.0 - p.x) / v.x
		if t_paddle <= t_wall:
			points.append(p + v * t_paddle)
			break
		p += v * t_wall
		points.append(p)
		v.y = -v.y
	return points

func advance_pong(delta: float) -> void:
	bounce_gap=maxf(0,bounce_gap-delta)
	if not Trial.target_open and not pong_returning: return
	target+=pong_velocity*delta
	if (target.y<174 and pong_velocity.y<0) or (target.y>786 and pong_velocity.y>0):
		target.y=clampf(target.y,174,786)
		pong_velocity.y=-pong_velocity.y
		pong_impact=0.18
		# Steep shots can touch the walls several times a second; the click is rate-limited so it
		# stays a light tick instead of a continuous rattle.
		if bounce_gap<=0:
			play_sound("bounce",-14.0)
			bounce_gap=0.28
			for k in 3: fx.add("spark",target,{"vel":Vector2(randf_range(-90,90),(-1 if target.y<400 else 1)*randf_range(60,160)),"life":0.35,"size":16.0,"color":Color(1,1,1,0.8)})
	if pong_velocity.x<0 and target.x<=140:
		if absf(player.y-target.y)<=(110 if pong_easy else 70):
			Trial.resolve(true)
			fx.celebrate(Vector2(150,target.y),"Returned!",Color("7ff3ff"))
			feedback="Returned!"
			play_sound("bounce")
			pong_returning=true
			var angle=clampf(0.2*signf(target.y-player.y)+(target.y-player.y)/116,-0.8,0.8)
			pong_velocity=Vector2(1,angle).normalized()*PONG_SPEED/Trial.reach_time()
			target.x=140
			pong_impact=0.18
		else:
			resolve(false)
			pong_returning=false
	elif pong_velocity.x>0 and target.x>=1460:
		pong_returning=false
		fx.add("ring",Vector2(1470,target.y),{"life":0.5,"radius":70.0,"color":Color("ff9a6a")})
		target.x=1460
		pong_velocity=Vector2(-absf(pong_velocity.x),pong_velocity.y)
		pong_impact=0.18
		play_sound("bounce")
		Trial.appear(target/Vector2(1600,900))

## The opponent tracks the ball closely, so Unity's launch angle (0.2 * sign + offset / paddle
## height) stays shallow; returns are never steeper than about 20 degrees.
func return_direction() -> Vector2:
	var sign_y = 1.0 if randf() < 0.5 else -1.0
	return Vector2(-1, sign_y * (0.08 if pong_easy else 0.2) + randf_range(-0.05,0.05)).normalized()

func create_stain() -> void:
	wipe_image=preload("res://core/dirt_sprites.gd").make(visual_variant)
	wipe_image.convert(Image.FORMAT_RGBA8)
	# Unity's stain sprite: 3.06 x 1.37 units at scale 2 on a 17 x 9.2 unit field.
	wipe_image.resize(575,258,Image.INTERPOLATE_LANCZOS)
	wipe_total=0
	wipe_erased=0
	wipe_progress=0.0
	wipe_origin=(target-Vector2(wipe_image.get_size())/2).clamp(Vector2(20,120),Vector2(1600-575-20,900-258-70))
	target=wipe_origin+Vector2(wipe_image.get_size())/2
	var bytes=wipe_image.get_data()
	for i in range(3,bytes.size(),4):
		if bytes[i]>2: wipe_total+=1
	wipe_texture=ImageTexture.create_from_image(wipe_image)

func erase_stain(from: Vector2,to: Vector2) -> void:
	if from.distance_to(to)<0.1: return
	var brush=sqrt(Trial.scrub_area/(Trial.rom.x*Trial.rom.y)*1440000/PI)
	var local_from=from-wipe_origin
	var local_to=to-wipe_origin
	var last=Vector2(wipe_image.get_width()-1,wipe_image.get_height()-1)
	var low=(local_from.min(local_to)-Vector2.ONE*brush).clamp(Vector2.ZERO,last)
	var high=(local_from.max(local_to)+Vector2.ONE*brush).clamp(Vector2.ZERO,last)
	var changed=false
	for y in range(int(low.y),int(high.y)+1):
		for x in range(int(low.x),int(high.x)+1):
			var p=Vector2(x,y)
			if wipe_image.get_pixel(x,y).a>0.01 and Geometry2D.get_closest_point_to_segment(p,local_from,local_to).distance_to(p)<=brush:
				wipe_image.set_pixel(x,y,Color.TRANSPARENT)
				wipe_erased+=1
				changed=true
	if changed:
		wipe_texture.update(wipe_image)
		suds_clock-=1.0
		if suds_clock<=0:
			suds_clock=2.0
			fx.add("bubble",to+Vector2(randf_range(-30,30),randf_range(-20,20)),{"life":0.9,"size":randf_range(10,22),"vel":Vector2(randf_range(-20,20),-50),"layer":"front"})

func play_stream(stream: AudioStream, volume: float = -12.0) -> void:
	if sound_on and is_instance_valid(sound):
		sound.volume_db=volume
		sound.pitch_scale=1.0
		sound.stream=stream
		sound.play()

func play_sound(effect: String, volume: float = -15.0) -> void:
	if sound_on and is_instance_valid(sound):
		sound.volume_db=volume
		sound.stream=load("res://assets/legacy/"+effect+".wav").duplicate()
		if sound.stream is AudioStreamWAV: sound.stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
		sound.play()

func sprite(asset: String,center: Vector2,extent: Vector2) -> void:
	draw_texture_rect(artwork[asset],Rect2(center-extent/2,extent),false)

func _draw() -> void:
	GameArt.draw(self)

func advance_passed_reefs(delta: float) -> void:
	for reef in passed_reefs: reef.x -= reef.speed * delta
	passed_reefs = passed_reefs.filter(func(reef): return reef.x > -180.0)



