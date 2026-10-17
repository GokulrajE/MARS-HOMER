extends Control
## Connect to MARS and watch everything it reports, before logging in. The fields follow
## Unity's DiagnosticSceneHandler: device and firmware, packet and frame rate, status and
## error flags, calibration, limb and control, robot and IMU angles, end-point position,
## force, target / desired / control, the handle button and (diagnostics stream) the
## controller terms.
signal closed
var back_text = "‹  Back to login"
const UITheme = preload("res://core/ui_theme.gd")
const Protocol = preload("res://core/protocol.gd")
const KINDS = ["VERSION", "SENSORSTREAM", "CONTROLPARAM", "DIAGNOSTICS"]
const COMMANDS = ["NONE", "SUCCESS", "FAIL"]
const LIMBS = ["NOLIMB", "RIGHT", "LEFT"]
const CONTROLS = ["NONE", "POSITION"]
var port_edit: LineEdit
var status: Label
var rows: Dictionary = {}
var diag_only: Array = []
var arrivals: Array = []
var sensor_button: Button
var diag_button: Button
var timer = 0.0
const LOG_DIR = "user://diagnostics"
const LOG_HEADER = "DateTime,DeviceRunTime,PacketNumber,Stream,Error,Limb,Calibration,ControlType,CommandStatus,Button,Angle1,Angle2,Angle3,Angle4,ImuAngle1,ImuAngle2,ImuAngle3,ImuAngle4,Force,Target,Desired,Control,ErrP,ErrD,ErrI,GravityComp,AngularVelocity,EndpointX,EndpointY,EndpointZ,PlaneZ,PlaneY"
var limb_picker: OptionButton
var limb_synced = false
var calibrate_button: Button
var position_toggle: CheckButton
var target_slider: HSlider
var target_label: Label
var set_target_button: Button
var log_toggle: CheckButton
var log_label: Label
var log_file: FileAccess
var log_path = ""
var log_rows = 0
var controls_note: Label
const IDLE_LOG = "Not logging. Files are kept in one common diagnostics folder."

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Robot.sample_received.connect(func(_packet): arrivals.append(Time.get_ticks_msec()))
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var head = HBoxContainer.new()
	page.add_child(head)
	head.add_child(UITheme.label("Device diagnostics", 40, UITheme.SKY))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var back = button(back_text, func(): closed.emit(), 250)
	head.add_child(back)
	page.add_child(UITheme.label("Connect the robot to see what it reports. Only the Control card can move the arm (Set target).", 20, UITheme.MUTED))
	var connection = PanelContainer.new()
	connection.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.13, 0.66), Color(1, 1, 1, 0.14), 1, 22, 18, 12))
	page.add_child(connection)
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	connection.add_child(bar)
	bar.add_child(UITheme.label("Port", 21))
	port_edit = LineEdit.new()
	port_edit.text = str(Services.settings.get_value("device", "port", Robot.default_port()))
	port_edit.placeholder_text = Robot.example_port()
	port_edit.custom_minimum_size = Vector2(300, 52)
	bar.add_child(port_edit)
	bar.add_child(button("Find", find_ports, 90))
	var connect_button = button("Connect", connect_robot, 150)
	accent(connect_button)
	bar.add_child(connect_button)
	bar.add_child(button("Disconnect", Robot.disconnect_port, 150))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	sensor_button = button("Sensor stream", func(): Robot.command(PackedByteArray([4])), 190)
	diag_button = button("Diagnostics stream", func(): Robot.command(PackedByteArray([8])), 220)
	bar.add_child(sensor_button)
	bar.add_child(diag_button)
	status = UITheme.label("", 21, UITheme.FOCUS, true)
	page.add_child(status)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	var top_left = VBoxContainer.new()
	top_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_left)
	var top_right = VBoxContainer.new()
	top_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_right)
	controls_card(top_left)
	log_card(top_right)
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	columns.add_child(right)
	group(left, "Device", [["time", "Time"], ["version", "Firmware"], ["connection", "Connection"], ["runtime", "Device time"], ["packet", "Packet number"], ["rate", "Frame rate"]])
	group(left, "State", [["stream", "Stream"], ["error", "Error"], ["calibration", "Calibration"], ["command", "Command status"], ["limb", "Limb"], ["control", "Control"], ["button", "MARS button"]])
	group(right, "Joints", [["angles", "Robot angles (°)"], ["imu", "IMU angles (°)"], ["endpoint_plane", "End point (plane, m)"], ["endpoint", "End point (m)"]])
	group(right, "Force and control", [["force", "Force (N)"], ["target", "Target (°)"], ["desired", "Desired (°)"], ["output", "Control output"]])
	group(right, "Controller (diagnostics stream)", [["err_p", "Error P"], ["err_d", "Error D"], ["err_i", "Error I"], ["gravity", "Gravity compensation"], ["velocity", "Angular velocity"]])
	Nav.set_scope(self)
	refresh()

func card_box(parent: Node, title: String) -> VBoxContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.13, 0.62), Color(1, 1, 1, 0.12), 1, 20, 20, 14))
	parent.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(UITheme.label(title, 22, UITheme.ACCENT.lightened(0.35)))
	return column

## The controls of Unity's diagnostics scene: limb, calibrate, position control and a target.
func controls_card(parent: Node) -> void:
	var column = card_box(parent, "Control")
	var limb_row = HBoxContainer.new()
	limb_row.add_theme_constant_override("separation", 12)
	column.add_child(limb_row)
	limb_row.add_child(UITheme.label("Limb", 20, UITheme.MUTED))
	limb_picker = OptionButton.new()
	for name in ["No limb", "Right", "Left"]: limb_picker.add_item(name)
	limb_picker.custom_minimum_size = Vector2(170, 48)
	limb_picker.item_selected.connect(func(index): Robot.command(PackedByteArray([2, index])))
	limb_row.add_child(limb_picker)
	calibrate_button = button("Calibrate", do_calibrate, 170)
	limb_row.add_child(calibrate_button)
	position_toggle = CheckButton.new()
	position_toggle.text = "Position control"
	position_toggle.custom_minimum_size = Vector2(0, 48)
	position_toggle.toggled.connect(func(on): Robot.command(PackedByteArray([6, 1 if on else 0])))
	column.add_child(position_toggle)
	var target_row = HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 12)
	column.add_child(target_row)
	target_slider = HSlider.new()
	target_slider.min_value = -120
	target_slider.max_value = 0
	target_slider.step = 1
	target_slider.value = -90
	target_slider.custom_minimum_size = Vector2(250, 40)
	target_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	target_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_slider.value_changed.connect(func(value): target_label.text = "%+d°" % int(value))
	target_row.add_child(target_slider)
	target_label = UITheme.label("-90°", 22, Color.WHITE)
	target_label.custom_minimum_size.x = 70
	target_row.add_child(target_label)
	set_target_button = button("Set target", do_set_target, 150)
	target_row.add_child(set_target_button)
	controls_note = UITheme.label("The arm moves when you set a target. Keep clear of it.", 18, UITheme.MUTED, true)
	column.add_child(controls_note)

func do_calibrate() -> void:
	controls_note.text = "Calibration requested; wait for MARS to confirm." if Robot.calibrate() else "Calibration needs a connection and IMU angles within ±50°."

func do_set_target() -> void:
	if Robot.move_to(target_slider.value): controls_note.text = "Moving to %d°…" % int(target_slider.value)
	else: controls_note.text = "Turn on position control first (it needs calibration)."

## Data logging goes to one common folder, whichever patient is logged in.
func log_card(parent: Node) -> void:
	var column = card_box(parent, "Data log")
	log_toggle = CheckButton.new()
	log_toggle.text = "Log data to file"
	log_toggle.custom_minimum_size = Vector2(0, 48)
	log_toggle.toggled.connect(func(on):
		if on: start_log()
		else: stop_log())
	column.add_child(log_toggle)
	log_label = UITheme.label(IDLE_LOG, 18, UITheme.MUTED, true)
	column.add_child(log_label)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	column.add_child(row)
	row.add_child(button("Open folder", open_folder, 160))
	row.add_child(button("Open latest", open_latest, 160))
	row.add_child(button("Copy path", copy_path, 140))
	row.add_child(button("Copy data", copy_data, 140))
	row.add_child(button("Save a copy…", save_copy, 170))

static func log_dir_path() -> String:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	return ProjectSettings.globalize_path(LOG_DIR)

## Newest MARS_Data_*.csv (names carry a sortable timestamp), or "".
static func latest_log() -> String:
	var directory = DirAccess.open(LOG_DIR)
	if directory == null: return ""
	var newest = ""
	for name in directory.get_files():
		if name.begins_with("MARS_Data_") and name.ends_with(".csv") and name > newest: newest = name
	return "" if newest == "" else LOG_DIR.path_join(newest)

func start_log() -> void:
	stop_log(false)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var stamp = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	log_path = LOG_DIR.path_join("MARS_Data_%s.csv" % stamp)
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file == null:
		log_label.text = "Could not create the log file."
		log_toggle.set_pressed_no_signal(false)
		return
	log_file.store_line("DeviceID: %s" % (Robot.version if Robot.version != "" else "unknown"))
	log_file.store_line(LOG_HEADER)
	log_rows = 0
	if not Robot.sample_received.is_connected(log_sample): Robot.sample_received.connect(log_sample)

func stop_log(update: bool = true) -> void:
	if log_file != null:
		log_file.flush()
		log_file.close()
		log_file = null
		if update: log_label.text = "Saved %d rows to %s" % [log_rows, log_path.get_file()]
	elif update: log_label.text = IDLE_LOG

func log_sample(packet: Dictionary) -> void:
	if log_file == null or not packet.has("sensors"): return
	var s: Array = packet.sensors
	var row: PackedStringArray = [Time.get_datetime_string_from_system(false, true), str(packet.runtime), str(packet.number), KINDS[clampi(int(packet.get("kind", 1)), 0, 3)], str(packet.error), LIMBS[clampi(int(packet.limb), 0, 2)], str(packet.calibration), CONTROLS[clampi(int(packet.control_type), 0, 1)], COMMANDS[clampi(int(packet.get("command_status", 0)), 0, 2)], str(packet.button)]
	for i in 8: row.append(str(s[i]))
	row.append(str(packet.force))
	for i in range(9, 12): row.append(str(s[i]))
	for i in range(12, 17): row.append(str(s[i]) if s.size() > i else "")
	for i in 3: row.append(str(packet.endpoint[i]))
	row.append(str(packet.plane_endpoint.x))
	row.append(str(packet.plane_endpoint.y))
	log_file.store_csv_line(row)
	log_rows += 1
	if log_rows % 50 == 0: log_file.flush()

func open_folder() -> void:
	OS.shell_open(log_dir_path())

func open_latest() -> void:
	var latest = latest_log()
	if latest == "":
		log_label.text = "No log file yet. Turn on logging first."
		return
	if log_file != null: log_file.flush()
	OS.shell_open(ProjectSettings.globalize_path(latest))

func copy_path() -> void:
	var latest = latest_log()
	if latest == "":
		log_label.text = "No log file yet."
		return
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(latest))
	log_label.text = "Path copied: " + ProjectSettings.globalize_path(latest)

func copy_data() -> void:
	var latest = latest_log()
	if latest == "":
		log_label.text = "No log file yet."
		return
	if log_file != null: log_file.flush()
	var text = FileAccess.get_file_as_string(latest)
	if text.length() > 2000000:
		log_label.text = "That file is too large to copy as text. Use Save a copy."
		return
	DisplayServer.clipboard_set(text)
	log_label.text = "Copied the contents of %s to the clipboard." % latest.get_file()

func save_copy() -> void:
	var latest = latest_log()
	if latest == "":
		log_label.text = "No log file yet."
		return
	if log_file != null: log_file.flush()
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "Save a copy of the latest diagnostics log"
	dialog.current_file = latest.get_file()
	dialog.filters = PackedStringArray(["*.csv ; CSV data"])
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		log_label.text = ("Saved a copy to " + path) if DirAccess.copy_absolute(ProjectSettings.globalize_path(latest), path) == OK else "Could not save the copy."
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.7)

func _exit_tree() -> void:
	stop_log(false)

func button(text: String, action: Callable, width: float) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(width, 52)
	node.pressed.connect(action)
	return node

func accent(node: Button) -> void:
	node.add_theme_stylebox_override("normal", UITheme.box(Color("0f766e"), UITheme.ACCENT, 1, 12, 20, 10))
	node.add_theme_stylebox_override("hover", UITheme.box(UITheme.ACCENT, UITheme.SKY, 2, 12, 20, 10))

func group(parent: Node, title: String, items: Array) -> void:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.08, 0.13, 0.62), Color(1, 1, 1, 0.12), 1, 20, 20, 14))
	parent.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	column.add_child(UITheme.label(title, 22, UITheme.ACCENT.lightened(0.35)))
	for item in items:
		var row = HBoxContainer.new()
		column.add_child(row)
		var key = UITheme.label(item[1], 20, UITheme.MUTED)
		key.custom_minimum_size.x = 210
		row.add_child(key)
		var value = UITheme.label("–", 21, Color.WHITE, true)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
		rows[item[0]] = value
		if title.begins_with("Controller"): diag_only.append(value)

func find_ports() -> void:
	var ports = Robot.list_ports()
	if ports.is_empty():
		status.text = "No serial ports found. On a Raspberry Pi pair the robot, then use sudo rfcomm bind 0 <address> or type bt:<address>."
		return
	var index = ports.find(port_edit.text.strip_edges())
	port_edit.text = ports[(index + 1) % ports.size()]
	status.text = "Ports found: " + ", ".join(ports) + ". Press Find again for the next."

func connect_robot() -> void:
	var name = Robot.normalize_port(port_edit.text)
	if name == "":
		status.text = "Enter a port first."
		return
	Services.settings.set_value("device", "port", name)
	Services.save()
	Robot.connect_port(name)

func fmt(value: float) -> String:
	return "%+.2f" % value

func list_text(values: Array) -> String:
	var parts: Array = []
	for v in values: parts.append("%+7.2f" % v)
	return "   ".join(parts)

func _process(delta: float) -> void:
	timer += delta
	if timer >= 0.1:
		timer = 0.0
		refresh()

func refresh() -> void:
	var now = Time.get_ticks_msec()
	arrivals = arrivals.filter(func(t): return now - t <= 1000)
	var packet: Dictionary = Robot.last_packet
	var live = Robot.healthy()
	if Robot.connected or Robot.enabled or status.text == "": status.text = Robot.message
	rows.time.text = Time.get_datetime_string_from_system(false, true)
	rows.version.text = Robot.version if Robot.version != "" else "–"
	rows.connection.text = "Streaming" if live else ("Connected, waiting for data" if Robot.connected else "Not connected")
	rows.rate.text = "%d Hz" % arrivals.size()
	var has_data = packet.has("sensors")
	var kind = int(packet.get("kind", 1))
	sensor_button.disabled = not Robot.connected or kind == 1
	calibrate_button.disabled = not live or packet.get("calibration", 0) == 1 or int(packet.get("limb", 0)) == 0
	calibrate_button.text = "Calibrated ✓" if packet.get("calibration", 0) == 1 else "Calibrate"
	position_toggle.disabled = not live or packet.get("calibration", 0) != 1
	position_toggle.set_pressed_no_signal(packet.get("control_type", 0) == 1)
	set_target_button.disabled = not live or packet.get("control_type", 0) != 1
	if packet.has("limb") and not limb_synced:
		limb_synced = true
		limb_picker.select(clampi(int(packet.limb), 0, 2))
	if log_file != null: log_label.text = "Logging: %d rows  ->  %s" % [log_rows, log_path.get_file()]
	diag_button.disabled = not Robot.connected or kind == 3
	if not has_data:
		for key in rows:
			if key not in ["time", "version", "connection", "rate"]: rows[key].text = "–"
		return
	var sensors: Array = packet.sensors
	rows.runtime.text = "%.3f s" % packet.runtime
	rows.packet.text = str(packet.number)
	rows.stream.text = KINDS[clampi(kind, 0, 3)]
	rows.error.text = "NOERROR" if packet.error == 0 else Protocol.error_text(packet.error)
	rows.error.add_theme_color_override("font_color", Color("5de08a") if packet.error == 0 else Color("ff8a7a"))
	rows.calibration.text = "YESCALIB" if packet.calibration == 1 else "NOCALIB"
	rows.command.text = COMMANDS[clampi(int(packet.get("command_status", 0)), 0, 2)]
	rows.limb.text = LIMBS[clampi(int(packet.limb), 0, 2)]
	rows.control.text = CONTROLS[clampi(int(packet.control_type), 0, 1)]
	rows.button.text = "Pressed" if packet.button == 0 else "Released"
	rows.angles.text = list_text(sensors.slice(0, 4))
	rows.imu.text = list_text(sensors.slice(4, 8))
	var plane: Vector2 = packet.plane_endpoint
	rows.endpoint_plane.text = "z %+.3f   y %+.3f" % [plane.x, plane.y]
	var ep: Vector3 = packet.endpoint
	rows.endpoint.text = "x %+.3f   y %+.3f   z %+.3f" % [ep.x, ep.y, ep.z]
	rows.force.text = "%.2f" % packet.force
	rows.target.text = "–" if sensors[9] == 999 else fmt(sensors[9])
	rows.desired.text = "–" if sensors[10] == 999 else fmt(sensors[10])
	rows.output.text = fmt(sensors[11])
	var diagnostics = sensors.size() >= 17
	for label in diag_only: label.modulate.a = 1.0 if diagnostics else 0.35
	rows.err_p.text = fmt(sensors[12]) if diagnostics else "switch to the diagnostics stream"
	rows.err_d.text = fmt(sensors[13]) if diagnostics else "–"
	rows.err_i.text = fmt(sensors[14]) if diagnostics else "–"
	rows.gravity.text = fmt(sensors[15]) if diagnostics else "–"
	rows.velocity.text = fmt(sensors[16]) if diagnostics else "–"
