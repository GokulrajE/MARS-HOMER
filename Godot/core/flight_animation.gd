extends RefCounted
static func pose(id:String,t:float,reaction:float,bank:float,data:Dictionary) -> Dictionary:
	var offset=Vector2(0,sin(t*data.bob)*4)
	var angle=bank*data.bank+sin(t*data.bob)*data.sway
	var stretch=Vector2(1,1+sin(t*data.bob)*.015)
	if reaction>0:
		var phase=1.0-clampf(reaction,0,1)
		var lift=sin(phase*PI)
		match id:
			"bheem": offset.y-=lift*12; angle-=lift*.10
			"chutki": offset+=Vector2(sin(phase*TAU)*5,-lift*10); angle+=sin(phase*TAU)*.07
			"raju": offset.y-=absf(sin(phase*TAU))*14; stretch.y+=lift*.035
			"bean": angle+=sin(phase*TAU*2)*.12*lift; offset.x+=sin(phase*TAU)*4
			"rajini": angle-=lift*.13; offset.y-=lift*5
			"vijay": offset+=Vector2(lift*8,-lift*12); angle-=lift*.15
	elif reaction<0:
		var strength=absf(reaction)/.7
		angle+=sin(t*17)*.04*strength
		offset.x+=sin(t*21)*3*strength
	return {"offset":offset,"angle":angle,"stretch":stretch}
