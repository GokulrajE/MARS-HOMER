extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var robot=root.get_node("Robot")
	if OS.get_name()!="Windows":
		print("Serial bridge test skipped: Windows required")
		quit()
		return
	# Intentionally nonexistent port: never opens or moves physical hardware.
	if not robot.connect_port("COM9999"):
		push_error("Bridge process did not start")
		quit(1)
		return
	for i in 80:
		await create_timer(0.1).timeout
		if robot.authenticated and robot.message!="Connecting to COM9999": break
	var success=robot.authenticated and not robot.connected and "COM9999" in robot.message
	print("MARS bridge: ","PASS (missing port reported without connecting)" if success else "FAIL: "+robot.message)
	robot.disconnect_port()
	quit(0 if success else 1)
