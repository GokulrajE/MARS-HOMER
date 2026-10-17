extends SceneTree
# Screenshots: login page (Diagnostics button) and the slimmed Device & setup tab.
func shot(name: String) -> void:
	root.get_node("Nav").dismiss_tip()
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/" + name + ".png")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/rld-" + str(Time.get_ticks_usec())
	trial.configure("demo")
	var launcher = load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_login()
	await shot("login-page")
	launcher.show_menu()
	await process_frame
	launcher.open_workflow()
	await process_frame
	launcher.workflow.tabs.tabs_visible = true
	launcher.workflow.tabs.current_tab = 1
	await shot("device-tab")
	quit()
