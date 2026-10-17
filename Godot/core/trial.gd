extends Node
signal ended
const Rules = preload("res://core/rules.gd")
const SESSION_HEADER = "SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,TrialStartTime,TrialStopTime,TrialRawDataFile,Movement,TrainingPlaneAngle,GameName,ReachSpeed,GameParameter,GameDuration,SuccessRate,MoveTime,CurrentTargets,CurrentHits,CurrentMisses,CummulativeTargets,CummulativeHits,CummulativeMisses,currentStar,CummulativeStars,RawDataFileName"
const RAW_HEADER = "DeviceRunTime,PacketNumber,Status,ControlType,ErrorStatus,Limb,Calibration,Force,Target,Desired,Control,Button,EndPointX,EndPointY,EndPointZ,EndPointYPlane,EndPointZPlane,EndPointTargetY,EndPointTargetZ,Error,ErrorDiff,ErrorSum,GamePlayerX,GamePlayerY,GameTargetX,GameTargetY,GameState,TargetNumber,HitNumber,MissNumber,Annotation,Miscellaneous"
var data_root = "user://simulation-data"
var hardware = false
var user_id = "demo"
var game = ""
var movement = ""
var rom = Vector2(0.3, 0.3)
var plane = -90.0
var speed = Rules.MIN_SPEED
var scrub_area = 0.001
var duration = 0.0
var running = false
var paused = false
var targets = 0
var hits = 0
var misses = 0
var target_open = false
var session = 1
var trial_day = 0
var trial_session = 0
var started = ""
var session_started = ""
var raw_name = ""
var raw: FileAccess
var history: Array = []
var last_result: Dictionary = {}
var error = ""
var annotation = ""
var player_position = Vector2.ZERO
var target_position = Vector2.ZERO
var sample_clock = 0.0
var packet = 0

func _ready() -> void:
	Robot.sample_received.connect(func(_packet):
		if running and hardware: sample())

func input_position(fallback: Vector2) -> Vector2:
	return Records.normalized_position(movement) if hardware else fallback

func held() -> bool:
	return hardware and not Robot.ready_for_training()

func stamp() -> String:
	return Time.get_datetime_string_from_system(false, true)

func user_path() -> String:
	return data_root.path_join(user_id).path_join("data")

func configure(id: String) -> bool:
	if running: return false
	if id.is_empty() or id != id.validate_filename() or id in [".", ".."]:
		error = "Use a user ID containing letters, numbers, underscores or dashes."
		return false
	user_id = id
	history.clear()
	session = 1
	trial_session = 0
	session_started = stamp()
	for folder in ["sessions", "rawdata", "rom", "trainingplane", "armweight", "applog", "errorlog"]:
		if DirAccess.make_dir_recursive_absolute(user_path().path_join(folder)) != OK:
			error = "Cannot create data folder: " + user_path()
			return false
	var path = user_path().path_join("sessions/sessions.csv")
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			error = "Cannot read sessions.csv"
			return false
		var header = file.get_csv_line()
		while header.size()>0 and header[0].trim_prefix("\ufeff").begins_with(":") and not file.eof_reached(): header=file.get_csv_line()
		if ",".join(header).trim_prefix("\ufeff") != SESSION_HEADER:
			error = "Existing sessions.csv has an incompatible header; no data changed."
			return false
		while not file.eof_reached():
			var row = file.get_csv_line()
			if row.size() == 24:
				history.append(row)
				session = maxi(session, int(row[0]) + 1)
	else:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			error = "Cannot create sessions.csv"
			return false
		for line in Records.preheader(): file.store_line(line)
		file.store_line(SESSION_HEADER)
	# An interrupted process can leave raw data without a summary. Reserve its
	# session number as well, so the next launch never overwrites that evidence.
	var raw_directory = DirAccess.open(user_path().path_join("rawdata"))
	for name in raw_directory.get_files():
		if name.begins_with("raw-sess") and name.contains("-trial"):
			session = maxi(session, int(name.trim_prefix("raw-sess").get_slice("-trial",0)) + 1)
	error = ""
	Records.load_profile()
	return true

func select_game(code: String) -> void:
	game = code
	movement = Rules.GAMES[code].movement
	speed = Rules.MIN_SPEED
	scrub_area = 0.001
	for row in history:
		if row[9] == game and row[7] == movement:
			speed = Rules.adapt(float(row[10]), float(row[13]))
			if game == "TW": scrub_area = clampf(float(row[11]),0.0001,0.001)

func reach_time() -> float:
	return Rules.reach_duration(movement, speed, rom)

func begin() -> bool:
	if running: return true
	if hardware:
		error = Records.training_block(movement)
		if error!="": return false
		rom = Records.limits(movement).size
	trial_day = 1
	trial_session = 1
	for row in history:
		if row[7] == movement and row[4].begins_with(stamp().left(10)):
			trial_day = maxi(trial_day, int(row[2]) + 1)
		if row[7] == movement and int(row[0]) == session:
			trial_session = maxi(trial_session, int(row[3]) + 1)
	started = stamp()
	duration = 0
	targets = 0
	hits = 0
	misses = 0
	packet = 0
	sample_clock = 0
	target_open = false
	paused = false
	last_result.clear()
	raw_name = "raw-sess%02d-trial%03d-%s-%s.csv" % [session, trial_day, game, movement]
	var path = user_path().path_join("rawdata/" + raw_name)
	if FileAccess.file_exists(path):
		error = "Raw file already exists; refusing to overwrite " + raw_name
		return false
	raw = FileAccess.open(path, FileAccess.WRITE)
	if raw == null:
		error = "Cannot create raw data file. Trial did not start."
		return false
	var bounds = Records.limits(movement) if hardware else Rect2(-rom/2,rom)
	var screen = Rules.screen_limits(game)
	for line in [":Device: MARS", ":Location: " + str(Records.profile.get("Location","SIMULATION")), ":User    : " + user_id, ":Movement: " + movement, ":Game: " + game, ":TrialType: " + ("Training" if hardware else "Simulation"), ":TrialStartTime: " + started.replace(" ", "T"), ":TrialNumberDay: " + str(trial_day), ":ScreenLimits: %f,%f,%f,%f" % [screen.position.x,screen.end.x,screen.position.y,screen.end.y], ":RobotLimits: %f,%f,%f,%f" % [bounds.position.x,bounds.end.x,bounds.position.y,bounds.end.y]]:
		raw.store_line(line)
	raw.store_line(RAW_HEADER + ",Angle1,Angle2,Angle3,Angle4")
	raw.flush()
	running = true
	return true

func appear(position: Vector2) -> void:
	if not running or target_open: return
	target_position = position
	targets += 1
	target_open = true
	annotation = "TARGET_APPEARED"
	sample()

func resolve(success: bool) -> void:
	if not running or not target_open: return
	target_open = false
	if success: hits += 1
	else: misses += 1
	annotation = "HIT" if success else "MISS"
	sample()

func advance(delta: float, is_paused: bool, player: Vector2, target: Vector2) -> void:
	if not running: return
	paused = is_paused or held()
	player_position = player
	target_position = target
	if paused: return
	var step = minf(delta, Rules.DURATION - duration)
	duration += step
	sample_clock += step
	# Simulation rows are frame samples, never fabricated robot telemetry.
	if not hardware and sample_clock >= 0.01:
		sample_clock = 0
		sample()
	if duration >= Rules.DURATION: finish("COMPLETED")

func sample() -> void:
	if raw == null: return
	var row: PackedStringArray = []
	row.resize(36)
	row.fill("")
	row[0] = str(duration)
	row[1] = str(packet)
	var screen = Rules.screen_limits(game)
	var p = screen.position + Vector2(player_position.x,1-player_position.y)*screen.size
	var t = screen.position + Vector2(target_position.x,1-target_position.y)*screen.size
	row[22] = str(p.x)
	row[23] = str(p.y)
	row[24] = str(t.x)
	row[25] = str(t.y)
	row[26] = "PAUSED" if paused else "RUNNING"
	row[27] = str(targets)
	row[28] = str(hits)
	row[29] = str(misses)
	row[30] = annotation
	row[31] = "Input=" + ("MARS" if hardware else "Simulation")
	if hardware and Robot.last_packet.has("sensors"):
		fill_telemetry(row,Robot.last_packet)
	raw.store_csv_line(row)
	packet += 1
	if packet % 100 == 0 or annotation != "": raw.flush()
	annotation = ""

func fill_telemetry(row: PackedStringArray,data: Dictionary) -> void:
	row[0]=str(data.runtime)
	row[1]=str(data.number)
	row[2]=str(data.status)
	row[3]=str(data.control_type)
	row[4]=str(data.error)
	row[5]=str(data.limb)
	row[6]=str(data.calibration)
	row[7]=str(data.force)
	for i in 3: row[8+i]=str(data.sensors[9+i])
	row[11]=str(data.button)
	for i in 3: row[12+i]=str(data.endpoint[i])
	row[15]=str(data.plane_endpoint.y)
	row[16]=str(data.plane_endpoint.x)
	var endpoint = Records.endpoint_target(target_position,movement)
	row[17]=str(endpoint.y)
	row[18]=str(endpoint.x)
	for i in 3:
		row[19+i]=str(data.sensors[12+i]) if data.sensors.size()>12+i else ""
	for i in 4: row[32+i]=str(data.sensors[i])

func finish(reason: String = "STOPPED") -> bool:
	if not running: return true
	if game == "TW": misses = targets - hits
	# A target cut short by the trial boundary is recorded as unresolved, not a miss.
	annotation = reason + (";TARGET_UNRESOLVED" if target_open else "")
	sample()
	raw.flush()
	var cumulative = Vector3i(targets, hits, misses)
	for previous in history:
		if previous[9] == game and previous[7] == movement:
			cumulative += Vector3i(int(previous[15]), int(previous[16]), int(previous[17]))
	# Unity uses integer percentage arithmetic.
	var rate = int(100.0 * hits / maxi(1, targets))
	var today = stamp().left(10)
	var previous_date = ""
	var today_hits = hits
	var today_stars = 0
	var all_stars = 0
	var previous_hits = 0
	for previous in history:
		if previous[1].left(10) < today and previous[1].left(10) > previous_date:
			previous_date = previous[1].left(10)
	for previous in history:
		if previous[9] != game: continue
		all_stars += int(previous[21])
		if previous[1].begins_with(today):
			today_hits += int(previous[16])
			today_stars += int(previous[21])
		elif previous[1].begins_with(previous_date): previous_hits += int(previous[16])
	var star = 1 if today_hits > previous_hits and today_stars == 0 else 0
	var next_scrub = clampf(scrub_area * 0.9,0.0001,0.001) if star else scrub_area
	var relative = user_id + "/data/rawdata/" + raw_name
	var row: PackedStringArray = [str(session),session_started,str(trial_day),str(trial_session),started,stamp(),relative,movement,str(plane),game,str(speed),str(reach_time()),"60",str(rate),str(duration),str(targets),str(hits),str(misses),str(cumulative.x),str(cumulative.y),str(cumulative.z),"0","0",raw_name]
	row[21] = str(star)
	row[22] = str(all_stars + star)
	if game == "BS":
		row[10] = "0"
		row[11] = "0" # Patient-paced touch target, without a timeout.
	if game == "FW":
		row[10] = "0"
		row[11] = "0.85" # Completion-based hold duration, seconds.
	if game == "TW":
		row[10] = "0"
		row[11] = str(next_scrub)
	var file = FileAccess.open(user_path().path_join("sessions/sessions.csv"), FileAccess.READ_WRITE)
	if file == null:
		paused = true
		error = "Session summary could not be saved. Raw data is preserved; retry Finish."
		return false
	file.seek_end()
	file.store_csv_line(row)
	file.flush()
	if file.get_error() != OK:
		paused = true
		error = "Session summary write failed. Raw data is preserved."
		return false
	history.append(row)
	last_result = {"hits":hits,"misses":misses,"targets":targets,"seconds":duration,"speed":speed,"next_speed":Rules.adapt(speed,rate),"reason":reason,"raw":raw_name}
	speed = last_result.next_speed
	scrub_area = next_scrub
	running = false
	raw.close()
	raw = null
	ended.emit()
	return true
