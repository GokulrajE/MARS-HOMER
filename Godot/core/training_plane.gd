extends Control
signal closed
signal saved(angle)
const UI=preload("res://core/ui_theme.gd")
var angle:SpinBox
var status:Label
var apply:Button
var badge:Control
var badge_t=0.0
## The angle most recently sent to the robot. A plane is only saved once the robot has been
## told to go there and has really arrived (a small change is not "already there").
var commanded=INF
const ARRIVED=3.0
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card=UI.card()
	card.position=Vector2(300,220)
	card.custom_minimum_size=Vector2(1000,450)
	add_child(card)
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	card.add_child(column)
	column.add_child(UI.label("Training plane",38))
	column.add_child(UI.label("−90° is horizontal. Choose the angle before assessing or training.",23))
	angle=SpinBox.new()
	angle.min_value=-100
	angle.max_value=0
	angle.step=1
	angle.value=Trial.plane
	angle.suffix="°"
	angle.custom_minimum_size=Vector2(250,60)
	column.add_child(angle)
	column.add_child(UI.label("Changing the plane reloads assessments within Unity’s ±5° tolerance.\nComplete new range and arm-weight assessments when none match.",21,UI.MUTED,true))
	status=UI.label("",22,UI.SKY,true)
	column.add_child(status)
	# Confirmation badge: a green tick that pops in after the plane is saved.
	badge=Control.new()
	badge.custom_minimum_size=Vector2(0,84)
	badge.draw.connect(draw_badge)
	badge.hide()
	column.add_child(badge)
	angle.value_changed.connect(func(_v): badge.hide())
	apply=Button.new()
	apply.custom_minimum_size.y=60
	apply.pressed.connect(apply_plane)
	column.add_child(apply)
	var back=Button.new()
	back.text="Back to movements"
	back.pressed.connect(func(): closed.emit())
	column.add_child(back)
	Nav.set_scope(self,apply_plane,"apply plane",func(): closed.emit(),"back")
func draw_badge()->void:
	var t=clampf(badge_t,0,1)
	var pop=1.0+(1.70158+1.0)*pow(t-1.0,3)+1.70158*pow(t-1.0,2)
	var c=Vector2(40,42)
	for k in 4: badge.draw_circle(c,(36+k*5)*pop,Color(0.25,0.9,0.55,0.05))
	badge.draw_circle(c,30*pop,Color("22c55e"))
	var draw_to=clampf(t*1.6,0,1)
	var a=c+Vector2(-12,2)*pop
	var b=c+Vector2(-3,12)*pop
	var d=c+Vector2(14,-10)*pop
	var tip=b.lerp(d,clampf((draw_to-0.5)*2,0,1))
	badge.draw_polyline(PackedVector2Array([a,a.lerp(b,clampf(draw_to*2,0,1))]),Color.WHITE,5,true)
	if draw_to>0.5: badge.draw_polyline(PackedVector2Array([b,tip]),Color.WHITE,5,true)
	badge.draw_string(UI.FONT,Vector2(92,52),"Saved: %.0f°" % Trial.plane,HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("86efac"))

func show_saved()->void:
	badge.show()
	badge_t=0.0
	var tween=create_tween()
	tween.tween_method(func(v): badge_t=v; badge.queue_redraw(),0.0,1.0,0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	status.add_theme_color_override("font_color",Color("86efac"))
	saved.emit(Trial.plane)

func at_target()->bool:
	return is_equal_approx(commanded,angle.value) and Robot.reached(angle.value,ARRIVED)

func _process(_delta:float)->void:
	apply.disabled=Trial.running or (Trial.hardware and not Robot.ready_for_training())
	if not Trial.hardware: apply.text="Save practice plane"
	elif at_target(): apply.text="Save plane %.0f°" % angle.value
	elif is_equal_approx(commanded,angle.value): apply.text="Moving to %.0f°…" % angle.value
	else: apply.text="Move robot to %.0f°" % angle.value
	if Trial.hardware and not Robot.ready_for_training(): status.text="Connect, calibrate and activate MARS before changing the plane."
func apply_plane()->void:
	if Trial.running: return
	if Trial.hardware:
		if not Robot.ready_for_training(): return
		if not at_target():
			if is_equal_approx(commanded,angle.value):
				status.text="Still moving to %.0f°. Press Save plane when the robot arrives." % angle.value
			elif Robot.move_to(angle.value):
				commanded=angle.value
				status.text="Moving to %.0f°. When the robot arrives, press Save plane." % angle.value
			else: status.text="MARS could not accept the plane change."
			return
	if Records.save_plane(angle.value):
		Records.log_event("Training plane saved: %.0f degrees" % angle.value)
		status.text="✓ Training plane saved: %.0f°. %d matching range assessments available." % [Trial.plane,Records.corners.size()]
		show_saved()
	else: status.text=Records.error
