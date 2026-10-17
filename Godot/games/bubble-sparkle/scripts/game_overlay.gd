extends Control

var trail: Array[Dictionary] = []
var last_position := Vector2(-1000,-1000)
var clock := 0.0

func _process(delta: float) -> void:
	var game = get_parent()
	if game.paused: return
	clock += delta
	for dot in trail: dot.life -= delta
	trail = trail.filter(func(dot): return dot.life > 0)
	if game.pointer_visible and not game.reduced and game.pointer_position.distance_to(last_position) > 4:
		trail.append({"pos": game.pointer_position, "life": 0.24})
		if trail.size() > 18: trail.pop_front()
		last_position = game.pointer_position
	if game.reduced: trail.clear()
	queue_redraw()

func _draw() -> void:
	var game = get_parent()
	if not game.pointer_visible: return
	if not get_viewport().get_visible_rect().has_point(game.pointer_position): return
	for dot in trail:
		var fraction: float = dot.life / 0.24
		draw_circle(dot.pos,7*fraction,Color(0.5,0.93,1,fraction*0.24))
	var pos: Vector2 = game.pointer_position
	var near: bool = not game.complete and game.cooldown <= 0 and pos.distance_to(game.target) <= 73
	var color := Color("ffe7a3") if near else Color("9eeeff")
	var radius := 7.0 if game.pointer_down else 9.0
	for i in range(5,0,-1): draw_circle(pos,radius+i*3,Color(color,0.025))
	draw_circle(pos,radius,Color(color,0.6))
	draw_arc(pos,radius+4,0,TAU,40,Color(color,0.75),1.5,true)
	draw_circle(pos,3,Color("ffffff"))
