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
	robot.recent_commands.clear()
	# A joint-limit error (arm lowered) must not send "deactivate control" (6, 0).
	robot.fail("Robot error ANG1LIMITERR (32)", false)
	check(robot.recent_commands.is_empty(), "A robot-reported error does not deactivate control")
	robot.last_fault = ""
	robot.accept_packet({"button": 1, "error": 32, "runtime": 1.0, "number": 1})
	check(not robot.recent_commands.any(func(c): return c.size() > 1 and c[0] == 6 and c[1] == 0), "An error packet does not switch control off")
	robot.last_fault = ""
	robot.fail("Serial bridge disconnected.")
	check(robot.recent_commands.any(func(c): return c.size() > 1 and c[0] == 6 and c[1] == 0), "A lost link still requests deactivation")
	print("Fault handling: %d failures" % failures)
	quit(1 if failures else 0)
