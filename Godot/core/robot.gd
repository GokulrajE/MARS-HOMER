extends Node
signal sample_received(packet)
signal button_released
signal button_changed(down)
signal button_cancelled
signal fault(message)
const Protocol = preload("res://core/protocol.gd")
var parser = Protocol.new()
var server = TCPServer.new()
var peer: StreamPeerTCP
var token = ""
var authenticated = false
var connected = false
var enabled = false
var port_name = ""
var last_packet: Dictionary = {}
var last_seen = -10000
var last_heartbeat = 0
var opened_at = 0
var process_id = -1
var pending = ""
var message = "Disconnected"
var previous_button = 1
var button_down = false
var low_rate_since = 0
var version = ""
var last_fault=""
## True after the link dropped by itself (watchdog, bridge loss); cleared by the next connect.
var link_lost = false
var log_file: FileAccess

func connect_port(port: String) -> bool:
	# Starting a new connection never sends stop commands over the old one.
	disconnect_port(false)
	link_lost = false
	port = normalize_port(port)
	if not valid_port(port):
		message = "Choose a port, for example %s." % example_port()
		return false
	port_name = port
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	var socket_port = 0
	for i in 40:
		socket_port = randi_range(18000,48000)
		if server.listen(socket_port,"127.0.0.1") == OK: break
	if not server.is_listening():
		message = "Unable to start local serial bridge."
		return false
	# Extract the bundled bridge for exported PCK builds too.
	var use_powershell = OS.get_name() == "Windows" and port.begins_with("COM")
	var bridge = "user://serial_bridge.ps1" if use_powershell else "user://serial_bridge.py"
	var output = FileAccess.open(bridge,FileAccess.WRITE)
	if output == null: return false
	output.store_string(FileAccess.get_file_as_string("res://platform/serial_bridge.ps1" if use_powershell else "res://platform/serial_bridge.py"))
	output.close()
	if use_powershell:
		process_id = OS.create_process("powershell.exe",PackedStringArray(["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-ExecutionPolicy","Bypass","-File",ProjectSettings.globalize_path(bridge),"-PortName",port,"-SocketPort",str(socket_port),"-Token",token]),false)
	else:
		# Linux / Raspberry Pi / macOS (and tcp: ports anywhere) use the Python bridge.
		process_id = OS.create_process(python_command(),PackedStringArray([ProjectSettings.globalize_path(bridge),"--port",port,"--socket",str(socket_port),"--token",token]),false)
		if process_id <= 0:
			message = "Python 3 was not found. Install it (sudo apt install python3) and try again."
			server.stop()
			return false
	enabled = process_id > 0
	opened_at = Time.get_ticks_msec()
	message = "Connecting to " + port
	return enabled

## The text a user typed, in the form the platform's bridge expects. COM names are
## case-insensitive; device paths (/dev/rfcomm0) and Bluetooth addresses must keep their case.
static func normalize_port(text: String) -> String:
	var cleaned = text.strip_edges()
	if cleaned.to_upper().begins_with("COM"): return cleaned.to_upper()
	if cleaned.to_lower().begins_with("bt:"): return "bt:" + cleaned.substr(3).to_upper()
	return cleaned

## Windows: COMn. Linux / Raspberry Pi / macOS: /dev/... devices (rfcomm, USB or UART
## serial), bt:<MAC> to connect over Bluetooth directly. tcp:host:port works everywhere.
static func valid_port(port: String) -> bool:
	if port.begins_with("tcp:"): return port.substr(4).contains(":")
	if OS.get_name() == "Windows": return port.begins_with("COM") and port.substr(3).is_valid_int()
	if port.begins_with("bt:"):
		var pattern=RegEx.new()
		pattern.compile("^bt:([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}(:([1-9]|[12][0-9]|30))?$")
		return pattern.search(port)!=null
	return port.begins_with("/dev/")

static func example_port() -> String:
	return "COM3" if OS.get_name() == "Windows" else "/dev/rfcomm0 or bt:AA:BB:CC:DD:EE:FF"

static func default_port() -> String:
	return "" if OS.get_name() == "Windows" else "/dev/rfcomm0"

static func python_command() -> String:
	return "python" if OS.get_name() == "Windows" else "python3"

## Serial devices the system currently offers (Bluetooth rfcomm nodes, USB and UART adapters).
static func list_ports() -> PackedStringArray:
	var found = PackedStringArray()
	if OS.get_name() == "Windows":
		var output: Array = []
		if OS.execute("powershell.exe", PackedStringArray(["-NoProfile","-NonInteractive","-Command","[System.IO.Ports.SerialPort]::GetPortNames()"]), output, false) == 0 and output.size() > 0:
			for line in str(output[0]).split("\n"):
				if line.strip_edges() != "": found.append(line.strip_edges())
		return found
	var directory = DirAccess.open("/dev")
	if directory == null: return found
	for name in directory.get_files():
		for prefix in ["rfcomm", "ttyUSB", "ttyACM", "ttyAMA", "serial", "cu.usbserial", "cu.usbmodem"]:
			if name.begins_with(prefix): found.append("/dev/" + name)
	found.sort()
	return found

func send_bytes(bytes: PackedByteArray) -> void:
	if authenticated and peer != null and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.put_data((JSON.stringify({"bytes":Marshalls.raw_to_base64(bytes)})+"\n").to_utf8_buffer())

## The most recent commands issued (diagnostics and tests).
var recent_commands: Array = []

func command(bytes: PackedByteArray) -> void:
	recent_commands.append(bytes)
	if recent_commands.size()>16: recent_commands.pop_front()
	if bytes.size()>0 and bytes[0]!=128:
		var records=get_node_or_null("/root/Records")
		if records!=null: records.log_event("Device command "+str(bytes[0]))
	send_bytes(Protocol.command(bytes))

func healthy() -> bool:
	return connected and Time.get_ticks_msec()-last_seen <= 2000 and last_packet.get("error",1) == 0

func ready_for_training() -> bool:
	return healthy() and last_packet.get("calibration",0) == 1 and last_packet.get("control_type",0) == 1

func calibrate() -> bool:
	if not healthy() or not last_packet.has("sensors"): return false
	for i in range(4,8):
		if absf(last_packet.sensors[i]) > 50: return false
	command(PackedByteArray([3]))
	return true

func set_plane(angle: float) -> bool:
	if not ready_for_training() or not is_finite(angle) or angle < -100 or angle > 0: return false
	var start = last_packet.sensors[9]
	if start == 999: start = last_packet.sensors[0]
	recent_commands.append(PackedByteArray([7]))
	send_bytes(Protocol.target_command(start,angle))
	return true

func cancel_button() -> void:
	# A press whose release can no longer be trusted (link lost) must not become a gesture.
	previous_button = 1
	if button_down:
		button_down = false
		button_cancelled.emit()

## Unity's setup moves the arm to -90 degrees, outside the +/-50 training-plane range.
func move_to(angle: float) -> bool:
	if not ready_for_training() or not is_finite(angle): return false
	var start = last_packet.sensors[9]
	if start == 999: start = last_packet.sensors[0]
	recent_commands.append(PackedByteArray([7]))
	send_bytes(Protocol.target_command(start,angle))
	return true

func reached(angle: float, tolerance: float = 10.0) -> bool:
	return healthy() and last_packet.has("sensors") and absf(last_packet.sensors[0]-angle) < tolerance

## `send_stop` false closes the link immediately without sending anything (used when the
## session ends: the Bluetooth connection is simply dropped, as in Unity).
func disconnect_port(send_stop: bool = true) -> void:
	cancel_button()
	if connected and send_stop:
		command(PackedByteArray([6,0]))
		command(PackedByteArray([5]))
	if peer != null:
		peer.put_data("{\"close\":true}\n".to_utf8_buffer())
		peer.disconnect_from_host()
	peer = null
	server.stop()
	connected = false
	authenticated = false
	enabled = false
	# A fresh dictionary, not clear(): the packet being handled may be this very object.
	last_packet = {}
	parser.buffer.clear()
	pending = ""
	message = "Disconnected"
	last_fault=""

## `deactivate` is false for faults the robot itself reports (for example a joint limit while the
## arm is lowered): the trial is held and the message shown, but control stays on, as in Unity,
## so the arm is not dropped and the control mode does not fall back to NONE.
func fail(reason: String, deactivate: bool = true) -> void:
	message = reason
	if last_fault==reason: return
	last_fault=reason
	if deactivate: command(PackedByteArray([6,0]))
	fault.emit(reason)

func accept_packet(packet: Dictionary) -> void:
	if packet.has("version"):
		version = packet.version
		return
	link_lost = false
	var now = Time.get_ticks_msec()
	if not last_packet.is_empty():
		var dt = packet.runtime-last_packet.runtime
		if dt>0.05:
			if low_rate_since == 0: low_rate_since = now
			elif now-low_rate_since>5000: fail("Telemetry below 20 Hz for five seconds; trial held.",false)
		else: low_rate_since = 0
	last_packet = packet
	last_seen = now
	message = "Connected • " + port_name
	if packet.error==0: last_fault=""
	if packet.error != 0: fail(Protocol.error_text(packet.error),false)
	var button_value = packet.button
	var error_value = packet.error
	sample_received.emit(packet)
	# The handle button is active-low: 0 is pressed, 1 is released. The gesture
	# layer sees every edge, even while a robot error holds gameplay, so a
	# patient can still finish and save a held trial.
	# Handlers above and below (a tap can lower the arm and drop the link) must not leave this
	# function reading a packet that no longer exists, so it works from copies.
	var down = button_value == 0
	if down != button_down:
		button_down = down
		button_changed.emit(down)
		if not enabled and peer == null: return
	if previous_button == 0 and button_value == 1 and error_value == 0: button_released.emit()
	previous_button = button_value

func _process(_delta: float) -> void:
	if not enabled: return
	if peer == null and server.is_connection_available():
		peer = server.take_connection()
	if peer != null:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var available = peer.get_available_bytes()
			if available>0:
				var received = peer.get_data(available)
				if received[0] == OK: pending += received[1].get_string_from_utf8()
			while pending.contains("\n"):
				var end = pending.find("\n")
				var decoded = JSON.parse_string(pending.substr(0,end))
				pending = pending.substr(end+1)
				if not decoded is Dictionary: continue
				if not authenticated:
					if decoded.get("token","") != token:
						peer.disconnect_from_host()
						peer = null
						pending = ""
						break
					authenticated = true
				elif decoded.get("connected",false):
					connected = true
					last_seen = Time.get_ticks_msec()
					command(PackedByteArray([0]))
					command(PackedByteArray([4]))
				elif decoded.has("error"):
					cancel_button()
					fail(decoded.error)
					if connected: link_lost = true
					connected = false
				elif decoded.has("bytes"):
					for packet in parser.feed(Marshalls.base64_to_raw(decoded.bytes)):
						# A handler may have dropped the link part-way through this batch.
						if peer == null or not connected: break
						accept_packet(packet)
		elif connected:
			connected = false
			link_lost = true
			cancel_button()
			fail("Serial bridge disconnected.")
	# A handler above (a button release that lowers the arm) may just have dropped the link.
	if not enabled: return
	var now = Time.get_ticks_msec()
	if connected and now-last_heartbeat >= 100:
		command(PackedByteArray([128]))
		last_heartbeat = now
	if connected and now-last_seen > 2000:
		cancel_button()
		link_lost = true
		fail("Robot watchdog timed out; trial held.")
	if not connected and now-opened_at > 8000 and not authenticated:
		fail("Serial bridge did not connect. Check the COM port and Windows PowerShell." if OS.get_name()=="Windows" else "Serial bridge did not connect. Check Python 3, the device path and serial permissions.")
		enabled = false

func _exit_tree() -> void:
	disconnect_port()
