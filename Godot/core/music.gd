extends Node
## One calm background track that plays through every screen and every session.
## It sits low behind menus and a little lower during a game so the capture / miss
## sounds stay clear. It is the only music in the software; Character Flight has none of its own.
## Ctrl+M switches it off and on; the choice is remembered.
const TRACK = "res://assets/music/bgm.mp3"
const MENU_DB = -11.0
const GAME_DB = -13.0
var player: AudioStreamPlayer
var enabled = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = bool(Services.settings.get_value("ui", "music", true))
	var stream = load(TRACK)
	if stream == null: return
	if stream is AudioStreamMP3: stream.loop = true
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -60.0
	add_child(player)
	if enabled: player.play()

## Level the track should have right now.
func target_db() -> float:
	if not enabled: return -60.0
	return GAME_DB if Trial.running else MENU_DB

func _process(delta: float) -> void:
	if player == null: return
	var wanted = target_db()
	player.volume_db = move_toward(player.volume_db, wanted, 40.0 * delta)
	if enabled and not player.playing: player.play()
	elif not enabled and player.playing and player.volume_db <= -59.0: player.stop()

func set_enabled(value: bool) -> void:
	enabled = value
	Services.settings.set_value("ui", "music", value)
	Services.save()
	Nav.tip_now("Music " + ("on" if value else "off"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and event.ctrl_pressed:
		set_enabled(not enabled)
