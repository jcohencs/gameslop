extends Node3D
## Game controller: hideout <-> raid loop, spawning, scams, heat and extraction.

const PlayerScript := preload("res://scripts/player.gd")
const KidScript := preload("res://scripts/kid.gd")
const ParentScript := preload("res://scripts/parent.gd")
const HudScript := preload("res://scripts/hud.gd")
const HubScript := preload("res://scripts/hub.gd")

const MAX_PARENTS := 12
const EXTRACT_RADIUS := 3.0
const EXTRACT_TIME := 5.0
const ACTIVE_EXTRACTS := 2

var hub: CanvasLayer
var hud: CanvasLayer
var player: CharacterBody3D
var level: Node3D
var layout: Dictionary
var extracts: Array = []  # [{name, pos, label}]
var extract_progress := 0.0
var raid_over := true
var kid_respawn_timer := 0.0
var raid_cooldown := 0.0


func _ready() -> void:
	add_to_group("main")
	randomize()
	GameState.reset()
	_build_environment()

	hud = HudScript.new()
	hud.main = self
	hud.visible = false
	add_child(hud)

	hub = HubScript.new()
	hub.main = self
	add_child(hub)
	hub.set_report("CARD SHARK: EXTRACTION HUSTLE\nPick a spot, scam kids out of their cards, punch out the parents who come for you, " +
		"and EXTRACT before time runs out. Earn $%d to buy your own Card Shop Empire." % GameState.WIN_COST, Color(1, 0.85, 0.5))
	_show_hub()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.55, 0.95)
	sky_mat.sky_horizon_color = Color(0.75, 0.85, 1.0)
	sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.6)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)


# --- Hub ---------------------------------------------------------------------

func _show_hub() -> void:
	hud.visible = false
	hub.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hub.refresh()


func hub_sell() -> void:
	var n := GameState.stash.size()
	var total := GameState.sell_stash()
	hub.set_report("Flipped %d cards for $%d. Capitalism!" % [n, total])


func hub_buy_junk() -> void:
	if GameState.try_spend(GameState.JUNK_PACK_COST):
		GameState.junk += GameState.JUNK_PACK_SIZE
		GameState.changed.emit()


func hub_buy_sticker() -> void:
	if GameState.try_spend(GameState.STICKER_COST):
		GameState.stickers += 1
		GameState.changed.emit()


func hub_buy_fist(id: String) -> void:
	GameState.buy_fist(id)


func hub_win() -> void:
	if not GameState.try_spend(GameState.WIN_COST):
		hub.set_report("You need $%d for the Empire." % GameState.WIN_COST, Color(1, 0.5, 0.5))
		return
	GameState.won = true
	GameState.changed.emit()
	hub.set_report("YOU DID IT. \"Card Shark's Collectibles Emporium\" is open, right across from Dragon's Den. " +
		"The kids still don't know. Scams: %d, extracts: %d, parents KO'd: %d. Keep hustling if you like." % [
			GameState.scams, GameState.extracts, GameState.knockouts], Color(1, 0.85, 0.3))


# --- Raid lifecycle ----------------------------------------------------------

func start_raid(id: String) -> void:
	if not GameState.start_raid(id):
		hub.set_report("Can't afford the entry fee.", Color(1, 0.5, 0.5))
		return
	var loc: Dictionary = GameState.LOCATIONS[id]
	level = Node3D.new()
	add_child(level)
	layout = Levels.build(id, level)

	player = PlayerScript.new()
	player.main = self
	player.position = layout["spawn"]
	level.add_child(player)
	player.rotation.y = layout["spawn_yaw"]

	for i in loc["kids"]:
		spawn_kid()

	extracts.clear()
	var options: Array = layout["extracts"].duplicate()
	options.shuffle()
	for i in mini(ACTIVE_EXTRACTS, options.size()):
		_add_extract(options[i])
	extract_progress = 0.0
	kid_respawn_timer = 0.0
	raid_cooldown = 0.0
	raid_over = false

	hub.visible = false
	hud.visible = true
	hud.close_all()
	hud.hide_overlay()
	_set_menu_mode(false)
	var names := []
	for e in extracts:
		names.append(e["name"])
	GameState.say("Raid started at %s. Extracts open: %s" % [loc["name"], ", ".join(names)], Color(0.5, 1, 0.6))


func _add_extract(info: Dictionary) -> void:
	var node := Node3D.new()
	node.position = info["pos"]
	level.add_child(node)
	var ring := Shapes.cylinder(node, EXTRACT_RADIUS, 0.06, Vector3(0, 0.04, 0), Color(0.2, 1, 0.4))
	var rm := Shapes.mat(Color(0.2, 1, 0.4, 0.35), 1.5)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	var beam := Shapes.cylinder(node, 0.25, 30.0, Vector3(0, 15, 0), Color(0.2, 1, 0.4))
	var bm := Shapes.mat(Color(0.3, 1, 0.5, 0.3), 2.0)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Shapes.label(node, "", Vector3(0, 3.0, 0), Color(0.4, 1, 0.5), 64)
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0007
	extracts.append({"name": info["name"], "pos": info["pos"], "label": label})


func _end_raid(success: bool, reason: String) -> void:
	if raid_over:
		return
	raid_over = true
	var loc_name: String = GameState.LOCATIONS[GameState.location_id]["name"]
	if success:
		var r := GameState.extract()
		hub.set_report("EXTRACTED from %s via %s!\nSecured %d cards worth $%d. They're in your stash - sell them here." % [
			loc_name, reason, r["cards"], r["value"]])
	else:
		var r := GameState.lose_raid()
		hub.set_report("%s\nLost %d cards ($%d), %d junk cards and %d stickers. Cash and stash are safe." % [
			reason, r["cards"], r["value"], r["junk"], r["stickers"]], Color(1, 0.5, 0.45))
	GameState.heat = 0.0
	GameState.health = GameState.max_health()
	player = null
	level.queue_free()
	level = null
	extracts.clear()
	hud.close_all()
	hud.hide_overlay()
	_show_hub()


func player_died() -> void:
	_end_raid(false, "GROUNDED! The parents caught you at %s." % GameState.LOCATIONS[GameState.location_id]["name"])


# --- Spawning ----------------------------------------------------------------

func spawn_kid() -> void:
	var kid := KidScript.new()
	kid.player = player
	var b: Rect2 = layout["kid_bounds"]
	kid.bounds = b
	kid.rarity_bonus = GameState.LOCATIONS[GameState.location_id]["rarity_bonus"]
	kid.position = Vector3(randf_range(b.position.x, b.end.x), 0.1, randf_range(b.position.y, b.end.y))
	kid.cried.connect(_on_kid_cried)
	level.add_child(kid)


func spawn_parent(type_id: String, reason := "") -> void:
	if level == null or get_tree().get_nodes_in_group("parents").size() >= MAX_PARENTS:
		return
	var p := ParentScript.new()
	p.setup(type_id)
	p.player = player
	var spawns: Array = layout["parent_spawns"].duplicate()
	spawns.shuffle()
	var pos: Vector3 = spawns[0]
	for s in spawns:
		if s.distance_to(player.global_position) > 12.0:
			pos = s
			break
	p.position = pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	level.add_child(p)
	if reason != "":
		GameState.say(reason, Color(1, 0.5, 0.4))


func _parent_type_for_heat() -> String:
	var s := GameState.stars()
	var pool := ["mom", "dad"]
	if s >= 2:
		pool.append("mom")
	if s >= 3:
		pool.append("pta")
	if s >= 4:
		pool.append_array(["pta", "coach"])
	if s >= 5:
		pool.append("coach")
	return pool[randi() % pool.size()]


func _on_kid_cried(kid: Node) -> void:
	var t := _parent_type_for_heat()
	spawn_parent(t, "%s's %s is coming for you!" % [kid.kid_name, ParentScript.TYPES[t]["name"]])
	if GameState.stars() >= 3 and randf() < 0.5:
		spawn_parent(_parent_type_for_heat())


# --- Raid loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if raid_over:
		return
	var gs := GameState
	if not hud.overlay.visible:
		gs.raid_time_left -= delta
	if gs.raid_time_left <= 0.0:
		_end_raid(false, "TIME'S UP! The store closed and your mom dragged you home.")
		return

	var parents := get_tree().get_nodes_in_group("parents").size()
	gs.heat = maxf(gs.heat - delta * (0.4 if parents > 0 else 1.6), 0.0)

	raid_cooldown -= delta
	if gs.heat >= 99.0 and raid_cooldown <= 0.0:
		raid_cooldown = 25.0
		gs.say("!!! PTA RAID !!! The whole parent council is here!", Color(1, 0.2, 0.2))
		for i in 4:
			spawn_parent(_parent_type_for_heat())
		gs.heat = 70.0

	var kids := get_tree().get_nodes_in_group("kids").size()
	if kids < gs.LOCATIONS[gs.location_id]["kids"]:
		kid_respawn_timer -= delta
		if kid_respawn_timer <= 0.0:
			kid_respawn_timer = 5.0
			spawn_kid()

	var extracting := _update_extraction(delta)
	if raid_over:
		return

	var t: Node = player.interact_target
	if extracting:
		pass
	elif hud.any_menu_open() or t == null:
		hud.set_prompt("")
	else:
		hud.set_prompt("[E] \"Hey kid, wanna trade?\"  (%s has a %s)" % [t.kid_name, gs.rarity_name(t.card)])
	hud.refresh_stats()


## Returns true while the player is standing in an extract zone.
func _update_extraction(delta: float) -> bool:
	var lines := []
	var inside := ""
	for e in extracts:
		var d := Vector2(player.global_position.x - e["pos"].x, player.global_position.z - e["pos"].z).length()
		e["label"].text = "EXTRACT: %s\n%dm" % [e["name"], d]
		lines.append("%s  -  %dm" % [e["name"], d])
		if d < EXTRACT_RADIUS:
			inside = e["name"]
	hud.set_extracts("\n".join(lines))
	if inside != "":
		extract_progress += delta / EXTRACT_TIME
		hud.set_prompt("EXTRACTING via %s... stay in the zone!" % inside)
		if extract_progress >= 1.0:
			hud.set_extract_progress(0.0)
			_end_raid(true, inside)
			return true
	else:
		extract_progress = maxf(extract_progress - delta / EXTRACT_TIME * 2.0, 0.0)
	hud.set_extract_progress(extract_progress)
	return inside != ""


func _unhandled_input(event: InputEvent) -> void:
	if raid_over or not event.is_action_pressed("pause"):
		return
	if hud.trade_panel.visible:
		close_menus()
	elif not hud.overlay.visible:
		_set_menu_mode(true)
		hud.show_overlay("PAUSED\n\n" + _controls_text(), "Resume", _resume)


func _controls_text() -> String:
	return "WASD move  |  Shift sprint  |  Space jump  |  Mouse look\nLeft click punch  |  Right click block  |  1-4 switch fists\nE trade with kids  |  Esc pause\n\nStand in a green EXTRACT zone for %d seconds to escape with your binder." % EXTRACT_TIME


func _set_menu_mode(on: bool) -> void:
	if player:
		player.input_locked = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	hud.crosshair.visible = not on


func _resume() -> void:
	hud.hide_overlay()
	_set_menu_mode(false)


func interact(target: Node) -> void:
	if hud.any_menu_open() or raid_over:
		return
	if target.can_trade():
		_set_menu_mode(true)
		hud.open_trade(target, _tactics_for(target))


func close_menus() -> void:
	hud.close_all()
	if not hud.overlay.visible:
		_set_menu_mode(false)


func on_player_hurt(blocked: bool) -> void:
	hud.flash_damage()
	# An unblocked smack sets your extraction countdown back.
	if not blocked:
		extract_progress = maxf(extract_progress - 0.25, 0.0)


func spawn_hit_spark(at: Vector3) -> void:
	if level == null:
		return
	var s := Shapes.sphere(level, 0.12, Vector3.ZERO, Color(1, 0.9, 0.4))
	s.material_override = Shapes.mat(Color(1, 0.9, 0.4), 4.0)
	s.global_position = at
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 2.5, 0.1)
	tw.tween_callback(s.queue_free)


# --- Scamming ----------------------------------------------------------------

func _tactics_for(kid: Node) -> Array:
	var gs := GameState
	var rarity_penalty: float = kid.card["rarity"] * 0.07
	var list := [
		{"id": "junk", "label": "Offer a \"super rare\" junk card", "base": 0.6, "heat": 8.0, "cry": 0.25,
			"cost_text": "costs 1 junk card", "available": gs.junk > 0},
		{"id": "sticker", "label": "Holo-sticker forgery", "base": 0.9, "heat": 4.0, "cry": 0.1,
			"cost_text": "costs 1 junk + 1 sticker", "available": gs.junk > 0 and gs.stickers > 0},
		{"id": "ufo", "label": "\"Whoa, is that a UFO?!\" (swipe it)", "base": 0.75, "heat": 22.0, "cry": 1.0,
			"cost_text": "free, kid WILL cry", "available": true},
	]
	for t in list:
		t["chance"] = clampf(t["base"] + gs.scam_bonus() - rarity_penalty, 0.05, 0.97)
		if gs.binder.size() >= gs.capacity():
			t["available"] = false
			t["cost_text"] = "BINDER FULL - go extract!"
	return list


func do_trade(kid: Node, tactic_id: String) -> void:
	if not is_instance_valid(kid) or not kid.can_trade():
		close_menus()
		return
	var tactic: Dictionary = {}
	for t in _tactics_for(kid):
		if t["id"] == tactic_id:
			tactic = t
	if tactic.is_empty() or not tactic["available"]:
		return
	var gs := GameState
	if tactic_id == "junk" or tactic_id == "sticker":
		gs.junk -= 1
	if tactic_id == "sticker":
		gs.stickers -= 1
	close_menus()

	if randf() < tactic["chance"]:
		var card: Dictionary = kid.card
		gs.add_to_binder(card)
		gs.scams += 1
		gs.add_heat(tactic["heat"])
		gs.say("Scammed %s out of a [%s] %s! ($%d)" % [kid.kid_name, gs.rarity_name(card), card["name"], gs.card_sell_value(card)],
			gs.rarity_color(card))
		if randf() < tactic["cry"]:
			kid.cry()
		else:
			kid.become_scammed()
	else:
		gs.add_heat(tactic["heat"] + 12.0)
		gs.say("%s saw right through you!" % kid.kid_name, Color(1, 0.5, 0.4))
		kid.cry()
	gs.changed.emit()
