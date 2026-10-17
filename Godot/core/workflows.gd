extends Control
signal closed
## Set in first-time setup: only the patient plan is shown, and saving it signals `completed`.
signal completed
var setup_mode=false
var nav_buttons: Array=[]
var back_button: Button
var tabs: TabContainer
var device_status: Label
var message: Label
var fields: Dictionary={}
var port: LineEdit
var port_result: Label
var shell: MarginContainer

func text(parent: Node,value: String) -> Label:
	var label=Label.new()
	label.text=value
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func action(parent: Node,title: String,callback: Callable) -> Button:
	var button=Button.new()
	button.text=title
	button.custom_minimum_size=Vector2(0,52)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func field(parent: Node,name: String,value: String) -> LineEdit:
	var row=HBoxContainer.new()
	parent.add_child(row)
	var label=text(row,name)
	label.custom_minimum_size.x=230
	var edit=LineEdit.new()
	edit.text=value
	edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit

func page(title: String) -> VBoxContainer:
	var scroll=ScrollContainer.new()
	scroll.name=title
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	return box

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left",50)
	shell.add_theme_constant_override("margin_right",50)
	shell.add_theme_constant_override("margin_top",24)
	shell.add_theme_constant_override("margin_bottom",48)
	add_child(shell)
	var column=VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	shell.add_child(column)
	tabs=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	# Tabs are switched with the Previous / Next section buttons, which one-button
	# MARS navigation can reach; the tab headers stay clickable for the mouse.
	column.add_child(tabs)
	var patient=page("Patient & plan")
	text(patient,"User: "+Trial.user_id+" • Save prescriptions and patient details here.")
	var today=Trial.stamp().left(10)
	var formatted=today.substr(8,2)+"-"+today.substr(5,2)+"-"+today.substr(0,4)+" 00:00:00"
	var end_date=Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today+"T00:00:00")+28*86400)
	var end_formatted=end_date.substr(8,2)+"-"+end_date.substr(5,2)+"-"+end_date.substr(0,4)+" 23:59:59"
	var defaults={"HomerID":Trial.user_id,"StartDate":formatted,"EndDate":end_formatted,"ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"RIGHT","Location":"","Group":"Experimental"}
	for key in defaults:
		if key=="TrainingSide": fields[key]=side_picker(patient,str(Records.profile.get(key,defaults[key])))
		else: fields[key]=field(patient,key,str(Records.profile.get(key,defaults[key])))
	action(patient,"Save profile and prescription",save_profile)
	var device=page("Device & setup")
	text(device,"Enter the serial port MARS uses, then save and test it. The port is stored on this computer and used automatically when a patient starts training.")
	device_status=text(device,"Disconnected")
	port=field(device,"Serial port",str(Services.settings.get_value("device","port",Robot.default_port())))
	port.placeholder_text=Robot.example_port()
	action(device,"Save port and test connection",save_and_test_port)
	port_result=text(device,"")
	var services=page("Uploads & services")
	var enabled=CheckButton.new()
	enabled.text="Mark completed trials for the installed MARS uploader"
	enabled.button_pressed=Services.uploads_enabled
	enabled.toggled.connect(func(value): Services.uploads_enabled=value; Services.save())
	services.add_child(enabled)
	var agent=CheckButton.new()
	agent.text="Use local session agent (127.0.0.1:5055) at login"
	agent.button_pressed=Services.agent_enabled
	agent.toggled.connect(func(value): Services.agent_enabled=value; Services.save())
	services.add_child(agent)
	for pair in [["Python executable","python_path"],["MARS uploader script","uploader"],["NeuroDash sender script","sender"],["Upload status file","upload_status"]]:
		var edit=field(services,pair[0],Services.get(pair[1]))
		edit.text_changed.connect(func(value): Services.set(pair[1],value); Services.save())
	action(services,"Upload saved data now",Services.upload_now)
	action(services,"Open NeuroDash login",func(): Services.neurodash(true))
	action(services,"Send data to NeuroDash",func(): Services.neurodash(false))
	var service_status=text(services,"")
	fields["service_status"]=service_status
	message=Label.new()
	message.custom_minimum_size.y=56
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color",Color("38bdf8"))
	column.add_child(message)
	var bottom=HBoxContainer.new()
	bottom.add_theme_constant_override("separation",12)
	column.add_child(bottom)
	nav_buttons.append(action(bottom,"◂ Previous section",func(): step_tab(-1)))
	nav_buttons.append(action(bottom,"Next section ▸",func(): step_tab(1)))
	for b in nav_buttons: b.custom_minimum_size.x=260
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	back_button=action(bottom,"Back to login" if setup_mode else "Back to games",func(): closed.emit())
	back_button.custom_minimum_size.x=240
	tabs.tab_changed.connect(func(_index): message.text="")
	Nav.advanced_changed.connect(apply_advanced)
	apply_advanced()
	if setup_mode:
		fields["HomerID"].text=Trial.user_id
		fields["HomerID"].editable=false
		message.text="New patient: please set up the plan and save it to continue."

## Only the patient plan is shown normally; Ctrl+Shift+X reveals every other section.
func apply_advanced() -> void:
	var show_all=Nav.advanced and not setup_mode
	tabs.tabs_visible=show_all
	for i in range(1,tabs.get_tab_count()): tabs.set_tab_hidden(i,not show_all)
	if not show_all: tabs.current_tab=0
	for b in nav_buttons: b.visible=show_all

## Training side is a choice, not free text.
func side_picker(parent: Node, current: String) -> OptionButton:
	var row=HBoxContainer.new()
	parent.add_child(row)
	var label=text(row,"TrainingSide")
	label.custom_minimum_size.x=230
	var picker=OptionButton.new()
	picker.add_item("RIGHT")
	picker.add_item("LEFT")
	picker.select(1 if current.to_upper()=="LEFT" else 0)
	picker.custom_minimum_size=Vector2(260,52)
	row.add_child(picker)
	return picker

func step_tab(direction: int) -> void:
	tabs.current_tab=posmod(tabs.current_tab+direction,tabs.get_tab_count())
	var scroll=tabs.get_current_tab_control()
	if scroll is ScrollContainer: scroll.scroll_vertical=0
	message.text="Section: "+scroll.name

func save_profile() -> void:
	var values: Dictionary={}
	for key in Records.CONFIG_HEADER.split(","):
		if fields.has(key): values[key]=fields[key].text.strip_edges()
	for key in ["ML","AP","MLAP","ForeArmLength","UpperArmLength"]:
		if not str(values[key]).is_valid_float() or float(values[key])<0:
			message.text="Enter a valid non-negative number for "+key
			return
	if str(values.TrainingSide).to_upper() not in ["LEFT","RIGHT"]:
		message.text="TrainingSide must be LEFT or RIGHT."
		return
	values.TrainingSide=str(values.TrainingSide).to_upper()
	values.TotalTime=str(float(values.ML)+float(values.AP)+float(values.MLAP))
	for key in ["StartDate","EndDate"]:
		var value=str(values[key])
		if value.length()!=19 or value.substr(2,1)!="-" or value.substr(5,1)!="-":
			message.text="Dates must use dd-MM-yyyy HH:mm:ss."
			return
		var iso=value.substr(6,4)+"-"+value.substr(3,2)+"-"+value.substr(0,2)+"T"+value.substr(11)
		var parsed=Time.get_unix_time_from_datetime_string(iso)
		if Time.get_datetime_string_from_unix_time(parsed)!=iso:
			message.text="Invalid calendar date: "+key
			return
	var start=str(values.StartDate)
	var end=str(values.EndDate)
	if start.substr(6,4)+start.substr(3,2)+start.substr(0,2)>end.substr(6,4)+end.substr(3,2)+end.substr(0,2):
		message.text="EndDate must be on or after StartDate."
		return
	if Records.save_profile(values):
		message.text="Profile and prescription saved."
		if setup_mode: completed.emit()
	else: message.text=Records.error


func _process(_delta: float) -> void:
	device_status.text=Robot.message+(" • "+Robot.version if Robot.version!="" else "")
	update_port_test()
	fields.service_status.text=Services.message

## Saves the port to the settings file, then reports whether MARS answers on it.
func save_and_test_port() -> void:
	var name=Robot.normalize_port(port.text)
	if not Robot.valid_port(name):
		port_result.text="Enter a valid port, for example %s." % Robot.example_port()
		return
	Services.settings.set_value("device","port",name)
	Services.save()
	Robot.connect_port(name)
	testing_port=true
	port_result.text="Saved. Testing %s…" % name

var testing_port=false
func update_port_test() -> void:
	if not testing_port: return
	if Robot.healthy():
		testing_port=false
		port_result.text="Connected: MARS is sending data. The port is saved and will be used automatically."
	elif not Robot.enabled:
		testing_port=false
		port_result.text="Could not connect: "+Robot.message
