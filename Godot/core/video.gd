extends PanelContainer
const UITheme = preload("res://core/ui_theme.gd")
const Guide = preload("res://core/video_guide.gd")
## Looping reference clip with a caption. Clips are the original Unity
## instructional videos, converted to Ogg Theora (Godot's native format).
## Every clip is 640 x 480 (4:3), so all of them show at the same size; clips that were
## square or portrait sit centred on a blurred copy of themselves. Entry: [file, caption,
## aspect, length in seconds, where the real picture sits inside the frame]. The three
## movement clips also get a glowing guide line showing how to move.
const FRAME = 4.0 / 3.0
const CLIPS = {
	"ML": ["res://assets/videos/ml.ogv", "Left-right (ML) movement", FRAME, 8.0, Rect2(0.125, 0.0, 0.75, 1.0)],
	"AP": ["res://assets/videos/ap.ogv", "Forward-back (AP) movement", FRAME, 2.97, Rect2(0, 0, 1, 1)],
	"MLAP": ["res://assets/videos/mlap.ogv", "Combined (MLAP) movement", FRAME, 11.3, Rect2(0, 0, 1, 1)],
	"SETUP": ["res://assets/videos/setting_up.ogv", "Activating MARS", FRAME, 3.9, Rect2(0.2188, 0, 0.5625, 1)],
	"ATTACH": ["res://assets/videos/attach_arm.ogv", "Attaching the arm", FRAME, 9.5, Rect2(0.1, 0, 0.8, 1)],
	"STRAP": ["res://assets/videos/strap_removal.ogv", "Removing the arm strap", FRAME, 18.47, Rect2(0.2188, 0, 0.5625, 1)]
}
var player: VideoStreamPlayer
var frame: AspectRatioContainer
var guide: Control
var caption: Label
var current = ""
var idle_text = ""
var hide_when_idle = false

func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.04, 0.07, 0.9), Color("405169"), 1, 18, 8, 8))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	# The picture keeps its own proportions; the overlay is laid over exactly the same rectangle.
	frame = AspectRatioContainer.new()
	frame.custom_minimum_size = Vector2(240, 180)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The card is exactly as tall as the picture: height follows width at the clip's ratio.
	frame.resized.connect(fit_height)
	column.add_child(frame)
	var stage = Control.new()
	frame.add_child(stage)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.finished.connect(func(): player.play())
	stage.add_child(player)
	guide = Guide.new()
	guide.player = player
	stage.add_child(guide)
	caption = UITheme.label("", 18, UITheme.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

func fit_height() -> void:
	var wanted = frame.size.x / maxf(0.1, frame.ratio)
	if absf(wanted - frame.custom_minimum_size.y) > 1.0: frame.custom_minimum_size.y = wanted

func play(key: String) -> void:
	if key == current and player.is_playing(): return
	current = key
	if not CLIPS.has(key):
		stop()
		return
	show()
	var stream = load(CLIPS[key][0])
	caption.text = "Reference video • " + CLIPS[key][1]
	if stream == null:
		caption.text = "Reference video unavailable"
		return
	frame.ratio = CLIPS[key][2]
	fit_height()
	guide.configure(key, CLIPS[key][3], CLIPS[key][4])
	player.stream = stream
	player.play()

func stop() -> void:
	player.stop()
	player.stream = null
	guide.configure("", 0.0, Rect2(0, 0, 1, 1))
	current = ""
	caption.text = idle_text
	visible = not hide_when_idle
