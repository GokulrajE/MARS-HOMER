extends RefCounted
## JEDI framing and MARS kinematics, ported from JediComm.cs / MarsComm.cs.
var buffer = PackedByteArray()
var rejected = 0
## Bit i of the error word. Names are those of MarsComm.ERRORTYPES in the Unity app.
const ERROR_NAMES = ["NOHEARTBEAT", "ANG1MISMATCHERR", "ANG234MISMATCHERR", "ANG1JUMPERR", "ANG234JUMPERR", "ANG1LIMITERR", "ANG234LIMITERR"]
const ERROR_HELP = [
	"the robot is not receiving the application's heartbeat",
	"the two joint-1 sensors disagree",
	"the joint 2-4 sensors disagree",
	"the joint-1 reading jumped suddenly",
	"a joint 2-4 reading jumped suddenly",
	"joint 1 is outside its allowed range: move the arm back inside the range",
	"joint 2-4 is outside its allowed range: move the arm back inside the range"
]

static func error_text(flags: int) -> String:
	var names: Array = []
	var help: Array = []
	for i in 16:
		if flags & (1 << i):
			names.append(ERROR_NAMES[i] if i < ERROR_NAMES.size() else "FLAG%d" % i)
			if i < ERROR_HELP.size(): help.append(ERROR_HELP[i])
	var text = "Robot error %s (%d)" % [" + ".join(names), flags]
	if not help.is_empty(): text += ": " + "; ".join(help)
	return text

static func command(payload: PackedByteArray) -> PackedByteArray:
	var frame = PackedByteArray([0xaa,0xaa,payload.size()+1])
	frame.append_array(payload)
	var checksum = 0
	for byte in frame: checksum += byte
	frame.append(checksum & 255)
	return frame

func feed(bytes: PackedByteArray) -> Array:
	buffer.append_array(bytes)
	var packets: Array = []
	while buffer.size() >= 4:
		if buffer[0] != 255 or buffer[1] != 255:
			buffer.remove_at(0)
			continue
		var length = int(buffer[2])
		if length < 5 or length == 255:
			rejected += 1
			buffer.remove_at(0)
			continue
		if buffer.size() < length + 3: break
		var frame = buffer.slice(0,length+3)
		var checksum = 0
		for i in frame.size()-1: checksum += frame[i]
		if (checksum & 255) != frame[-1]:
			rejected += 1
			buffer.remove_at(0)
			continue
		buffer = buffer.slice(length+3)
		var packet = decode(frame.slice(2,length+2))
		if not packet.is_empty(): packets.append(packet)
		else: rejected += 1
	if buffer.size() > 4096: buffer = buffer.slice(-256)
	return packets

static func decode(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 5: return {}
	var kind = payload[1] >> 4
	var packet = {"status":int(payload[1]),"error":payload[2] | (payload[3]<<8),"limb":payload[4]&3,"button":(payload[4]>>4)&1,"calibration":payload[1]&1,"control_type":(payload[1]&14)>>1,"command_status":payload[4]>>6,"kind":kind}
	if kind == 0:
		packet.version = payload.slice(5).get_string_from_ascii()
		return packet
	if kind != 1 and kind != 3: return {}
	var count = 12 if kind == 1 else 17
	if payload.size() != 11+count*4: return {}
	packet.number = payload.decode_u16(5)
	packet.runtime = payload.decode_u32(7)*0.001
	packet.sensors = []
	for i in count:
		var value = payload.decode_float(11+i*4)
		if not is_finite(value): return {}
		packet.sensors.append(value)
	packet.force = packet.sensors[8]*0.00981
	packet.endpoint = endpoint(packet.sensors[0],packet.sensors[1],packet.sensors[2])
	packet.plane_endpoint = plane_endpoint(packet.sensors[1],packet.sensors[2])
	return packet

static func endpoint(a: float,b: float,c: float) -> Vector3:
	a = deg_to_rad(a)
	b = deg_to_rad(b)
	c = deg_to_rad(c)
	var radius = 0.475*cos(b)+0.291*cos(b+c)
	return Vector3(cos(a)*radius,sin(a)*radius,-0.475*sin(b)-0.291*sin(b+c))

static func plane_endpoint(b: float,c: float) -> Vector2:
	var ep = endpoint(0,b,c)
	# Existing AROM coordinates: horizontal Z, vertical Y-in-plane.
	return Vector2(ep.z,ep.x)

static func target_command(start: float,target: float,seconds: float=6) -> PackedByteArray:
	var payload = PackedByteArray([7])
	payload.resize(17)
	payload.encode_float(1,start)
	payload.encode_float(5,0)
	payload.encode_float(9,target)
	payload.encode_float(13,seconds)
	return command(payload)
