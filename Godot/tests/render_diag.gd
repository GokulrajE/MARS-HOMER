extends SceneTree
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var robot = root.get_node("Robot")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	root.get_node("Trial").data_root = "res://test-output/rd-" + str(Time.get_ticks_usec())
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await process_frame
	launcher.screen.diagnostics.emit()
	await process_frame
	var page = launcher.screen
	check(page.get_script().resource_path.ends_with("diagnostics.gd"), "Diagnostics screen opens from login")
	page.refresh()
	check(page.rows.connection.text == "Not connected" and page.rows.angles.text == "–", "Empty state before connecting")
	var sensors = []
	sensors.resize(17)
	sensors.fill(0.0)
	sensors[0] = -88.5; sensors[1] = 12.25; sensors[2] = 31.0; sensors[3] = 4.0
	sensors[4] = 3.5; sensors[8] = 2000.0; sensors[9] = 999; sensors[10] = -90.0; sensors[11] = 0.12
	sensors[12] = 0.5; sensors[13] = -0.25; sensors[16] = 7.5
	robot.connected = true
	robot.version = "MARS-HOMER,AB-FW-1.1"
	robot.last_seen = Time.get_ticks_msec()
	robot.last_packet = {"kind": 3, "sensors": sensors, "runtime": 12.345, "number": 321, "error": 0, "limb": 1, "button": 1, "calibration": 1, "control_type": 1, "command_status": 1, "force": 19.62, "endpoint": Vector3(0.4, 0.0, -0.2), "plane_endpoint": Vector2(-0.2, 0.4)}
	page.refresh()
	check(page.rows.stream.text == "DIAGNOSTICS" and page.rows.limb.text == "RIGHT", "Stream and limb shown")
	check(page.rows.angles.text.contains("-88.50") and page.rows.err_p.text == "+0.50" and page.rows.velocity.text == "+7.50", "Angles and controller terms shown")
	check(page.rows.target.text == "–" and page.rows.desired.text == "-90.00", "Unset target shows a dash")
	check(page.rows.control.text == "POSITION" and page.rows.output.text == "+0.12", "Control mode and output shown separately")
	check(page.rows.error.text == "NOERROR" and page.rows.button.text == "Released", "Error and button shown")
	# Controls follow the robot state.
	check(page.calibrate_button.disabled and page.calibrate_button.text == "Calibrated ✓", "Calibrated robot shows Calibrated")
	check(not page.position_toggle.disabled and page.position_toggle.button_pressed, "Position control reflects the robot")
	check(not page.set_target_button.disabled, "Set target is available in position control")
	# Logging to the common diagnostics folder.
	var Diag = load("res://core/diagnostics.gd")
	page.log_toggle.button_pressed = true
	check(page.log_file != null and page.log_path.begins_with("user://diagnostics/MARS_Data_"), "Logging starts in the common diagnostics folder")
	for i in 5:
		robot.last_packet.number = 400 + i
		robot.sample_received.emit(robot.last_packet)
	page.log_toggle.button_pressed = false
	check(page.log_file == null and page.log_rows == 5, "Five packets were logged")
	var text = FileAccess.get_file_as_string(page.log_path)
	var lines = text.split(String.chr(10))
	check(lines[0].begins_with("DeviceID: MARS-HOMER") and lines[1].begins_with("DateTime,DeviceRunTime") and lines.size() >= 8, "The file has a device line, a header and the rows")
	check(lines[2].contains("DIAGNOSTICS") and lines[2].contains("-88.5"), "Rows carry the stream and the angles")
	check(Diag.latest_log() == page.log_path, "The newest file is found")
	page.copy_path()
	check(page.log_label.text.begins_with("Path copied"), "Copy path reports success")
	DirAccess.remove_absolute(page.log_path)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/diag.png")
	robot.last_packet = {}
	robot.connected = false
	# Training side is a drop-down, and setup closes cleanly.
	root.get_node("Trial").configure("sidepatient" + str(Time.get_ticks_usec()))
	launcher.show_menu()
	await process_frame
	launcher.open_workflow()
	await process_frame
	var side = launcher.workflow.fields["TrainingSide"]
	check(side is OptionButton and side.get_item_count() == 2, "Training side is a Left / Right drop-down")
	print("Diagnostics page: %d failures" % failures)
	quit(1 if failures else 0)
