extends RefCounted
# Decorative visits use only the session clock, never target/scoring state.
static func oval(g: CanvasItem,p:Vector2,r:Vector2,color:Color) -> void:
	g.draw_set_transform(p,0,r)
	g.draw_circle(Vector2.ZERO,1,color)
	g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
static func draw(g: Node2D) -> void:
	var t: float = g.clock
	# Two parallax layers of small fish schools.
	for layer in 2:
		for i in 9:
			var x = fposmod(1800.0+i*34-t*(26+layer*17)+layer*670,1950)-150
			var y = 180+layer*410+sin(t*1.2+i*.6)*12+(i%3)*17
			var c = Color(0.25,0.7,0.8,0.22) if layer==0 else Color(0.95,0.77,0.37,0.24)
			oval(g,Vector2(x,y),Vector2(9,4),c)
			g.draw_colored_polygon(PackedVector2Array([Vector2(x+7,y),Vector2(x+15,y-5),Vector2(x+15,y+5)]),c)
	# A sea turtle glides past during the first third of a session.
	if t>5 and t<21:
		var p = Vector2(1750-(t-5)*120,180+sin(t*.6)*20)
		var flap = sin(t*3)*12
		oval(g,p+Vector2(-8,-24-flap),Vector2(27,9),Color("5ba99c"))
		oval(g,p+Vector2(8,24+flap),Vector2(27,9),Color("5ba99c"))
		oval(g,p+Vector2(-51,0),Vector2(20,14),Color("89c7ad"))
		oval(g,p,Vector2(45,30),Color("244f60"))
		oval(g,p,Vector2(37,24),Color("5c998b"))
		for k in 3: g.draw_arc(p+Vector2((k-1)*19,0),13,0,TAU,18,Color("345f62"),2,true)
		g.draw_circle(p+Vector2(-58,-4),3,Color("132e48"))
	# Jellyfish pulse and trail tentacles in the later, darker part of the journey.
	if t>30:
		for i in 3:
			var p = Vector2(1600-(t-30)*40+i*110,180+i*55+sin(t+i)*16)
			var pulse = 1+sin(t*2.3+i)*.12
			oval(g,p,Vector2(26*pulse,18),Color(0.59,0.72,1,0.35))
			g.draw_arc(p,26*pulse,PI,TAU,24,Color(0.7,0.85,1,0.65),2,true)
			for strand in 4:
				var points=PackedVector2Array()
				for j in 12: points.append(p+Vector2((strand-1.5)*11+sin(t*2+j*.5+strand)*5,10+j*4))
				g.draw_polyline(points,Color(0.7,0.8,1,0.4),2,true)
	# Foreground seagrass: real lateral parallax, regenerated beyond the camera.
	for i in 18:
		var x=fposmod(i*113.0-t*55,1900)-150
		for blade in 3:
			var points=PackedVector2Array()
			for j in 10:
				var h=j/9.0
				points.append(Vector2(x+(blade-1)*12+sin(t*1.6+i+h*2)*h*15,900-h*(35+(i%4)*10)))
			g.draw_polyline(points,Color("247c79"),5,true)
