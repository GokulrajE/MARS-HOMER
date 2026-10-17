extends SceneTree
# End to end through platform/serial_bridge.py with a fake robot behind a tcp: port.
# Needs Python 3 and localhost sockets; never touches real hardware.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func sensor_frame() -> PackedByteArray:
	var data = PackedByteArray()
	data.resize(59)
	data[0] = 59
	data[1] = 0x13
	data[4] = 2
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
	# Port validation per platform.
	check(robot.valid_port("tcp:127.0.0.1:5000"), "tcp ports are valid everywhere")
	check(not robot.valid_port("tcp:nonsense"), "tcp needs a port number")
	check(not robot.valid_port(""), "empty port is refused")
	if OS.get_name() == "Windows":
		check(robot.valid_port("COM3") and not robot.valid_port("/dev/rfcomm0"), "Windows takes COM ports")
	else:
		check(robot.valid_port("/dev/rfcomm0") and robot.valid_port("/dev/ttyUSB0"), "Linux takes serial devices")
		check(robot.valid_port("bt:AA:BB:CC:DD:EE:FF") and not robot.valid_port("bt:AA:BB:CC:DD:EE"), "Linux takes Bluetooth addresses")
		check(not robot.valid_port("COM3"), "Linux refuses COM names")
	check(robot.normalize_port(" com7 ") == "COM7", "COM names are upper-cased")
	check(robot.normalize_port("/dev/rfcomm0") == "/dev/rfcomm0", "device paths keep their case")
	check(robot.normalize_port("bt:aa:bb:cc:dd:ee:ff") == "bt:AA:BB:CC:DD:EE:FF", "Bluetooth addresses are upper-cased")
	check(robot.list_ports() is PackedStringArray, "Port detection returns a list")
	# Fake robot.
	var listener = TCPServer.new()
	var device_port = 0
	for i in 40:
		device_port = randi_range(20000, 40000)
		if listener.listen(device_port, "127.0.0.1") == OK: break
	check(listener.is_listening(), "Fake robot is listening")
	check(robot.connect_port("tcp:127.0.0.1:%d" % device_port), "Bridge process starts")
	var peer: StreamPeerTCP
	var sent = false
	var received = PackedByteArray()
	for i in 120:
		await create_timer(0.1).timeout
		if peer == null and listener.is_connection_available(): peer = listener.take_connection()
		if peer != null:
			peer.poll()
			var available = peer.get_available_bytes()
			if available > 0: received.append_array(peer.get_data(available)[1])
			if robot.connected and not sent:
				sent = true
				peer.put_data(sensor_frame())
		if robot.last_packet.has("number") and received.size() >= 4: break
	check(peer != null, "Bridge opened the device")
	check(robot.authenticated and robot.connected, "App authenticated the bridge and the device opened")
	check(robot.last_packet.get("number", -1) == 42, "Sensor packet travelled device -> bridge -> app")
	check(received.size() >= 4 and received[0] == 0xAA and received[1] == 0xAA, "Commands travelled app -> bridge -> device")
	robot.disconnect_port()
	print("MARS Python bridge: %d failures" % failures)
	quit(1 if failures else 0)

