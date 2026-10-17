extends Node2D
var game:Node
## Time of day. A game's first trial of a run starts from the setting that suits
## its scenery; every further trial moves on, so the same game never looks the
## same twice in a row. The setting is fixed for the whole trial.
const TIME_OF_DAY={"MC":0,"TW":0,"TT":0,"CB":1,"PP":1,"FR":1,"FW":1,"SS":2,"DC":2,"BS":2}
static var played:Dictionary={}
static func note_trial(game:String)->void:
	played[game]=int(played.get(game,-1))+1
static func trial_index()->int:
	return maxi(0,int(played.get(Trial.game,0)))
static func lighting_time()->float:
	if Trial.game=="FW": return 45.0
	var i=trial_index()
	# i/3 shifts the pairing every third trial, so lighting and scenery take all nine combinations.
	return float(posmod(TIME_OF_DAY.get(Trial.game,0)+i+i/3,3))*20.0+5.0
## Which of the three scenery variants this trial uses.
static func look()->int:
	return posmod(trial_index(),3)
static func stage(seconds:float)->int:
	return mini(2,int(maxf(0,seconds)/20.0))
static func variant(index:int,session:int=0)->int:
	return posmod(index+session,3)
## Scenery colours for the current time of day, shifted in hue by this trial's look.
static func palette(day:Color,evening:Color,night:Color)->Color:
	var t=lighting_time()
	var c=day.lerp(evening,smoothstep(15,22,t)).lerp(night,smoothstep(35,42,t))
	var l=look()
	if l==0: return c
	return Color.from_hsv(fposmod(c.h+(0.11 if l==1 else -0.09),1.0),c.s,c.v,c.a)
func _ready()->void:
	z_index=50
func _process(_delta:float)->void:
	if not is_instance_valid(game): return
	if Trial.game=="FR" and is_instance_valid(game.fish_sprite):
		game.fish_sprite.modulate=[Color.WHITE,Color("ffd58c"),Color("a6dcff")][variant(Trial.targets,Trial.trial_session)]

	queue_redraw()
func _draw()->void:
	if not is_instance_valid(game): return
	var dusk=smoothstep(15,22,lighting_time())
	var night=smoothstep(35,42,lighting_time())
	var wash=Color(0.9,0.38,0.12,dusk*.065*(1-night)).lerp(Color(.025,.055,.16,night*.16),night)
	draw_rect(Rect2(0,0,1600,900),wash)
	if Trial.game=="BS" and Trial.target_open and game.cooldown<=0:
		var p:Vector2=game.target
		var mode=variant(Trial.targets,Trial.trial_session)
		if mode==1: draw_arc(p,20,0,TAU,32,Color(1,1,1,.65),2,true)
		elif mode==2:
			for i in 5:
				var q=p+Vector2.from_angle(i*TAU/5+Trial.duration*.3)*17
				draw_circle(q,3,Color(1,.9,.65,.7))




