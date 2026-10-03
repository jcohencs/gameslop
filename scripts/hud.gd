extends CanvasLayer
## In-raid UI: stats, timer, extracts, crosshair, messages, trade menu, overlays.

var main: Node

var stats_label: Label
var health_bar: ProgressBar
var heat_label: Label
var timer_label: Label
var extract_label: Label
var extract_bar: ProgressBar
var fist_label: Label
var prompt_label: Label
var feed: VBoxContainer
var crosshair: Label
var damage_flash: ColorRect

var trade_panel: PanelContainer
var trade_title: Label
var trade_body: Label
var trade_buttons: VBoxContainer

var overlay: PanelContainer
var overlay_label: Label
var overlay_button: Button


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_trade()
	_build_overlay()
	GameState.changed.connect(refresh_stats)
	GameState.message.connect(push_message)
	refresh_stats()


# --- Construction helpers (also used by the hub) ----------------------------

static func panel_style(alpha := 0.75) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, alpha)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.border_color = Color(1, 0.8, 0.2, 0.6)
	sb.set_border_width_all(2)
	return sb


static func make_label(text := "", size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


static func make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(0, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b


static func make_bar(color: Color, width := 240.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_hud() -> void:
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", panel_style(0.6))
	stats_panel.position = Vector2(16, 16)
	add_child(stats_panel)
	var v := VBoxContainer.new()
	stats_panel.add_child(v)
	timer_label = make_label("", 22, Color(1, 0.8, 0.2))
	v.add_child(timer_label)
	health_bar = make_bar(Color(0.85, 0.2, 0.25))
	v.add_child(health_bar)
	stats_label = make_label("", 17)
	v.add_child(stats_label)
	heat_label = make_label("", 20, Color(1, 0.35, 0.3))
	v.add_child(heat_label)

	var ex_panel := PanelContainer.new()
	ex_panel.add_theme_stylebox_override("panel", panel_style(0.6))
	ex_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ex_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ex_panel.offset_right = -16
	ex_panel.offset_top = 16
	add_child(ex_panel)
	var ev := VBoxContainer.new()
	ex_panel.add_child(ev)
	ev.add_child(make_label("EXTRACTS", 18, Color(0.4, 1, 0.5)))
	extract_label = make_label("", 17)
	ev.add_child(extract_label)

	fist_label = make_label("", 22)
	fist_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fist_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fist_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fist_label.offset_right = -20
	fist_label.offset_bottom = -16
	add_child(fist_label)

	crosshair = make_label("+", 26)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(crosshair)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -70
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	extract_bar = make_bar(Color(0.3, 1, 0.45), 360)
	extract_bar.visible = false
	extract_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(extract_bar)
	prompt_label = make_label("", 22, Color(1, 1, 0.6))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(prompt_label)

	feed = VBoxContainer.new()
	feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feed.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feed.offset_top = 16
	add_child(feed)

	damage_flash = ColorRect.new()
	damage_flash.color = Color(1, 0, 0, 0)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)


func _centered_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(0.92))
	p.custom_minimum_size = min_size
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	return p


func _build_trade() -> void:
	trade_panel = _centered_panel(Vector2(580, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	trade_panel.add_child(v)
	trade_title = make_label("", 26, Color(1, 0.8, 0.2))
	v.add_child(trade_title)
	trade_body = make_label("", 18)
	trade_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(trade_body)
	trade_buttons = VBoxContainer.new()
	v.add_child(trade_buttons)


func _build_overlay() -> void:
	overlay = _centered_panel(Vector2(620, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	overlay.add_child(v)
	overlay_label = make_label("", 19)
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.add_theme_font_size_override("font_size", 22)
	overlay_button.custom_minimum_size = Vector2(0, 46)
	v.add_child(overlay_button)


# --- Updates -----------------------------------------------------------------

func refresh_stats() -> void:
	var gs := GameState
	health_bar.max_value = gs.max_health()
	health_bar.value = gs.health
	var t := maxf(gs.raid_time_left, 0.0)
	timer_label.text = "TIME LEFT  %d:%02d" % [int(t) / 60, int(t) % 60]
	timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if t < 60.0 else Color(1, 0.8, 0.2))
	stats_label.text = "HP %d / %d\nBinder (AT RISK): %d / %d  ($%d)\nJunk cards: %d   Holo stickers: %d" % [
		gs.health, gs.max_health(), gs.binder.size(), gs.capacity(), gs.cards_value(gs.binder),
		gs.junk, gs.stickers]
	var s := gs.stars()
	heat_label.text = "HEAT [%s%s]" % ["#".repeat(s), "-".repeat(5 - s)]
	var owned := []
	for id in gs.FISTS:
		if gs.fists_owned[id]:
			owned.append("[%d] %s" % [gs.FISTS[id]["key"], gs.FISTS[id]["name"]])
	fist_label.text = "%s\nLMB punch  |  RMB block\n%s" % [gs.fist()["name"], "  ".join(owned)]


func set_extracts(lines: String) -> void:
	extract_label.text = lines


func set_extract_progress(frac: float) -> void:
	extract_bar.visible = frac > 0.0
	extract_bar.value = frac * 100.0


func set_prompt(text: String) -> void:
	prompt_label.text = text


func push_message(text: String, color := Color.WHITE) -> void:
	var l := make_label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feed.add_child(l)
	while feed.get_child_count() > 5:
		feed.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func flash_damage() -> void:
	damage_flash.color = Color(1, 0, 0, 0.35)
	var tw := damage_flash.create_tween()
	tw.tween_property(damage_flash, "color:a", 0.0, 0.35)


func any_menu_open() -> bool:
	return trade_panel.visible or overlay.visible


# --- Trade menu --------------------------------------------------------------

func open_trade(kid: Node, tactics: Array) -> void:
	var c: Dictionary = kid.card
	trade_title.text = "Trade with %s" % kid.kid_name
	trade_body.text = "%s is holding a [%s] %s.\nStreet value: $%d (you'd sell it for $%d)\n\nHow do you want to \"negotiate\"?" % [
		kid.kid_name, GameState.rarity_name(c), c["name"], c["value"], GameState.card_sell_value(c)]
	trade_title.add_theme_color_override("font_color", GameState.rarity_color(c))
	for b in trade_buttons.get_children():
		b.queue_free()
	for t in tactics:
		var b := make_button("%s   (%d%% chance, %s)" % [t["label"], roundi(t["chance"] * 100.0), t["cost_text"]],
			main.do_trade.bind(kid, t["id"]))
		b.disabled = not t["available"]
		trade_buttons.add_child(b)
	trade_buttons.add_child(make_button("Walk away", main.close_menus))
	trade_panel.visible = true


# --- Overlay (pause, raid over) ----------------------------------------------

func show_overlay(text: String, button_text: String, cb: Callable) -> void:
	overlay_label.text = text
	overlay_button.text = button_text
	for c in overlay_button.pressed.get_connections():
		overlay_button.pressed.disconnect(c["callable"])
	overlay_button.pressed.connect(cb)
	overlay.visible = true


func hide_overlay() -> void:
	overlay.visible = false


func close_all() -> void:
	trade_panel.visible = false
