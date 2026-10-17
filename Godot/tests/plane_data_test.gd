extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var trial=root.get_node("Trial")
	var records=root.get_node("Records")
	trial.data_root="user://verification-plane-"+str(Time.get_ticks_usec())
	trial.configure("plane-audit")
	var launcher=load("res://main.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	launcher.show_choose()
	launcher.open_training_plane()
	var editor=launcher.screen
	editor.angle.value=-70
	editor.apply_plane()
	check(trial.plane==-70,"Plane control saves selected angle")
	records.load_profile()
	check(trial.plane==-70,"Plane survives disk reload")
	var assessment=load("res://core/assessment.gd").new()
	assessment.kind="MLAP"
	root.add_child(assessment)
	assessment.set_process(false)
	assessment.extrema.assign([Vector2(0,.1),Vector2(0,-.1),Vector2(-.2,0),Vector2(.2,0)])
	assessment.retain=100
	assessment.review=true
	assessment.save()
	check(assessment.range_text()=="ML 40.0 cm  •  AP 20.0 cm","Assessment label in centimetres")
	check(records.limits("MLAP").size.distance_to(Vector2(.4,.2))<.00001,"Saved assessment stays in metres")
	var rows=records.table(trial.user_path().path_join("rom/MLAP-rom.csv"))
	check(rows.size()==1 and float(rows[0].TrainingPlaneAngle)==-70,"Assessment stores plane")
	records.save_plane(-90)
	check(not records.corners.has("MLAP"),"Different plane does not reuse incompatible assessment")
	records.save_plane(-70)
	check(records.corners.has("MLAP"),"Original plane restores matching assessment")
	for side in ["LEFT","RIGHT"]:
		records.profile.TrainingSide=side
		for p in [Vector2.ZERO,Vector2.ONE,Vector2(.25,.75)]:
			var ep=records.endpoint_target(p,"MLAP")
			root.get_node("Robot").last_packet={"plane_endpoint":ep}
			check(records.normalized_position("MLAP").distance_to(p)<.00001,"Metre target mapping roundtrip "+side)
	for code in trial.Rules.GAMES:
		trial.select_game(code)
		trial.rom=Vector2(.4,.2)
		trial.speed=.1
		trial.begin()
		trial.appear(Vector2(.25,.75))
		trial.advance(.1,false,Vector2(.5,.5),Vector2(.25,.75))
		trial.resolve(true)
		check(trial.finish("AUDIT"),code+" finish saves")
	var sessions=records.table(trial.user_path().path_join("sessions/sessions.csv"))
	check(sessions.size()==trial.Rules.GAMES.size(),"Every game has exactly one session")
	for row in sessions:
		check(float(row.TrainingPlaneAngle)==-70,"Saved plane "+row.GameName)
		check(int(row.CurrentHits)==1 and int(row.CurrentTargets)==1,"Saved hit counts "+row.GameName)
		if row.GameName=="BS":
			check(float(row.ReachSpeed)==0 and float(row.GameParameter)==0,"Bubble stores patient-paced target convention")
		elif row.GameName=="FW":
			check(float(row.ReachSpeed)==0 and is_equal_approx(float(row.GameParameter),.85),"Fireworks stores patient-paced hold duration")
		elif row.GameName!="TW":
			var distance=.4 if row.Movement=="ML" else .2 if row.Movement=="AP" else .3
			check(absf(float(row.GameParameter)-distance/.1)<.00001,"Saved physical reach duration "+row.GameName)
		else: check(float(row.ReachSpeed)==0,"Unity Table Wiping scrub-area convention preserved")
		check(FileAccess.file_exists(trial.user_path().path_join("rawdata/"+row.RawDataFileName)),"Raw file exists "+row.GameName)
	print("Plane, metres and saved distances: %d failures" % failures)
	quit(1 if failures else 0)
