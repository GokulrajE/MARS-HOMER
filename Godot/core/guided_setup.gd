extends Control
## Unity ROBOTCALIB -> CHOOSEPLANE -> MARSSETUP as one guided sequence, and the
## MARSSETUP "deactivate" branch used when a session ends. Each step's single
## action is the MARS button's primary tap.
signal finished(result)
signal cancelled
const UITheme = preload("res://core/ui_theme.gd")
const VideoCard = preload("res://core/video.gd")
const STEPS = ["Calibrate", "Activate", "Attach arm", "Training plane", "Ready"]
const ARM_ATTACHED = 10.0
const HAND_ON = 15.0
const CALIB_LIMIT = 50.0
const REACH_TOLERANCE = 10.0
enum { CALIBRATE, ACTIVATE, ACTIVATING, ATTACH, CHOOSE_PLANE, SETTING_PLANE, READY, REMOVE, OFF }
var state = CALIBRATE
var shutdown = false
var instruction: Label
var status: Label
var steps_bar: HBoxContainer
var video: PanelContainer
var plane_row: HBoxContainer
var plane_slider: HSlider
var plane_value: Label
var action_button: Button
var limb_sent = 0.0
var move_sent = 0.0
var plane_known = false
var built_step = -1
var connect_row: HBoxContainer
var port_edit: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plane_known = not Records.table(Trial.user_path().path_join("trainingplane/trainingplane.csv")).is_empty()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_bottom", 54)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	page.add_child(UITheme.label("Preparing MARS to switch off" if shutdown else "Set up MARS", 40, UITheme.ACCENT))
	steps_bar = HBoxContainer.new()
	steps_bar.add_theme_constant_override("separation", 10)
	page.add_child(steps_bar)
	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	body.add_child(left)
	instruction = UITheme.label("", 36, UITheme.FOCUS, true)
	left.add_child(instruction)
	status = UITheme.label("", 24, UITheme.TEXT, true)
	left.add_child(status)
	connect_row = HBoxContainer.new()
	connect_row.add_theme_constant_override("separation", 10)
	left.add_child(connect_row)
	connect_row.add_child(UITheme.label("Serial port", 22))
	port_edit = LineEdit.new()
	port_edit.text = str(Services.settings.get_value("device", "port", Robot.default_port()))
	port_edit.placeholder_text = Robot.example_port()
	port_edit.custom_minimum_size = Vector2(300, 56)
	connect_row.add_child(port_edit)
	var find = make_button("Find", find_ports, 90)
	find.tooltip_text = "List the serial ports and Bluetooth devices this computer offers"
	connect_row.add_child(find)
	plane_row = HBoxContainer.new()
	plane_row.add_theme_constant_override("separation", 10)
	left.add_child(plane_row)
	plane_row.add_child(make_button("−5°", func(): plane_slider.value -= 5, 90))
	plane_slider = HSlider.new()
	plane_slider.min_value = -100
	plane_slider.max_value = 0
	plane_slider.step = 1
	plane_slider.value = Trial.plane
	plane_slider.custom_minimum_size = Vector2(420, 40)
	plane_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plane_row.add_child(plane_slider)
	plane_row.add_child(make_button("+5°", func(): plane_slider.value += 5, 90))
	plane_value = UITheme.label("", 28)
	plane_row.add_child(plane_value)
	action_button = make_button("", primary, 420)
	left.add_child(action_button)
	video = VideoCard.new()
	video.hide_when_idle = true
	video.custom_minimum_size.x = 460
	video.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(video)
	var bottom = HBoxContainer.new()
	page.add_child(bottom)
	bottom.add_child(make_button("◂ Back", func(): cancelled.emit(), 150))
	state = REMOVE if shutdown else CALIBRATE
	auto_connect()
	Nav.tip("setup", "In this step the MARS button does the one thing shown on screen. Press it once to continue.")
	Nav.set_scope(self, primary, "continue", func(): cancelled.emit(), "go back")

func make_button(title: String, action: Callable, width: float) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width, 60)
	button.pressed.connect(action)
	return button

func imu() -> Array:
	if not Robot.last_packet.has("sensors"): return []
	return Robot.last_packet.sensors.slice(4, 8)

func angles_ok() -> bool:
	var values = imu()
	if values.size() < 4: return false
	for value in values:
		if absf(value) > CALIB_LIMIT: return false
	return true

func attached() -> bool:
	return Robot.healthy() and Robot.last_packet.get("force", 0.0) > ARM_ATTACHED

func hand_on() -> bool:
	return Robot.healthy() and Robot.last_packet.get("force", 0.0) > HAND_ON

func current_step() -> int:
	match state:
		CALIBRATE: return 0
		ACTIVATE, ACTIVATING: return 1
		ATTACH: return 2
		CHOOSE_PLANE, SETTING_PLANE: return 3
	return 4

## The single action for the current step: what Unity's button release did.
## Fills the field with the first port the system reports and lists them all.
func find_ports() -> void:
	var ports = Robot.list_ports()
	if ports.is_empty():
		status.text = "No serial ports found. On a Raspberry Pi pair the robot, then use sudo rfcomm bind 0 <address>, or type bt:<address>."
		return
	var index = ports.find(port_edit.text.strip_edges())
	port_edit.text = ports[(index + 1) % ports.size()]
	status.text = "Ports found: " + ", ".join(ports) + ". Press Find again to try the next."

## A saved, valid port is connected as soon as setup opens, so the patient only has to press
## the MARS button. (Skipped when running scripted tests.)
func auto_connect() -> void:
	if shutdown or Robot.connected or Robot.enabled or "--script" in OS.get_cmdline_args(): return
	var saved = Robot.normalize_port(str(Services.settings.get_value("device", "port", "")))
	if saved == "" or not Robot.valid_port(saved): return
	port_edit.text = saved
	connect_robot()
	status.text = "Connecting to %s automatically…" % saved

func connect_robot() -> void:
	var port_name = Robot.normalize_port(port_edit.text)
	if port_name == "": return
	Services.settings.set_value("device", "port", port_name)
	Services.save()
	Robot.connect_port(port_name)

func primary() -> void:
	if state == OFF:
		finished.emit("shutdown")
		return
	# Lowering the arm only ever disconnects, even when telemetry looks unhealthy: pressing the
	# button here must never start a new connection.
	if shutdown and state == REMOVE:
		if not hand_on():
			Robot.disconnect_port(false)
			state = OFF
		return
	if not Robot.healthy():
		# A live link that reports an error is not reconnected (that would drop the arm's control).
		if Robot.connected: status.text = Robot.message
		else: connect_robot()
		return
	match state:
		CALIBRATE:
			if Robot.calibrate(): status.text = "Calibration requested. Wait for MARS to confirm."
		ACTIVATE:
			Robot.command(PackedByteArray([6, 1]))
			state = ACTIVATING
		ATTACH:
			if attached(): state = CHOOSE_PLANE if not plane_known else SETTING_PLANE
		CHOOSE_PLANE:
			var target = plane_slider.value
			if Robot.reached(target) and Robot.last_packet.get("control_type", 0) == 1:
				if Records.save_plane(target):
					plane_known = true
					state = READY
			else: Robot.move_to(target)
		REMOVE:
			if not hand_on():
				# Just drop the Bluetooth connection: no target, no control command, no waiting.
				Robot.disconnect_port(false)
				state = OFF
		READY:
			finished.emit("ready")
		OFF:
			finished.emit("shutdown")

func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var healthy = Robot.healthy()
	if not shutdown and state == CALIBRATE:
		var side = 1 if str(Records.profile.get("TrainingSide", "RIGHT")).to_upper() == "RIGHT" else 2
		if healthy and Robot.last_packet.get("limb", 0) != side and now - limb_sent > 0.5:
			limb_sent = now
			Robot.command(PackedByteArray([2, side]))
		if healthy and Robot.last_packet.get("calibration", 0) == 1: state = ACTIVATE
	elif state == ACTIVATING and Robot.ready_for_training():
		if Robot.reached(-90): state = ATTACH
		elif now - move_sent > 1.0:
			move_sent = now
			Robot.move_to(-90)
	elif state == SETTING_PLANE and Robot.ready_for_training():
		if Robot.reached(Trial.plane): state = READY
		elif now - move_sent > 1.0:
			move_sent = now
			Robot.move_to(Trial.plane)
	if state == ACTIVATE and not healthy: state = CALIBRATE
	refresh(healthy or state == OFF)

func refresh(healthy: bool) -> void:
	if not shutdown and built_step != current_step():
		built_step = current_step()
		for child in steps_bar.get_children(): child.queue_free()
		for i in STEPS.size():
			var chip = Label.new()
			chip.text = "%d  %s" % [i + 1, STEPS[i]]
			chip.add_theme_font_size_override("font_size", 20)
			var active = i == current_step()
			var done = i < current_step()
			chip.add_theme_color_override("font_color", Color.WHITE if active else UITheme.ACCENT if done else UITheme.MUTED)
			chip.add_theme_stylebox_override("normal", UITheme.box(UITheme.BUTTON if active else Color.TRANSPARENT, UITheme.FOCUS if active else Color("405169"), 3 if active else 1, 16, 16, 6))
			steps_bar.add_child(chip)
	plane_row.visible = state == CHOOSE_PLANE
	plane_value.text = "%d°" % int(plane_slider.value) + ("  (horizontal)" if int(plane_slider.value) == -90 else "")
	var sensors = Robot.last_packet.get("sensors", [])
	var text = ""
	connect_row.visible = not healthy and not shutdown
	if not healthy and not shutdown:
		instruction.text = "Connect MARS: check the serial port, then press the MARS button or Connect."
		status.text = Robot.message
		action_button.visible = true
		action_button.text = "Connect"
		video.stop()
		return
	action_button.visible = true
	action_button.disabled = false
	match state:
		CALIBRATE:
			var values = imu()
			text = "IMU angles [ %s ] deg\nAngles must be within ±%d deg." % [" | ".join(values.map(func(v): return "%+03d" % int(v))), int(CALIB_LIMIT)]
			instruction.text = "Press the MARS button when ready." if angles_ok() else "Make sure all angles are within %d degrees." % int(CALIB_LIMIT)
			instruction.add_theme_color_override("font_color", UITheme.FOCUS if angles_ok() else Color("ff7a6b"))
			action_button.text = "Calibrate"
			action_button.disabled = not angles_ok()
			video.stop()
		ACTIVATE:
			instruction.text = "Press the MARS button to activate."
			action_button.text = "Activate MARS"
			video.play("SETUP")
		ACTIVATING:
			instruction.text = "Activating… the arm is moving to its starting position."
			text = "%.1f deg | %.1f N" % [absf(sensors[0]) if sensors.size() > 0 else 0.0, Robot.last_packet.get("force", 0.0)]
			action_button.visible = false
			video.play("SETUP")
		ATTACH:
			text = "%.1f N" % Robot.last_packet.get("force", 0.0)
			if attached():
				instruction.text = "Press the MARS button to set the training plane."
				action_button.text = "Continue"
			else:
				instruction.text = "Please attach your hand to MARS."
				action_button.visible = false
			video.play("ATTACH")
		CHOOSE_PLANE:
			var target = plane_slider.value
			instruction.text = "Choose the training plane (−90° is horizontal), move there, then press the MARS button to save it."
			text = "Robot at %.0f° • target %.0f°" % [sensors[0] if sensors.size() > 0 else 0.0, target]
			action_button.text = "Save plane %.0f°" % target if Robot.reached(target) else "Move to %.0f°" % target
			video.stop()
		SETTING_PLANE:
			instruction.text = "Setting training plane: %.0f°" % Trial.plane
			text = "Robot at %.0f°" % (sensors[0] if sensors.size() > 0 else 0.0)
			action_button.visible = false
		READY:
			instruction.text = "MARS is ready. Press the MARS button to choose a movement."
			action_button.text = "Choose movement ▸"
			video.stop()
		REMOVE:
			if hand_on():
				instruction.text = "Please remove your hand from MARS."
				action_button.visible = false
				video.play("STRAP")
			else:
				instruction.text = "Press the MARS button to move the robot arm down."
				action_button.text = "Lower the arm"
				video.stop()
		OFF:
			instruction.text = "MARS is lowered and disconnected. Press the MARS button to see your summary."
			text = "Device disconnected."
			action_button.text = "Show summary ▸"
	status.text = text
