extends Control
const UI=preload("res://core/ui_theme.gd")
var launcher:Control
var panel:PanelContainer
var readout:Label
var bar:ProgressBar
var slower:Button
var faster:Button
var trail:Array=[]
var mouse=Vector2.ZERO
var cursor_glow=true
var sparks:Array=[]
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=100
	panel=UI.card()
	panel.position=Vector2(1060,110)
	panel.custom_minimum_size=Vector2(500,240)
	add_child(panel)
	var column=VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UI.label("Game speed · Ctrl+G",28))
	readout=UI.label("",20)
	column.add_child(readout)
	# Unity's speed indicator: fills from green (slow) to red (fast) with reach speed / 0.25 m/s.
	bar=ProgressBar.new()
	bar.max_value=1.0
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2(0,16)
	column.add_child(bar)
	column.add_child(UI.label("Arrow keys also work: left = slower, right = faster",17,UI.MUTED))
	var row=HBoxContainer.new()
	column.add_child(row)
	for direction in [-1,1]:
		var b=Button.new()
		b.text="− Slower" if direction<0 else "+ Faster"
		b.custom_minimum_size=Vector2(210,52)
		b.pressed.connect(func(): change_speed(direction*.005))
		row.add_child(b)
		if direction<0: slower=b
		else: faster=b
	var close=Button.new()
	close.text="Close"
	close.pressed.connect(func(): panel.hide())
	column.add_child(close)
	panel.hide()
func change_speed(amount:float)->void:
	if not Trial.running or Trial.game in ["TW","FW","BS"]: return
	var g=launcher.game_node
	var old=Trial.reach_time()
	var old_speed=Trial.speed
	Trial.speed=clampf(Trial.speed+amount,Trial.Rules.MIN_SPEED,Trial.Rules.MAX_SPEED)
	var ratio=Trial.reach_time()/old
	if Trial.game in ["SS","PP","DC","TW","TT","MC","CB"]:
		g.age*=ratio
		if Trial.game=="PP": g.pong_velocity*=old/Trial.reach_time()
		if Trial.game in ["TT","CB"]:
			for gate in g.passed_reefs: gate.speed*=old/Trial.reach_time()
	elif Trial.game=="FR":
		var fraction=g.target_remaining/maxf(.001,g.target_seconds)
		g.target_seconds=Trial.reach_time()
		g.target_remaining=g.target_seconds*fraction
	else:
		var old_limit=maxf(1.45,old) if Trial.game=="FW" else old
		var new_limit=maxf(1.45,Trial.reach_time()) if Trial.game=="FW" else Trial.reach_time()
		g.target_age*=new_limit/old_limit
	Trial.annotation="RS:%.3f | previous:%.3f" % [Trial.speed,old_speed]
	Records.log_event("Manual speed: "+Trial.annotation)
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode==KEY_G and Trial.running and Trial.game not in ["TW","FW","BS"]:
		panel.visible=not panel.visible
		get_viewport().set_input_as_handled()
	if panel.visible and event is InputEventKey and event.pressed and Trial.running:
		if event.keycode in [KEY_LEFT,KEY_DOWN,KEY_MINUS]:
			change_speed(-.005)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_RIGHT,KEY_UP,KEY_EQUAL,KEY_PLUS]:
			change_speed(.005)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and cursor_glow:
		mouse=make_input_local(event).position
		trail.append({"p":mouse,"life":.45})
		if trail.size()>40: trail.pop_front()
		# A few sparkles shed from the head, like a shooting star.
		for k in 2:
			sparks.append({"p":mouse,"v":Vector2.from_angle(randf()*TAU)*randf_range(20,90),"life":.5,"max":.5})
func _process(delta:float)->void:
	for dot in trail: dot.life-=delta
	trail=trail.filter(func(dot): return dot.life>0)
	for spark in sparks:
		spark.life-=delta
		spark.p+=spark.v*delta
	sparks=sparks.filter(func(spark): return spark.life>0)
	if not Trial.running or Trial.game in ["TW","FW","BS"]: panel.hide()
	if panel.visible:
		readout.text="%.3f m/s   •   target duration %.1f s
Range: %.0f × %.0f cm" % [Trial.speed,Trial.reach_time(),Trial.rom.x*100,Trial.rom.y*100]
		var level=clampf(Trial.speed/Trial.Rules.MAX_SPEED,0,1)
		bar.value=level
		bar.add_theme_stylebox_override("fill",UI.box(Color("22c55e").lerp(Color("ef4444"),level),Color.TRANSPARENT,0,8,0,0))
		slower.disabled=Trial.speed<=Trial.Rules.MIN_SPEED+.0001
		faster.disabled=Trial.speed>=Trial.Rules.MAX_SPEED-.0001
	queue_redraw()
func _draw()->void:
	var count=trail.size()
	# Tapered comet tail: wide and faint at the old end, thin and bright at the head.
	for i in range(1,count):
		var a=trail[i].life/.45
		var t=float(i)/count
		draw_line(trail[i-1].p,trail[i].p,Color(.25,.7,1,a*.20),16*t*a+2,true)
		draw_line(trail[i-1].p,trail[i].p,Color(.55,.9,1,a*.45),7*t*a+1,true)
		draw_line(trail[i-1].p,trail[i].p,Color(1,1,1,a*.85),2.4*t*a,true)
	for spark in sparks:
		var f=spark.life/spark.max
		draw_circle(spark.p,2.6*f,Color(.8,.97,1,f*.9))
	if count>0:
		var p:Vector2=trail[-1].p
		var a2:float=clampf(trail[-1].life/.45,0,1)
		for r in 5: draw_circle(p,22-r*4,Color(.4,.85,1,a2*(.05+r*.04)))
		# Four-point star flare with a white core.
		draw_line(p-Vector2(20,0),p+Vector2(20,0),Color(.9,1,1,a2*.75),1.6,true)
		draw_line(p-Vector2(0,20),p+Vector2(0,20),Color(.9,1,1,a2*.75),1.6,true)
		draw_line(p-Vector2(9,9),p+Vector2(9,9),Color(.8,.95,1,a2*.4),1.0,true)
		draw_line(p-Vector2(9,-9),p+Vector2(9,-9),Color(.8,.95,1,a2*.4),1.0,true)
		draw_circle(p,4,Color(1,1,1,a2))
