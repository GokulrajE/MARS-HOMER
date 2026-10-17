extends Control
## Overlay for the movement reference clips: a glowing guide line showing how the
## hand should travel, a ring marker that follows the clip, and a "REC"
## viewfinder frame. Paths are normalised to the video frame and traced from the
## wrist cuff in the original Unity footage.
const PATHS = {
	# Left-right: the wrist sweeps across the top of the frame and back.
	"ML": {"points": [Vector2(0.84, 0.25), Vector2(0.66, 0.22), Vector2(0.48, 0.22), Vector2(0.34, 0.28), Vector2(0.25, 0.34)], "period": 8.0, "closed": false},
	# Forward-back: the hand leaves the body and extends forward, then returns.
	"AP": {"points": [Vector2(0.67, 0.53), Vector2(0.65, 0.42), Vector2(0.56, 0.31), Vector2(0.49, 0.23)], "period": 2.97, "closed": false},
	# Combined: a loop through the near, far and side positions (the clip shows it twice).
	"MLAP": {"points": [Vector2(0.62, 0.62), Vector2(0.45, 0.33), Vector2(0.30, 0.52)], "period": 5.65, "closed": true}
}
const SAMPLES = 72
var player: VideoStreamPlayer
var clip := ""
var line := PackedVector2Array()
var closed := false
var period := 8.0
var length := 0.0
## Where the real picture sits inside the shared 4:3 frame (normalised).
var content := Rect2(0, 0, 1, 1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Smooth Catmull-Rom curve through the key points (closed loops wrap around).
static func smooth(points: Array, wrap: bool) -> PackedVector2Array:
	var result = PackedVector2Array()
	var count = points.size()
	var segments = count if wrap else count - 1
	for i in segments:
		var p0: Vector2 = points[(i - 1 + count) % count] if wrap or i > 0 else points[i]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % count]
		var p3: Vector2 = points[(i + 2) % count] if wrap or i + 2 < count else points[(i + 1) % count]
		for k in SAMPLES / segments:
			var t = float(k) / (SAMPLES / segments)
			result.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
	if not wrap: result.append(points[count - 1])
	return result

func configure(key: String, seconds: float, picture: Rect2) -> void:
	clip = key
	length = seconds
	content = picture
	line = PackedVector2Array()
	if PATHS.has(key):
		closed = PATHS[key].closed
		period = PATHS[key].period
		line = smooth(PATHS[key].points, closed)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_visible_in_tree(): queue_redraw()

## Path point (in the picture) -> pixel in the overlay.
func to_px(p: Vector2) -> Vector2:
	return (content.position + p * content.size) * size

## Position along the path (0..1) for the current playback time.
func progress(seconds: float) -> float:
	if closed: return fposmod(seconds / period, 1.0)
	return 0.5 - 0.5 * cos(TAU * seconds / period)

func point_at(s: float) -> Vector2:
	var last = line.size() - 1
	if closed:
		var f = fposmod(s, 1.0) * line.size()
		var i = int(f) % line.size()
		return line[i].lerp(line[(i + 1) % line.size()], f - floorf(f))
	var f2 = clampf(s, 0.0, 1.0) * last
	var j = mini(int(f2), last - 1)
	return line[j].lerp(line[j + 1], f2 - j)

func chip(text: String, at: Vector2, font: Font, scale: float, dot: bool = false) -> void:
	var size_px = int(18 * scale)
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + (34 if dot else 20) * scale
	var box = Rect2(at, Vector2(width, 28 * scale))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(int(8 * scale))
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	draw_style_box(style, box)
	var x = box.position.x + 10 * scale
	if dot:
		draw_circle(Vector2(x + 5 * scale, box.position.y + 14 * scale), 5 * scale, Color("ff3b3b"))
		x += 18 * scale
	draw_string(font, Vector2(x, box.position.y + 20 * scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)

func _draw() -> void:
	if player == null: return
	var scale = clampf(size.x / 360.0, 0.6, 1.5)
	var font = ThemeDB.fallback_font
	var seconds = player.stream_position if player.is_playing() else 0.0
	# Guide line and marker first, so the frame sits on top.
	if line.size() > 1:
		var px = PackedVector2Array()
		for p in line: px.append(to_px(p))
		if closed: px.append(px[0])
		draw_polyline(px, Color(0.25, 0.95, 0.8, 0.10), 20 * scale, true)
		draw_polyline(px, Color(0.30, 0.95, 0.80, 0.22), 11 * scale, true)
		draw_polyline(px, Color(0.62, 1.0, 0.86, 0.55), 5 * scale, true)
		draw_polyline(px, Color(1, 1, 1, 0.85), 1.8 * scale, true)
		var s = progress(seconds)
		# The stretch just travelled glows brighter, like a comet tail.
		var tail = PackedVector2Array()
		for k in 14:
			tail.append(to_px(point_at(s - (13 - k) * 0.012 * (1.0 if closed or s >= 0.5 - 0.5 * cos(TAU * (seconds + 0.01) / period) else -1.0))))
		draw_polyline(tail, Color(0.8, 1.0, 0.95, 0.75), 7 * scale, true)
		if not closed:
			for end_point in [line[0], line[line.size() - 1]]:
				draw_arc(to_px(end_point), 9 * scale, 0, TAU, 20, Color(1, 1, 1, 0.55), 2 * scale, true)
		var marker = to_px(point_at(s))
		for ring in 5: draw_circle(marker, (34 - ring * 5) * scale, Color(0.2, 0.9, 1.0, 0.05 + ring * 0.035))
		draw_arc(marker, 22 * scale, 0, TAU, 40, Color(0.5, 1.0, 1.0, 0.95), 3.2 * scale, true)
		draw_arc(marker, 15 * scale, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.4 * scale, true)
		draw_circle(marker, 5 * scale, Color.WHITE)
	# Viewfinder corners.
	var inset = 8.0 * scale
	var arm = 22.0 * scale
	for corner in [[Vector2(inset, inset), Vector2(1, 1)], [Vector2(size.x - inset, inset), Vector2(-1, 1)], [Vector2(inset, size.y - inset), Vector2(1, -1)], [Vector2(size.x - inset, size.y - inset), Vector2(-1, -1)]]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_polyline(PackedVector2Array([c + Vector2(d.x * arm, 0), c, c + Vector2(0, d.y * arm)]), Color(1, 1, 1, 0.7), 2.0 * scale, true)
	chip("REC", Vector2(size.x - (80 * scale), 16 * scale), font, scale, true)
	# Playback bar: camera, scrubber and play button, as in the reference design.
	var length_now = length if length > 0.0 else maxf(player.get_stream_length(), 0.001)
	var bar_y = size.y - 26 * scale
	var left_x = 46 * scale
	var right_x = size.x - 56 * scale
	draw_rect(Rect2(left_x - 30 * scale, bar_y - 12 * scale, 22 * scale, 16 * scale), Color(1, 1, 1, 0.85))
	draw_circle(Vector2(left_x - 19 * scale, bar_y - 4 * scale), 4 * scale, Color(0, 0, 0, 0.6))
	draw_line(Vector2(left_x, bar_y), Vector2(right_x, bar_y), Color(1, 1, 1, 0.3), 3 * scale, true)
	var fraction = clampf(seconds / length_now, 0, 1)
	draw_line(Vector2(left_x, bar_y), Vector2(lerpf(left_x, right_x, fraction), bar_y), Color(0.45, 1.0, 0.9), 3 * scale, true)
	draw_circle(Vector2(lerpf(left_x, right_x, fraction), bar_y), 6 * scale, Color.WHITE)
	var button = Vector2(right_x + 26 * scale, bar_y)
	draw_circle(button, 14 * scale, Color(1, 1, 1, 0.9))
	draw_colored_polygon(PackedVector2Array([button + Vector2(-4, -7) * scale, button + Vector2(-4, 7) * scale, button + Vector2(8, 0) * scale]), Color(0.1, 0.12, 0.18))
	var stamp = "00:%02d" % int(seconds)
	draw_string(font, Vector2(left_x, bar_y - 14 * scale), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * scale), Color(1, 1, 1, 0.85))
