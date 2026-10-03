extends CanvasLayer
## In-raid UI: compass, status, timer, heat, health/stamina, binder, weapon, crosshair,
## prompts, message feed, card popups, trade screen and pause menu.

const CardView := preload("res://scripts/ui/card_view.gd")
const Compass := preload("res://scripts/ui/compass.gd")
const Crosshair := preload("res://scripts/ui/crosshair.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")


class HeatMeter extends Control:
	var stars := 0
	var pulse := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(170, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		pulse += delta
		queue_redraw()

	func _draw() -> void:
		for i in 5:
			var c := Vector2(17 + i * 34, 17)
			var on := i < stars
			var col := Color(1, 0.3, 0.25) if on else Color(1, 1, 1, 0.15)
			var s := 1.0
			if on and stars >= 4:
				s += sin(pulse * 8.0 + i) * 0.08
			draw_colored_polygon(UI.star_points(c, 14 * s, 6 * s), col)


var main: Node
var root: Control
var compass: Control
var status_label: Label
var timer_label: Label
var location_label: Label
var heat: HeatMeter
var hp_bar: ProgressBar
var hp_lag: ProgressBar
var hp_text: Label
var stamina_bar: ProgressBar
var speed_label: Label
var binder_label: Label
var binder_strip: HBoxContainer
var weapon_label: Label
var combo_pips: HBoxContainer
var slots_label: Label
var crosshair: Control
var prompt_box: HBoxContainer
var prompt_label: Label
var prompt_key: PanelContainer
var feed: VBoxContainer
var popup_holder: Control
var vignette: ColorRect
var damage_flash: ColorRect

var trade_panel: PanelContainer
var trade_card: Control
var trade_title: Label
var trade_body: Label
var trade_buttons: VBoxContainer

var pause_panel: PanelContainer
var settings: PanelContainer

var _binder_count := -1
var _hp_lag_value := 100.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_overlays()
	_build_top()
	_build_bottom()
	_build_trade()
	_build_pause()
	GameState.message.connect(push_message)
	GameState.card_acquired.connect(show_card)


func set_player(p: Node3D) -> void:
	compass.player = p
	crosshair.player = p


# --- Construction ------------------------------------------------------------

func _anchored(c: Control, preset: int, grow_h: int, grow_v: int) -> Control:
	c.set_anchors_and_offsets_preset(preset)
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v
	root.add_child(c)
	return c


func _build_overlays() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.0;\nuniform vec4 tint : source_color = vec4(0.8, 0.0, 0.0, 1.0);\n" + \
		"void fragment() { float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.75, d) * strength); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	root.add_child(vignette)
	damage_flash = ColorRect.new()
	damage_flash.color = Color(1, 0, 0, 0)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)
	crosshair = Crosshair.new()
	root.add_child(crosshair)


func _build_top() -> void:
	# Compass + detection status, top center.
	var top := UI.vbox(2)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_anchored(top, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	top.offset_top = 10
	compass = Compass.new()
	top.add_child(compass)
	status_label = UI.label("HIDDEN", 18, UI.GOOD, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(status_label)
	feed = UI.vbox(4)
	top.add_child(feed)

	# Timer + location, top left.
	var tl := UI.panel(0.6)
	_anchored(tl, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	tl.position = Vector2(16, 14)
	var tlv := UI.vbox(0)
	tl.add_child(tlv)
	location_label = UI.label("", 14, UI.TEXT_DIM)
	tlv.add_child(location_label)
	timer_label = UI.label("5:00", 34, UI.ACCENT, true)
	tlv.add_child(timer_label)

	# Heat, top right.
	var tr := UI.panel(0.6)
	_anchored(tr, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	tr.offset_right = -16
	tr.offset_top = 14
	var trv := UI.vbox(2)
	tr.add_child(trv)
	trv.add_child(UI.label("HEAT", 14, UI.TEXT_DIM))
	heat = HeatMeter.new()
	trv.add_child(heat)


func _build_bottom() -> void:
	# Health / stamina / binder, bottom left.
	var bl := UI.panel(0.6)
	_anchored(bl, Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	bl.offset_left = 16
	bl.offset_bottom = -16
	var v := UI.vbox(6)
	bl.add_child(v)
	var hp_row := UI.hbox(10)
	v.add_child(hp_row)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(260, 20)
	hp_row.add_child(stack)
	hp_lag = UI.bar(Color(1, 1, 1, 0.7), Vector2(260, 20))
	stack.add_child(hp_lag)
	hp_bar = UI.bar(Color(0.9, 0.22, 0.25), Vector2(260, 20))
	hp_bar.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0), 6, 0, Color.TRANSPARENT, 0))
	stack.add_child(hp_bar)
	hp_text = UI.label("100", 18, UI.TEXT, true)
	hp_row.add_child(hp_text)
	stamina_bar = UI.bar(Color(0.95, 0.85, 0.3), Vector2(260, 8))
	stamina_bar.tooltip_text = "Stamina: spent on charged heavy attacks"
	v.add_child(stamina_bar)
	binder_label = UI.label("", 15, UI.TEXT)
	v.add_child(binder_label)
	binder_strip = UI.hbox(3)
	v.add_child(binder_strip)

	# Weapon, bottom right.
	var br := UI.panel(0.6)
	_anchored(br, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	br.offset_right = -16
	br.offset_bottom = -16
	var wv := UI.vbox(4)
	br.add_child(wv)
	weapon_label = UI.label("", 22, UI.TEXT, true)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wv.add_child(weapon_label)
	combo_pips = UI.hbox(4)
	combo_pips.alignment = BoxContainer.ALIGNMENT_END
	wv.add_child(combo_pips)
	slots_label = UI.label("", 14, UI.TEXT_DIM)
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wv.add_child(slots_label)
	wv.add_child(UI.label("LMB attack (hold: heavy)  RMB block/parry  Q sand  Wheel swap", 13, UI.TEXT_DIM))

	# Interaction prompt, lower center.
	prompt_box = UI.hbox(8)
	prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_anchored(prompt_box, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	prompt_box.offset_bottom = -150
	prompt_key = UI.keycap("E")
	prompt_box.add_child(prompt_key)
	prompt_label = UI.label("", 20, UI.TEXT, true)
	prompt_box.add_child(prompt_label)
	prompt_box.visible = false

	speed_label = UI.label("", 16, UI.TEXT, true)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(speed_label, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	speed_label.offset_top = 70
	speed_label.offset_bottom = 70

	popup_holder = Control.new()
	_anchored(popup_holder, Control.PRESET_CENTER_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)
	popup_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _centered_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 14, 2, UI.ACCENT, 20))
	p.custom_minimum_size = min_size
	_anchored(p, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	p.visible = false
	return p


func _build_trade() -> void:
	trade_panel = _centered_panel(Vector2(760, 0))
	var h := UI.hbox(22)
	trade_panel.add_child(h)
	trade_card = CardView.new({}, Vector2(210, 294))
	h.add_child(trade_card)
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	trade_title = UI.label("", 28, UI.ACCENT, true)
	v.add_child(trade_title)
	trade_body = UI.wrap(UI.label("", 17, UI.TEXT_DIM))
	v.add_child(trade_body)
	trade_buttons = UI.vbox(8)
	v.add_child(trade_buttons)


func _build_pause() -> void:
	pause_panel = _centered_panel(Vector2(440, 0))
	var v := UI.vbox(12)
	pause_panel.add_child(v)
	var t := UI.label("PAUSED", 34, UI.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.button("Resume", func(): main.resume(), 20, 48))
	v.add_child(UI.button("Settings", _open_settings, 20, 48))
	v.add_child(UI.button("Abandon raid (lose binder)", func(): main.abandon_raid(), 20, 48))
	var help := UI.wrap(UI.label("WASD move · Shift sprint · hold Space to bunny hop (works while sprinting)\nCtrl/C crouch (quiet) & slide at speed · air strafe: hold A/D + turn the mouse mid-air\nLMB attack (3-hit combo) · hold LMB: charged heavy (uses stamina)\nRMB block · tap RMB right before a hit to PARRY · Q pocket sand\n1-7 / mouse wheel: switch weapon · E trade", 14, UI.TEXT_DIM))
	v.add_child(help)
	settings = SettingsPanel.new()
	_anchored(settings, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	settings.visible = false
	settings.closed.connect(_settings_closed)


func _settings_closed() -> void:
	settings.visible = false
	pause_panel.visible = true


func _open_settings() -> void:
	pause_panel.visible = false
	settings.visible = true


# --- Per-frame updates -------------------------------------------------------

func refresh(delta: float, player: Node3D) -> void:
	var gs := GameState
	var t := maxf(gs.raid_time_left, 0.0)
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	var urgent := t < 60.0
	timer_label.add_theme_color_override("font_color", UI.BAD if urgent else UI.ACCENT)
	if urgent:
		timer_label.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.01)
	if gs.location_id != "":
		location_label.text = gs.LOCATIONS[gs.location_id]["name"].to_upper()
	heat.stars = gs.stars()

	var mh := gs.max_health()
	hp_bar.max_value = mh
	hp_lag.max_value = mh
	hp_bar.value = gs.health
	_hp_lag_value = move_toward(_hp_lag_value, gs.health, delta * 40.0) if _hp_lag_value > gs.health else gs.health
	hp_lag.value = _hp_lag_value
	hp_text.text = "%d" % ceili(gs.health)
	stamina_bar.max_value = gs.max_stamina()
	stamina_bar.value = gs.stamina
	if player:
		# Dim red when there isn't enough stamina for a heavy.
		stamina_bar.modulate = Color.WHITE if gs.stamina >= player.HEAVY_STAMINA else Color(1, 0.45, 0.3)
		speed_label.text = "%d m/s%s" % [roundi(player.hspeed()), "  SLIDE" if player.sliding else ""]
		speed_label.modulate.a = clampf((player.hspeed() - player.run_speed) / 1.5, 0.0, 1.0)
	var low := 1.0 - gs.health / mh
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", clampf((low - 0.5) * 1.6, 0.0, 0.8) * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.006)))

	binder_label.text = "BINDER %d/%d   $%d AT RISK" % [gs.binder.size(), gs.capacity(), gs.cards_value(gs.binder)]
	if _binder_count != gs.binder.size():
		_binder_count = gs.binder.size()
		for c in binder_strip.get_children():
			c.queue_free()
		for i in gs.capacity():
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(14, 20)
			r.color = gs.rarity_color(gs.binder[i]) if i < gs.binder.size() else Color(1, 1, 1, 0.1)
			binder_strip.add_child(r)

	var w := gs.weapon()
	weapon_label.text = w["name"]
	if w["kind"] == "sand":
		weapon_label.text += "  (%d packets)" % gs.sand
	elif gs.weapons_owned.get("sand", false):
		weapon_label.text += "\nPocket sand: %d  [Q]" % gs.sand
	if player:
		var chain: Array = w["combo"]
		var step: int = player.combo % chain.size() if player.combo_timer > 0.0 else 0
		if combo_pips.get_child_count() != chain.size():
			for c in combo_pips.get_children():
				c.free()
			for i in chain.size():
				var r := ColorRect.new()
				r.custom_minimum_size = Vector2(22, 6)
				combo_pips.add_child(r)
		for i in combo_pips.get_child_count():
			(combo_pips.get_child(i) as ColorRect).color = UI.ACCENT if i < step else Color(1, 1, 1, 0.15)
	var slots := []
	for i in gs.WEAPON_ORDER.size():
		var id: String = gs.WEAPON_ORDER[i]
		if gs.weapons_owned[id]:
			slots.append(("[%d]" if id == gs.weapon_id else "%d") % (i + 1))
	slots_label.text = "  ".join(slots)


func set_status(level: int) -> void:
	match level:
		2:
			status_label.text = "SPOTTED!"
			status_label.add_theme_color_override("font_color", UI.BAD)
		1:
			status_label.text = "SEARCHING..."
			status_label.add_theme_color_override("font_color", UI.ACCENT)
		_:
			status_label.text = "HIDDEN"
			status_label.add_theme_color_override("font_color", UI.GOOD)


func set_markers(markers: Array) -> void:
	compass.markers = markers


func set_extract_progress(frac: float) -> void:
	crosshair.extract = frac


func set_target(kind: String) -> void:
	crosshair.target_kind = kind


func set_prompt(text: String, key := "E") -> void:
	prompt_box.visible = text != ""
	prompt_label.text = text
	prompt_key.visible = key != ""
	if key != "":
		(prompt_key.get_child(0) as Label).text = key


func push_message(text: String, color := Color.WHITE) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.05, 0.08, 0.6), 6, 0, Color.TRANSPARENT, 6))
	var l := UI.label(text, 17, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	feed.add_child(p)
	while feed.get_child_count() > 4:
		feed.get_child(0).free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func show_card(card: Dictionary) -> void:
	Sfx.play("card", 0.0)
	var cv := CardView.new(card, Vector2(150, 210))
	popup_holder.add_child(cv)
	cv.position = Vector2(40, -105)
	cv.rotation = 0.2
	var tw := cv.create_tween()
	tw.tween_property(cv, "position:x", -190.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cv, "rotation", -0.05, 0.35)
	tw.tween_interval(1.8)
	tw.tween_property(cv, "position:x", 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(cv.queue_free)


func flash_damage(blocked: bool) -> void:
	damage_flash.color = Color(0.4, 0.6, 1.0, 0.18) if blocked else Color(1, 0, 0, 0.32)
	var tw := damage_flash.create_tween()
	tw.tween_property(damage_flash, "color:a", 0.0, 0.35)


func damage_from(pos: Vector3) -> void:
	crosshair.damage_from(pos)


func hit_marker(big: bool) -> void:
	crosshair.hit(big)


func any_menu_open() -> bool:
	return trade_panel.visible or pause_panel.visible or settings.visible


# --- Trade -------------------------------------------------------------------

func open_trade(kid: Node, tactics: Array, warning: String) -> void:
	var c: Dictionary = kid.card
	trade_card.set_card(c)
	trade_title.text = "\"Hey %s, wanna trade?\"" % kid.kid_name
	trade_body.text = "%s is holding a %s %s. You'd flip it for $%d.%s" % [
		kid.kid_name, GameState.rarity_name(c), c["name"], GameState.card_sell_value(c), warning]
	for b in trade_buttons.get_children():
		b.queue_free()
	for t in tactics:
		var b := UI.button("", main.do_trade.bind(kid, t["id"]), 17, 64)
		b.disabled = not t["available"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var inner := UI.vbox(4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 12
		inner.offset_right = -12
		inner.offset_top = 6
		var top := UI.hbox(8)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := UI.label(t["label"], 17, UI.TEXT if t["available"] else UI.TEXT_DIM, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_l)
		top.add_child(UI.label("%d%%" % roundi(t["chance"] * 100.0), 17, UI.GOOD.lerp(UI.BAD, 1.0 - t["chance"]), true))
		inner.add_child(top)
		var chance := UI.bar(UI.GOOD.lerp(UI.BAD, 1.0 - t["chance"]), Vector2(0, 6))
		chance.value = t["chance"] * 100.0
		chance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(chance)
		inner.add_child(UI.label(t["cost_text"], 13, UI.TEXT_DIM))
		b.add_child(inner)
		trade_buttons.add_child(b)
	trade_buttons.add_child(UI.button("Walk away  (Esc)", main.close_menus, 17, 40))
	trade_panel.visible = true
	trade_panel.scale = Vector2(0.92, 0.92)
	trade_panel.pivot_offset = trade_panel.size * 0.5
	trade_panel.create_tween().tween_property(trade_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_pause() -> void:
	pause_panel.visible = true


func close_all() -> void:
	trade_panel.visible = false
	pause_panel.visible = false
	settings.visible = false
