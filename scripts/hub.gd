extends CanvasLayer
## The Shady Van hideout: sell your stash, gear up, and pick a place to hustle.

const Hud := preload("res://scripts/hud.gd")

var main: Node
var header: Label
var report: Label
var shop_list: VBoxContainer
var deploy_list: VBoxContainer


func _ready() -> void:
	layer = 5
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(Hud.make_label("THE SHADY VAN  -  hideout", 30, Color(1, 0.8, 0.2)))
	header = Hud.make_label("", 18)
	root.add_child(header)
	report = Hud.make_label("", 18, Color(0.6, 1, 0.6))
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(report)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 20)
	root.add_child(cols)

	shop_list = _column(cols, "SHOP", 1.2)
	deploy_list = _column(cols, "DEPLOY", 1.0)

	GameState.changed.connect(refresh)
	refresh()


func _column(parent: Control, title: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.panel_style(0.8))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(Hud.make_label(title, 22, Color(0.7, 0.85, 1.0)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func set_report(text: String, color := Color(0.6, 1, 0.6)) -> void:
	report.text = text
	report.add_theme_color_override("font_color", color)


func refresh() -> void:
	if not visible:
		return
	var gs := GameState
	header.text = "Cash: $%d    Stash: %d cards (sells for $%d)    Raids: %d   Extracts: %d   Parents KO'd: %d" % [
		gs.cash, gs.stash.size(), gs.cards_value(gs.stash), gs.raids, gs.extracts, gs.knockouts]
	_fill_shop()
	_fill_deploy()


func _section(list: VBoxContainer, text: String) -> void:
	list.add_child(Hud.make_label(text, 16, Color(0.7, 0.8, 1.0)))


func _add(list: VBoxContainer, text: String, cb: Callable, disabled := false) -> void:
	var b := Hud.make_button(text, cb)
	b.disabled = disabled
	list.add_child(b)


func _fill_shop() -> void:
	var gs := GameState
	for c in shop_list.get_children():
		c.queue_free()

	_section(shop_list, "SELL")
	_add(shop_list, "Sell entire stash  (+$%d)" % gs.cards_value(gs.stash), main.hub_sell, gs.stash.is_empty())

	_section(shop_list, "SUPPLIES (you carry these in - lost if you don't extract)")
	_add(shop_list, "Pack of %d junk cards  -  $%d   (have %d)" % [gs.JUNK_PACK_SIZE, gs.JUNK_PACK_COST, gs.junk], main.hub_buy_junk)
	_add(shop_list, "Holo sticker  -  $%d   (have %d)" % [gs.STICKER_COST, gs.stickers], main.hub_buy_sticker)

	_section(shop_list, "FISTS  (equip: click, or 1-4 in a raid)")
	for id in gs.FISTS:
		var f: Dictionary = gs.FISTS[id]
		var stats := "dmg %d, knockback %d" % [f["damage"], f["knock"]]
		if gs.fists_owned[id]:
			var eq := "EQUIPPED" if gs.fist_id == id else "equip"
			_add(shop_list, "%s  (%s)  -  %s" % [f["name"], stats, eq], gs.equip_fist.bind(id), gs.fist_id == id)
		else:
			_add(shop_list, "%s  (%s)  -  $%d" % [f["name"], stats, f["cost"]], main.hub_buy_fist.bind(id))

	_section(shop_list, "UPGRADES (permanent)")
	for id in gs.UPGRADES:
		var u: Dictionary = gs.UPGRADES[id]
		var lvl: int = gs.upgrades[id]
		var maxed: bool = lvl >= u["max"]
		var price := "MAXED" if maxed else "$%d" % gs.upgrade_cost(id)
		_add(shop_list, "%s  [%d/%d]  %s  -  %s" % [u["name"], lvl, u["max"], u["desc"], price], gs.buy_upgrade.bind(id), maxed)

	_section(shop_list, "THE DREAM")
	_add(shop_list, "Buy your own Card Shop Empire  -  $%d" % gs.WIN_COST, main.hub_win, gs.won)


func _fill_deploy() -> void:
	var gs := GameState
	for c in deploy_list.get_children():
		c.queue_free()
	for id in gs.LOCATIONS:
		var loc: Dictionary = gs.LOCATIONS[id]
		var fee := "free" if loc["fee"] == 0 else "$%d entry" % loc["fee"]
		_add(deploy_list, "GO: %s  (%s)" % [loc["name"], fee], main.start_raid.bind(id), gs.cash < loc["fee"])
		var d := Hud.make_label("%s\n%d:%02d raid timer, %d kids." % [loc["desc"], int(loc["time"]) / 60, int(loc["time"]) % 60, loc["kids"]], 15, Color(0.8, 0.8, 0.85))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deploy_list.add_child(d)
	var tip := Hud.make_label("\nHow raids work: scam kids, then reach a green EXTRACT zone and stay in it to escape. " +
		"Die or run out of time and your binder and supplies are gone. Cash, stash and upgrades are always safe.", 15, Color(1, 0.85, 0.5))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deploy_list.add_child(tip)
