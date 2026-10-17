extends Control

var age := 0.0
var replay: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var game = get_parent()
	replay = Button.new()
	replay.text = "Play Again"
	replay.size = Vector2(280,60)
	replay.position = size / 2 + Vector2(-140,130)
	replay.add_theme_font_override("font",game.heading_font)
	replay.add_theme_font_size_override("font_size",22)
	replay.add_theme_color_override("font_color",Color("102b39"))
	replay.add_theme_color_override("font_focus_color",Color("102b39"))
	replay.add_theme_color_override("font_hover_color",Color("102b39"))
	replay.add_theme_stylebox_override("normal",game.style(Color("83e4d1"),Color("a4ffea"),18))
	replay.add_theme_stylebox_override("hover",game.style(Color("b4f6e6"),Color("ffffff"),18))
	replay.add_theme_stylebox_override("pressed",game.style(Color("64c9b6"),Color("ffffff"),18))
	replay.pressed.connect(game.restart)
	add_child(replay)
	replay.grab_focus()
	modulate.a = 1.0 if game.reduced else 0.0

func _process(delta: float) -> void:
	age += delta
	modulate.a = 1.0 if get_parent().reduced else smoothstep(0.0,0.55,age)
	queue_redraw()

func centered(text: String, y: float, font: Font, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,Vector2(size.x/2-width/2,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	var game = get_parent()
	var center := size/2
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.05,0.09,0.65))
	var box: StyleBoxFlat = game.style(Color("132c40"),Color("548a91"),30)
	box.shadow_color = Color(0.2,0.85,0.7,0.1)
	box.shadow_size = 24
	draw_style_box(box,Rect2(center-Vector2(300,245),Vector2(600,490)))
	for i in 3:
		var pos := center+Vector2((i-1)*72,-185)
		var col: Color = game.COLORS[i]
		draw_circle(pos,25,Color(col,0.12))
		var points := PackedVector2Array()
		for j in 8: points.append(pos+Vector2.from_angle(j*PI/4)*(15 if j%2==0 else 4))
		draw_colored_polygon(points,col)
	centered("Beautifully done!",center.y-118,game.reward_font,38,Color("eefaff"))
	centered("A little reach. A world of wonder.",center.y-80,game.font,20,Color("a7c4d2"))
	centered("FINAL SCORE",center.y-26,game.heading_font,14,Color("83e4d1"))
	centered(str(game.hits*10),center.y+41,game.heading_font,60,Color("ffffff"))
	centered("%d of %d reaches completed" % [game.hits,game.goal],center.y+83,game.font,21,Color("c1d9e2"))
	centered("Take a rest whenever you need.",center.y+222,game.font,16,Color("a7c4d2"))

