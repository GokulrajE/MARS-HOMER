extends RefCounted
## Small faceted reward star, with bounded glow and smooth reveal/fade.
static func draw(g:CanvasItem,p:Vector2,r:float,alpha:float=1.0,angle:float=0.0)->void:
	if r<0.1 or alpha<=0: return
	for i in range(3,0,-1): g.draw_circle(p,r*(1+i*.25),Color(1,.72,.2,alpha*.025))
	var points=PackedVector2Array()
	for i in 10: points.append(p+Vector2.from_angle(-PI/2+angle+i*PI/5)*(r if i%2==0 else r*.46))
	for i in 10:
		var color=Color("fff0ae") if i%2==0 else Color("e9a52b")
		color.a=alpha
		g.draw_colored_polygon(PackedVector2Array([p,points[i],points[(i+1)%10]]),color)
	points.append(points[0])
	g.draw_polyline(points,Color(1,.91,.59,alpha),1.2,true)

static func spring(t:float)->float:
	t=clampf(t,0,1)
	var c=1.9
	return 1.0+(c+1.0)*pow(t-1.0,3)+c*pow(t-1.0,2)

## Four-point twinkle with a soft halo.
static func sparkle(g:CanvasItem,p:Vector2,r:float,alpha:float,angle:float=0.0)->void:
	if r<0.5 or alpha<=0: return
	g.draw_circle(p,r*1.6,Color(1,.9,.55,alpha*.10))
	for k in 2:
		var d=Vector2.from_angle(angle+k*PI/2)*r
		g.draw_polyline(PackedVector2Array([p-d,p,p+d]),Color(1,.97,.8,alpha),1.6,true)
	g.draw_circle(p,r*.22,Color(1,1,1,alpha))

## Reward shown where a target was captured: light rays, a springy golden star that
## spins and shines, two companion stars and an outward burst of twinkles.
static func celebrate(g:CanvasItem,p:Vector2,age:float,reduced:bool=false)->void:
	var t=clampf(age/1.6,0,1)
	if t>=1: return
	var fade=1.0-smoothstep(.68,1.0,t)
	var center=p+Vector2(0,-52-(0 if reduced else 36*smoothstep(0,1,t)))
	# Soft bloom and slow light rays behind the star.
	for i in range(5,0,-1): g.draw_circle(center,(24+i*14)*spring(t*3),Color(1,.78,.3,fade*.03))
	if not reduced:
		for k in 10:
			var a=age*.7+k*TAU/10
			var len=(60+34*(k%2))*clampf(t*4,0,1)
			g.draw_polyline(PackedVector2Array([center+Vector2.from_angle(a)*18,center+Vector2.from_angle(a)*len]),Color(1,.93,.62,fade*.35),2.2,true)
	# Companion stars rise slightly later.
	for side in [-1,1]:
		var u=clampf((age-.10)/1.3,0,1)
		if u>0 and u<1:
			var pos=center+Vector2(side*(62*spring(u*2.2)),22-(0 if reduced else 14*u))
			draw(g,pos,15*spring(u*3),(1.0-smoothstep(.65,1.0,u)),0 if reduced else side*sin(u*PI)*.35)
	# Main star with a travelling shine.
	var grow=spring(clampf(age/.42,0,1))
	draw(g,center,38*grow,fade,0 if reduced else sin(age*2.2)*.22)
	if not reduced:
		var shine=fposmod(age*1.6,1.0)
		var edge=center+Vector2(-30+60*shine,-6)
		g.draw_circle(edge,5*grow,Color(1,1,1,fade*.5*sin(shine*PI)))
	# Twinkles fly outward and shimmer.
	if not reduced:
		for k in 12:
			var a=k*TAU/12+.4
			var d=(46+88*(1.0-pow(1.0-clampf(age/1.1,0,1),2.4)))*(0.8+.3*(k%3)/2.0)
			sparkle(g,center+Vector2.from_angle(a)*d,(5+4*(k%3))*(1.0-t*.5),fade*(0.55+0.45*sin(age*9+k)),age*1.5+k)

