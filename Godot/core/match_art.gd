extends RefCounted
const Cycle=preload("res://core/visual_cycle.gd")
const COLORS=[Color("ffab49"),Color("80de8b"),Color("56c9fa"),Color("ba96ff")]
static func panel(g:CanvasItem,rect:Rect2,color:Color,radius:int,border:Color=Color.TRANSPARENT,width:int=0)->void:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.border_color=border
	s.set_border_width_all(width)
	g.draw_style_box(s,rect)
static func ellipse(g:CanvasItem,p:Vector2,r:float,scale_y:float,color:Color)->void:
	g.draw_set_transform(p,0,Vector2(1,scale_y))
	g.draw_circle(Vector2.ZERO,r,color)
	g.draw_set_transform(Vector2.ZERO)
static func symbol(g:CanvasItem,p:Vector2,index:int,r:float,color:Color)->void:
	if index==0:
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0)]),color)
	elif index==1:
		g.draw_arc(p,r*.8,0,TAU,24,color,3,true)
		g.draw_line(p+Vector2(-r*.45,r*.45),p+Vector2(r*.45,-r*.45),color,3,true)
	elif index==2:
		for j in 2:
			var points=PackedVector2Array()
			for k in 15: points.append(p+Vector2(-r+k*r/7.0,sin(k*TAU/14)*3+j*8-4))
			g.draw_polyline(points,color,2.5,true)
	else:
		var points=PackedVector2Array()
		for k in 10: points.append(p+Vector2.from_angle(k*PI/5-PI/2)*(r if k%2==0 else r*.45))
		g.draw_colored_polygon(points,color)
static func orb(g:CanvasItem,p:Vector2,index:int,r:float,t:float)->void:
	var c:Color=COLORS[index]
	g.draw_circle(p+Vector2(0,3),r+2,c.darkened(.65))
	for k in 12:
		var u=k/11.0
		g.draw_circle(p+Vector2(-u*r*.18,-u*r*.22),r*(1-u*.65),c.darkened(.32).lerp(c.lightened(.28),u))
	g.draw_arc(p,r-3,PI*.96,PI*1.94,32,Color(1,1,1,.4),2,true)
	ellipse(g,p+Vector2(-r*.3,-r*.48),r*.24,.5,Color(1,1,1,.6))
	symbol(g,p+Vector2(1,3),index,r*.32,Color("f6fcff"))
	var angle=t*.7+index
	g.draw_circle(p+Vector2.from_angle(angle)*r*.83,2.2,Color(1,1,1,.65))
static func draw(g:Node2D)->void:
	var t:float=g.clock
	var Art=g.GameArt
	Art.gradient(g,Rect2(0,0,1600,900),Cycle.palette(Color("367f9d"),Color("7f6585"),Color("10263f")),Cycle.palette(Color("b2dacf"),Color("dfae91"),Color("315b68")))
	# Restrained scenery stays behind the playable field.
	for i in 4:
		var x=fposmod(i*520.0+t*(5+i),2100)-200
		Art.cloud(g,Vector2(x,165+i%2*90),.65+i*.12,Cycle.palette(Color("d9ebe7"),Color("d6b4bb"),Color("344e64")))
	for layer in 3:
		var points=PackedVector2Array([Vector2(-20,900)])
		for x in range(-20,1640,24):
			points.append(Vector2(x,575+layer*70+sin(x*.004+layer*1.9)*55+sin(x*.009+layer)*16))
		points.append(Vector2(1640,900))
		g.draw_colored_polygon(points,Cycle.palette(Color("669d98"),Color("8f888d"),Color("244b61")).darkened(layer*.14))
	for side in [0,1]:
		var x=60+side*1480
		g.draw_line(Vector2(x,775),Vector2(x,520),Color("365e61"),14,true)
		for k in 5:
			var p=Vector2(x+sin(k*2.1)*44,510-k*24)
			p.x+=sin(t*.6+k)*3
			g.draw_circle(p,47-k*3,Cycle.palette(Color("508e85"),Color("797b7e"),Color("234858")))
	for i in 20:
		var p=Vector2(fposmod(i*97+t*9,1600),540+sin(t*.5+i*1.7)*60+i%3*50)
		g.draw_circle(p,1.5+sin(t+i)*.5,Color(.95,1,.75,.24+.12*sin(t*1.3+i)))
	# Curved terrace, inset movement track and soft pool of light under the basket.
	Art.gradient(g,Rect2(0,848,1600,52),Color("263e4e"),Color("142634"))
	g.draw_line(Vector2(0,848),Vector2(1600,848),Color("96c5c2"),3,true)
	panel(g,Rect2(72,872,1456,10),Color("132b39"),6,Color("476775"),1)
	for i in 25: g.draw_circle(Vector2(110+i*57,877),1.5,Color("729294"))
	ellipse(g,Vector2(g.player.x,852),96,.17,Color(0,0,0,.25))
	ellipse(g,Vector2(g.player.x,874),65,.07,Color(COLORS[g.color_index],.7))
	if Trial.target_open:
		for i in g.balls.size():
			var p:Vector2=g.balls[i]
			# Keep the painted centre exactly on the collision centre.
			for k in 5:
				var d=12+k*12
				g.draw_circle(p-Vector2(0,d),maxf(2,12-k*2),Color(COLORS[i],.09-k*.015))
			orb(g,p,i,40,t)
			if g.visual_variant==1: g.draw_arc(p,44,t*.4,t*.4+PI*1.3,32,Color(COLORS[i],.5),2,true)
			elif g.visual_variant==2:
				for k in 3: g.draw_circle(p+Vector2.from_angle(t*.6+k*TAU/3)*45,2,Color(1,1,1,.6))
	# The cue is compact and never follows the falling balls.
	panel(g,Rect2(689,116,222,48),Color("183747"),20,Color("659eaa"),1)
	symbol(g,Vector2(719,140),g.color_index,12,COLORS[g.color_index])
	g.draw_string(ThemeDB.fallback_font,Vector2(743,148),["ORANGE","GREEN","BLUE","PURPLE"][g.color_index],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("f3f4f6"))
	var bounce=maxf(0,g.catch_pose)
	var stretch=sin(bounce/0.5*PI)*.13
	var tilt=g.visual_tilt*.42
	var center:Vector2=g.player+Vector2(0,-sin(bounce/0.5*PI)*9)
	var c:Color=COLORS[g.color_index]
	# Handle and liner flex gently with horizontal movement.
	g.draw_set_transform(center,tilt,Vector2(1+stretch,1-stretch))
	g.draw_arc(Vector2(0,-5),64,PI,TAU,36,Color("253a40"),12,true)
	g.draw_arc(Vector2(0,-5),64,PI,TAU,36,Color("c7a77a"),6,true)
	g.draw_set_transform(Vector2.ZERO)
	if bounce>0:
		var u=1-bounce/.5
		orb(g,center+Vector2(0,-60+u*70),g.match_caught_color,maxf(2,31*(1-u)),t)
	g.draw_set_transform(center,tilt,Vector2(1+stretch,1-stretch))
	var shape=PackedVector2Array([Vector2(-76,-14),Vector2(76,-14),Vector2(61,57),Vector2(47,67),Vector2(-47,67),Vector2(-61,57)])
	g.draw_polygon(shape,PackedColorArray([Color("cbae7b"),Color("cbae7b"),Color("8e6646"),Color("73573e"),Color("9b7550"),Color("b58c60")]))
	for row in 6:
		var y=-5+row*11
		var w=70-row*2
		g.draw_line(Vector2(-w,y),Vector2(w,y),Color("e0c28c"),3,true)
		for col in 9:
			var x=-55+col*14+(row%2)*5
			if absf(x)<w-4: g.draw_line(Vector2(x,y-6),Vector2(x-2,y+4),Color("73553d"),2,true)
	panel(g,Rect2(-79,-22,158,22),c.darkened(.3),10,c.lightened(.22),2)
	g.draw_line(Vector2(-64,-15),Vector2(64,-15),Color(c.lightened(.45),.75),2,true)
	g.draw_circle(Vector2(0,25),24,Color("263c48"))
	g.draw_arc(Vector2(0,25),24,0,TAU,32,c,2,true)
	symbol(g,Vector2(0,25),g.color_index,13,c.lightened(.2))
	g.draw_set_transform(Vector2.ZERO)


