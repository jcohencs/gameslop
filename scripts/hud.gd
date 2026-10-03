extends CanvasLayer
## All UI: stats, crosshair, messages, trade menu, shop menu, overlays.

var main: Node

var stats_label: Label
var health_bar: ProgressBar
var heat_label: Label
var weapon_label: Label
var prompt_label: Label
var feed: VBoxContainer
var crosshair: Label
var damage_flash: ColorRect

var trade_panel: PanelContainer
var trade_title: Label
var trade_body: Label
var trade_buttons: VBoxContainer

var shop_panel: PanelContainer
var shop_list: VBoxContainer
var shop_header: Label

var overlay: PanelContainer
var overlay_label: Label
var overlay_button: Button


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_trade()
	_build_shop()
	_build_overlay()
	GameState.changed.connect(refresh)
	GameState.message.connect(push_message)
	refresh()


# --- Construction ------------------------------------------------------------

func _panel_style(alpha := 0.75) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, alpha)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.border_color = Color(1, 0.8, 0.2, 0.6)
	sb.set_border_width_all(2)
	return sb


func _label(text := "", size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(0, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b


func _build_hud() -> void:
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _panel_style(0.6))
	stats_panel.position = Vector2(16, 16)
	add_child(stats_panel)
	var v := VBoxContainer.new()
	stats_panel.add_child(v)
	v.add_child(_label("CARD SHARK", 22, Color(1, 0.8, 0.2)))
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(240, 20)
	health_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.25)
	health_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(health_bar)
	stats_label = _label("", 17)
	v.add_child(stats_label)
	heat_label = _label("", 22, Color(1, 0.35, 0.3))
	v.add_child(heat_label)

	weapon_label = _label("", 22)
	weapon_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weapon_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weapon_label.offset_right = -20
	weapon_label.offset_bottom = -16
	add_child(weapon_label)

	crosshair = _label("+", 30)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(crosshair)

	prompt_label = _label("", 22, Color(1, 1, 0.6))
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.offset_bottom = -70
	add_child(prompt_label)

	feed = VBoxContainer.new()
	feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feed.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feed.offset_top = 16
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(feed)

	damage_flash = ColorRect.new()
	damage_flash.color = Color(1, 0, 0, 0)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)


func _centered_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(0.92))
	p.custom_minimum_size = min_size
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	add_child(p)
	return p


func _build_trade() -> void:
	trade_panel = _centered_panel(Vector2(560, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	trade_panel.add_child(v)
	trade_title = _label("", 26, Color(1, 0.8, 0.2))
	v.add_child(trade_title)
	trade_body = _label("", 18)
	trade_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(trade_body)
	trade_buttons = VBoxContainer.new()
	v.add_child(trade_buttons)


func _build_shop() -> void:
	shop_panel = _centered_panel(Vector2(640, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	shop_panel.add_child(v)
	v.add_child(_label("SHADY VAN - \"Totally Legit Card Exchange\"", 24, Color(1, 0.8, 0.2)))
	shop_header = _label("", 18)
	v.add_child(shop_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shop_list)


func _build_overlay() -> void:
	overlay = _centered_panel(Vector2(620, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	overlay.add_child(v)
	overlay_label = _label("", 19)
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(overlay_label)
	overlay_button = Button.new()
	overlay_button.add_theme_font_size_override("font_size", 22)
	overlay_button.custom_minimum_size = Vector2(0, 46)
	v.add_child(overlay_button)


# --- Updates -----------------------------------------------------------------

func refresh() -> void:
	refresh_stats()
	if shop_panel.visible:
		_fill_shop()


## Cheap per-frame update (no shop rebuild).
func refresh_stats() -> void:
	var gs := GameState
	health_bar.max_value = gs.max_health()
	health_bar.value = gs.health
	stats_label.text = "HP %d / %d\nCash: $%d\nBinder: %d / %d cards (worth $%d)\nJunk cards: %d   Holo stickers: %d\nScams: %d   Parents KO'd: %d" % [
		gs.health, gs.max_health(), gs.cash, gs.cards.size(), gs.capacity(), gs.collection_value(),
		gs.junk, gs.stickers, gs.scams, gs.knockouts]
	var s := gs.stars()
	heat_label.text = "HEAT [%s%s]  %d%%" % ["#".repeat(s), "-".repeat(5 - s), roundi(gs.heat)]
	if main and main.player:
		var p = main.player
		var w: Dictionary = p.weapon()
		var ammo_text := "RELOADING..." if p.reload_timer > 0.0 else "%d / %d" % [p.ammo[p.weapon_id], w["mag"]]
		var owned := []
		for id in gs.WEAPONS:
			if gs.weapons_owned[id]:
				owned.append("[%d] %s" % [gs.WEAPONS[id]["key"], gs.WEAPONS[id]["name"]])
		weapon_label.text = "%s\n%s\n%s" % [w["name"], ammo_text, "  ".join(owned)]


func set_prompt(text: String) -> void:
	prompt_label.text = text


func push_message(text: String, color := Color.WHITE) -> void:
	var l := _label(text, 20, color)
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
	return trade_panel.visible or shop_panel.visible or overlay.visible


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
		var b := _button("%s   (%d%% chance, %s)" % [t["label"], roundi(t["chance"] * 100.0), t["cost_text"]],
			main.do_trade.bind(kid, t["id"]))
		b.disabled = not t["available"]
		trade_buttons.add_child(b)
	trade_buttons.add_child(_button("Walk away", main.close_menus))
	trade_panel.visible = true


# --- Shop --------------------------------------------------------------------

func open_shop() -> void:
	shop_panel.visible = true
	_fill_shop()


func _fill_shop() -> void:
	var gs := GameState
	shop_header.text = "Cash: $%d    Binder: %d/%d cards worth $%d" % [gs.cash, gs.cards.size(), gs.capacity(), gs.collection_value()]
	for c in shop_list.get_children():
		c.queue_free()

	shop_list.add_child(_section("SELL"))
	var sell := _button("Sell all cards  (+$%d)" % gs.collection_value(), main.shop_sell)
	sell.disabled = gs.cards.is_empty()
	shop_list.add_child(sell)

	shop_list.add_child(_section("SUPPLIES"))
	shop_list.add_child(_button("Pack of %d junk cards  -  $%d   (you have %d)" % [gs.JUNK_PACK_SIZE, gs.JUNK_PACK_COST, gs.junk], main.shop_buy_junk))
	shop_list.add_child(_button("Holo sticker (makes junk look shiny)  -  $%d   (you have %d)" % [gs.STICKER_COST, gs.stickers], main.shop_buy_sticker))
	var heal_cost := ceili((gs.max_health() - gs.health) * 0.5)
	var heal := _button("Juice box & band-aids (full heal)  -  $%d" % heal_cost, main.shop_heal)
	heal.disabled = heal_cost <= 0
	shop_list.add_child(heal)

	shop_list.add_child(_section("UPGRADES"))
	for id in gs.UPGRADES:
		var u: Dictionary = gs.UPGRADES[id]
		var lvl: int = gs.upgrades[id]
		var text := "%s  [%d/%d]  %s" % [u["name"], lvl, u["max"], u["desc"]]
		if lvl < u["max"]:
			text += "  -  $%d" % gs.upgrade_cost(id)
		else:
			text += "  -  MAXED"
		var b := _button(text, main.shop_upgrade.bind(id))
		b.disabled = lvl >= u["max"]
		shop_list.add_child(b)

	shop_list.add_child(_section("HARDWARE (for dealing with parents)"))
	for id in gs.WEAPONS:
		var w: Dictionary = gs.WEAPONS[id]
		if w["cost"] == 0:
			continue
		var owned: bool = gs.weapons_owned[id]
		var b := _button("%s  -  %s" % [w["name"], "OWNED" if owned else "$%d" % w["cost"]], main.shop_weapon.bind(id))
		b.disabled = owned
		shop_list.add_child(b)

	shop_list.add_child(_section("THE DREAM"))
	var win := _button("Buy your own Card Shop Empire  -  $%d" % gs.WIN_COST, main.shop_win)
	win.disabled = gs.won
	shop_list.add_child(win)
	shop_list.add_child(_button("Close", main.close_menus))


func _section(text: String) -> Label:
	return _label(text, 16, Color(0.7, 0.8, 1.0))


# --- Overlay (title, death, win) ---------------------------------------------

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
	shop_panel.visible = false
