class_name UI
## Shared UI theme + small widget helpers used by the HUD, hideout and menus.

const ACCENT := Color(1.0, 0.78, 0.2)
const ACCENT_DIM := Color(0.75, 0.55, 0.1)
const BG := Color(0.07, 0.06, 0.1)
const PANEL := Color(0.11, 0.1, 0.16, 0.92)
const PANEL_LIGHT := Color(0.15, 0.135, 0.21, 1.0)
const TEXT := Color(0.95, 0.94, 0.98)
const TEXT_DIM := Color(0.68, 0.66, 0.76)
const GOOD := Color(0.4, 1.0, 0.55)
const BAD := Color(1.0, 0.38, 0.35)
const INFO := Color(0.55, 0.78, 1.0)

static var _theme: Theme
static var _bold: FontVariation


static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
		_bold.spacing_glyph = 1
	return _bold


static func box(color: Color, radius := 10, border := 0, border_color := Color.TRANSPARENT, margin := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 4)

	var normal := box(Color(0.2, 0.18, 0.28), 8, 2, Color(1, 1, 1, 0.06), 10)
	var hover := box(Color(0.3, 0.26, 0.42), 8, 2, ACCENT, 10)
	var pressed := box(ACCENT_DIM, 8, 2, ACCENT, 10)
	var disabled := box(Color(0.14, 0.13, 0.18, 0.8), 8, 2, Color(1, 1, 1, 0.03), 10)
	var focus := box(Color(0, 0, 0, 0), 8, 2, Color(ACCENT, 0.6), 10)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color(0.1, 0.08, 0.05))
		t.set_color("font_disabled_color", type, Color(0.5, 0.48, 0.56))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 12, 2, Color(1, 1, 1, 0.07), 14))
	t.set_stylebox("panel", "Panel", box(PANEL, 12))

	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), 6, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 6, 0, Color.TRANSPARENT, 0))

	var tab_sel := box(PANEL_LIGHT, 10, 0, Color.TRANSPARENT, 12)
	tab_sel.border_width_bottom = 3
	tab_sel.border_color = ACCENT
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.12, 0.11, 0.17, 0.9), 10, 0, Color.TRANSPARENT, 12))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.22, 0.2, 0.3, 0.95), 10, 0, Color.TRANSPARENT, 12))
	t.set_stylebox("panel", "TabContainer", box(PANEL_LIGHT, 12, 0, Color.TRANSPARENT, 16))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", 20)
	t.set_font("font", "TabContainer", bold_font())

	var slider_bg := box(Color(0, 0, 0, 0.5), 4, 0, Color.TRANSPARENT, 0)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT_DIM, 4, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 4, 0, Color.TRANSPARENT, 0))

	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.05, 0.08, 0.95), 6, 1, ACCENT, 8))
	_theme = t
	return t


static func label(text := "", size := 18, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Button with hover lift + click sound.
static func button(text: String, cb: Callable, size := 18, min_h := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click", 0.05))
	b.pressed.connect(cb)
	b.mouse_entered.connect(_hover_in.bind(b))
	b.mouse_exited.connect(_hover_out.bind(b))
	return b


static func _hover_in(b: Button) -> void:
	if b.disabled or not b.is_inside_tree():
		return
	Sfx.play("hover", 0.1, -10.0)
	b.pivot_offset = b.size * 0.5
	b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.08)


static func _hover_out(b: Button) -> void:
	if b.is_inside_tree():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1)


static func bar(color: Color, min_size := Vector2(220, 14)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = min_size
	p.show_percentage = false
	p.add_theme_stylebox_override("fill", box(color, 6, 0, Color.TRANSPARENT, 0))
	return p


static func panel(alpha := 0.92, border := Color(1, 1, 1, 0.07)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(PANEL, alpha), 12, 2, border, 14))
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Key-cap style label, e.g. [E].
static func keycap(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.95, 0.94, 0.98), 5, 0, Color.TRANSPARENT, 4))
	var l := label(key, 16, Color(0.08, 0.08, 0.1), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


## Small "pips" row, e.g. upgrade levels or difficulty.
static func pips(filled: int, total: int, color := ACCENT) -> HBoxContainer:
	var h := hbox(4)
	for i in total:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(14, 8)
		r.color = color if i < filled else Color(1, 1, 1, 0.12)
		h.add_child(r)
	return h


static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts
