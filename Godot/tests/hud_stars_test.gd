extends SceneTree
func _initialize()->void: call_deferred("run")
func run()->void:
	var hud=load("res://core/game_hud.gd")
	var rows:Array=[]
	for data in [["SS",1,1],["MC",1,1],["SS",1,2],["SS",0,2]]:
		var row=PackedStringArray()
		row.resize(24)
		row.fill("")
		row[9]=data[0]; row[21]=str(data[1]); row[22]=str(data[2])
		rows.append(row)
	assert(hud.saved_stars("SS",rows)==2,"Sum earned stars, not cumulative totals")
	assert(hud.saved_stars("MC",rows)==1,"Each game's stars isolated")
	assert(hud.saved_stars("FR",rows)==0,"New game starts at zero")
	print("HUD star accounting: PASS")
	quit()
