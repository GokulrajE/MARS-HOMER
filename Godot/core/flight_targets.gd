extends RefCounted
## One collectible per flight character, drawn in code so each pilot chases
## something of their own (Bheem's laddoo is no longer everyone's target).
const INFO = {
	"coin": {"cheer":"Golden catch!","hint":"golden coin"},
	"laddoo": {"cheer": "Laddoo!", "hint": "glowing laddoo"},
	"lotus": {"cheer": "Lotus!", "hint": "pink lotus"},
	"mango": {"cheer": "Mango!", "hint": "ripe mango"},
	"teddy": {"cheer": "Teddy!", "hint": "lost teddy"},
	"shades": {"cheer": "Style!", "hint": "golden shades"},
	"football": {"cheer": "Goal!", "hint": "bright football"}
}

static func ellipse(g: CanvasItem, p: Vector2, rx: float, ry: float, angle: float, color: Color) -> void:
	g.draw_set_transform(p, angle, Vector2(1, ry / maxf(0.001, rx)))
	g.draw_circle(Vector2.ZERO, rx, color)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func draw(g: CanvasItem, kind: String, p: Vector2, t: float, accent: Color) -> void:
	# Drawn about the origin and enlarged so every collectible reads clearly at play distance.
	g.draw_set_transform(p, 0, Vector2(1.7, 1.7))
	var o = Vector2.ZERO
	for ring in 5: g.draw_circle(o, 38 - ring * 5, Color(accent.r, accent.g, accent.b, 0.04 + ring * 0.015))
	match kind:
		"coin":
			var width=0.35+0.65*absf(cos(t*2.5))
			g.draw_set_transform(p,0,Vector2(1.7*width,1.7))
			g.draw_circle(Vector2.ZERO,24,Color("b36e17"))
			g.draw_circle(Vector2.ZERO,21,Color("ffd35a"))
			g.draw_arc(Vector2.ZERO,17,0,TAU,40,Color("fff1ab"),2,true)
			g.draw_string(ThemeDB.fallback_font,Vector2(-8,8),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("b87820"))
		"lotus": lotus(g, o, t)
		"mango": mango(g, o)
		"teddy": teddy(g, p, t)
		"shades": shades(g, o, t)
		"football": football(g, o, t)
		_: laddoo(g, o)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func laddoo(g: CanvasItem, p: Vector2) -> void:
	g.draw_circle(p, 20, Color("d48420"))
	g.draw_circle(p + Vector2(-2, -3), 17, Color("f5bc46"))
	for i in 18:
		g.draw_circle(p + Vector2.from_angle(i * 2.4) * sqrt(i / 18.0) * 15, 1.5, Color("ffe3a0"))

static func lotus(g: CanvasItem, p: Vector2, t: float) -> void:
	for layer in 2:
		var count = 8 if layer == 0 else 6
		for i in count:
			var angle = i * TAU / count + layer * 0.3 + sin(t * 1.2) * 0.05
			var tip = p + Vector2.from_angle(angle) * (24 if layer == 0 else 15)
			ellipse(g, (p + tip) / 2, 13 - layer * 3, 6 - layer, angle, Color("ff9ccc") if layer == 0 else Color("ffd0e6"))
	g.draw_circle(p, 7, Color("ffd45e"))
	g.draw_circle(p + Vector2(-2, -2), 3, Color("fff1a8"))

static func mango(g: CanvasItem, p: Vector2) -> void:
	ellipse(g, p + Vector2(0, 2), 19, 24, 0.5, Color("e58a1f"))
	ellipse(g, p + Vector2(-2, 0), 16, 21, 0.5, Color("ffc23d"))
	ellipse(g, p + Vector2(-7, -8), 4, 8, 0.5, Color(1, 1, 1, 0.5))
	g.draw_line(p + Vector2(7, -21), p + Vector2(10, -27), Color("5e7b2f"), 3, true)
	ellipse(g, p + Vector2(17, -25), 11, 5, -0.5, Color("4fa14a"))

static func teddy(g: CanvasItem, p: Vector2, t: float) -> void:
	var brown = Color("a56f3f")
	var tilt = sin(t * 2.0) * 0.1
	g.draw_set_transform(p, tilt, Vector2(1.7,1.7))
	g.draw_circle(Vector2(0, 14), 15, brown)
	g.draw_circle(Vector2(0, 16), 9, Color("d7aa75"))
	for side in [-1, 1]:
		g.draw_circle(Vector2(side * 14, -14), 8, brown)
		g.draw_circle(Vector2(side * 14, -14), 4, Color("d7aa75"))
		g.draw_circle(Vector2(side * 16, 3), 6, brown)
	g.draw_circle(Vector2(0, -3), 17, brown)
	g.draw_circle(Vector2(0, 2), 8, Color("d7aa75"))
	g.draw_circle(Vector2(-6, -7), 2.4, Color("2b1d17"))
	g.draw_circle(Vector2(6, -7), 2.4, Color("2b1d17"))
	g.draw_circle(Vector2(0, 0), 3, Color("2b1d17"))
	g.draw_line(Vector2(0, 3), Vector2(0, 6), Color("2b1d17"), 1.5, true)
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func shades(g: CanvasItem, p: Vector2, t: float) -> void:
	for side in [-1, 1]:
		ellipse(g, p + Vector2(side * 12, 0), 12, 9, 0, Color("1b1d29"))
		ellipse(g, p + Vector2(side * 12 - 3, -3), 5, 2.5, -0.4, Color(0.7, 0.85, 1.0, 0.65))
	g.draw_line(p + Vector2(-2, -2), p + Vector2(2, -2), Color("e6c35a"), 3, true)
	g.draw_line(p + Vector2(-23, -3), p + Vector2(-31, -8), Color("e6c35a"), 3, true)
	g.draw_line(p + Vector2(23, -3), p + Vector2(31, -8), Color("e6c35a"), 3, true)
	var glint = 0.5 + 0.5 * sin(t * 4.0)
	g.draw_line(p + Vector2(18, -14) - Vector2(5, 0) * glint, p + Vector2(18, -14) + Vector2(5, 0) * glint, Color("fff6c2"), 2, true)
	g.draw_line(p + Vector2(18, -19) , p + Vector2(18, -9), Color(1, 0.96, 0.76, glint), 2, true)

static func football(g: CanvasItem, p: Vector2, t: float) -> void:
	g.draw_set_transform(p, t * 1.3, Vector2.ONE)
	g.draw_circle(Vector2.ZERO, 21, Color("2a3140"))
	g.draw_circle(Vector2.ZERO, 19, Color("f6f8fb"))
	var centre = PackedVector2Array()
	for i in 5: centre.append(Vector2.from_angle(i * TAU / 5 - PI / 2) * 8)
	g.draw_colored_polygon(centre, Color("2a3140"))
	for i in 5:
		var a = i * TAU / 5 - PI / 2
		g.draw_line(Vector2.from_angle(a) * 8, Vector2.from_angle(a) * 15, Color("2a3140"), 1.8, true)
		g.draw_circle(Vector2.from_angle(a + TAU / 10) * 17, 3.4, Color("2a3140"))
	g.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
