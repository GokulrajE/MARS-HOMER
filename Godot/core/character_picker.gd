extends Control
signal chosen
signal cancelled
const Cast=preload("res://core/flight_characters.gd")
const UI=preload("res://core/ui_theme.gd")
var selected=Cast.selected()
var buttons:Dictionary={}
var portraits:Dictionary={}
var clock=0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel",UI.box(UI.BG))
	add_child(bg)
	var margin=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,55)
	add_child(margin)
	var page=VBoxContainer.new()
	page.add_theme_constant_override("separation",15)
	margin.add_child(page)
	page.add_child(UI.label("Choose your flying companion",40))
	page.add_child(UI.label("Six personalities. The same training challenge. Select a card to choose your pilot.",22,UI.MUTED))
	var grid=GridContainer.new()
	grid.columns=3
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",18)
	page.add_child(grid)
	for id in Cast.CAST:
		var data=Cast.CAST[id]
		var button=Button.new()
		button.custom_minimum_size=Vector2(470,290)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.size_flags_vertical=Control.SIZE_EXPAND_FILL
		button.set_meta("label",data.name)
		button.pressed.connect(select.bind(id))
		var inner=VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,Control.PRESET_MODE_MINSIZE,12)
		inner.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var art=TextureRect.new()
		art.texture=load("res://assets/art/"+data.file+".png")
		art.custom_minimum_size.y=170
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inner.add_child(art)
		portraits[id]=art
		for label in [UI.label(data.name,28),UI.label(data.mood,18,UI.MUTED)]:
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			inner.add_child(label)
		button.add_child(inner)
		grid.add_child(button)
		buttons[id]=button
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	page.add_child(row)
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for title in ["Back","Start flight"]:
		var button=Button.new()
		button.text=title
		button.custom_minimum_size=Vector2(210,58)
		button.pressed.connect(func():
			if title=="Back": cancelled.emit()
			else:
				Services.settings.set_value("flight","character",selected)
				Services.save()
				chosen.emit())
		row.add_child(button)
	refresh()
	Nav.set_scope(self)
	buttons[selected].grab_focus.call_deferred()
func select(id:String) -> void:
	selected=id
	refresh()
func refresh() -> void:
	for id in buttons:
		buttons[id].add_theme_stylebox_override("normal",UI.box(Color("164e63") if id==selected else UI.PANEL,UI.SKY if id==selected else Color("405169"),3 if id==selected else 1,16,12,12))
func _process(delta:float) -> void:
	clock+=delta
	for id in portraits:
		var art:TextureRect=portraits[id]
		art.pivot_offset=art.size/2
		art.rotation=sin(clock*Cast.CAST[id].bob)*.018
