extends CanvasLayer
## Unity's error panel (connectStatusHandler): when MARS reports an error, such as an angle limit,
## jump or sensor mismatch, or the link to MARS is lost, a panel covers the screen and the MARS
## button no longer drives the app. Unity shows "Device has issue. Call the Engineers." for any
## error other than a plain NOHEARTBEAT (flag 1); this version adds the specific error and what to
## do about it. A tap is ignored while the panel is up; holding the button (or Close) finishes the
## trial, saves it and leaves for the summary. The panel clears itself once the error has gone.
signal close_requested
const UITheme = preload("res://core/ui_theme.gd")
const Protocol = preload("res://core/protocol.gd")
const CLEAR_SECONDS = 1.0
var dim: ColorRect
var title: Label
var body: Label
var detail: Label
var hint: Label
var close_button: Button
var shown = false
var clear_for = 0.0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.theme = UITheme.build()
	add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.04, 0.06, 0.96), Color("ff6b6b"), 3, 26, 38, 30))
	center.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	title = UITheme.label("Device has issue", 44, Color("ff8a8a"))
	column.add_child(title)
	body = UITheme.label("", 28, Color.WHITE, true)
	column.add_child(body)
	detail = UITheme.label("", 20, UITheme.MUTED, true)
	column.add_child(detail)
	hint = UITheme.label("", 20, UITheme.FOCUS, true)
	column.add_child(hint)
	close_button = Button.new()
	close_button.text = "Close  •  finish and save"
	close_button.custom_minimum_size = Vector2(0, 58)
	close_button.pressed.connect(request_close)
	column.add_child(close_button)
	dim.hide()

## The error flags that raise the panel. A lone NOHEARTBEAT (bit 0) is ignored, as in Unity.
static func error_flags() -> int:
	return int(Robot.last_packet.get("error", 0)) & ~1

func wanted() -> String:
	if not Trial.hardware: return ""
	var launcher = get_parent()
	if "screen" in launcher and is_instance_valid(launcher.screen) and launcher.screen.get_script() != null and launcher.screen.get_script().resource_path.ends_with("diagnostics.gd"): return "" # Unity skips its Diagnostics scene
	if Robot.link_lost: return "link"
	if Robot.connected and error_flags() != 0: return "error"
	return ""

func _process(delta: float) -> void:
	var kind = wanted()
	if kind != "":
		clear_for = 0.0
		show_panel(kind)
	elif shown:
		clear_for += delta
		if clear_for >= CLEAR_SECONDS: hide_panel()

func show_panel(kind: String) -> void:
	if kind == "link":
		title.text = "MARS disconnected"
		body.text = "Check that MARS is switched on and Bluetooth is connected. Your trial has been saved."
		detail.text = Robot.message
	else:
		title.text = "Device has issue"
		body.text = "Call the engineers."
		detail.text = Protocol.error_text(error_flags())
	hint.text = "Hold the MARS button for %.1f s, or click Close, to finish and save." % Nav.hold_time()
	if shown: return
	shown = true
	dim.show()
	Nav.lock = request_close
	Records.log_event("Error panel shown: " + title.text)

func hide_panel() -> void:
	shown = false
	dim.hide()
	if Nav.lock == request_close: Nav.lock = Callable()

func request_close() -> void:
	hide_panel()
	close_requested.emit()
