extends Control
## Small line icons for movements and the arm-weight scale.
var kind := "ml"
var color := Color("fdba74")

func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _arrow(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, color, 2.6, true)
	var direction = (to - from).normalized()
	var side = direction.rotated(PI / 2) * 5.0
	draw_polyline(PackedVector2Array([to - direction * 8 + side, to, to - direction * 8 - side]), color, 2.6, true)

func _draw() -> void:
	var c = size / 2.0
	match kind:
		"ml":
			_arrow(c + Vector2(-2, -7), c + Vector2(16, -7))
			_arrow(c + Vector2(2, 7), c + Vector2(-16, 7))
		"ap":
			_arrow(c + Vector2(-7, 2), c + Vector2(-7, -16))
			_arrow(c + Vector2(7, -2), c + Vector2(7, 16))
		"mlap":
			_arrow(c, c + Vector2(0, -17))
			_arrow(c, c + Vector2(17, 0))
			_arrow(c, c + Vector2(0, 17))
			_arrow(c, c + Vector2(-17, 0))
		_:
			# Balance scale for the arm-weight assessment.
			draw_line(c + Vector2(0, -16), c + Vector2(0, 14), color, 2.6, true)
			draw_line(c + Vector2(-15, -10), c + Vector2(15, -10), color, 2.6, true)
			draw_line(c + Vector2(-9, 14), c + Vector2(9, 14), color, 2.6, true)
			for side in [-1, 1]:
				var top = c + Vector2(side * 15, -10)
				draw_line(top, top + Vector2(-5, 14), color, 1.6, true)
				draw_line(top, top + Vector2(5, 14), color, 1.6, true)
				draw_arc(top + Vector2(0, 14), 7, 0, PI, 12, color, 2.2, true)
