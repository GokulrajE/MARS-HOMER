extends RefCounted
## Scenery, sprites and animation for the native games (everything except Fish
## Rescue, Bubble Sparkle and Fireworks, which ship their own art). Only
## presentation lives here; scoring and timing stay in legacy_game.gd.
const GameFx = preload("res://core/game_fx.gd")
const Cycle=preload("res://core/visual_cycle.gd")
const Gates=preload("res://core/gate_variants.gd")
const BheemArt = preload("res://core/bheem_art.gd")
const Targets = preload("res://core/flight_targets.gd")
const ReefVisitors = preload("res://core/reef_visitors.gd")
const BALLS = ["orange", "green", "blue", "purple"]
const BALL_COLORS = [Color("ff9a3c"), Color("7ed957"), Color("49b6ff"), Color("b07cff")]
static var pill: StyleBoxFlat
static var dim_pill: StyleBoxFlat

static func tex(name: String) -> Texture2D:
	return GameFx.tex(name)

static func sprite(g: CanvasItem, texture: Texture2D, center: Vector2, width: float, rotation: float = 0.0, tint: Color = Color.WHITE, flip_x: bool = false, anchor: Vector2 = Vector2(0.5, 0.5)) -> void:
	var size = texture.get_size()
	var height = width * size.y / size.x
	g.draw_set_transform(center, rotation, Vector2(-1 if flip_x else 1, 1))
	g.draw_texture_rect(texture, Rect2(-Vector2(width * anchor.x, height * anchor.y), Vector2(width, height)), false, tint)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func gradient(g: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	g.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))

static func glow(g: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	for i in 6:
		var c = color
		c.a = color.a * (0.10 + 0.05 * i)
		g.draw_circle(pos, radius * (1.0 - i * 0.15), c)

static func shadow(g: CanvasItem, pos: Vector2, width: float) -> void:
	g.draw_set_transform(pos, 0, Vector2(1, 0.28))
	g.draw_circle(Vector2.ZERO, width / 2, Color(0, 0, 0, 0.28))
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## Tile a texture over the 1600 x 900 field, scrolling by `offset`.
static func tile(g: CanvasItem, texture: Texture2D, scale: Vector2, offset: Vector2, tint: Color = Color.WHITE, y_top: float = 0.0, y_bottom: float = 900.0) -> void:
	var size = texture.get_size() * scale
	var x = -fposmod(offset.x, size.x)
	while x < 1600:
		var y = y_top - fposmod(offset.y, size.y)
		while y < y_bottom:
			g.draw_texture_rect(texture, Rect2(Vector2(x, y), size), false, tint)
			y += size.y
		x += size.x

## Soft cartoon cloud from overlapping circles with a flat base.
static func cloud(g: CanvasItem, pos: Vector2, scale: float, tint: Color = Color(1, 1, 1)) -> void:
	# Opaque so overlapping circles read as one soft shape.
	for k in [[-52, 8, 30], [-12, -10, 42], [34, 2, 36], [72, 14, 26], [-82, 16, 22]]:
		g.draw_circle(pos + Vector2(k[0], k[1]) * scale, k[2] * scale, tint)
	g.draw_rect(Rect2(pos + Vector2(-84, 14) * scale, Vector2(176, 24) * scale), tint)
	g.draw_circle(pos + Vector2(-84, 26) * scale, 12 * scale, tint)
	g.draw_circle(pos + Vector2(92, 26) * scale, 12 * scale, tint)

static func ease_back(t: float) -> float:
	t = clampf(t, 0, 1)
	var c = 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3) + c * pow(t - 1.0, 2)

# ------------------------------------------------------------------ frame

static func tick(g: Node2D, delta: float) -> void:
	g.fx.update(delta)
	g.pong_impact=maxf(0,g.pong_impact-delta)
	g.wipe_progress=lerpf(g.wipe_progress,float(g.wipe_erased)/maxf(1,g.wipe_total),1-exp(-9*delta))
	var velocity = (g.player - g.previous) / maxf(delta, 0.0001)
	if absf(velocity.x) > 18.0: g.facing_goal = -1.0 if velocity.x < 0 else 1.0
	g.facing = move_toward(g.facing, g.facing_goal, delta * 12.0)
	g.visual_tilt = lerpf(g.visual_tilt, clampf(velocity.x * 0.00055, -0.28, 0.28), 1.0 - exp(-12.0 * delta))
	g.pop_clock += delta
	if Trial.game == "PP":
		g.opp_y = lerpf(g.opp_y, g.target.y, 1.0 - exp(-9.0 * delta))
		if g.trail.is_empty() or g.trail[-1].distance_to(g.target) > 9.0:
			g.trail.append(g.target)
			if g.trail.size() > 24: g.trail.pop_front()
		elif not (Trial.target_open or g.pong_returning) and not g.trail.is_empty(): g.trail.pop_front()
	if Trial.game in ["TT","CB"]:
		g.swim_tilt = lerpf(g.swim_tilt, clampf(velocity.y * 0.00065,-0.35,0.35),1.0-exp(-10.0*delta))
	if g.catch_pose != 0: g.catch_pose = move_toward(g.catch_pose,0.0,delta)

static func on_resolve(g: Node2D, success: bool) -> void:
	var fx: RefCounted = g.fx
	var at: Vector2 = g.target
	match Trial.game:
		"SS":
			if success:
				preload("res://core/space_effects.gd").burst(fx,at,g.visual_variant)
			else:
				fx.add("flash", Vector2.ZERO, {"color": Color("ff4a3d"), "life": 0.5})
				fx.miss(Vector2(clampf(at.x, 80, 1520), 800), "Missed")
		"MC":
			if success:
				fx.confetti(g.player + Vector2(0, -20), 28)
				fx.celebrate(g.player + Vector2(0, -60), "Caught!", BALL_COLORS[g.color_index])
				g.match_caught_color = g.color_index
				g.catch_pose = 0.5
			else:
				fx.miss(g.player + Vector2(0, -40), "Wrong colour" if g.target_hit_wrong else "Missed")
		"PP":
			if not success: fx.miss(Vector2(clampf(at.x, 90, 1510), at.y), "Missed")
		"TT", "CB":
			g.catch_pose = 1.0 if success else -0.7
			if success:
				fx.add("ring",at,{"life":0.8,"radius":145.0,"color":Color("91fff0")})
				for k in 18:
					fx.add("spark",at,{"life":0.8,"vel":Vector2.from_angle(k*TAU/18)*randf_range(90,220),"size":18.0,"color":Color("ffe38b")})
				fx.add("star", at, {"life": 0.9})
				fx.add("star", at + Vector2(-60, -50), {"life": 0.8})
				fx.add("star", at + Vector2(60, 50), {"life": 0.8})
				fx.celebrate(g.player + Vector2(40, -60), Targets.INFO[g.character_data.target].cheer if Trial.game=="CB" else "Through!")
			else:
				fx.add("puff", g.player, {"life": 0.7, "size": 140.0})
				fx.miss(g.player + Vector2(0, -60), "Bumped")
		"DC":
			if success:
				for k in 3: fx.add("star", at + Vector2.from_angle(k * TAU / 3) * 48, {"life": 0.9})
				fx.add("ring", at, {"life": 0.7, "radius": 130.0, "color": Color("7ff3ff")})
				fx.celebrate(at, "+1", Color("ffe27a"))
				g.catch_pose = 0.7
			else: fx.miss(at, "Too slow")
		"TW":
			if success:
				for k in 6: fx.add("star", at + Vector2.from_angle(k * TAU / 6) * randf_range(60, 120), {"life": randf_range(0.7, 1.1)})
				fx.confetti(at, 18)
				fx.celebrate(at + Vector2(0, -60), "Sparkling clean!", Color("bff6ff"))
			else: fx.miss(at, "Missed")

# ------------------------------------------------------------------ shell

static func banner(g: CanvasItem, text: String) -> void:
	if pill == null:
		pill = StyleBoxFlat.new()
		pill.bg_color = Color(0.03, 0.07, 0.12, 0.72)
		pill.set_corner_radius_all(26)
		pill.border_color = Color(1, 1, 1, 0.16)
		pill.set_border_width_all(1)
	var font = ThemeDB.fallback_font
	var size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	# Sits to the right of the compact HUD, which owns the top-left corner.
	var rect = Rect2(700, 14, size.x + 56, 50)
	g.draw_style_box(pill, rect)
	g.draw_string(font, Vector2(rect.position.x + 28, rect.position.y + 35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)

static func pause_overlay(g: CanvasItem) -> void:
	g.draw_rect(Rect2(0, 0, 1600, 900), Color(0.02, 0.04, 0.08, 0.62))
	var font = ThemeDB.fallback_font
	g.draw_string(font, Vector2(0, 430), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, 1600, 84, Color.WHITE)
	g.draw_string(font, Vector2(0, 490), "Tap the MARS button to resume  •  hold it to finish & save", HORIZONTAL_ALIGNMENT_CENTER, 1600, 28, Color("b6c4d6"))

static func instruction(game: String) -> String:
	return {"SS": "Move left / right  •  keep still to fire", "MC": "Catch the ball that matches your basket", "PP": "Move up / down to return the ball", "CB": "Fly up / down through the glowing laddoo passage", "TT": "Swim up / down through the reef opening", "DC": "Reach the diamond and hold for one second", "TW": "Wipe across the whole stain"}[game]

# ------------------------------------------------------------------ games

static func draw(g: Node2D) -> void:
	match Trial.game:
		"SS": draw_space(g)
		"MC": draw_match(g)
		"PP": draw_pong(g)
		"CB": BheemArt.draw(g)
		"TT": draw_tuktuk(g)
		"DC": draw_diamond(g)
		"TW": draw_table(g)
	g.fx.draw(g)
	if Trial.game=="PP": easy_chip(g)
	if g.paused: pause_overlay(g)

static func draw_space(g: Node2D) -> void:
	var space_look = Cycle.look()
	gradient(g, Rect2(0, 0, 1600, 900), [Color("0b0720"), Color("04161b"), Color("1b0a12")][space_look], [Color("261046"), Color("0c3b3f"), Color("45182c")][space_look])
	var drift = Vector2(sin(g.clock * 0.05) * 90.0, cos(g.clock * 0.04) * 60.0)
	g.draw_texture_rect(tex("nebula"), Rect2(Vector2(-120, -480) + drift, Vector2(1840, 1840)), false, [Color(1, 1, 1, 0.9), Color(0.45, 1.0, 0.85, 0.9), Color(1.0, 0.55, 0.45, 0.9)][space_look])
	tile(g, tex("stars_medium"), Vector2(1.6, 1.6), Vector2(0, -g.clock * 40), Color(1, 1, 1, 0.8))
	tile(g, tex("stars_big"), Vector2(1.6, 1.6), Vector2(0, -g.clock * 75), Color(1, 1, 1, 0.9))
	if Trial.target_open:
		var spin = g.clock * 0.9
		glow(g, g.target, 70, Color("ff8a4a", 0.5))
		if g.visual_variant==0: sprite(g,g.artwork.asteroid,g.target,110,spin)
		elif g.visual_variant==1:
			var points=PackedVector2Array()
			for i in 6: points.append(g.target+Vector2.from_angle(i*TAU/6+spin)*48)
			g.draw_colored_polygon(points,Color("83c8e7"))
			for point in points: g.draw_line(g.target,point,Color("e7faff"),2,true)
		else:
			g.draw_circle(g.target,45,Color("a87951"))
			for i in 5: g.draw_circle(g.target+Vector2.from_angle(i*2.4+spin)*25,8,Color("644b43"))
	for bullet in g.bullets:
		glow(g, bullet, 20, Color("ff4a4a", 0.6))
		sprite(g, tex("laser"), bullet + Vector2(0, 14), 46)
	var tilt = g.visual_tilt
	var flame = 34.0 + sin(g.clock * 40.0) * 8.0 + absf(tilt) * 30
	var base = g.player + Vector2(0, 52)
	g.draw_colored_polygon(PackedVector2Array([base + Vector2(-16, 0), base + Vector2(16, 0), base + Vector2(0, flame * 1.9)]), Color("ff7a2e", 0.85))
	g.draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 0), base + Vector2(9, 0), base + Vector2(0, flame * 1.25)]), Color("ffe48a", 0.95))
	glow(g, g.player + Vector2(0, 40), 60, Color("5ac8ff", 0.35))
	sprite(g, tex("ship_blue"), g.player, 124, tilt)

static func draw_match(g: Node2D) -> void:
	preload("res://core/match_art.gd").draw(g)

static func draw_pong(g: Node2D) -> void:
	gradient(g, Rect2(0, 0, 1600, 900), Cycle.palette(Color("071c2b"),Color("2a1a2c"),Color("050d18")), Cycle.palette(Color("0d3b4a"),Color("4a2c3a"),Color("0a2230")))
	var table = Rect2(70, 150, 1460, 660)
	var style = StyleBoxFlat.new()
	style.bg_color = Cycle.palette(Color("0f5a63"),Color("675369"),Color("153849"))
	style.set_corner_radius_all(30)
	style.border_color = Color("c9f6ef")
	style.set_border_width_all(6)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 24
	g.draw_style_box(style, table)
	g.draw_rect(Rect2(table.position.x + 8, table.position.y + 8, table.size.x - 16, table.size.y / 2.0), Color(1, 1, 1, 0.04))
	for y in range(int(table.position.y) + 14, int(table.end.y) - 20, 38):
		g.draw_rect(Rect2(799, y, 4, 20), Color(1, 1, 1, 0.45))
	g.draw_arc(Vector2(800, 480), 90, 0, TAU, 48, Color(1, 1, 1, 0.25), 4)
	# A short tapered ribbon, never a row of overlapping ball silhouettes.
	if Trial.target_open or g.pong_returning:
		ball_tail(g)
	if g.pong_easy: easy_path(g)
	if Trial.target_open or g.pong_returning:
		shadow(g, g.target + Vector2(10, 34), 50)
		glow(g, g.target, 48, Color("bff6ff", 0.55))
		var squash=sin(g.pong_impact/0.18*PI)*0.22
		g.draw_set_transform(g.target,g.pong_velocity.angle(),Vector2(1-squash,1+squash))
		g.draw_circle(Vector2.ZERO,24,Color("e3fcff"))
		g.draw_arc(Vector2.ZERO,17,g.clock*3,g.clock*3+PI,24,Color("82cbd5"),3,true)
		g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		g.draw_circle(g.target + Vector2(-7, -7), 8, Color(1, 1, 1, 0.9))
		if g.visual_variant==1: g.draw_arc(g.target,17,0,TAU,24,Color("429ba9"),4,true)
		elif g.visual_variant==2:
			for i in 4: g.draw_circle(g.target+Vector2.from_angle(i*TAU/4)*12,3,Color("6a76b0"))
	# A full-height rebound wall, rather than a moving opponent.
	var wall=StyleBoxFlat.new()
	wall.bg_color=Color("277784")
	wall.border_color=Color("8ef3ec")
	wall.set_border_width_all(3)
	wall.set_corner_radius_all(10)
	g.draw_style_box(wall,Rect2(1484,160,24,640))
	for y in range(180,790,38): g.draw_line(Vector2(1488,y),Vector2(1504,y+16),Color(1,1,1,.3),2,true)
	paddle(g, Vector2(120, g.player.y), Color("64f0d0"))

## Comet tail: one smooth tapered ribbon that fades to nothing, built from the ball's recent path.
static func ball_tail(g: Node2D) -> void:
	var n = g.trail.size()
	if n < 3: return
	var shape = PackedVector2Array()
	var shape_colors = PackedColorArray()
	var back = PackedVector2Array()
	for i in n:
		var u = float(i) / (n - 1)
		var direction: Vector2 = g.trail[mini(i + 1, n - 1)] - g.trail[maxi(i - 1, 0)]
		var normal = direction.orthogonal().normalized() if direction.length() > 0.01 else Vector2.UP
		var half = 1.0 + 15.0 * u
		shape.append(g.trail[i] + normal * half)
		back.append(g.trail[i] - normal * half)
	for i in n: shape_colors.append(Color(0.55, 0.93, 1.0, 0.38 * pow(float(i) / (n - 1), 2)))
	for i in range(n - 1, -1, -1):
		shape.append(back[i])
		shape_colors.append(Color(0.55, 0.93, 1.0, 0.38 * pow(float(i) / (n - 1), 2)))
	if Geometry2D.triangulate_polygon(shape).size() > 0: g.draw_polygon(shape, shape_colors)
	# A thin bright core along the newest part of the path.
	for i in range(maxi(1, n - 7), n):
		var u2 = float(i - (n - 7)) / 7.0
		g.draw_line(g.trail[i - 1], g.trail[i], Color(1, 1, 1, 0.55 * u2), 1.0 + 3.0 * u2, true)

## Dashed guide to where the ball will arrive, with a landing marker on the paddle line.
static func easy_path(g: Node2D) -> void:
	var path: PackedVector2Array = g.predicted_path()
	if path.size() < 2: return
	var offset = fposmod(g.clock * 90.0, 28.0)
	for i in range(1, path.size()):
		var a = path[i - 1]
		var b = path[i]
		var length = a.distance_to(b)
		var direction = (b - a) / maxf(length, 0.001)
		var d = -offset if i == 1 else 0.0
		while d < length:
			var start = maxf(d, 0.0)
			var end = minf(d + 14.0, length)
			if end > start: g.draw_line(a + direction * start, a + direction * end, Color(1, 0.92, 0.55, 0.55), 3.0, true)
			d += 28.0
	var land = path[path.size() - 1]
	var pulse = 1.0 + sin(g.clock * 6.0) * 0.12
	g.draw_circle(land, 30 * pulse, Color(1, 0.9, 0.5, 0.12))
	g.draw_arc(land, 22 * pulse, 0, TAU, 40, Color(1, 0.92, 0.55, 0.9), 3.0, true)
	g.draw_line(land + Vector2(-9, 0), land + Vector2(9, 0), Color(1, 0.95, 0.7, 0.9), 2.0, true)
	g.draw_line(land + Vector2(0, -9), land + Vector2(0, 9), Color(1, 0.95, 0.7, 0.9), 2.0, true)

static func easy_chip(g: Node2D) -> void:
	var rect: Rect2 = g.EASY_CHIP
	var on: bool = g.pong_easy
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.17, 0.05, 0.78) if on else Color(0.03, 0.07, 0.12, 0.72)
	style.set_corner_radius_all(22)
	style.border_color = Color("ffe48b") if on else Color(1, 1, 1, 0.25)
	style.set_border_width_all(2 if on else 1)
	g.draw_style_box(style, rect)
	var knob = Vector2(rect.position.x + (rect.size.x - 28 if on else 28), rect.position.y + 22)
	g.draw_circle(knob, 10, Color("ffe48b") if on else Color(0.7, 0.75, 0.85))
	g.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + (22 if on else 50), rect.position.y + 29), "Easy mode: ON  (E)" if on else "Easy mode: off  (E)", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)

static func paddle(g: CanvasItem, center: Vector2, color: Color) -> void:
	var half=102 if Trial.game=="PP" and g.pong_easy else 62
	var rect = Rect2(center - Vector2(13, half), Vector2(26, half*2))
	glow(g, center, 90, Color(color, 0.25))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.border_color = color.lightened(0.55)
	style.set_border_width_all(3)
	g.draw_style_box(style, rect)
	g.draw_rect(Rect2(center.x - 4, center.y - 50, 5, 100), Color(1, 1, 1, 0.45))

static func reef_column(g: Node2D, x: float, edge: float, top: bool, kind:int=0) -> void:
	if Gates.draw(g,x,edge,top,kind): return
	var direction = -1.0 if top else 1.0
	var height = edge if top else 900.0-edge
	if height <= 0: return
	# Overlapping rounded boulders keep rock detail at a consistent scale.
	var count = maxi(1,ceili(height/85.0))
	for i in range(count-1,-1,-1):
		var near = maxf(0,i*85.0-10)
		var far = minf(height+20,(i+1)*85.0+15)
		far=maxf(far,near+44)
		var width = (62.0 if i==0 else 76.0)+sin(i*2.7+edge)*10
		var outline=[Vector2(-width+15,near),Vector2(width-18,near),Vector2(width,near+20),Vector2(width+4,far-18),Vector2(width-18,far),Vector2(-width+12,far),Vector2(-width-4,far-20),Vector2(-width,near+18)]
		var points=PackedVector2Array()
		var uv=PackedVector2Array()
		for v in outline:
			points.append(Vector2(x+v.x,edge+direction*v.y))
			uv.append(Vector2(.50+v.x/850.0,.14+fposmod(i*.171+edge*.0007,.58)+(v.y-near)/maxf(1,far-near)*.14))
		g.draw_polygon(points,PackedColorArray([Color(0.8,0.95,1)]),uv,tex("reef_column"))
		var border=points.duplicate()
		border.append(points[0])
		g.draw_polyline(border,Color("183e4b"),3,true)
		if i%2==1:
			for k in 3:
				var start=Vector2(x+width*.6,edge+direction*(near+40))
				var end=start+Vector2((k-1)*12,-direction*(17+k*6))
				g.draw_line(start,end,Color("b386b9"),6,true)
				g.draw_circle(end,3,Color("e1accb"))
	g.draw_line(Vector2(x-44,edge),Vector2(x+44,edge),Color("a0d7c3"),3,true)

static func draw_tuktuk(g: Node2D) -> void:
	var speed = 1360.0 / maxf(0.5, Trial.reach_time())
	if is_instance_valid(g.reef_water): g.reef_water.material.set_shader_parameter("swim_clock",g.clock)
	ReefVisitors.draw(g)
	for reef in g.passed_reefs:
		reef_column(g,reef.x,reef.y-72,true,reef.kind)
		reef_column(g,reef.x,reef.y+72,false,reef.kind)
	# Distant bubbles drift more slowly than the playable reef gate.
	for i in 28:
		var p = Vector2(fposmod(i*173.0-g.clock*speed*0.08,1660)-30, fposmod(i*127.0-g.clock*(12+i%5),940)-20)
		var r = 3.0 + i%5*1.5
		g.draw_circle(p,r,Color(0.5,0.9,1,0.07))
		g.draw_arc(p,r,0,TAU,20,Color(0.7,0.95,1,0.28),1.3,true)
		g.draw_circle(p+Vector2(-r*.3,-r*.4),r*.18,Color(1,1,1,0.65))
	if Trial.target_open:
		var gx: float = g.target.x
		var gy: float = g.target.y
		reef_column(g,gx,gy-72,true,g.visual_variant)
		reef_column(g,gx,gy+72,false,g.visual_variant)
		glow(g,Vector2(gx,gy),60,Color("38bdf8",0.22))
		# Small centered guide; both rock lips show the real opening clearly.
		for i in 3:
			var cx = gx - 22 + i*22
			g.draw_polyline(PackedVector2Array([Vector2(cx-5,gy-7),Vector2(cx+2,gy),Vector2(cx-5,gy+7)]),Color("a3f4e5",0.55+0.2*sin(g.clock*3-i)),2,true)
	var body = g.player + Vector2(0,sin(g.clock*5.0)*4.0)
	if is_instance_valid(g.swim_sprite):
		g.swim_sprite.position = body
		g.swim_sprite.rotation = g.swim_tilt + sin(g.clock*5.5)*0.035
		g.swim_sprite.scale = Vector2(1.0+sin(g.clock*9)*0.045,1.0-sin(g.clock*9)*0.035) * 180.0 / g.swim_sprite.texture.get_width()
		g.swim_sprite.material.set_shader_parameter("swim_clock",g.clock)
	# A separate paddling fin makes the swimming cycle readable at game scale.
	var fin_root = body + Vector2(8,17).rotated(g.swim_tilt)
	var flap = sin(g.clock*10.0)
	var fin = PackedVector2Array([fin_root,fin_root+Vector2(-25,8+flap*13),fin_root+Vector2(-15,25+flap*9),fin_root+Vector2(5,15)])
	g.draw_colored_polygon(fin,Color("f69732"))
	var fin_edge=fin.duplicate()
	fin_edge.append(fin[0])
	g.draw_polyline(fin_edge,Color("793b22"),2,true)
	for ray in 3: g.draw_line(fin_root,fin_root+Vector2(-20+ray*7,18+flap*10),Color("c66325"),1.2,true)
	# A short trail of exhaled bubbles follows the fish and freezes on pause.
	for i in 7:
		var t = fposmod(g.clock*0.7+i/7.0,1.0)
		var p = body + Vector2(-55-t*105,-t*28+sin(i+g.clock*2)*4)
		g.draw_arc(p,2+t*5,0,TAU,18,Color(0.75,0.96,1,(1-t)*0.6),1.4,true)

static func draw_diamond(g: Node2D) -> void:
	gradient(g, Rect2(0, 0, 1600, 900), Cycle.palette(Color("427a98"),Color("66406d"),Color("100a2e")), Cycle.palette(Color("617ca7"),Color("774c77"),Color("2f1559")))
	for i in 46:
		var p = Vector2(fposmod(i * 211.0, 1600.0), fposmod(i * 131.0 + g.clock * (6 + i % 5), 900.0))
		var twinkle = 0.25 + 0.5 * absf(sin(g.clock * 1.5 + i))
		g.draw_circle(p, 1.5 + (i % 3), Color(0.8, 0.85, 1.0, twinkle))
	if Trial.target_open:
		var born = ease_back(g.age / 0.45)
		var pulse = 1.0 + sin(g.clock * 5.0) * 0.06
		var size = 84.0 * born * pulse
		glow(g, g.target, 90, Color("7ff3ff", 0.32))
		sprite(g, tex("flare"), g.target, 190 * born, g.clock * 0.6, Color(1, 1, 1, 0.8))
		preload("res://core/gem_art.gd").draw(g,g.target,clampf(born,0,1.12)*(1+g.hold*.12),g.clock,g.visual_variant)
		preload("res://core/target_feedback.gd").draw(g,g.target,64,clampf(Trial.reach_time()+0.5-g.age,0,Trial.reach_time()),Trial.reach_time(),g.hold)
		if g.hold > 0:
			glow(g, g.target, 60 + 40 * g.hold, Color("ffe27a", 0.3))
	var frame = 1 if (g.hold > 0 or g.catch_pose > 0) else int(g.clock * 2.2) % 2
	shadow(g, g.player + Vector2(0, 46), 80)
	var character = tex("catcher_%d" % frame)
	var extent = Vector2(100, 100 * character.get_height() / float(character.get_width()))
	g.draw_set_transform(g.player + Vector2(0, sin(g.clock * 6.0) * 3.0), 0, Vector2(g.facing, 1))
	g.draw_texture_rect(character, Rect2(-extent / 2, extent), false)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func draw_table(g: Node2D) -> void:
	var table_look = Cycle.look()
	var table_tint = [Color.WHITE, Color(1.0, 0.9, 0.78), Color(0.8, 0.86, 1.0)][table_look]
	if table_look == 1:
		g.draw_set_transform(Vector2(1600, 0), 0, Vector2(-1, 1))
		g.draw_texture_rect(tex("table"), Rect2(0, 0, 1600, 900), false, table_tint)
		g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	elif table_look == 2:
		g.draw_texture_rect(tex("table"), Rect2(-240, -140, 2080, 1170), false, table_tint)
	else:
		g.draw_texture_rect(tex("table"), Rect2(0, 0, 1600, 900), false, table_tint)
	gradient(g, Rect2(0, 0, 1600, 900), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.32))
	g.draw_rect(Rect2(0, 0, 1600, 900), Color(0.1, 0.05, 0.0, 0.12))
	if g.wipe_texture != null and (Trial.target_open or g.fx.list.size() > 0):
		var stain_size = Vector2(g.wipe_image.get_size())
		var center = g.wipe_origin + stain_size / 2.0
		g.draw_set_transform(center, 0, Vector2(1, stain_size.y / stain_size.x))
		glow(g, Vector2.ZERO, stain_size.x * 0.62, Color(1, 1, 1, 0.14))
		g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		g.draw_texture(g.wipe_texture, g.wipe_origin)
		var percent = int(100.0 * g.wipe_erased / maxf(1, g.wipe_total))
		if Trial.target_open:
			# A slim progress bar under the stain replaces the ring, which no longer fits its shape.
			var bar = Rect2(g.wipe_origin.x, g.wipe_origin.y + stain_size.y + 22, stain_size.x, 10)
			var track=StyleBoxFlat.new()
			track.bg_color=Color(.01,.06,.09,.75)
			track.set_corner_radius_all(7)
			g.draw_style_box(track,bar.grow(3))
			var fill=track.duplicate()
			fill.bg_color=Color("60e6c5")
			if g.wipe_progress>0.001: g.draw_style_box(fill,Rect2(bar.position,Vector2(bar.size.x*g.wipe_progress,bar.size.y)))
			var tip=bar.position+Vector2(bar.size.x*g.wipe_progress,5)
			glow(g,tip,17,Color("a5ffeb",.4))
			g.draw_string(ThemeDB.fallback_font, bar.position + Vector2(0, 38), "%d%% clean" % percent, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 22, Color.WHITE)
	var swipe = clampf((g.player - g.previous).length() * 0.02, 0, 0.5)
	var direction = 1.0 if g.player.x >= g.previous.x else -1.0
	shadow(g, g.player + Vector2(10, 38), 110)
	sprite(g, tex("sponge"), g.player, 150, g.visual_tilt - 0.1)




