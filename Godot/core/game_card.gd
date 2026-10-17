extends Control
## Background of a game card: a rounded gradient, a soft border that brightens on
## hover or focus, and the round play / replay badge on the right.
var button: Button
var left := Color("2a1456")
var right := Color("7a35b8")
var replay := false

static func rounded(rect: Rect2, radius: float, segments: int = 8) -> PackedVector2Array:
	var points = PackedVector2Array()
	var corners = [
		[rect.position + Vector2(radius, radius), PI],
		[Vector2(rect.end.x - radius, rect.position.y + radius), PI * 1.5],
		[rect.end - Vector2(radius, radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5]
	]
	for corner in corners:
		for i in segments + 1:
			points.append(corner[0] + Vector2.from_angle(corner[1] + i * (PI / 2.0) / segments) * radius)
	return points

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for signal_name in ["mouse_entered", "mouse_exited", "focus_entered", "focus_exited", "button_down", "button_up"]:
		button.connect(signal_name, queue_redraw)

func _draw() -> void:
	var hovered = button.is_hovered()
	var focused = button.has_focus()
	var lift = 0.12 if hovered or focused else 0.0
	var outline = rounded(Rect2(Vector2.ZERO, size).grow(-1.5), 26)
	var colors = PackedColorArray()
	for point in outline:
		var u = clampf(point.x / maxf(1.0, size.x), 0, 1)
		var shade = left.lerp(right, u).lightened(lift)
		# A gentle top-down sheen gives the glass look.
		shade = shade.lerp(Color.WHITE, 0.08 * (1.0 - clampf(point.y / maxf(1.0, size.y), 0, 1)))
		colors.append(shade)
	draw_polygon(outline, colors)
	var edge = Color(1, 1, 1, 0.22)
	var width = 1.5
	if focused:
		edge = Color("38bdf8")
		width = 4.0
	elif hovered:
		edge = Color(1, 1, 1, 0.6)
		width = 2.0
	var closed = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, edge, width, true)
	var centre = Vector2(size.x - 64, size.y / 2.0)
	draw_circle(centre, 32, Color(1, 1, 1, 0.16 if hovered or focused else 0.10))
	draw_arc(centre, 32, 0, TAU, 48, Color(1, 1, 1, 0.9 if hovered or focused else 0.6), 2.5, true)
	var ink = Color(0.8, 0.92, 1.0, 0.95)
	if replay:
		draw_arc(centre, 13, -PI * 0.2, PI * 1.45, 28, ink, 3.2, true)
		var tip = centre + Vector2.from_angle(-PI * 0.2) * 13
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -9), tip + Vector2(10, 1), tip + Vector2(-8, 6)]), ink)
	else:
		draw_colored_polygon(PackedVector2Array([centre + Vector2(-8, -14), centre + Vector2(-8, 14), centre + Vector2(15, 0)]), ink)
