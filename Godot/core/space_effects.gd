extends RefCounted
static func burst(fx:RefCounted,p:Vector2,variant:int)->void:
	var color=[Color("ffb35e"),Color("8eeaff"),Color("efb986")][variant]
	fx.add("space_blast",p,{"life":.85,"color":color})
	for i in 14:
		var angle=i*TAU/14+randf_range(-.12,.12)
		fx.add("space_fragment",p,{"vel":Vector2.from_angle(angle)*randf_range(105,265),"life":randf_range(.65,1.15),"spin":randf_range(-5,5),"size":randf_range(7,19),"color":color,"variant":variant})
	for i in 22:
		fx.add("space_ember",p,{"vel":Vector2.from_angle(randf()*TAU)*randf_range(190,430),"life":randf_range(.25,.75),"color":color})
	fx.add("popup",p+Vector2(0,-65),{"text":"+1","color":color,"life":.8})
static func draw(g:CanvasItem,item:Dictionary,u:float)->void:
	var p:Vector2=item.pos
	var c:Color=item.color
	match item.kind:
		"space_blast":
			# A brief local core gives way to a thin shock wave and soft vapour.
			var core=pow(maxf(0,1-u*3.8),2)
			for k in range(6,0,-1):
				g.draw_circle(p,(22+u*110)*k/6.0,Color(c,.12*core))
			g.draw_circle(p,30*core,Color(1,.96,.81,core))
			var r=18+150*(1-pow(1-u,2))
			g.draw_arc(p,r,0,TAU,64,Color(c,pow(1-u,2)*.75),1+4*(1-u),true)
			g.draw_arc(p,r*.82,0,TAU,64,Color(1,.95,.85,pow(1-u,3)*.35),1.5,true)
			for k in 7:
				var q=p+Vector2.from_angle(k*TAU/7)*u*70
				g.draw_circle(q,12+u*28,Color(.32,.39,.48,sin(u*PI)*.075))
		"space_fragment":
			c=c.darkened(.38 if item.variant!=1 else .12)
			c.a=1-smoothstep(.5,1,u)
			g.draw_set_transform(p,item.spin*item.t,Vector2.ONE*(1-u*.35))
			var s:float=item.size
			g.draw_colored_polygon(PackedVector2Array([Vector2(-s,-s*.3),Vector2(-s*.3,-s),Vector2(s*.8,-s*.5),Vector2(s,s*.5),Vector2(-s*.2,s*.7)]),c)
			g.draw_line(Vector2(-s*.3,-s*.8),Vector2(s*.7,-s*.4),Color(item.color,c.a*.8),2,true)
			g.draw_line(Vector2(-s*.4,-s*.1),Vector2(s*.3,s*.35),Color(.1,.18,.24,c.a*.65),2,true)
			g.draw_set_transform(Vector2.ZERO)
		"space_ember":
			var v:Vector2=item.vel
			g.draw_line(p-v.normalized()*(8+16*(1-u)),p,Color(c,(1-u)*.65),2,true)
			g.draw_circle(p,1+2*(1-u),Color(1,.95,.8,1-u))
