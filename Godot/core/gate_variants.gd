extends RefCounted
static var rock:Texture2D
static var temple:Texture2D
static func draw(g:CanvasItem,x:float,edge:float,top:bool,kind:int,forest:bool=false)->bool:
	if kind==0: return false
	if rock==null: rock=load("res://assets/art/reef_column.png")
	if temple==null: temple=load("res://assets/art/bheem_pillar.png")
	var direction=-1.0 if top else 1.0
	var height=edge if top else 900-edge
	if height<=0: return true
	var texture=temple if forest else rock
	var tint=Color("b7d8cb") if kind==2 else Color("e8afc6")
	if forest: tint=Color("c1d4b0") if kind==1 else Color("d1c7b3")
	# Short textured segments preserve the artwork's detail at any gate height.
	for i in range(ceili(height/68.0)-1,-1,-1):
		var near=maxf(0,i*68.0-6)
		var far=minf(height+12,(i+1)*68.0+6)
		far=maxf(far,near+28)
		var width=60.0+sin(i*2.7+edge)*8 if kind==1 else 72.0
		var outline=[Vector2(-width+9,near),Vector2(width-9,near),Vector2(width,near+12),Vector2(width-3,far-8),Vector2(width-12,far),Vector2(-width+5,far),Vector2(-width,far-12),Vector2(-width,near+8)]
		var points=PackedVector2Array()
		var uv=PackedVector2Array()
		for v in outline:
			points.append(Vector2(x+v.x,edge+direction*v.y))
			uv.append(Vector2(.5+v.x/650.0,.22+fposmod(i*.13,.30)+(v.y-near)/maxf(1,far-near)*.12))
		g.draw_polygon(points,PackedColorArray([tint]),uv,texture)
		var border=points.duplicate()
		border.append(points[0])
		g.draw_polyline(border,Color("293d41"),2,true)
		if kind==1:
			for side in [-1,1]:
				var p=Vector2(x+side*(width-8),edge+direction*(near+30))
				var sway=sin(Trial.duration*1.5+i)*4
				var q=p+Vector2(side*(23+sway),direction*22)
				var color=Color("426e3b") if forest else Color("bd72b2")
				g.draw_line(p,q,color.darkened(.35),7,true)
				g.draw_line(p,q,color,4,true)
				for k in 3:
					var tip=q+Vector2(side*(k*7-5),direction*(8+k*5))
					g.draw_line(q,tip,color.lightened(.15),3,true)
					if forest:
						g.draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-9,direction*6),tip+Vector2(0,direction*17),tip+Vector2(8,direction*7)]),Color("6f9d51"))
					else: g.draw_circle(tip,3,Color("f4b5d8"))
		elif i%2==0:
			var p=Vector2(x+25,edge+direction*(near+24))
			g.draw_arc(p,10,0,TAU,20,Color(.6,.9,.8,.6),2,true)
			g.draw_line(p+Vector2(-5,0),p+Vector2(5,0),Color(.6,.9,.8,.6),2,true)
	# A narrow luminous rim clearly marks the unchanged opening.
	g.draw_line(Vector2(x-48,edge),Vector2(x+48,edge),Color("d2efda"),3,true)
	return true
