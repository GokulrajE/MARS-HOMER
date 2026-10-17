extends RefCounted
const CAST = {
	"bheem": {"target":"laddoo","name":"Bheem","file":"bheem_fly","mood":"Brave flight • bright plucked melody","bob":3.5,"bank":0.7,"sway":0.035,"color":Color("ffd46c"),"accent":Color("6cddff")},
	"chutki": {"target":"laddoo","name":"Chutki","file":"flight_chutki","mood":"Graceful glide • airy bells","bob":2.5,"bank":0.55,"sway":0.025,"color":Color("f9a8d4"),"accent":Color("c4b5fd")},
	"raju": {"target":"laddoo","name":"Raju","file":"flight_raju","mood":"Bouncy flight • playful marimba","bob":5.2,"bank":0.85,"sway":0.06,"color":Color("7dd3fc"),"accent":Color("fde68a")},
	"bean": {"target":"teddy","name":"Mr Bean","file":"flight_bean","mood":"Wobbly cruise • comic pizzicato","bob":2.9,"bank":1.1,"sway":0.095,"color":Color("c4a484"),"accent":Color("a7f3d0")},
	"rajini": {"target":"coin","name":"Rajini","file":"flight_rajini","mood":"Relaxed hero • warm bass groove","bob":2.1,"bank":0.45,"sway":0.02,"color":Color("fbbf24"),"accent":Color("fca5a5")},
	"vijay": {"target":"coin","name":"Vijay","file":"flight_vijay","mood":"Energetic swoop • upbeat synth","bob":4.1,"bank":0.9,"sway":0.045,"color":Color("67e8f9"),"accent":Color("a5b4fc")}
}
static var forced := ""
static var last := ""
## A new pilot for every trial, never the same one twice in a row.
static func next_character() -> String:
	if forced != "": return forced
	var ids: Array = CAST.keys().filter(func(id): return id != last)
	last = ids[randi() % ids.size()]
	return last
static func selected() -> String:
	var id=str(Services.settings.get_value("flight","character","bheem"))
	return id if CAST.has(id) else "bheem"
static func music_gain() -> float:
	return clampf(float(Services.settings.get_value("flight","volume",0.35)),0,1)
static func music_enabled() -> bool:
	return bool(Services.settings.get_value("flight","music",true))
static func music(id:String) -> AudioStreamWAV:
	var stream=load("res://assets/music/"+id+".wav").duplicate() as AudioStreamWAV
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	return stream
