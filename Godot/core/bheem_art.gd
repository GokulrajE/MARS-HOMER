extends RefCounted
const Gates=preload("res://core/gate_variants.gd")
const Motion=preload("res://core/flight_animation.gd")
const Targets=preload("res://core/flight_targets.gd")
const Cycle=preload("res://core/visual_cycle.gd")
static func star(g: CanvasItem,p:Vector2,r:float,c:Color) -> void:
	if r<0.1: return
	var points=PackedVector2Array()
	for i in 8: points.append(p+Vector2.from_angle(i*PI/4)*(r if i%2==0 else r*.25))
	g.draw_colored_polygon(points,c)
static var pillar_texture: Texture2D
static func pillar(g: CanvasItem,x:float,edge:float,top:bool,kind:int=0) -> void:
	if Gates.draw(g,x,edge,top,kind,true): return
	if pillar_texture==null: pillar_texture=load("res://assets/art/bheem_pillar.png")
	var texture_size=pillar_texture.get_size()
	var height=edge if top else 900-edge
	var direction=-1.0 if top else 1.0
	g.draw_set_transform(Vector2(x,edge),0,Vector2(1,direction))
	# The carved capital retains its proportions; only the shaft extends to the edge.
	var cap=minf(82,height)
	g.draw_texture_rect_region(pillar_texture,Rect2(-78,0,156,cap),Rect2(texture_size*Vector2(.15,0),texture_size*Vector2(.70,.17)))
	if height>cap:
		g.draw_texture_rect_region(pillar_texture,Rect2(-56,cap,112,height-cap+8),Rect2(texture_size*Vector2(.27,.18),texture_size*Vector2(.46,.55)))
	g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func style(color: Color,radius:int) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.border_color=Color("614534")
	s.set_border_width_all(2)
	return s
static func draw(g:Node2D) -> void:
	var t:float=g.clock
	var actor:Dictionary=g.character_data
	g.reef_water.material.set_shader_parameter("swim_clock",t)
	# Slow cloud wisps, distant birds and kites establish depth independently of gates.
	for i in 5:
		var x=fposmod(1750+i*370-t*21,2100)-250
		g.draw_set_transform(Vector2(x,120+i%2*90),0,Vector2(3.5,1))
		g.draw_circle(Vector2.ZERO,24,Color(1,.88,.69,.10))
		g.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for i in 6:
		var p=Vector2(fposmod(1700+i*95-t*42,2100)-120,160+(i%3)*44)
		var wing=sin(t*5+i)*9
		g.draw_polyline(PackedVector2Array([p+Vector2(-13,-wing),p,p+Vector2(13,-wing)]),Color(.22,.19,.24,.48),3,true)
	var look=Cycle.look()
	if look==1:
		# Paper lanterns drift upward through the cool morning haze.
		for i in 9:
			var lp=Vector2(fposmod(i*211.0+sin(t*.4+i)*30.0,1700)-50,fposmod(760-t*(26+i%4*7)+i*131.0,980)-40)
			for ring in 4: g.draw_circle(lp,30-ring*6,Color(1,.72,.35,.05+ring*.03))
			g.draw_circle(lp,10,Color("ffd27a"))
			g.draw_circle(lp+Vector2(-2,-2),6,Color("fff0b8"))
	elif look==2:
		# Slanting monsoon rain across the whole sky.
		for i in 90:
			var rp=Vector2(fposmod(i*53.7-t*140.0,1700)-50,fposmod(i*97.3+t*(520+i%5*40),960)-30)
			g.draw_line(rp,rp+Vector2(-7,28),Color(.8,.9,1,.22),1.6,true)
	for i in (2 if look==0 else 0):
		var p=Vector2(fposmod(1900+i*600-t*30,2300)-200,270+i*180+sin(t+i)*15)
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-22),p+Vector2(17,0),p+Vector2(0,27),p+Vector2(-17,0)]),Color("d49d54") if i==0 else Color("a376a3"))
		var tail=PackedVector2Array()
		for k in 15: tail.append(p+Vector2(sin(t*2+k*.5)*7,27+k*4))
		g.draw_polyline(tail,Color(.6,.38,.32,.55),1.5,true)
	for gate in g.passed_reefs:
		pillar(g,gate.x,gate.y-72,true,gate.kind)
		pillar(g,gate.x,gate.y+72,false,gate.kind)
	if Trial.target_open:
		var p:Vector2=g.target
		pillar(g,p.x,p.y-72,true,g.visual_variant)
		pillar(g,p.x,p.y+72,false,g.visual_variant)
		Targets.draw(g,actor.target,p,t,actor.color)
		for i in 5: star(g,p+Vector2.from_angle(t+i*TAU/5)*34,3+sin(t*4+i),Color("fff2a9"))
	var pose=Motion.pose(g.character_id,t,g.catch_pose,g.swim_tilt,actor)
	var body:Vector2=g.player+pose.offset
	g.swim_sprite.position=body
	g.swim_sprite.rotation=pose.angle
	g.swim_sprite.scale=pose.stretch*245.0/g.swim_sprite.texture.get_width()
	g.swim_sprite.material.set_shader_parameter("swim_clock",t)
	g.swim_sprite.material.set_shader_parameter("reaction",maxf(0,g.catch_pose))
	g.swim_sprite.material.set_shader_parameter("actor_style",g.Cast.CAST.keys().find(g.character_id))
	if g.character_id=="rajini" and fposmod(t,5.0)<0.5:
		star(g,body+Vector2(50,-53).rotated(pose.angle),5*sin(fposmod(t,5.0)*TAU),Color("fff6c2"))
	# Blue-gold magic trails fade behind the broom, never obscuring the target.
	for i in 42:
		var u=fposmod(t*.65+i/42.0,1.0)
		var p=body+Vector2(-90-u*240,sin(u*9-t*3+i)*12+u*25)
		var c:Color=actor.accent if i%2==0 else actor.color
		c.a=(1-u)*.8
		star(g,p,2+(1-u)*3+maxf(0,g.catch_pose)*3,c)
	if g.catch_pose < 0:
		for i in 3: star(g,body+Vector2(48+cos(t*6+i*TAU/3)*27,-64+sin(t*6+i*TAU/3)*7),4,Color("ffe48b"))
