extends Control
## Animated backdrop shared by every non-game screen: a deep gradient, slowly
## drifting soft light orbs and rising motes. Purely decorative.
const ORBS = [
	[Color("0d9488"), 0.050, 330.0, 0.11, 0.17, 0.0],
	[Color("2563eb"), 0.065, 400.0, 0.13, 0.12, 1.7],
	[Color("1f9cff"), 0.055, 300.0, 0.09, 0.15, 3.1],
	[Color("38bdf8"), 0.035, 260.0, 0.14, 0.10, 4.6],
	[Color("0d9488"), 0.040, 220.0, 0.17, 0.13, 5.9]
]
# A blurred copy of glass_forest.png (see platform/blur_background.py) keeps text easy to read.
const FOREST=preload("res://assets/art/glass_forest_blur.png")
var clock = 0.0
var motes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 12: motes.append([randf(), randf(), randf_range(0.01, 0.035), randf_range(1.5, 3.5), randf() * TAU])

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func _draw() -> void:
	var size = Vector2(1600, 1000)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([Color("111827"), Color("111827"), Color("172638"), Color("111827")]))
	draw_texture_rect(FOREST,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.05,0.09,.18))
	for orb in ORBS:
		var center = Vector2(size.x * (0.5 + 0.42 * sin(clock * orb[1] * 2.0 + orb[5])), size.y * (0.5 + 0.40 * cos(clock * orb[1] * 1.6 + orb[5] * 1.3)))
		for ring in 7:
			var color: Color = orb[0]
			color.a = 0.006 + ring * 0.002
			draw_circle(center, orb[2] * (1.0 - ring * 0.12), color)
	for mote in motes:
		var y = fposmod(mote[1] - clock * mote[2], 1.0)
		var x = mote[0] + sin(clock * 0.3 + mote[4]) * 0.02
		draw_circle(Vector2(x * size.x, y * size.y), mote[3], Color(0.7, 0.95, 1.0, 0.10 + 0.10 * sin(clock + mote[4])))
	# Gentle vignette keeps the focus on the content.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.0))
	draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.78), Vector2(size.x, size.y * 0.78), size, Vector2(0, size.y)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35)]))


