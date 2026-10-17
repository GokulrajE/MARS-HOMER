extends RefCounted
## Small particle / sprite-animation engine shared by the native games.
## Effects live in game space (1600 x 900) and are drawn by the game's own _draw.
const DIR = "res://assets/art/"
static var cache: Dictionary = {}
var list: Array = []

static func tex(name: String) -> Texture2D:
	if not cache.has(name):
		var path = DIR + name + (".jpg" if name in ["meadow", "valley", "table"] else ".png")
		cache[name] = load(path)
	return cache[name]

func clear() -> void:
	list.clear()

func add(kind: String, pos: Vector2, data: Dictionary = {}) -> void:
	var item = {"kind": kind, "pos": pos, "t": 0.0, "life": 0.8}
	item.merge(data, true)
	list.append(item)

## Positive feedback: ring, stars and a rising score popup.
func celebrate(pos: Vector2, text: String = "+1", color: Color = Color("ffe27a")) -> void:
	add("ring", pos, {"life": 0.55, "radius": 90.0, "color": color})
	add("popup", pos + Vector2(0, -50), {"text": text, "color": color, "life": 1.0})
	for i in 12:
		var angle = TAU * i / 12.0 + randf() * 0.4
		add("spark", pos, {"vel": Vector2.from_angle(angle) * randf_range(180, 380), "life": randf_range(0.5, 0.9), "size": randf_range(18, 34), "color": color, "gravity": 260.0})

## Negative feedback: a soft grey puff and a "miss" popup.
func miss(pos: Vector2, text: String = "Miss") -> void:
	add("puff", pos, {"life": 0.7, "size": 120.0})
	add("popup", pos + Vector2(0, -40), {"text": text, "color": Color("ff9a8a"), "life": 0.9})

func confetti(pos: Vector2, count: int = 24) -> void:
	var palette = [Color("ff7a5c"), Color("5cf2c6"), Color("38bdf8"), Color("a98bff"), Color("ff8ccf")]
	for i in count:
		add("confetti", pos, {"vel": Vector2(randf_range(-260, 260), randf_range(-520, -200)), "life": randf_range(0.9, 1.5), "color": palette[i % palette.size()], "spin": randf_range(-9, 9), "gravity": 900.0})

func update(delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var item = list[i]
		item.t += delta
		if item.has("vel"):
			item.pos += item.vel * delta
			if item.has("gravity"): item.vel.y += item.gravity * delta
		if item.t >= item.life: list.remove_at(i)

func draw(canvas: CanvasItem, layer: String = "") -> void:
	for item in list:
		var u = clampf(item.t / item.life, 0, 1)
		var kind: String = item.kind
		if layer != "" and item.get("layer", "front") != layer: continue
		if kind.begins_with("space_"):
			preload("res://core/space_effects.gd").draw(canvas,item,u)
			continue
		match kind:
			"explosion":
				var frame = mini(int(u * 14), 13)
				var sheet = tex("explosion")
				var size = item.get("size", 220.0)
				canvas.draw_texture_rect_region(sheet, Rect2(item.pos - Vector2(size, size) / 2, Vector2(size, size)), Rect2((frame % 4) * 128, (frame / 4) * 128, 128, 128))
			"spark":
				var s = item.size * (1.0 - u)
				var c: Color = item.color
				c.a = 1.0 - u
				canvas.draw_texture_rect(tex("spark"), Rect2(item.pos - Vector2(s, s) / 2, Vector2(s, s)), false, c)
			"ring":
				var c2: Color = item.color
				c2.a = (1.0 - u) * 0.8
				canvas.draw_arc(item.pos, 10 + item.radius * ease(u, 0.4), 0, TAU, 48, c2, 6.0 * (1.0 - u) + 1)
			"popup":
				var c3: Color = item.color
				c3.a = 1.0 - maxf(0, u - 0.6) / 0.4
				var font = preload("res://core/ui_theme.gd").DISPLAY
				var rise = Vector2(0, -70 * ease(u, 0.5))
				canvas.draw_string_outline(font, item.pos + rise - Vector2(260, 0), item.text, HORIZONTAL_ALIGNMENT_CENTER, 520, 46, 10, Color(0, 0, 0, c3.a * 0.7))
				canvas.draw_string(font, item.pos + rise - Vector2(260, 0), item.text, HORIZONTAL_ALIGNMENT_CENTER, 520, 46, c3)
			"puff":
				var size2 = item.size * (0.6 + u)
				canvas.draw_texture_rect(tex("puff"), Rect2(item.pos - Vector2(size2, size2) / 2, Vector2(size2, size2)), false, Color(1, 1, 1, 0.8 * (1.0 - u)))
			"confetti":
				var c4: Color = item.color
				c4.a = 1.0 - maxf(0, u - 0.7) / 0.3
				canvas.draw_set_transform(item.pos, item.spin * item.t, Vector2.ONE)
				canvas.draw_rect(Rect2(-7, -4, 14, 8), c4)
				canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"shatter":
				var size3 = item.size * (0.7 + 0.6 * ease(u, 0.5))
				canvas.draw_texture_rect(tex("asteroid_shatter"), Rect2(item.pos - Vector2(size3, size3) / 2, Vector2(size3, size3)), false, Color(1, 1, 1, 1.0 - u))
			"bubble":
				var c5 = Color(0.8, 0.95, 1.0, 0.7 * (1.0 - u))
				canvas.draw_arc(item.pos, item.size * (0.7 + u * 0.4), 0, TAU, 20, c5, 2.5)
				canvas.draw_circle(item.pos + Vector2(-item.size * 0.25, -item.size * 0.25), item.size * 0.14, Color(1, 1, 1, 0.8 * (1.0 - u)))
			"flash":
				var c6: Color = item.color
				c6.a = 0.45 * (1.0 - u)
				canvas.draw_rect(Rect2(0, 0, 1600, 900), c6, false, 28)
			"star":
				var reveal=1-pow(1-clampf(u/.22,0,1),3)
				var fade=1-smoothstep(.6,1,u)
				preload("res://core/reward_star.gd").draw(canvas,item.pos+Vector2(0,-22*u),27*reveal,fade,sin(u*PI)*.16)
