extends Node2D
const DayCycle=preload("res://core/visual_cycle.gd")

const COLORS = [Color("76e9ed"), Color("ffb768"), Color("ef8dcf"), Color("bca0ff"), Color("f9dc84")]
const NAMES = ["Sky rocket", "Golden fountain", "Sparkle wheel", "Flower burst"]
var rng = RandomNumberGenerator.new()
var stars: Array = []
var particles: Array = []
var rockets: Array = []
var active = false
var started = false
var completed = false
var elapsed = 0.0
var player_x = 800.0
var desired_x = 800.0
var target_x = 1100.0
var kind = 0
var tint = COLORS[0]
var charge = 0.0
var cooldown = 0.0
var emission = 0.0
# Fountains and wheels that are burning, each kept where and how it was lit so the next
# target can appear immediately without moving them: {x, tint, kind, variant, left, budget}.
var lit_fountains: Array = []
var count = 0
var target_age = 0.0
var reach = 490.0
var sound_on = true
var gentle = false
var side = 1
var message = "A little movement. A sky full of wonder."
var status: Label
var score: Label
var settings: PanelContainer
var start_button: Button
var voices: Array = []
const THEME_NAMES = ["Moonlit garden", "Aurora lake", "Lantern festival", "Twilight coast"]
const SKY_TOP = [Color("090f29"),Color("061b2b"),Color("20102f"),Color("211b47")]
const SKY_BOTTOM = [Color("405472"),Color("245c69"),Color("794c69"),Color("c27e7d")]
var theme_id = 0
var rotate_themes = true
var theme_picker: OptionButton
var theme_label: Label
var halo: Texture2D
var rings: Array = []
var hd_sprites: Dictionary = {}
var emission_budget = 0.0
var smoke: Array = []
var variant = 0
var fuse_time = 0.0
var finale_time = -1.0
var finale_step = 0
var garden_lights: Array = []
var pause_message = ""
var delayed_bursts: Array = []
var surprises: Array = []
var companion = Vector2(850,720)
var companion_joy = 0.0

func choose_theme(index: int):
	theme_id = posmod(index,4)
	theme_picker.select(theme_id)
	theme_label.text = THEME_NAMES[theme_id].to_upper()
	var config = ConfigFile.new()
	config.set_value("scene","theme",theme_id)
	config.set_value("scene","rotate",rotate_themes)
	config.save("user://garden.cfg")
	queue_redraw()

func _ready():
	scale = Vector2.ONE*2.4
	for asset in ["lantern","lamp","rocket","fountain","wheel","flower","blossom"]:
		var texture_asset=load("res://games/fire-works/assets/"+asset+".svg") as Texture2D
		if texture_asset!=null: hd_sprites[asset]=texture_asset
	rng.randomize()
	for i in range(135):
		stars.append(Vector3(rng.randf_range(20,1580),rng.randf_range(40,600),rng.randf_range(0.5,1.8)))
	build_ui()
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.55))
	gradient.add_point(0.25,Color(1,1,1,0.16))
	gradient.set_color(gradient.get_point_count()-1,Color(1,1,1,0))
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	halo = texture
	var config = ConfigFile.new()
	if config.load("user://garden.cfg") == OK:
		rotate_themes = config.get_value("scene","rotate",true)
		theme_id = int(config.get_value("scene","theme",-1)) + (1 if rotate_themes else 0)
	choose_theme(theme_id)
	set_process(true)

func label_at(text_value: String, position_value: Vector2, size_value: int, color_value: Color) -> Label:
	var l = Label.new()
	l.text = text_value
	l.position = position_value
	l.add_theme_font_size_override("font_size",size_value)
	l.add_theme_color_override("font_color",color_value)
	add_child(l)
	return l

func button(text_value: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(120,48)
	b.add_theme_font_size_override("font_size",18)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("20384d")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.border_color = Color("527080")
	style.set_border_width_all(1)
	style.shadow_color = Color(0.6,0.75,0.9,0.1)
	style.shadow_size = 7
	b.add_theme_stylebox_override("normal",style)
	var hover = style.duplicate()
	hover.bg_color = Color("355a6b")
	b.add_theme_stylebox_override("hover",hover)
	b.pressed.connect(callback)
	return b

func build_ui():
	label_at("G A R D E N   O F   L I G H T",Vector2(62,82),19,Color("a8c9d4"))
	score = label_at("Fireworks  0",Vector2(62,114),29,Color("f6e8cb"))
	theme_label = label_at("",Vector2(62,158),14,Color("90b8c4"))
	var row = HBoxContainer.new()
	row.position = Vector2(1110,48)
	row.add_theme_constant_override("separation",12)
	add_child(row)
	start_button = button("Start",start_session)
	row.add_child(start_button)
	row.add_child(button("Pause",pause_session))
	row.add_child(button("Settings",func(): settings.visible = not settings.visible))
	status = label_at(message,Vector2(300,820),24,Color("dfdedb"))
	status.size.x = 1000
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_at("Move left / right  •  Rest on the glowing target to light it",Vector2(470,861),17,Color("91a7b8"))
	settings = PanelContainer.new()
	settings.position = Vector2(1110,118)
	settings.custom_minimum_size = Vector2(420,200)
	settings.visible = false
	add_child(settings)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	settings.add_child(box)
	var title = Label.new()
	title.text = "Comfort settings"
	title.add_theme_font_size_override("font_size",22)
	box.add_child(title)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("132535")
	panel_style.set_corner_radius_all(18)
	panel_style.set_content_margin_all(18)
	settings.add_theme_stylebox_override("panel",panel_style)
	settings.position.x = 1070
	theme_picker = OptionButton.new()
	theme_picker.custom_minimum_size.y = 42
	for theme_name in THEME_NAMES: theme_picker.add_item(theme_name)
	theme_picker.item_selected.connect(choose_theme)
	box.add_child(theme_picker)
	var rotation = CheckButton.new()
	rotation.text = "Fresh theme each session"
	var saved = ConfigFile.new()
	saved.load("user://garden.cfg")
	rotation.button_pressed = saved.get_value("scene","rotate",true)
	rotation.toggled.connect(func(v): rotate_themes = v; choose_theme(theme_id))
	box.add_child(rotation)
	var ranges = HBoxContainer.new()
	box.add_child(ranges)
	for entry in [["Small",260.0],["Medium",380.0],["Wide",490.0]]:
		var value: float = entry[1]
		ranges.add_child(button(entry[0],func():
			reach = value
			target_x = clampf(target_x,800-reach,800+reach)
			desired_x = clampf(desired_x,800-reach,800+reach)
			charge = 0.0))
	var audio = CheckButton.new()
	audio.text = "Sound effects"
	audio.button_pressed = true
	audio.toggled.connect(func(v):
		sound_on = v
		if not v:
			for voice in voices: voice.stop())
	box.add_child(audio)
	var motion = CheckButton.new()
	motion.text = "Gentle effects (fewer sparks)"
	motion.toggled.connect(func(v): gentle = v)
	box.add_child(motion)
	box.add_child(button("Fullscreen / F11",toggle_fullscreen))

func toggle_fullscreen():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func start_session():
	if not started or completed:
		if completed and rotate_themes: choose_theme(theme_id+1)
		count = 0
		delayed_bursts.clear()
		surprises.clear()
		companion = Vector2(850,720)
		companion_joy = 0
		garden_lights.clear()
		fuse_time = 0
		finale_time = -1
		finale_step = 0
		particles.clear()
		rockets.clear()
		rings.clear()
		smoke.clear()
		emission_budget = 0
		cooldown = 0
		emission = 0
		lit_fountains.clear()
		completed = false
		started = true
		player_x = 800
		desired_x = 800
		spawn_target()
	active = true
	if not pause_message.is_empty():
		message = pause_message
		pause_message = ""
	start_button.text = "Resume"

func pause_session():
	if completed or not started: return
	if active: pause_message = message
	active = false
	for voice in voices: voice.stop()
	message = "Take your time. Press Resume when you’re ready."

func spawn_target():
	target_age = 0.0
	side *= -1
	target_x = 800 + side * rng.randf_range(reach*0.35,reach)
	kind = posmod(Trial.targets+Trial.trial_session,4)
	variant = rng.randi_range(0,2)
	tint = COLORS[rng.randi_range(0,4)]
	charge = 0
	Trial.appear(Vector2(target_x/1600.0,0.5))
	message = "Move to the " + NAMES[kind].to_lower() + " and let your light rest there."
	if kind==1: message = "Move to the " + ["gold rain","rainbow fountain","jewel fountain"][variant] + " and let your light rest there."

func _unhandled_input(event):
	if Trial.hardware: return
	if event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		desired_x = clampf(get_global_transform_with_canvas().affine_inverse().basis_xform(event.position).x,800-reach,800+reach)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pause_session()

# Device integrations can pass a calibrated value from -1 (left) to +1 (right).
func set_movement(value: float):
	desired_x = 800 + clampf(value,-1,1) * reach

func _process(delta):
	if Trial.hardware: set_movement(Trial.input_position(Vector2.ZERO).x*2-1)
	Trial.advance(delta, not active, Vector2(player_x/1600.0,0.5),Vector2(target_x/1600.0,0.5))
	if (not Trial.running and finale_time < 0) or Trial.held(): return
	if active and cooldown <= 0 and fuse_time <= 0 and Trial.target_open:
		target_age += delta
		# Patient-paced target: wait for a completed hold, with no speed timeout.
	status.text = message
	score.text = "Fireworks  %d" % count
	if not active:
		if not started and not gentle: elapsed += minf(delta,0.04)
		queue_redraw()
		return
	var dt = minf(delta,0.04)
	elapsed += dt
	companion_joy = maxf(0,companion_joy-dt)
	var buddy_goal = Vector2(player_x+45,718)
	if not gentle: buddy_goal += Vector2(sin(elapsed*2)*9,-sin(elapsed*3)*5-companion_joy*8)
	companion = companion.lerp(buddy_goal,1-exp(-4*dt))
	for i in range(surprises.size()-1,-1,-1):
		surprises[i].age += dt
		if surprises[i].age>4: surprises.remove_at(i)
	for i in range(delayed_bursts.size()-1,-1,-1):
		delayed_bursts[i].delay -= dt
		if delayed_bursts[i].delay<=0:
			var event = delayed_bursts[i]
			delayed_bursts.remove_at(i)
			burst(event.p,event.color,false,event.pattern)
	for light in garden_lights: light.age += dt
	for i in range(smoke.size()-1,-1,-1):
		smoke[i].age += dt
		if smoke[i].age>3.4: smoke.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		rings[i].age += dt
		if rings[i].age>1.4: rings.remove_at(i)
	var axis = Input.get_axis("ui_left","ui_right")
	if axis != 0 and not Trial.hardware: desired_x = clampf(desired_x + axis*420*dt,800-reach,800+reach)
	player_x = lerpf(player_x,desired_x,1-exp(-9*dt))
	if finale_time >= 0:
		finale_time += dt
		if finale_step<7 and finale_time>=[0.0,0.65,1.5,1.5,2.7,3.5,4.3][finale_step]:
			var x = [440,1160,640,960,800,520,1080][finale_step]
			launch_rocket(x,Color("ffce7b") if finale_step>=5 else COLORS[finale_step%5],[5,6,2,3,7,4,4][finale_step])
			finale_step += 1
		if finale_time>11 and rockets.is_empty() and particles.is_empty() and delayed_bursts.is_empty():
			completed = true
			active = false
			start_button.text = "Play again"
			message = "Your garden is glowing. Beautifully done! Play again whenever you’re ready."
	elif fuse_time>0:
		fuse_time -= dt
		if fuse_time<=0: ignite()
	elif cooldown > 0:
		cooldown = maxf(0.001,cooldown-dt)
		if rockets.is_empty() and lit_fountains.is_empty() and delayed_bursts.is_empty() and particles.is_empty():
			cooldown=0
		if cooldown <= 0:
			if not Trial.running:
				finale_time = 0
				message = "Twelve little movements. One wonderful celebration — enjoy your finale!"
			else: spawn_target()
	elif absf(player_x-target_x)<55:
		charge += dt
		message = "Hold your light here… the fuse is warming up."
		if charge >= 0.85:
			charge = 0.85
			fuse_time = 0.6
			message = "It’s lit! Watch your firework come to life."
	else:
		charge = maxf(0,charge-dt*2)
	for f in lit_fountains:
		f.left -= dt
		f.budget += dt*(45 if gentle else 90)
		var emit_count = int(f.budget)
		f.budget -= emit_count
		var total = 3.4 if f.kind == 1 else 2.8
		for i in range(emit_count):
			var angle = -PI/2 + rng.randf_range(-0.38,0.38) if f.kind == 1 else elapsed*13 + i*PI
			if f.kind==1:
				var envelope = minf((total-f.left)/0.65,1.0)*minf(f.left/0.7,1.0)
				var color = Color("ffcc71") if f.variant==0 else Color.from_hsv(fposmod(elapsed*0.18+i*0.035,1),0.65,1) if f.variant==1 else f.tint
				add_particle(Vector2(f.x,680),Vector2.from_angle(angle)*rng.randf_range(300,535)*maxf(0.3,envelope),color,rng.randf_range(2.1,2.7),rng.randf_range(1.1,2.5),185)
			else:
				add_particle(Vector2(f.x,707),Vector2.from_angle(angle)*rng.randf_range(100,340),f.tint,rng.randf_range(0.5,1.3),2.3,180)
	lit_fountains = lit_fountains.filter(func(f): return f.left > 0)
	emission = 0.0 if lit_fountains.is_empty() else 1.0
	for i in range(rockets.size()-1,-1,-1):
		var r = rockets[i]
		r.p += r.v*dt
		r.life -= dt
		for j in range(2 if gentle else 5):
			add_particle(r.p,Vector2(rng.randf_range(-22,22),rng.randf_range(35,95)),Color("ffcc7a"),0.6,2,15)
		if r.life <= 0:
			burst(r.p,r.color,r.pattern==1,r.pattern)
			rockets.remove_at(i)
	for i in range(particles.size()-1,-1,-1):
		var p = particles[i]
		p.life -= dt
		if p.life<=0:
			particles.remove_at(i)
			continue
		p.prev = p.p
		if p.trail.size()==0 or p.p.distance_to(p.trail[-1])>5:
			p.trail.append(p.p)
			if p.trail.size()>(3 if gentle else 6): p.trail.remove_at(0)
		p.v.y += p.gravity*dt
		p.v *= exp(-0.32*dt)
		p.p += p.v*dt
	queue_redraw()

func ignite():
	if not Trial.running or not Trial.target_open: return
	if cooldown>0 or finale_time>=0: return
	Trial.resolve(true)
	count += 1
	companion_joy = 2.4
	garden_lights.append({"age":0.0,"color":tint})
	cooldown = 0.1
	charge = 0
	message = ["A little spark, a lovely sky.","Look what your movement created!","Let it sparkle. Take your time."][count%3]
	play_sound("launch")
	if kind == 0 or kind == 3:
		launch_rocket(target_x,tint,(1+variant) if kind==3 else rng.randi_range(4,8))
	else:
		lit_fountains.append({"x":target_x,"tint":tint,"kind":kind,"variant":variant,"left":3.4 if kind==1 else 2.8,"budget":0.0})
		emission = 1.0
		play_sound("fountain")
	# Spawn only after the current firework and its trailing sparks finish.

func launch_rocket(x: float, color: Color, pattern: int):
	var flight = 1.5 if pattern<4 else 1.35+0.06*(pattern%4)
	rockets.append({"p":Vector2(x,704),"v":Vector2(0,-290 if pattern<4 else -315),"life":flight,"color":color,"pattern":pattern})

func add_particle(pos: Vector2, velocity: Vector2, color: Color, life: float, radius: float, gravity: float):
	if particles.size() >= 650: return
	particles.append({"p":pos,"prev":pos,"v":velocity,"color":color,"life":life,"max":life,"radius":radius,"gravity":gravity,"trail":PackedVector2Array()})

func burst(pos: Vector2, color: Color, flower: bool, pattern: int = 0):
	play_sound("willow" if pattern==4 else "chime" if pattern in [5,6] else "crackle" if pattern==8 else "burst")
	companion_joy = 1.8
	if pattern==7:
		delayed_bursts.append({"p":pos+Vector2(0,-25),"color":color.lerp(Color("fff1b1"),0.65),"pattern":5,"delay":0.65})
	if pattern==8:
		for i in range(5): delayed_bursts.append({"p":pos+Vector2.from_angle(i*TAU/5)*90,"color":color,"pattern":9,"delay":0.65+i*0.11})
	if count>0 and count%4==0 and pattern<9 and surprises.is_empty():
		surprises.append({"p":pos,"age":0.0,"butterfly":count%8!=0,"color":color})
	rings.append({"p":pos,"color":color,"age":0.0})
	if not gentle: smoke.append({"p":pos,"color":color,"age":0.0})
	var total = 75 if gentle else 240
	if pattern==9: total = 12 if gentle else 28
	for i in range(total):
		var angle = TAU*i/total
		var speed = (155+65*cos(angle*5)) if flower else rng.randf_range(70,235)
		var velocity = Vector2.from_angle(angle)*speed
		var life = rng.randf_range(1.8,2.8)
		var gravity = 24.0 if pattern>=2 else 42.0
		var spark_color = color.lerp(Color("fff0c4"),rng.randf()*0.4)
		if pattern==4:
			velocity = Vector2.from_angle(angle)*rng.randf_range(100,220)
			life = rng.randf_range(3.4,4.5)
			gravity = 65
			spark_color = Color("ffd080").lerp(Color("fff2bd"),rng.randf()*0.4)
		elif pattern==5:
			velocity = Vector2(cos(angle)*240,sin(angle)*65).rotated(-0.32) if i%3!=0 else Vector2.from_angle(angle)*85
		elif pattern==6:
			var wing = exp(cos(angle))-2*cos(4*angle)-pow(sin(angle/12),5)
			velocity = Vector2(sin(angle),-cos(angle))*wing*65
		elif pattern==8:
			velocity = Vector2.from_angle(angle)*(180+35*sin(angle*16))
		elif pattern==9:
			velocity = Vector2.from_angle(angle)*rng.randf_range(18,50)
			life = 0.7
		if pattern==2:
			velocity = Vector2(16*pow(sin(angle),3),-(13*cos(angle)-5*cos(2*angle)-2*cos(3*angle)-cos(4*angle)))*12
		elif pattern==3:
			var edge = fposmod(float(i)/total*10,1.0)
			var index = int(float(i)/total*10)
			var a = Vector2.from_angle(-PI/2+index*TAU/10)*(220 if index%2==0 else 92)
			var b = Vector2.from_angle(-PI/2+(index+1)*TAU/10)*(92 if index%2==0 else 220)
			velocity = a.lerp(b,edge)
		add_particle(pos,velocity,spark_color,life,rng.randf_range(1.3,3.1),gravity)
	for i in range(20):
		add_particle(pos,Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(25,100),Color("fff4d6"),1.3,2,20)

func play_sound(effect: String):
	if not sound_on: return
	var duration = 1.1 if effect == "fountain" else 0.65
	var rate = 22050
	var data = PackedByteArray()
	data.resize(int(duration*rate)*2)
	var phase = 0.0
	for i in range(int(duration*rate)):
		var t = float(i)/rate
		var env = pow(1-t/duration,2)*minf(t*100,1)
		var sample = 0.0
		if effect == "launch":
			phase += TAU*(400+1200*t)/rate
			sample = (sin(phase)*0.12+rng.randf_range(-0.03,0.03))*env
		elif effect == "burst":
			sample = (rng.randf_range(-0.32,0.32)*exp(-t*7)+sin(t*TAU*65)*0.17)*env
		elif effect == "chime":
			sample = (sin(t*TAU*660)+sin(t*TAU*990)*0.4)*0.1*env
		elif effect == "willow":
			sample = (sin(t*TAU*90)*0.15+rng.randf_range(-0.09,0.09))*env
		elif effect == "crackle":
			sample = rng.randf_range(-0.24,0.24)*pow(maxf(0,sin(t*91)),8)*env
		else:
			sample = (rng.randf_range(-0.12,0.12)+sin(t*TAU*1600)*0.025)*env
		data.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	var voice = AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = -7
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(func(): voices.erase(voice); voice.queue_free())
	voice.play()

func glow(pos: Vector2, radius: float, color: Color):
	if halo: draw_texture_rect(halo,Rect2(pos-Vector2.ONE*radius*2,Vector2.ONE*radius*4),false,color)

func _draw():
	draw_scenery()
	for puff in smoke:
		var age: float = puff.age
		for i in range(6):
			var pos: Vector2 = puff.p+Vector2(sin(i*2.1)*age*28,-age*12+cos(i*3.1)*age*22)
			glow(pos,45+age*35,Color(puff.color,0.055*(1-age/3.4)))
	for star in stars:
		var a = 0.45 + 0.2*sin(elapsed*0.6+star.x) if not gentle else 0.6
		if star.y<480: draw_circle(Vector2(star.x,star.y),star.z,Color(0.76,0.87,1,a*clampf((500-star.y)/130,0,1)))
	draw_foreground()
	draw_reactive_light()
	draw_garden_lanterns()
	for x in [90,230,1370,1510]:
		glow(Vector2(x,646),45,Color("ffc67c"))
		sprite("lamp",Rect2(x-25,619,50,139))
	draw_line(Vector2(800-reach,760),Vector2(800+reach,760),Color("b6a37d"),1.3,true)
	for wave in range(2):
		var points = PackedVector2Array()
		for x in range(int(800-reach),int(800+reach)+1,5):
			points.append(Vector2(x,760+sin(x*0.021+(0 if gentle else elapsed)*(1+wave))*3))
		draw_polyline(points,Color(1,0.81,0.48,0.25),1,true)
	for x in [800-reach,800,800+reach]: draw_circle(Vector2(x,760),4,Color("85a8ad"))
	if started and not completed and finale_time<0 and cooldown<=0:
		glow(Vector2(target_x,728),44,tint)
		var pulse = 0.0 if gentle else sin(elapsed*2)*3
		if charge<=0: draw_arc(Vector2(target_x,710),51+pulse,0,TAU,64,Color(tint,0.5),2,true)
		if absf(player_x-target_x)>70 and fuse_time<=0:
			var direction = signf(target_x-player_x)
			var cue = Vector2(player_x+direction*55,773)
			draw_polyline(PackedVector2Array([cue+Vector2(-direction*7,-6),cue,cue+Vector2(-direction*7,6)]),Color("edd4a1"),2,true)
		if charge>0: preload("res://core/target_feedback.gd").hold_ring(self,Vector2(target_x,710),51,charge/0.85)
		draw_firework(Vector2(target_x,710))
	# Lit fountains and wheels keep burning where they were lit.
	for f in lit_fountains:
		draw_firework(Vector2(f.x,710),f.kind)
		glow(Vector2(f.x,680),30,Color(f.tint,0.7))
	for p in particles:
		var a = clampf(p.life/p.max,0,1)
		for j in range(1,p.trail.size()):
			draw_line(p.trail[j-1],p.trail[j],Color(p.color,a*float(j)/p.trail.size()*0.55),maxf(0.6,p.radius*0.6),true)
		draw_line(p.p-p.v*0.035,p.p,Color(p.color,a*0.65),p.radius,true)
		draw_circle(p.p,p.radius*3,Color(p.color,a*0.055))
		draw_circle(p.p,p.radius,Color(p.color,a))
		if p.radius>2.6:
			glow(p.p,7,Color(p.color,a*0.6))
			var twinkle = 0.5+0.5*sin(p.life*21)
			draw_line(p.p-Vector2(4,0),p.p+Vector2(4,0),Color(1,0.95,0.8,a*twinkle),1,true)
			draw_line(p.p-Vector2(0,4),p.p+Vector2(0,4),Color(1,0.95,0.8,a*twinkle),1,true)
	for ring in rings:
		glow(ring.p,85*(1+ring.age),Color(ring.color,maxf(0,0.35-ring.age*0.3)))
		if not gentle: draw_arc(ring.p,20+ring.age*160,0,TAU,90,Color(ring.color,0.15*(1-ring.age/1.4)),1.5,true)
	for r in rockets: glow(r.p,12,r.color)
	draw_surprises()
	draw_companion()
	glow(Vector2(player_x,773),26,Color("fff1bd"))
	sprite("lantern",Rect2(player_x-18,748,36,48))
	for i in range(14 if not gentle else 4):
		var angle = i*TAU/14+(0 if gentle else elapsed*0.6)
		var p = Vector2(player_x,773)+Vector2.from_angle(angle)*30
		draw_circle(p,1.1,Color(1,0.81,0.43,0.65))
	if not started:
		draw_circle(Vector2(800,400),70,Color(0.7,0.85,1,0.025))
		draw_arc(Vector2(800,400),100,0,TAU,90,Color(0.7,0.85,1,0.08),1,true)

func draw_scenery():
	var t = 0.0 if gentle else elapsed
	for y in range(0,900,3):
		draw_rect(Rect2(0,y,1600,3),DayCycle.palette(Color("315b76"),Color("78516d"),SKY_TOP[theme_id]).lerp(DayCycle.palette(Color("7d9b9b"),Color("ad786d"),SKY_BOTTOM[theme_id]),pow(float(y)/900,1.2)))
	# Wide atmospheric pools keep the middle of the sky clear for fireworks.
	glow(Vector2(800,530),330,Color(SKY_BOTTOM[theme_id],0.3))
	for i in range(9):
		var p = Vector2(120+i*185+sin(t*0.06+i)*65,330+sin(i*4.2)*170)
		if halo: draw_texture_rect(halo,Rect2(p-Vector2(230,70),Vector2(460,140)),false,Color(0.55,0.64,0.82,0.055))
	if theme_id == 1:
		for band in range(3):
			for k in range(18):
				var ribbon = PackedVector2Array()
				for x in range(0,1620,16):
					ribbon.append(Vector2(x,210+band*44+sin(x*0.004+t*0.13+band)*58-k*4))
				var c = Color("67ebc9") if band%2==0 else Color("b38ff2")
				draw_polyline(ribbon,Color(c,0.028*(1-float(k)/18)),5,true)
	var moon = Vector2(1270,205)
	glow(moon,100,Color("ffe5bd"))
	draw_circle(moon,34,Color("f7e8c9"))
	for crater in [Vector3(-11,6,7),Vector3(13,13,4),Vector3(6,-15,8)]:
		draw_circle(moon+Vector2(crater.x,crater.y),crater.z,Color(0.65,0.65,0.65,0.12))
	for layer in range(3):
		var poly = PackedVector2Array([Vector2(0,740)])
		for x in range(0,1621,20):
			var y = 525+layer*47+sin(x*0.004+layer*1.8)*40+cos(x*0.008)*19
			if theme_id == 1: y -= absf(sin(x*0.006+layer))*85
			if theme_id == 3: y += 60
			poly.append(Vector2(x,y))
		poly.append(Vector2(1600,740))
		var base = Color("162638").lerp(SKY_BOTTOM[theme_id],0.28-layer*0.08)
		draw_colored_polygon(poly,base)
		if halo:
			draw_texture_rect(halo,Rect2(-200,500+layer*50,2000,130),false,Color(0.55,0.69,0.85,0.10))
	if theme_id == 1 or theme_id == 3:
		var water_y = 590 if theme_id == 1 else 610
		draw_rect(Rect2(0,water_y,1600,135),Color("183b50") if theme_id==1 else Color("575375"))
		for i in range(85):
			var y = water_y+6+i*1.5
			var width = 12+pow(float(i)/85,1.3)*130
			var x = 1270+sin(i*2.3+t*0.7)*18
			draw_line(Vector2(x-width,y),Vector2(x+width,y),Color(1,0.83,0.65,0.08),1.3,true)
		for i in range(35):
			var x = fmod(i*173.0+t*4,1650)-25
			var y = water_y+15+fmod(i*29.0,95)
			draw_line(Vector2(x,y),Vector2(x+35+sin(i)*22,y),Color(0.7,0.85,0.92,0.09),1,true)
	if theme_id == 0:
		for x in [0,65,150,1450,1530,1600]:
			draw_tree(Vector2(x,698),0.8+0.2*sin(x),Color("122b36"))
	if theme_id == 1:
		for x in range(0,1600,48):
			if x>260 and x<1350: continue
			var h = 80+sin(x*0.14)*35
			draw_line(Vector2(x,701),Vector2(x,701-h),Color("102a34"),5,true)
			for k in range(3):
				var y = 701-h+k*20
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x-22-k*7,y+40),Vector2(x+22+k*7,y+40)]),Color("15323b"))
	if theme_id == 2:
		for i in range(16):
			var x = 55+i*101+sin(t*0.25+i)*9
			var y = 260+fposmod(i*79.0-t*6,330)
			var size_value = 20+fposmod(i*7.0,18)
			glow(Vector2(x,y),size_value,Color("ffc386"))
			draw_set_transform(Vector2(x,y),sin(t*0.6+i)*0.06)
			sprite("lantern",Rect2(-size_value/2,-size_value*0.65,size_value,size_value*1.3))
			draw_set_transform(Vector2.ZERO)
		for segment in range(80):
			var x = segment*20.0
			var y = 165+sin(x/1600*PI)*65
			draw_line(Vector2(x,y),Vector2(x+20,165+sin((x+20)/1600*PI)*65),Color("a78883"),1,true)
			if segment%4==0:
				glow(Vector2(x,y+9),12,Color("ffcc83"))
				draw_circle(Vector2(x,y+9),3,Color("ffe6ab"))
	if theme_id == 3:
		for x in [72,1500]:
			var p = Vector2(x,690)
			draw_line(p,p+Vector2(20,-170),Color("323148"),12,true)
			for i in range(7):
				var points = PackedVector2Array()
				for k in range(15):
					var f = float(k)/14
					points.append(p+Vector2(20,-170)+Vector2((i-3)*33*f,-sin(f*PI)*40+f*f*40))
				draw_polyline(points,Color("36364d"),5,true)

func draw_tree(p: Vector2, scale_value: float, color: Color):
	draw_line(p,p+Vector2(0,-155)*scale_value,color,13*scale_value,true)
	for i in range(7):
		var offset = Vector2(sin(i*2.4)*55,-125-cos(i*1.7)*40)*scale_value
		draw_circle(p+offset,48*scale_value,color)

func draw_foreground():
	var t = 0.0 if gentle else elapsed
	var ground = Color("102b31") if theme_id<2 else Color("332e43")
	draw_colored_polygon(PackedVector2Array([Vector2(0,707),Vector2(450,734),Vector2(1050,726),Vector2(1600,702),Vector2(1600,900),Vector2(0,900)]),ground)
	for i in range(130):
		var x = i*12.4
		if x>310 and x<1300: continue
		var h = 28+fposmod(i*39.7,110)
		var lean = sin(i*4.7)*28+sin(t*0.4+i)*4
		draw_colored_polygon(PackedVector2Array([Vector2(x-5,910),Vector2(x+lean,910-h),Vector2(x+7,910)]),Color("102b36") if i%2==0 else Color("183d45"))
	for i in range(24):
		var x = fposmod(i*137.3,1600)
		if x>280 and x<1340: continue
		var y = 832+fposmod(i*27.0,90)
		var h = 55+fposmod(i*31.0,55)
		draw_set_transform(Vector2(x,y),sin(t*0.7+i)*0.035)
		sprite("blossom",Rect2(-h*0.4,-h,h*0.8,h))
		draw_set_transform(Vector2.ZERO)
		glow(Vector2(x,y-h*0.7),12,Color(COLORS[i%5],0.3))
	# A softly lit stone path anchors the horizontal movement lane.
	for y in range(749,803,2):
		draw_rect(Rect2(260,y,1080,2),Color(0.6,0.65,0.7,0.035*sin((y-749)/54.0*PI)))
	for x in range(0,1600,18):
		var h = 7+sin(x*0.8)*5
		var sway = sin(t*0.9+x)*2
		draw_line(Vector2(x,740),Vector2(x-3+sway,728-h),Color("36575b") if theme_id<2 else Color("635065"),1.5,true)
	for i in range(52):
		var x = fmod(i*137.7,1600)
		if x>260 and x<1340: continue
		var y = 766+fmod(i*37.0,120)
		var p = Vector2(x,y)
		var flower = COLORS[i%COLORS.size()].lerp(Color("a0b5be"),0.35)
		draw_line(p,p+Vector2(2,-14),Color("4c7270"),1.5,true)
		for k in range(5): draw_circle(p+Vector2(2,-16)+Vector2.from_angle(k*TAU/5)*3,2.5,Color(flower,0.65))
		draw_circle(p+Vector2(2,-16),1.5,Color("ffe1a1"))
	for i in range(25):
		var p = Vector2(fmod(i*173.1,1600)+sin(t*0.3+i)*15,580+fmod(i*43.0,145)+sin(t*0.5+i*2)*9)
		var alpha = 0.25+0.25*sin(t*0.7+i)
		glow(p,8,Color(0.8,1,0.65,alpha))
		draw_circle(p,1.4,Color(0.9,1,0.7,alpha))
	# Session medallions fill gradually without distracting from the target.
	for i in range(12):
		var p = Vector2(345+i*82,814)
		var earned = i<garden_lights.size()
		var growth = minf(garden_lights[i].age/0.8,1.0) if earned else 0.0
		draw_circle(p,5,Color(0.4,0.6,0.55,0.3))
		if earned:
			var color: Color = garden_lights[i].color
			glow(p+Vector2(0,-12),18*growth,Color(color,0.6))
			draw_set_transform(p,0,Vector2.ONE*(0.3+growth*0.7))
			sprite("blossom",Rect2(-13,-34,26,34))
			draw_set_transform(Vector2.ZERO)
	for i in range(12):
		var p = Vector2(682+i*21,61)
		draw_circle(p,4,Color("f9d48b") if i<count else Color(0.7,0.8,0.9,0.17))
		if i<count: glow(p,9,Color(1,0.8,0.4,0.35))

func lantern_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color("eebb75")
	s.corner_radius_top_left = 5
	s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5
	s.corner_radius_bottom_right = 5
	return s

func draw_firework(p: Vector2, lit_kind: int = -1):
	var asset = ["rocket","fountain","wheel","flower"][kind if lit_kind < 0 else lit_kind]
	var bob = 0.0 if gentle else sin(elapsed*2)*1.5
	sprite(asset,Rect2(p+Vector2(-42,-75+bob),Vector2(84,98)))
	if charge>0 and lit_kind < 0:
		var progress = clampf(charge/0.85,0,1)
		var fuse_start = p+Vector2(30,-25)
		var fuse_end = p+Vector2(7,-44)
		var fuse = fuse_start.lerp(fuse_end,progress)
		draw_line(fuse_start,fuse_end,Color("a28b6a"),2,true)
		draw_line(fuse_start,fuse,Color("ffda7b"),3,true)
		glow(fuse,9,Color("ffdc87"))
		for i in range(5):
			var a = elapsed*15+i*TAU/5
			draw_line(fuse,fuse+Vector2.from_angle(a)*(5+charge*6),Color("ffe4a4"),1,true)

func sprite(asset: String, rect: Rect2):
	if hd_sprites.has(asset): draw_texture_rect(hd_sprites[asset],rect,false)

func draw_reactive_light():
	for light in smoke:
		var strength = sin(clampf(light.age/3.4,0,1)*PI)*0.16
		if gentle: strength *= 0.35
		var color: Color = light.color
		# Broad, slow illumination over the scenery, away from interface text.
		if halo: draw_texture_rect(halo,Rect2(light.p.x-500,440,1000,350),false,Color(color,strength))
		for x in [90,230,1370,1510]:
			glow(Vector2(x,666),80,Color(color,strength*0.7))
		for i in range(garden_lights.size()):
			glow(Vector2(345+i*82,799),23,Color(color,strength))
		glow(Vector2(player_x,773),42,Color(color,strength))
		if theme_id in [1,3]:
			var water_y = 590 if theme_id==1 else 610
			for i in range(35):
				var y = water_y+i*3.2
				var width = (10+i*2.4)*sin(light.age*0.5+0.4)
				var x = light.p.x+sin(i*1.5+(0 if gentle else elapsed)*2)*11
				draw_line(Vector2(x-width,y),Vector2(x+width,y),Color(color,strength*1.8*(1-i/40.0)),1.5,true)
	# Rocket reflections travel with the launch.
	if theme_id in [1,3]:
		for rocket in rockets:
			for i in range(12):
				var x = rocket.p.x+sin(i*1.8+elapsed)*5
				var y = 635+i*4
				draw_line(Vector2(x-5-i,y),Vector2(x+5+i,y),Color(rocket.color,0.12),1.3,true)

func draw_garden_lanterns():
	for i in range(12):
		var x = 380+i*76
		var y = 158+sin(float(i)/11*PI)*25
		if i<11:
			var next_y = 158+sin(float(i+1)/11*PI)*25
			draw_line(Vector2(x,y),Vector2(x+76,next_y),Color(0.6,0.65,0.75,0.18),1,true)
		var lit = i<count
		draw_line(Vector2(x,y),Vector2(x,y+8),Color(0.65,0.7,0.8,0.3),1,true)
		draw_circle(Vector2(x,y+11),3,Color("ffe6a5") if lit else Color("3a4656"))
		if lit: glow(Vector2(x,y+11),13,Color("ffc879"))
	for i in range(count/3):
		var x = 320+i*310+sin((0 if gentle else elapsed)*0.2+i)*15
		var y = 545-i*32-sin((0 if gentle else elapsed)*0.17+i)*12
		glow(Vector2(x,y),24,Color(1,0.8,0.5,0.45))
		sprite("lantern",Rect2(x-10,y-15,20,30))

func draw_companion():
	var flap = 0.5 if gentle else 0.5+0.5*sin(elapsed*17)
	glow(companion,21,Color(0.8,1,0.55,0.55))
	for side_value in [-1,1]:
		draw_set_transform(companion,side_value*(0.3+flap*0.5),Vector2(1,0.65))
		draw_circle(Vector2(side_value*9,-7),8,Color(0.8,0.95,1,0.45))
		draw_set_transform(Vector2.ZERO)
	draw_circle(companion+Vector2(0,3),7,Color("e2f796"))
	draw_circle(companion+Vector2(0,-5),6,Color("5e6977"))
	var look = Vector2(0,-1) if not rockets.is_empty() else Vector2(signf(target_x-player_x),0)
	for side_value in [-1,1]:
		draw_circle(companion+Vector2(side_value*2.5,-6),2,Color.WHITE)
		draw_circle(companion+Vector2(side_value*2.5,-6)+look*0.7,0.9,Color("1a2436"))
	if companion_joy>0 and not gentle:
		for i in range(4):
			var p = companion+Vector2.from_angle(elapsed*2+i*PI/2)*22
			draw_circle(p,1.3,Color("ffeaa4"))

func draw_surprises():
	for surprise in surprises:
		var alpha = sin(surprise.age/4*PI)*0.65
		var p: Vector2 = surprise.p+Vector2(sin(surprise.age)*35,-surprise.age*14 if not gentle else 0)
		if surprise.butterfly:
			var wing = 0.65 if gentle else 0.55+0.25*sin(surprise.age*7)
			for side_value in [-1,1]:
				draw_set_transform(p,side_value*0.3,Vector2(wing,1))
				draw_circle(Vector2(side_value*14,-6),14,Color(surprise.color,alpha))
				draw_circle(Vector2(side_value*10,10),9,Color("ffe7ab")*Color(1,1,1,alpha))
				draw_set_transform(Vector2.ZERO)
			draw_line(p+Vector2(0,-10),p+Vector2(0,15),Color(1,0.95,0.7,alpha),2,true)
		else:
			var points = PackedVector2Array()
			for i in range(6): points.append(p+Vector2((i-2.5)*24,sin(i*2)*22))
			draw_polyline(points,Color(0.7,0.85,1,alpha*0.6),1,true)
			for point in points:
				glow(point,8,Color(0.8,0.9,1,alpha))
				draw_circle(point,2,Color(1,1,1,alpha))



