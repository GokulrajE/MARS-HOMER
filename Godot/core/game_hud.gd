extends Control
const UI=preload("res://core/ui_theme.gd")
var clock_label:Label
var score_label:Label
var pause:Button
var stars_label:Label
var total_stars=0
static func saved_stars(code:String,history:Array)->int:
	var total=0
	for row in history:
		if row.size()==24 and row[9]==code: total+=maxi(0,int(row[21]))
	return total
func pill(rect:Rect2,color:Color)->void:
	var style=UI.box(Color(.035,.065,.15,.85),Color(color,.65),2,40,0,0)
	style.shadow_color=Color(color,.25)
	style.shadow_size=12
	draw_style_box(style,rect)
	draw_arc(rect.position+Vector2(40,40),25,PI,PI*1.5,20,Color(color,.3),1,true)
func label_at(text:String,p:Vector2,size_px:int,color:Color)->Label:
	var l=UI.label(text,size_px,color)
	l.position=p
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
func _ready()->void:
	position=Vector2(28,22)
	size=Vector2(1544,100)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	total_stars=saved_stars(Trial.game,Trial.history)
	clock_label=label_at("60 s",Vector2(85,19),40,Color.WHITE)
	label_at("SCORE",Vector2(330,31),25,Color("c7d7ef"))
	score_label=label_at("00",Vector2(445,24),32,Color("ffe293"))
	label_at("TOTAL STARS",Vector2(585,31),23,Color("c7d7ef"))
	stars_label=label_at(str(total_stars),Vector2(835,22),36,Color("ffe293"))
	stars_label.tooltip_text="All saved stars earned by this patient in this game"
	pause=button("Ⅱ  Pause",Vector2(1090,10),Color("38bdf8"))
	var leave=button("↪  Exit",Vector2(1330,10),Color("fa667a"))
	leave.pressed.connect(get_parent().finish_game)
	pause.pressed.connect(get_parent().toggle_pause)
	leave.tooltip_text="Finish and save this trial"
	# Bottom-right: how much of today's prescription is done (trial n of N).
	var ring=preload("res://core/session_ring.gd").new()
	ring.position=Vector2(1600-18-148-28,1000-42-66-22)
	add_child(ring)
func button(text:String,p:Vector2,color:Color)->Button:
	var b=Button.new()
	b.text=text
	b.position=p
	b.size=Vector2(200,64)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",27)
	var s=UI.box(Color(color.darkened(.75),.92),Color(color,.75),2,32,12,8)
	s.shadow_color=Color(color,.3)
	s.shadow_size=9
	b.add_theme_stylebox_override("normal",s)
	b.add_theme_stylebox_override("hover",UI.box(color.darkened(.5),color,2,32,12,8))
	add_child(b)
	return b
func _process(_delta:float)->void:
	clock_label.text="%02d s" % ceili(maxf(0,60-Trial.duration))
	score_label.text="Held" if Trial.held() else "%02d" % Trial.hits
	pause.text="▶  Play" if Trial.paused else "Ⅱ  Pause"
	queue_redraw()
func star(p:Vector2,r:float)->void:
	var points=PackedVector2Array()
	for i in 10: points.append(p+Vector2.from_angle(-PI/2+i*PI/5)*(r if i%2==0 else r*.46))
	draw_circle(p,r*1.4,Color(1,.7,.12,.08))
	draw_colored_polygon(points,Color("ffdf7f"))
	draw_polyline(points,Color("fff0b4"),1.5,true)
func _draw()->void:
	pill(Rect2(0,0,230,86),Color("65eaff"))
	pill(Rect2(270,0,770,86),Color("9c9bff"))
	draw_arc(Vector2(44,43),25,0,TAU,48,Color(.2,.5,.65,.4),7,true)
	var remaining=clampf((60-Trial.duration)/60,0,1)
	if remaining>0: draw_arc(Vector2(44,43),25,-PI/2,-PI/2+TAU*remaining,48,Color("68e9ff"),7,true)
	star(Vector2(304,43),20)
	star(Vector2(798,43),24)
	draw_line(Vector2(550,18),Vector2(550,68),Color(.7,.7,1,.2),2,true)

