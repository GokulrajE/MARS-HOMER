extends SceneTree
# Releasing the MARS button in the detachment scene drops the link from inside the packet handler;
# the app must stay "Disconnected" and must not then report "Serial bridge did not connect".
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func sensor_frame(released: bool = false) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize(59)
	data[0] = 59
	data[1] = 0x13
	data[4] = 2 | (0x10 if released else 0)
	data.encode_u16(5, 42)
	data.encode_u32(7, 1234)
	for i in 12: data.encode_float(11 + i * 4, 0)
	var frame = PackedByteArray([255, 255])
	frame.append_array(data)
	var checksum = 0
	for byte in frame: checksum += byte
	frame.append(checksum & 255)
	return frame

func run() -> void:
	var robot = root.get_node("Robot")
	var listener = TCPServer.new()
	var device_port = 0
	for i in 40:
		device_port = randi_range(20000, 40000)
		if listener.listen(device_port, "127.0.0.1") == OK: break
	check(robot.connect_port("tcp:127.0.0.1:%d" % device_port), "Bridge process starts")
	var peer: StreamPeerTCP
	for i in 150:
		await create_timer(0.1).timeout
		if peer == null and listener.is_connection_available(): peer = listener.take_connection()
		if peer != null and robot.connected: break
	check(robot.connected, "Connected through the bridge")
	# Telemetry flows, then the button goes down and up; the release lowers the arm (drops the link).
	robot.button_changed.connect(func(down):
		if not down: robot.disconnect_port(false))
	robot.opened_at -= 20000 # the connection is old, so the 8-second connect timeout would trigger
	peer.put_data(sensor_frame(false))
	for i in 10: await create_timer(0.05).timeout
	peer.put_data(sensor_frame(true))
	for i in 30: await create_timer(0.05).timeout
	check(not robot.connected and not robot.enabled, "The release dropped the link")
	check(robot.message == "Disconnected", "The status stays Disconnected, not: " + robot.message)
	check(robot.last_fault == "", "No fault is reported after a deliberate disconnect: " + robot.last_fault)
	print("Bridge release: %d failures" % failures)
	quit(1 if failures else 0)
