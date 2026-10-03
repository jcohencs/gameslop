extends CanvasLayer
## Title screen + the Shady Van hideout (tabs: Deploy, Stash, Shop, Upgrades).

const CardView := preload("res://scripts/ui/card_view.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var main: Node
var root: Control
var bg_cards: Array = []
var title_view: Control
var hub_view: Control
var settings: PanelContainer
var cash_label: Label
var stats_label: Label
var report_panel: PanelContainer
var report: Label
var tabs: TabContainer
var deploy_tab: VBoxContainer
var stash_tab: VBoxContainer
var shop_tab: VBoxContainer
var upgrades_tab: VBoxContainer
var orders_tab: VBoxContainer
var continue_button: Button
var _dirty := true


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_background()
	_build_title()
	_build_hub()
	settings = SettingsPanel.new()
	settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings.visible = false
	settings.closed.connect(func(): settings.visible = false)
	root.add_child(settings)
	GameState.changed.connect(func(): _dirty = true)
	show_title()


# --- Background --------------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float stripes = step(0.5, fract((uv.x + uv.y) * 14.0 - TIME * 0.15));
	vec3 a = vec3(0.07, 0.055, 0.11);
	vec3 b = vec3(0.09, 0.07, 0.14);
	vec3 col = mix(a, b, stripes);
	col += vec3(0.25, 0.15, 0.02) * smoothstep(0.9, 0.0, distance(uv, vec2(0.5, 1.1))) * 0.6;
	COLOR = vec4(col, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	root.add_child(bg)
	for i in 9:
		var cv := CardView.new(GameState.roll_card(1.5), Vector2(120, 168))
		cv.show_price = false
		cv.modulate.a = 0.22
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cv)
		cv.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		cv.rotation = randf_range(-0.5, 0.5)
		bg_cards.append({"node": cv, "vel": Vector2(randf_range(-15, 15), randf_range(-25, -8)), "spin": randf_range(-0.15, 0.15)})


func _process(delta: float) -> void:
	if not visible:
		return
	var vp := root.get_viewport_rect().size
	for c in bg_cards:
		var n: Control = c["node"]
		n.position += c["vel"] * delta
		n.rotation += c["spin"] * delta
		if n.position.y < -200:
			n.position = Vector2(randf_range(0, vp.x), vp.y + 20)
		if n.position.x < -150:
			n.position.x = vp.x
		elif n.position.x > vp.x + 50:
			n.position.x = -120
	if _dirty and hub_view.visible:
		_dirty = false
		_refresh()


# --- Title -------------------------------------------------------------------

func _build_title() -> void:
	title_view = UI.vbox(14)
	title_view.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_view.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_view.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_view.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(title_view)
	var t := UI.label("CARD SHARK", 92, UI.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 14)
	title_view.add_child(t)
	var sub := UI.label("E X T R A C T I O N   H U S T L E", 24, UI.TEXT, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_view.add_child(sub)
	var tag := UI.label("Scam kids. Punch parents. Get out with the cards.", 17, UI.TEXT_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_view.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	title_view.add_child(spacer)
	var buttons := UI.vbox(10)
	buttons.custom_minimum_size = Vector2(340, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_view.add_child(buttons)
	continue_button = UI.button("Continue", _continue, 22, 52)
	buttons.add_child(continue_button)
	buttons.add_child(UI.button("New Game", _new_game, 22, 52))
	buttons.add_child(UI.button("Settings", func(): settings.visible = true, 22, 52))
	buttons.add_child(UI.button("Quit", func(): get_tree().quit(), 22, 52))


func show_title() -> void:
	visible = true
	title_view.visible = true
	hub_view.visible = false
	continue_button.visible = GameState.has_save()


func _continue() -> void:
	GameState.load_game()
	show_hub()
	set_report("Welcome back. The van smells like cards and regret.", UI.ACCENT)


func _new_game() -> void:
	GameState.reset()
	GameState.save_game()
	show_hub()
	set_report("Welcome to the hustle. Pick a spot, scam some kids, punch out the parents, and EXTRACT before time runs out. " +
		"Earn $%d to buy your own Card Shop Empire." % GameState.WIN_COST, UI.ACCENT)
	tabs.current_tab = 0


func show_hub() -> void:
	visible = true
	title_view.visible = false
	hub_view.visible = true
	_dirty = true
	_refresh()


# --- Hub layout --------------------------------------------------------------

func _build_hub() -> void:
	hub_view = MarginContainer.new()
	hub_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		hub_view.add_theme_constant_override("margin_" + side, 22)
	root.add_child(hub_view)
	var v := UI.vbox(10)
	hub_view.add_child(v)

	var top := UI.hbox(16)
	v.add_child(top)
	var title := UI.label("THE SHADY VAN", 32, UI.ACCENT, true)
	top.add_child(title)
	stats_label = UI.label("", 15, UI.TEXT_DIM)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(stats_label)
	cash_label = UI.label("", 32, UI.GOOD, true)
	top.add_child(cash_label)
	top.add_child(UI.button("Settings", func(): settings.visible = true, 16, 40))
	top.add_child(UI.button("Title", show_title, 16, 40))

	report_panel = UI.panel(0.85, UI.ACCENT)
	v.add_child(report_panel)
	report = UI.wrap(UI.label("", 17, UI.TEXT))
	report_panel.add_child(report)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_i): Sfx.play("click"))
	v.add_child(tabs)
	deploy_tab = _tab("DEPLOY")
	stash_tab = _tab("STASH")
	shop_tab = _tab("SHOP")
	upgrades_tab = _tab("UPGRADES")
	orders_tab = _tab("ORDERS")


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var v := UI.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	return v


func set_report(text: String, color := UI.GOOD) -> void:
	report.text = text
	report.add_theme_color_override("font_color", color)
	report_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.85), 12, 2, color, 14))
	report_panel.modulate.a = 0.0
	report_panel.create_tween().tween_property(report_panel, "modulate:a", 1.0, 0.25)


func _refresh() -> void:
	var gs := GameState
	cash_label.text = "$%d" % gs.cash
	stats_label.text = "Stash: %d cards ($%d)   ·   Raids %d   ·   Extracts %d   ·   Scams %d   ·   KOs %d" % [
		gs.stash.size(), gs.cards_value(gs.stash), gs.raids, gs.extracts, gs.scams, gs.knockouts]
	tabs.set_tab_title(1, "STASH (%d)" % gs.stash.size())
	tabs.set_tab_title(4, "ORDERS (%d ready)" % gs.orders_ready())
	_fill_deploy()
	_fill_stash()
	_fill_shop()
	_fill_upgrades()
	_fill_orders()


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


func _tile(min_w := 0.0) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.14, 0.13, 0.2, 0.95), 12, 2, Color(1, 1, 1, 0.06), 14))
	p.custom_minimum_size = Vector2(min_w, 0)
	var v := UI.vbox(6)
	p.add_child(v)
	return [p, v]


# --- Deploy ------------------------------------------------------------------

func _fill_deploy() -> void:
	var gs := GameState
	_clear(deploy_tab)
	var row := UI.hbox(14)
	deploy_tab.add_child(row)
	for id in gs.LOCATIONS:
		var loc: Dictionary = gs.LOCATIONS[id]
		var tv := _tile(270)
		var tile: PanelContainer = tv[0]
		var v: VBoxContainer = tv[1]
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		v.add_child(UI.wrap(UI.label(loc["name"], 21, UI.ACCENT, true)))
		var diff := UI.hbox(8)
		diff.add_child(UI.label("Danger", 14, UI.TEXT_DIM))
		diff.add_child(UI.pips(loc["difficulty"], 3, UI.BAD))
		diff.add_child(UI.label("   Loot", 14, UI.TEXT_DIM))
		diff.add_child(UI.pips(1 + int(loc["rarity_bonus"]), 4, UI.ACCENT))
		v.add_child(diff)
		v.add_child(UI.wrap(UI.label(loc["desc"], 15, UI.TEXT)))
		var guard: String = load("res://scripts/parent.gd").TYPES[loc["guard"]]["name"]
		v.add_child(UI.wrap(UI.label("Timer %d:%02d  ·  %d kids  ·  Guard: %s" % [int(loc["time"]) / 60, int(loc["time"]) % 60, loc["kids"], guard], 14, UI.TEXT_DIM)))
		var fee := "FREE ENTRY" if loc["fee"] == 0 else "ENTRY $%d" % loc["fee"]
		var go := UI.button("DEPLOY  -  %s" % fee, main.start_raid.bind(id), 19, 50)
		go.disabled = gs.cash < loc["fee"]
		v.add_child(go)

	# Wave Mode (specs/004).
	var wt := _tile()
	var wtile: PanelContainer = wt[0]
	wtile.add_theme_stylebox_override("panel", UI.box(Color(0.2, 0.1, 0.16, 0.95), 12, 2, UI.BAD, 14))
	deploy_tab.add_child(wtile)
	var wrow := UI.hbox(18)
	wt[1].add_child(wrow)
	var winfo := UI.vbox(4)
	winfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(winfo)
	winfo.add_child(UI.label("REC CENTER SHOWDOWN  ·  WAVE MODE", 22, UI.BAD, true))
	winfo.add_child(UI.wrap(UI.label("Hold the Sunnyvale Rec Center gym against endless waves of parents with toy blasters. " +
		"Every 5th wave: Principal Grimsby. Cash is banked as you earn it; nothing is lost when you go down.", 15, UI.TEXT)))
	var owned := []
	for id in gs.BLASTER_ORDER:
		if gs.blasters_owned[id]:
			owned.append(gs.BLASTERS[id]["name"])
	winfo.add_child(UI.label("Best wave: %s   ·   Blasters: %s" % [str(gs.best_wave) if gs.best_wave > 0 else "-", ", ".join(owned)], 14, UI.TEXT_DIM))
	var wgo := UI.button("DEPLOY  -  FREE", main.start_waves, 20, 56)
	wgo.custom_minimum_size = Vector2(220, 56)
	wgo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(wgo)

	var lo := _tile()
	deploy_tab.add_child(lo[0])
	var lv: VBoxContainer = lo[1]
	lv.add_child(UI.label("LOADOUT", 18, UI.INFO, true))
	lv.add_child(UI.label("Weapon: %s     Binder slots: %d     Max HP: %d     Max stamina: %d" % [
		gs.weapon()["name"], gs.capacity(), gs.max_health(), gs.max_stamina()], 15, UI.TEXT))
	var sup := UI.label("Junk cards: %d     Holo stickers: %d     Pocket sand: %d     (lost if you don't extract)" % [gs.junk, gs.stickers, gs.sand], 15,
		UI.BAD if gs.junk == 0 else UI.TEXT)
	lv.add_child(sup)
	if gs.junk == 0:
		lv.add_child(UI.label("You have no junk cards! Buy some in the SHOP tab, or you'll only have the UFO trick.", 15, UI.BAD))
	lv.add_child(UI.wrap(UI.label("Raid rules: scam kids, then stand in a green EXTRACT zone to escape. Two of three extracts are open each raid. " +
		"Get knocked out or run out of time and you lose your binder and supplies. Cash, stash and upgrades are always safe.", 14, UI.TEXT_DIM)))


# --- Stash -------------------------------------------------------------------

func _fill_stash() -> void:
	var gs := GameState
	_clear(stash_tab)
	var head := UI.hbox(12)
	stash_tab.add_child(head)
	var l := UI.label("%d cards  ·  worth $%d" % [gs.stash.size(), gs.cards_value(gs.stash)], 20, UI.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var sell := UI.button("SELL EVERYTHING  (+$%d)" % gs.cards_value(gs.stash), main.hub_sell, 18, 46)
	sell.disabled = gs.stash.is_empty()
	head.add_child(sell)
	if gs.stash.is_empty():
		stash_tab.add_child(UI.label("Your stash is empty. Extract with cards to fill it.", 16, UI.TEXT_DIM))
		return
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	stash_tab.add_child(grid)
	for i in gs.stash.size():
		var cell := UI.vbox(4)
		var cv := CardView.new(gs.stash[i], Vector2(140, 196))
		cell.add_child(cv)
		cell.add_child(UI.button("Sell $%d" % gs.card_sell_value(gs.stash[i]), main.hub_sell_card.bind(i), 15, 32))
		grid.add_child(cell)


# --- Shop --------------------------------------------------------------------

func _fill_shop() -> void:
	var gs := GameState
	_clear(shop_tab)
	shop_tab.add_child(UI.label("SUPPLIES  (you carry these into raids)", 17, UI.INFO, true))
	var sup := UI.hbox(12)
	shop_tab.add_child(sup)
	for item in [["Pack of %d junk cards" % gs.JUNK_PACK_SIZE, "Bait for the classic \"super rare\" trade.", gs.JUNK_PACK_COST, gs.junk, main.hub_buy_junk],
			["Holo sticker", "Makes junk look shiny. Best scam odds, almost no heat.", gs.STICKER_COST, gs.stickers, main.hub_buy_sticker],
			["%d pocket sand packets" % gs.SAND_PACK, "Ammo for Pocket Sand. One throw per packet.", gs.SAND_COST, gs.sand, main.hub_buy_sand]]:
		var tv := _tile(280)
		sup.add_child(tv[0])
		var v: VBoxContainer = tv[1]
		v.add_child(UI.label(item[0], 18, UI.TEXT, true))
		v.add_child(UI.wrap(UI.label(item[1], 14, UI.TEXT_DIM)))
		v.add_child(UI.label("You have: %d" % item[3], 14, UI.TEXT))
		var b := UI.button("BUY  $%d" % item[2], item[4], 17, 40)
		b.disabled = gs.cash < item[2]
		v.add_child(b)

	shop_tab.add_child(UI.label("WEAPONS", 17, UI.INFO, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	shop_tab.add_child(grid)
	for id in gs.WEAPON_ORDER:
		var w: Dictionary = gs.WEAPONS[id]
		var tv := _tile(330)
		grid.add_child(tv[0])
		var v: VBoxContainer = tv[1]
		var head := UI.hbox(8)
		var n := UI.label(w["name"], 18, UI.TEXT, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(n)
		head.add_child(UI.label(w["kind"].to_upper(), 13, UI.ACCENT if w["kind"] == "sword" else UI.INFO, true))
		v.add_child(head)
		if w["kind"] == "sand":
			v.add_child(UI.wrap(UI.label("POCKET SAND! Throw a cone of sand (LMB, or Q with any weapon) that blinds every parent " +
				"in front of you for %.1fs. They stumble around and lose track of you. Uses sand packets (Supplies)." % w["blind"], 14, UI.TEXT_DIM)))
		else:
			_stat(v, "Damage", w["damage"] / 50.0)
			_stat(v, "Speed", 1.0 - (w["rate"] - 0.25) / 0.35)
			_stat(v, "Reach", (w["range"] - 1.8) / 1.6)
			_stat(v, "Knockback", w["knock"] / 15.0)
		var b: Button
		if gs.weapons_owned[id]:
			var eq: bool = gs.weapon_id == id
			b = UI.button("EQUIPPED" if eq else "EQUIP", main.hub_equip.bind(id), 16, 38)
			b.disabled = eq
		else:
			b = UI.button("BUY  $%d" % w["cost"], main.hub_buy_weapon.bind(id), 16, 38)
			b.disabled = gs.cash < w["cost"]
		v.add_child(b)
	_fill_blasters()


func _fill_blasters() -> void:
	var gs := GameState
	shop_tab.add_child(UI.label("BLASTERS  (Wave Mode only)", 17, UI.BAD, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	shop_tab.add_child(grid)
	for id in gs.BLASTER_ORDER:
		var b: Dictionary = gs.BLASTERS[id]
		var tv := _tile(330)
		grid.add_child(tv[0])
		var v: VBoxContainer = tv[1]
		var head := UI.hbox(8)
		var n := UI.label(b["name"], 18, UI.TEXT, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(n)
		head.add_child(UI.label("BLASTER", 13, UI.BAD, true))
		v.add_child(head)
		v.add_child(UI.wrap(UI.label(b["role"], 14, UI.TEXT_DIM)))
		var dps: float = b["damage"] * b["pellets"] / b["rate"]
		_stat(v, "Damage", dps / 150.0)
		_stat(v, "Range", b["range"] / 60.0)
		_stat(v, "Magazine", b["mag"] / 30.0)
		var b2: Button
		if gs.blasters_owned[id]:
			b2 = UI.button("OWNED  (slot %d)" % (gs.BLASTER_ORDER.find(id) + 1), func(): pass, 16, 38)
			b2.disabled = true
		else:
			b2 = UI.button("BUY  $%d" % b["cost"], main.hub_buy_blaster.bind(id), 16, 38)
			b2.disabled = gs.cash < b["cost"]
		v.add_child(b2)


func _stat(parent: Control, stat_name: String, frac: float) -> void:
	var row := UI.hbox(8)
	var l := UI.label(stat_name, 13, UI.TEXT_DIM)
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	var bar := UI.bar(UI.ACCENT, Vector2(200, 8))
	bar.value = clampf(frac, 0.05, 1.0) * 100.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	parent.add_child(row)


# --- Upgrades ----------------------------------------------------------------

func _fill_orders() -> void:
	var gs := GameState
	_clear(orders_tab)
	orders_tab.add_child(UI.label("COLLECTOR ORDERS", 18, UI.INFO, true))
	orders_tab.add_child(UI.wrap(UI.label("Collectors pay way over sell price for specific cards. Fill orders from your stash; " +
		"the cheapest qualifying cards are used.", 15, UI.TEXT_DIM)))
	var row := UI.hbox(14)
	orders_tab.add_child(row)
	for i in gs.orders.size():
		var o: Dictionary = gs.orders[i]
		var tv := _tile(330)
		var tile: PanelContainer = tv[0]
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
		var v: VBoxContainer = tv[1]
		var col: Color = gs.RARITIES[o["rarity"]]["color"] if o["kind"] == "rarity" else UI.ACCENT
		v.add_child(UI.wrap(UI.label(o["title"], 20, col, true)))
		v.add_child(UI.label("Reward: $%d" % o["reward"], 18, UI.GOOD, true))
		var have := gs.order_have(o)
		v.add_child(UI.label("In your stash: %d / %d" % [have, o["count"]], 15, UI.TEXT if have >= o["count"] else UI.TEXT_DIM))
		var b: Button
		if o.get("filled", false):
			b = UI.button("FILLED", func(): pass, 17, 44)
			b.disabled = true
		elif have >= o["count"]:
			b = UI.button("FULFILL  +$%d" % gs.order_payout(o), main.hub_fulfill_order.bind(i), 17, 44)
		else:
			b = UI.button("NEED %d MORE" % (o["count"] - have), func(): pass, 17, 44)
			b.disabled = true
		v.add_child(b)
	orders_tab.add_child(UI.label("New orders after every raid.", 14, UI.TEXT_DIM))


func _fill_upgrades() -> void:
	var gs := GameState
	_clear(upgrades_tab)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	upgrades_tab.add_child(grid)
	for id in gs.UPGRADES:
		var u: Dictionary = gs.UPGRADES[id]
		var lvl: int = gs.upgrades[id]
		var tv := _tile(250)
		grid.add_child(tv[0])
		var v: VBoxContainer = tv[1]
		v.add_child(UI.label(u["name"], 18, UI.TEXT, true))
		v.add_child(UI.label(u["desc"], 14, UI.TEXT_DIM))
		v.add_child(UI.pips(lvl, u["max"]))
		var maxed: bool = lvl >= u["max"]
		var b := UI.button("MAXED" if maxed else "UPGRADE  $%d" % gs.upgrade_cost(id), main.hub_upgrade.bind(id), 16, 38)
		b.disabled = maxed or gs.cash < gs.upgrade_cost(id)
		v.add_child(b)

	var tv := _tile()
	upgrades_tab.add_child(tv[0])
	var dv: VBoxContainer = tv[1]
	dv.add_child(UI.label("THE DREAM: Card Shark's Collectibles Emporium", 20, UI.ACCENT, true))
	dv.add_child(UI.label("Your own card shop, right across from Dragon's Den. You win.", 15, UI.TEXT_DIM))
	var win := UI.button("OWNED" if gs.won else "BUY THE EMPIRE  $%d" % gs.WIN_COST, main.hub_win, 18, 46)
	win.disabled = gs.won
	dv.add_child(win)
