extends RefCounted
## One ring per target, never two. While the player is away from the target it shows the
## time left for this target (a ring that slowly drains and turns amber near the end).
## Once the player rests on the target the same ring switches to hold progress (gold, filling).
static func hold_ring(g:CanvasItem,p:Vector2,r:float,progress:float)->void:
	var value=clampf(progress,0,1)
	if value<=0.01: return
	var start=-PI/2
	var end=start+TAU*value
	g.draw_arc(p,r,start,end,72,Color(1,.86,.45,.16),11,true)
	g.draw_arc(p,r,start,end,72,Color("ffe6a1"),4,true)
	g.draw_circle(p+Vector2.from_angle(end)*r,4.5,Color("fff7d9"))

## Time left as a glowing ring: green while there is plenty, yellow past half way, and
## orange to red (with a gentle pulse) as time runs out.
static func time_color(value:float)->Color:
	if value>=0.6: return Color("5de08a")
	if value>=0.3: return Color("5de08a").lerp(Color("ffd45c"),(0.6-value)/0.3)
	return Color("ffd45c").lerp(Color("ff5a4d"),clampf((0.3-value)/0.3,0,1))

static func time_ring(g:CanvasItem,p:Vector2,r:float,fraction_left:float)->void:
	var value=clampf(fraction_left,0,1)
	if value<=0.005: return
	var color=time_color(value)
	var pulse=1.0+(sin(Time.get_ticks_msec()/110.0)*0.07 if value<0.2 else 0.0)
	var start=-PI/2
	var end=start+TAU*value
	for k in 3: g.draw_arc(p,r,start,end,72,Color(color,.07+.05*k),(22-k*5)*pulse,true)
	g.draw_arc(p,r,start,end,72,Color(color,.97),5,true)
	g.draw_arc(p,r,start,end,72,Color(1,1,1,.35),1.6,true)
	g.draw_circle(p+Vector2.from_angle(end)*r,5.0,Color(color.lightened(.5),.95))

## Shared entry: hold progress when holding, otherwise time left.
static func draw(g:CanvasItem,p:Vector2,r:float,remaining:float,total:float,hold:float=0.0)->void:
	if hold>0: hold_ring(g,p,r,hold)
	else: time_ring(g,p,r,remaining/maxf(total,0.001))
