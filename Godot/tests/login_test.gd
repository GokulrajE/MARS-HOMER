extends SceneTree
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var Login = load("res://core/login.gd")
	check(Login.valid_id("P-001") and not Login.valid_id("bad/id") and not Login.valid_id(""), "Patient IDs are validated")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await process_frame
	var login = launcher.screen
	check(login.get_script().resource_path.ends_with("login.gd"), "Login screen opens")
	login.id_edit.text = "bad/id"
	login.go()
	check(login.error.text != "", "An invalid ID shows a message")
	var id = "newpatient" + str(Time.get_ticks_usec())
	login.id_edit.text = id
	login.update_note()
	check(login.note.text.begins_with("New patient"), "An unknown ID is announced as a new patient")
	login.go()
	await process_frame
	check(launcher.signed_account == id, "Login accepted")
	check(root.get_node("Trial").user_id == id, "The ID becomes the patient")
	# A new patient must set up the plan first; only saving it completes the login.
	var setup = launcher.workflow
	check(setup != null and setup.setup_mode, "A new patient is taken to plan setup")
	check(not setup.tabs.tabs_visible and not setup.nav_buttons[0].visible, "Only the patient plan is shown")
	check(not setup.fields["HomerID"].editable and setup.fields["HomerID"].text == id, "The patient ID is fixed")
	var nav = root.get_node("Nav")
	setup.fields["ML"].text = "abc"
	setup.save_profile()
	check(launcher.workflow == setup and launcher.menu == null, "An invalid plan does not log in")
	setup.fields["ML"].text = "10"
	setup.save_profile()
	await process_frame
	await process_frame
	check(launcher.menu != null and not launcher.user_edit.editable, "Saving the plan opens Welcome, locked to the patient")
	check(not launcher.menu.saved_button.visible, "Open saved data is hidden")
	# Ctrl+Shift+X reveals the technical sections.
	var key = InputEventKey.new()
	key.keycode = KEY_X
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	nav._input(key)
	check(nav.advanced and launcher.menu.saved_button.visible, "Ctrl+Shift+X shows Open saved data")
	launcher.open_workflow()
	await process_frame
	check(launcher.workflow.tabs.tabs_visible and not launcher.workflow.tabs.is_tab_hidden(1), "Ctrl+Shift+X shows the other sections")
	nav._input(key)
	check(not nav.advanced and not launcher.workflow.tabs.tabs_visible, "Pressing it again hides them")
	# An existing patient with a saved plan goes straight to Welcome.
	launcher.show_login()
	await process_frame
	launcher.screen.id_edit.text = id
	launcher.screen.go()
	await process_frame
	check(launcher.menu != null, "A returning patient goes straight to Welcome")
	print("Login: %d failures" % failures)
	quit(1 if failures else 0)
