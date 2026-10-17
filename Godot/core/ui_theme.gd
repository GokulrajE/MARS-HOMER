extends RefCounted
# Shared look for every non-game screen. The focus style is deliberately heavy:
# it is the only cue a MARS-button user has for "what will Hold select".
const FONT = preload("res://assets/fonts/AtkinsonHyperlegibleNext.ttf")
# Titan One is reserved for the big, friendly game feedback ("Caught!", "Missed", "+1").
const DISPLAY = preload("res://assets/fonts/TitanOne-Regular.ttf")
const ALERT = Color("f97316")
const SKY = Color("38bdf8")
const BG = Color("111827")
const PANEL = Color(0.045,0.09,0.14,0.73)
const BUTTON = Color(0.12,0.19,0.25,0.65)
const BUTTON_HOVER = Color(0.18,0.30,0.37,0.8)
const ACCENT = Color("0d9488")
const FOCUS = Color("38bdf8")
const TEXT = Color("f3f4f6")
const MUTED = Color("b6c4d6")

static func box(color: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 10, pad_x: int = 18, pad_y: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style

static func build() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 22
	theme.default_font = FONT
	for kind in ["Button", "CheckButton", "OptionButton"]:
		var normal = box(BUTTON, Color("405169"), 1)
		normal.shadow_color = Color(0, 0, 0, 0.35)
		normal.shadow_size = 6
		normal.shadow_offset = Vector2(0, 3)
		var hover = box(BUTTON_HOVER, ACCENT, 2)
		hover.shadow_color = Color(ACCENT, 0.25)
		hover.shadow_size = 4
		theme.set_stylebox("normal", kind, normal)
		theme.set_stylebox("hover", kind, hover)
		theme.set_stylebox("pressed", kind, box(ACCENT.darkened(0.45), ACCENT, 2))
		theme.set_stylebox("hover_pressed", kind, box(ACCENT.darkened(0.35), ACCENT, 2))
		theme.set_stylebox("disabled", kind, box(BUTTON.darkened(0.4), Color.TRANSPARENT, 0))
		# Focus replaces the normal look so that it cannot be mistaken for hover.
		theme.set_stylebox("focus", kind, box(Color.TRANSPARENT, FOCUS, 3))
		theme.set_color("font_color", kind, TEXT)
		theme.set_color("font_hover_color", kind, Color.WHITE)
		theme.set_color("font_focus_color", kind, Color.WHITE)
		theme.set_color("font_pressed_color", kind, Color.WHITE)
		theme.set_color("font_disabled_color", kind, MUTED.darkened(0.4))
	theme.set_stylebox("normal", "LineEdit", box(Color("111827"), Color("405169"), 1, 8))
	theme.set_stylebox("focus", "LineEdit", box(Color("111827"), FOCUS, 3, 8))
	theme.set_stylebox("read_only", "LineEdit", box(Color("111827").darkened(0.3), Color.TRANSPARENT, 0, 8))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color("405169"), 1, 14, 20, 16))
	theme.set_stylebox("panel", "TabContainer", box(PANEL, Color("405169"), 1, 12, 16, 14))
	theme.set_stylebox("tab_selected", "TabContainer", box(PANEL, ACCENT, 2, 10, 18, 9))
	theme.set_stylebox("tab_unselected", "TabContainer", box(BUTTON.darkened(0.3), Color.TRANSPARENT, 0, 10, 18, 9))
	theme.set_stylebox("tab_hovered", "TabContainer", box(BUTTON_HOVER, Color.TRANSPARENT, 0, 10, 18, 9))
	theme.set_stylebox("tab_focus", "TabContainer", box(PANEL, FOCUS, 3, 10, 18, 9))
	theme.set_color("font_selected_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	theme.set_font_size("font_size", "TabContainer", 22)
	theme.set_stylebox("background", "ProgressBar", box(Color("111827"), Color.TRANSPARENT, 0, 8, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", box(ACCENT, Color.TRANSPARENT, 0, 8, 0, 0))
	return theme

static func label(text: String, size: int = 22, color: Color = TEXT, wrap: bool = false) -> Label:
	var node = Label.new()
	if size >= 30:
		var heading = FontVariation.new()
		heading.base_font = FONT
		heading.variation_opentype = {"wght": 650.0}
		node.add_theme_font_override("font", heading)
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func card(color: Color = PANEL, border: Color = Color("405169")) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(color, border, 1, 14, 20, 16))
	return panel

