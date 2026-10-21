extends SceneTree
# The mouse-simulation / MARS-device switch lives on the login page and shows only after Ctrl+Shift+X.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	var nav = root.get_node("Nav")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	nav.advanced = false
	# The switch remembers its choice in application.cfg; put the real value back at the end.
	var original_mode = bool(root.get_node("Services").settings.get_value("ui", "hardware", false))
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await process_frame
	var login = launcher.screen
	check(not login.mode_box.visible, "The input switch is hidden by default")
	var key = InputEventKey.new()
	key.keycode = KEY_X
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	nav._input(key)
	check(login.mode_box.visible, "Ctrl+Shift+X shows the input switch")
	login.dev_button.pressed.emit()
	check(trial.hardware and trial.data_root == "user://data", "Choosing MARS device switches to device data")
	login.sim_button.pressed.emit()
	check(not trial.hardware and trial.data_root == "user://simulation-data", "Choosing mouse simulation switches back")
	nav._input(key)
	check(not login.mode_box.visible, "Pressing it again hides the switch")
	nav._input(key)
	check(nav.advanced, "Technical options on again")
	var records = root.get_node("Records")
	trial.data_root = "res://test-output/lm-" + str(Time.get_ticks_usec())
	trial.configure("modeuser")
	records.save_profile({"HomerID": "modeuser", "StartDate": "01-10-2026 00:00:00", "EndDate": "31-12-2099 23:59:59", "TotalTime": "30", "ML": "10", "AP": "10", "MLAP": "10", "ForeArmLength": "0.291", "UpperArmLength": "0.475", "TrainingSide": "RIGHT", "Location": "", "Group": "Experimental"})
	login.signed_in.emit("modeuser")
	await process_frame
	await process_frame
	check(not nav.advanced, "Logging in hides the technical options again")
	check(launcher.menu != null and not launcher.menu.saved_button.visible, "Open saved data is hidden on Welcome")
	launcher.open_workflow()
	await process_frame
	check(not launcher.workflow.tabs.tabs_visible, "Device & setup and Uploads & services are hidden on Welcome")
	nav._input(key)
	check(launcher.workflow.tabs.tabs_visible and launcher.workflow.tabs.get_tab_count() == 3, "Ctrl+Shift+X shows them")
	nav._input(key)
	launcher.workflow.closed.emit()
	await process_frame
	launcher.show_menu()
	await process_frame
	check(not "sim_button" in launcher.menu, "Welcome no longer carries the switch")
	root.get_node("Services").settings.set_value("ui", "hardware", original_mode)
	root.get_node("Services").save()
	print("Login mode: %d failures" % failures)
	quit(1 if failures else 0)
