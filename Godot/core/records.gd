extends Node
const CONFIG_HEADER = "HomerID,StartDate,EndDate,TotalTime,ML,AP,MLAP,ForeArmLength,UpperArmLength,TrainingSide,Location,Group"
const ROM_HEADER = "DateTime,TrainingPlaneAngle,TopRawX,TopRawY,BottomRawX,BottomRawY,LeftRawX,LeftRawY,RightRawX,RightRawY,TopAdjustedX,TopAdjustedY,BottomAdjustedX,BottomAdjustedY,LeftAdjustedX,LeftAdjustedY,RightAdjustedX,RightAdjustedY,RawDataFileName"
const WEIGHT_HEADER = "DateTime,TrainingPlaneAngle,LeftTargetX,LeftTargetY,LeftActualX,LeftActualY,LeftForce,RightTargetX,RightTargetY,RightActualX,RightActualY,RightForce,TopTargetX,TopTargetY,TopActualX,TopActualY,TopForce,BottomTargetX,BottomTargetY,BottomActualX,BottomActualY,BottomForce,CenterTargetX,CenterTargetY,CenterActualX,CenterActualY,CenterForce,RawDataFileName"
## An assessment belongs to the plane it was recorded at: any change of plane means redoing
## every assessment (a small tolerance only absorbs float round-trips through the CSV).
const PLANE_TOLERANCE = 0.5
## True when the last plane save made existing assessments invalid.
var assessments_reset = false
var profile: Dictionary = {}
var error = ""
var corners: Dictionary = {}
var weight: Dictionary = {}
var device_raw: FileAccess
var device_raw_path=""
var device_samples=0

func _ready() -> void:
	Robot.sample_received.connect(record_device_sample)

func record_device_sample(packet: Dictionary) -> void:
	if Trial.session_started=="" or not Trial.hardware: return
	var expected=Trial.user_path().path_join("rawdata/device-sess%02d.csv" % Trial.session)
	if expected!=device_raw_path or device_raw==null:
		if device_raw!=null: device_raw.close()
		device_raw_path=expected
		device_raw=FileAccess.open(expected,FileAccess.READ_WRITE if FileAccess.file_exists(expected) else FileAccess.WRITE)
		if device_raw==null: return
		if device_raw.get_length()==0:
			device_raw.store_line(":Device: MARS")
			device_raw.store_line(":TrialType: SetupAndDiagnostics")
			device_raw.store_line(Trial.RAW_HEADER+",Angle1,Angle2,Angle3,Angle4")
		device_raw.seek_end()
	var row: PackedStringArray=[]
	row.resize(36)
	row.fill("")
	Trial.fill_telemetry(row,packet)
	row[26]="DEVICE_STREAM"
	row[31]="MARS"
	device_raw.store_csv_line(row)
	device_samples+=1
	if device_samples%100==0: device_raw.flush()

func _exit_tree() -> void:
	if device_raw!=null:
		device_raw.flush()
		device_raw.close()

func table(path: String) -> Array:
	error=""
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null: return []
	var header = PackedStringArray()
	var rows: Array = []
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size()==0: continue
		row[0] = row[0].trim_prefix("\ufeff")
		if row[0].begins_with(":") or row[0]=="": continue
		if header.is_empty():
			header = row
			continue
		if row.size()!=header.size():
			error = "Malformed row in " + path.get_file()
			return []
		var item: Dictionary = {}
		for i in header.size(): item[header[i]] = row[i]
		rows.append(item)
	return rows

## The three pre-header lines Unity puts at the top of its session, plane, arm-weight and error files.
func preheader() -> PackedStringArray:
	return PackedStringArray([":Location: " + str(profile.get("Location","")), ":Device: MARS", ":User: " + Trial.user_id])

func append(path: String,header: String,row: PackedStringArray) -> bool:
	if row.size()!=header.split(",").size():
		error = "Record column count mismatch: " + path
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var exists = FileAccess.file_exists(path)
	var file = FileAccess.open(path,FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		error = "Cannot write " + path
		return false
	if not exists:
		# Unity writes :Location / :Device / :User lines above the header of these files.
		if path.get_file() in ["trainingplane.csv","armweight.csv","errorLog.csv"]:
			for line in preheader(): file.store_line(line)
		file.store_line(header)
	file.seek_end()
	file.store_csv_line(row)
	file.flush()
	var result = file.get_error()==OK
	if not result: error = "Writing failed: " + path
	return result

func load_profile() -> void:
	profile.clear()
	var rows = table(Trial.user_path().path_join("configdata.csv"))
	if not rows.is_empty(): profile = rows[-1]
	rows = table(Trial.user_path().path_join("trainingplane/trainingplane.csv"))
	Trial.plane = float(rows[-1].TrainingPlaneAngle) if not rows.is_empty() else -90.0
	load_assessments()

func load_assessments() -> void:
	corners.clear()
	weight.clear()
	for movement in ["ML","AP","MLAP"]:
		for row in table(Trial.user_path().path_join("rom/"+movement+"-rom.csv")):
			if absf(float(row.TrainingPlaneAngle)-Trial.plane)<=PLANE_TOLERANCE: corners[movement]=row
	for row in table(Trial.user_path().path_join("armweight/armweight.csv")):
		if absf(float(row.TrainingPlaneAngle)-Trial.plane)<=PLANE_TOLERANCE: weight=row

func save_profile(values: Dictionary) -> bool:
	var row: PackedStringArray = []
	for key in CONFIG_HEADER.split(","): row.append(str(values.get(key,"")))
	if append(Trial.user_path().path_join("configdata.csv"),CONFIG_HEADER,row):
		profile = values.duplicate()
		return true
	return false

func save_plane(angle: float) -> bool:
	if not append(Trial.user_path().path_join("trainingplane/trainingplane.csv"),"DateTime,TrainingPlaneAngle",[Trial.stamp(),str(angle)]): return false
	var had = not corners.is_empty() or not weight.is_empty()
	Trial.plane = angle
	load_assessments()
	assessments_reset = had and corners.is_empty() and weight.is_empty()
	return true

func limits(movement: String) -> Rect2:
	if not corners.has(movement): return Rect2(-Trial.rom/2,Trial.rom)
	var row = corners[movement]
	var low = Vector2(float(row.LeftAdjustedX),float(row.BottomAdjustedY))
	var high = Vector2(float(row.RightAdjustedX),float(row.TopAdjustedY))
	return Rect2(low,high-low)

func normalized_position(movement: String) -> Vector2:
	if not Robot.last_packet.has("plane_endpoint"): return Vector2.ONE/2
	var bounds = limits(movement)
	var ep: Vector2 = Robot.last_packet.plane_endpoint
	var point = (ep-bounds.position)/Vector2(maxf(bounds.size.x,0.001),maxf(bounds.size.y,0.001))
	if profile.get("TrainingSide","RIGHT").to_upper()=="RIGHT": point.x = 1-point.x
	point.y = 1-point.y
	return point.clamp(Vector2.ZERO,Vector2.ONE)

func endpoint_target(point: Vector2,movement: String) -> Vector2:
	var p = point
	if profile.get("TrainingSide","RIGHT").to_upper()=="RIGHT": p.x=1-p.x
	p.y=1-p.y
	var bounds = limits(movement)
	return bounds.position + p*bounds.size

func today_minutes(movement: String) -> float:
	var total = 0.0
	for row in Trial.history:
		if row[7]==movement and row[4].begins_with(Trial.stamp().left(10)): total+=float(row[14])/60.0
	return total

func training_block(movement: String) -> String:
	if profile.is_empty(): return "Create or import a patient profile first."
	if not Robot.ready_for_training(): return "Connect and calibrate MARS, then enable position control."
	var expected_limb=1 if str(profile.get("TrainingSide","RIGHT")).to_upper()=="RIGHT" else 2
	if Robot.last_packet.get("limb",0)!=expected_limb: return "Set the robot limb to match this patient's training side."
	if absf(Robot.last_packet.sensors[0]-Trial.plane)>10: return "Move the robot to the saved training plane before training."
	if Robot.last_packet.force<=10: return "Attach the training arm before starting."
	if not corners.has(movement): return "Complete the %s range assessment at this training plane." % movement
	var bounds = limits(movement)
	if (movement != "AP" and bounds.size.x <= 0.001) or (movement != "ML" and bounds.size.y <= 0.001): return "Assessment range is too small. Repeat the assessment."
	if movement=="MLAP" and weight.is_empty(): return "Complete the arm-weight assessment at this plane."
	if movement=="MLAP":
		for key in ["LeftForce","RightForce","TopForce","BottomForce","CenterForce"]:
			if not str(weight.get(key,"")).is_valid_float() or float(weight.get(key,0))<=0: return "The saved arm-weight assessment is incomplete. Repeat it."
	if float(profile.get(movement,0))<=0: return "No training time is prescribed for " + movement
	if today_minutes(movement)>=float(profile.get(movement,0)): return "Today's prescribed time for %s is complete." % movement
	var end = str(profile.get("EndDate",""))
	if end.length()>=10:
		var iso = end.substr(6,4)+"-"+end.substr(3,2)+"-"+end.substr(0,2)
		if iso<Trial.stamp().left(10): return "The prescription has expired. Update it in Patient & plan."
	return ""

func log_event(text: String) -> void:
	if Trial.session_started=="": return
	append(Trial.user_path().path_join("applog/godot-events.csv"),"DateTime,Event",[Trial.stamp(),text])

func log_error(text: String,status: String="NOTRESOLVED") -> void:
	if Trial.session_started=="": return
	append(Trial.user_path().path_join("errorlog/errorLog.csv"),"DateTime,HospitalID,SessionNumber,TrialNumberDay,Scene,Movement,Error,Status",[Trial.stamp(),str(profile.get("HomerID",Trial.user_id)),str(Trial.session),str(Trial.trial_day),"GODOT",Trial.movement,text,status])

func import_user(source: String,id: String) -> bool:
	if Trial.running or id.is_empty() or id!=id.validate_filename() or id in [".",".."]: return false
	var destination = Trial.data_root.path_join(id)
	if DirAccess.dir_exists_absolute(destination):
		error = "That user already exists. Choose a new ID to import without overwriting."
		return false
	var data = source.path_join("data") if DirAccess.dir_exists_absolute(source.path_join("data")) else source
	if not FileAccess.file_exists(data.path_join("configdata.csv")):
		error = "Select the old user's folder or its data folder. configdata.csv was not found."
		return false
	var configuration=table(data.path_join("configdata.csv"))
	if configuration.is_empty() or not configuration[-1].has("HomerID"):
		error="The source patient configuration is invalid."
		return false
	var source_sessions=data.path_join("sessions/sessions.csv")
	if FileAccess.file_exists(source_sessions):
		var check_rows=table(source_sessions)
		if error!="": return false
		for record in check_rows:
			if record.size()!=24 or not record.has("TrialRawDataFile"):
				error="The source session format is incompatible; no records imported."
				return false
	if not copy_records(data,destination.path_join("data")): return false
	var session_path=destination.path_join("data/sessions/sessions.csv")
	if FileAccess.file_exists(session_path):
		var rows=table(session_path)
		var output=FileAccess.open(session_path,FileAccess.WRITE)
		if output==null:
			error="Could not update imported raw-file references."
			return false
		output.store_line(":Location: Imported")
		output.store_line(":Device: MARS")
		output.store_line(":User: "+id)
		output.store_line(Trial.SESSION_HEADER)
		for record in rows:
			record.TrialRawDataFile=id+"/data/rawdata/"+str(record.get("RawDataFileName",""))
			var row: PackedStringArray=[]
			for key in Trial.SESSION_HEADER.split(","): row.append(str(record.get(key,"")))
			output.store_csv_line(row)
		output.close()
	return true

func copy_records(source: String,destination: String) -> bool:
	var directory = DirAccess.open(source)
	if directory==null: return false
	if DirAccess.make_dir_recursive_absolute(destination)!=OK: return false
	for file in directory.get_files():
		if file.get_extension().to_lower() not in ["csv","txt","log"]: continue
		if DirAccess.copy_absolute(source.path_join(file),destination.path_join(file))!=OK:
			error = "Import failed while copying " + file
			return false
	for folder in directory.get_directories():
		if directory.is_link(folder): continue
		if not copy_records(source.path_join(folder),destination.path_join(folder)): return false
	return true
