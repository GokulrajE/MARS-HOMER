extends SceneTree
var failures=0
var trial: Node
var records: Node
var robot: Node
const Protocol=preload("res://core/protocol.gd")

func check(ok: bool,description: String) -> void:
	if not ok:
		failures+=1
		push_error(description)

func packet_bytes() -> PackedByteArray:
	var data=PackedByteArray()
	data.resize(59)
	data[0]=59
	data[1]=0x13
	data[4]=2
	data.encode_u16(5,42)
	data.encode_u32(7,1234)
	for i in 12: data.encode_float(11+i*4,0)
	data.encode_float(43,2000)
	var frame=PackedByteArray([255,255])
	frame.append_array(data)
	var checksum=0
	for byte in frame: checksum+=byte
	frame.append(checksum&255)
	return frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	trial=root.get_node("Trial")
	records=root.get_node("Records")
	robot=root.get_node("Robot")
	trial.data_root="res://test-output/system-"+str(Time.get_ticks_usec())
	check(trial.configure("system"),"Configure test user")
	var parser=Protocol.new()
	var frame=packet_bytes()
	check(parser.feed(frame.slice(0,17)).is_empty(),"Fragment buffered")
	var decoded=parser.feed(frame.slice(17))
	check(decoded.size()==1,"Fragmented sensor packet decoded")
	var data=decoded[0]
	check(data.number==42 and is_equal_approx(data.runtime,1.234),"Device time and packet number")
	check(is_equal_approx(data.force,19.62),"Grams converted to Newtons")
	check(data.plane_endpoint.distance_to(Vector2(0,0.766))<0.00001,"Kinematics")
	var corrupt=frame.duplicate()
	corrupt[20]^=1
	check(parser.feed(corrupt).is_empty(),"Bad checksum rejected")
	check(parser.feed(frame).size()==1,"Framing recovers")
	check(Protocol.command(PackedByteArray([128]))==PackedByteArray([170,170,2,128,214]),"Heartbeat exact bytes")
	var command=Protocol.target_command(1,20,6)
	check(command.decode_float(4)==1 and command.decode_float(12)==20 and command.decode_float(16)==6,"Position command byte layout")
	var values={"HomerID":"system","StartDate":"01-01-2020 00:00:00","EndDate":"31-12-2099 23:59:59","TotalTime":"30","ML":"10","AP":"10","MLAP":"10","ForeArmLength":"0.291","UpperArmLength":"0.475","TrainingSide":"LEFT","Location":"test","Group":"Experimental"}
	check(records.save_profile(values),"Save profile")
	check(records.save_plane(10),"Save plane")
	records.load_profile()
	check(records.profile.HomerID=="system" and trial.plane==10,"Reload clinical profile")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.open_workflow()
	await process_frame
	check(is_instance_valid(launcher.workflow),"Workflow UI loads")
	for i in launcher.workflow.tabs.get_tab_count():
		launcher.workflow.tabs.current_tab=i
		await process_frame
	var assessment=load("res://core/assessment.gd").new()
	assessment.kind="MLAP"
	root.add_child(assessment)
	await process_frame
	assessment.set_process(false)
	assessment.start()
	for i in 100:
		assessment.cursor=Vector2(sin(i*TAU/100)*0.2,cos(i*TAU/100)*0.15)
		assessment.collect(0.01)
	assessment.stop()
	check(assessment.review,"Range assessment review")
	assessment.save()
	check(records.corners.has("MLAP"),"Range saved in legacy schema")
	check(records.limits("MLAP").size.x>0.38,"Extreme 5 percent range calculation")
	assessment.queue_free()
	await process_frame
	assessment=load("res://core/assessment.gd").new()
	assessment.kind="WEIGHT"
	root.add_child(assessment)
	await process_frame
	assessment.set_process(false)
	assessment.start()
	for target in assessment.targets:
		assessment.cursor=target
		for i in 21: assessment.collect(0.1)
	check(assessment.review,"Five weight targets completed")
	assessment.save()
	check(not records.weight.is_empty() and float(records.weight.LeftForce)==20,"Weight data saved")
	assessment.queue_free()
	await process_frame
	trial.hardware=true
	robot.connected=true
	robot.last_seen=Time.get_ticks_msec()
	robot.last_packet=data
	check(records.training_block("MLAP")=="","Device start gates pass with calibrated fixture")
	trial.select_game("FR")
	check(trial.begin(),"Hardware fixture trial starts")
	trial.appear(Vector2.ONE/2)
	trial.sample()
	robot.last_seen=-10000
	trial.advance(1,false,Vector2.ZERO,Vector2.ZERO)
	check(trial.duration==0 and trial.paused,"Watchdog holds trial clock")
	robot.last_seen=Time.get_ticks_msec()
	check(trial.finish("TEST"),"Save telemetry trial")
	await process_frame
	var raw=FileAccess.open(trial.user_path().path_join("rawdata/"+trial.raw_name),FileAccess.READ)
	for i in 11: raw.get_line()
	var row=raw.get_csv_line()
	check(row.size()==36 and row[1]=="42" and is_equal_approx(float(row[7]),19.62),"Measured telemetry persisted")
	check(row[32]!="" and row[33]!="" and float(row[32])==0 and float(row[33])==0,"Joint angles persisted")
	raw.close()
	trial.hardware=false
	robot.connected=false
	var original=trial.user_path()
	check(records.import_user(original,"imported"),"Import old user without overwriting")
	check(not records.import_user(original,"imported"),"Refuse import overwrite")
	launcher.queue_free()
	await process_frame
	print("MARS system: %d failures" % failures)
	quit(1 if failures else 0)
