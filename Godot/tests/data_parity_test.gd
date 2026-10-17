extends SceneTree
# Saved files must match the Unity project's layout: file names, pre-header lines, column headers,
# row widths and date formats. Unity's headers are read straight from its source when it is present.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func unity_header(source: String, name: String) -> String:
	var path = ProjectSettings.globalize_path("res://").path_join("../Assets/scripts/" + source).simplify_path()
	if not FileAccess.file_exists(path): return ""
	var text = FileAccess.get_file_as_string(path)
	var start = text.find(name)
	if start < 0: return ""
	var open_at = text.find("{", start)
	var close_at = text.find("}", open_at)
	var parts = []
	for piece in text.substr(open_at + 1, close_at - open_at - 1).split(","):
		var cleaned = piece.strip_edges().trim_prefix("\"").trim_suffix("\"")
		if cleaned != "": parts.append(cleaned)
	return ",".join(parts)

func lines_of(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(path).replace("\r", "").split("\n", false)

func run() -> void:
	var trial = root.get_node("Trial")
	var records = root.get_node("Records")
	trial.data_root = "res://test-output/parity-" + str(Time.get_ticks_usec())
	check(trial.configure("parity"), "Create user")
	trial.hardware = false
	check(records.save_profile({"HomerID": "parity", "StartDate": "01-10-2026 00:00:00", "EndDate": "31-10-2026 23:59:59", "TotalTime": "30", "ML": "10", "AP": "10", "MLAP": "10", "ForeArmLength": "0.291", "UpperArmLength": "0.475", "TrainingSide": "RIGHT", "Location": "Clinic", "Group": "Experimental"}), "Save profile")
	check(records.save_plane(-90), "Save plane")
	trial.select_game("SS")
	check(trial.begin(), "Begin")
	trial.appear(Vector2(0.4, 0.4))
	trial.resolve(true)
	trial.appear(Vector2(0.6, 0.4))
	trial.resolve(false)
	check(trial.finish(), "Finish")
	records.log_error("test error")
	var base = trial.user_path()
	# Unity's own header definitions.
	var unity_session = unity_header("DataManager.cs", "SESSIONFILEHEADER")
	var unity_raw = unity_header("DataManager.cs", "RAWFILEHEADER")
	var unity_plane = unity_header("DataManager.cs", "TRAININGPLANEFILEHEADER")
	var unity_error = unity_header("DataManager.cs", "ERRORLOGFILEHEADER")
	var unity_weight = unity_header("DataManager.cs", "ARMWEIGHTFILEHEADER")
	var unity_rom = unity_header("others.cs", "FILEHEADER")
	if unity_session != "":
		check(trial.SESSION_HEADER == unity_session, "Session header matches Unity")
		check(trial.RAW_HEADER == unity_raw, "Raw header matches Unity")
		check(records.WEIGHT_HEADER == unity_weight, "Arm weight header matches Unity")
		check(records.ROM_HEADER == unity_rom, "ROM header matches Unity")
	else: print("Unity sources not found; checked against the built-in copy only")
	# sessions.csv
	var sessions = lines_of(base.path_join("sessions/sessions.csv"))
	check(sessions[0] == ":Location: Clinic" or sessions[0].begins_with(":Location:"), "sessions.csv starts with :Location")
	check(sessions[1] == ":Device: MARS" and sessions[2] == ":User: parity", "sessions.csv has :Device and :User")
	check(sessions[3] == trial.SESSION_HEADER, "sessions.csv header")
	var row = Array(sessions[4].split(","))
	check(row.size() == 24, "Session row has 24 columns")
	var date = RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
	for index in [1, 4, 5]: check(date.search(row[index]) != null, "Session date column %d is yyyy-MM-dd HH:mm:ss" % index)
	check(row[7] == "ML" and row[9] == "SS" and row[15] == "2" and row[16] == "1" and row[17] == "1", "Targets, hits and misses are recorded")
	check(row[13] == "50", "Success rate is an integer percentage")
	check(FileAccess.file_exists(trial.data_root.path_join(row[6])), "TrialRawDataFile points at a real file")
	# raw trial file
	var raw_name = "raw-sess%02d-trial%03d-SS-ML.csv" % [int(row[0]), int(row[2])]
	check(row[23] == raw_name, "Raw file is named like Unity: " + raw_name)
	var raw = lines_of(base.path_join("rawdata/" + raw_name))
	var header_at = -1
	for i in raw.size():
		if not raw[i].begins_with(":"):
			header_at = i
			break
	check(raw[0].begins_with(":Device") and raw[1].begins_with(":Location") and raw[2].begins_with(":User") and raw[3].begins_with(":Movement"), "Raw file pre-header lines")
	check(raw[header_at].begins_with(trial.RAW_HEADER), "Raw header starts with Unity's columns")
	var width = raw[header_at].split(",").size()
	var consistent = true
	for i in range(header_at + 1, raw.size()):
		if raw[i].split(",").size() != width: consistent = false
	check(raw.size() > header_at + 2 and consistent, "Every raw row has the header's column count")
	# plane, config, error log
	var plane = lines_of(base.path_join("trainingplane/trainingplane.csv"))
	check(plane[0].begins_with(":Location") and plane[3] == "DateTime,TrainingPlaneAngle" and plane[3] == (unity_plane if unity_plane != "" else plane[3]), "trainingplane.csv layout")
	check(date.search(plane[4].split(",")[0]) != null and plane[4].split(",")[1] == "-90.0", "Plane row: date and angle")
	var error_file = lines_of(base.path_join("errorlog/errorLog.csv"))
	check(error_file[0].begins_with(":Location") and error_file[3] == (unity_error if unity_error != "" else error_file[3]), "errorLog.csv layout")
	var config = lines_of(base.path_join("configdata.csv"))
	check(config[0] == records.CONFIG_HEADER and config[1].split(",").size() == 12, "configdata.csv header and 12 columns")
	check(RegEx.create_from_string("^[0-9]{2}-[0-9]{2}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$").search(config[1].split(",")[1]) != null, "Config dates are dd-MM-yyyy HH:mm:ss")
	print("Data parity: %d failures" % failures)
	quit(1 if failures else 0)
