class_name UITheme
extends RefCounted
## Shared military-style theme and small UI factory helpers used by every menu and the HUD.

const BG := Color(0.04, 0.06, 0.08)
const PANEL := Color(0.06, 0.09, 0.12, 0.86)
const PANEL_LIGHT := Color(0.12, 0.16, 0.2, 0.92)
const ACCENT := Color(0.98, 0.77, 0.13)
const ACCENT_DARK := Color(0.6, 0.45, 0.05)
const TEXT := Color(0.94, 0.95, 0.96)
const MUTED := Color(0.6, 0.67, 0.74)
const BORDER := Color(0.25, 0.32, 0.38)
const FRIENDLY := Color(0.38, 0.68, 1.0)
const ENEMY := Color(1.0, 0.3, 0.25)
const GOOD := Color(0.45, 0.85, 0.4)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.42))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, BORDER, 1, 2, true))
	t.set_stylebox("hover", "Button", _box(Color(0.18, 0.23, 0.28, 0.98), ACCENT, 2, 2, true))
	t.set_stylebox("pressed", "Button", _box(ACCENT, ACCENT, 2, 2, true))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.1, 0.8), Color(0.2, 0.2, 0.2), 1))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 1))
	t.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 1))
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(4)
	t.set_stylebox("slider", "HSlider", _box(Color(0.15, 0.19, 0.23), Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT_DARK, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("normal", "OptionButton", _box(PANEL_LIGHT, BORDER, 2))
	t.set_stylebox("hover", "OptionButton", _box(Color(0.18, 0.23, 0.28), ACCENT, 2))
	t.set_stylebox("pressed", "OptionButton", _box(PANEL_LIGHT, ACCENT, 2))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.03, 0.05, 0.07), BORDER, 2))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, BORDER, 1))
	t.set_stylebox("tab_selected", "TabContainer", _box(ACCENT, ACCENT, 0))
	t.set_stylebox("tab_unselected", "TabContainer", _box(PANEL_LIGHT, Color(0, 0, 0, 0), 0))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.18, 0.23, 0.28), Color(0, 0, 0, 0), 0))
	t.set_color("font_selected_color", "TabContainer", BG)
	t.set_color("font_unselected_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", 20)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


## slant: CODM-style parallelogram buttons (small horizontal skew).
static func _box(bg: Color, border: Color, bw: int = 1, radius: int = 4, slant := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if slant:
		s.skew = Vector2(0.18, 0)
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func label(text: String, size: int = 20, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func button(text: String, cb: Callable, min_size := Vector2(220, 64), sound := "click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		AudioManager.ui(sound)
		cb.call())
	return b


## Gold call-to-action button (lobby START etc.).
static func cta(text: String, cb: Callable, min_size := Vector2(300, 84)) -> Button:
	var b := button(text, cb, min_size, "confirm")
	b.add_theme_stylebox_override("normal", _box(ACCENT, Color(1, 0.9, 0.5), 2, 2, true))
	b.add_theme_stylebox_override("hover", _box(Color(1, 0.85, 0.3), Color(1, 1, 1), 2, 2, true))
	b.add_theme_stylebox_override("pressed", _box(ACCENT_DARK, ACCENT, 2, 2, true))
	b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.03))
	b.add_theme_font_size_override("font_size", 34)
	return b


## Panel with a coloured top/left accent stripe (CODM cards).
static func card(min_size := Vector2.ZERO, stripe: Color = ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var sb := _box(PANEL, stripe, 0, 3)
	sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## Safe area (notches/cutouts) converted to viewport coordinates.
static func safe_rect(vp: Viewport) -> Rect2:
	var vs := vp.get_visible_rect().size
	var full := Rect2(Vector2.ZERO, vs)
	if DisplayServer.get_name() == "headless":
		return full
	var sa := DisplayServer.get_display_safe_area()
	var ws := Vector2(DisplayServer.window_get_size())
	if sa.size.x <= 0 or ws.x <= 0:
		return full
	var k := vs / ws
	var r := Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k)
	return r.intersection(full) if r.intersects(full) else full
