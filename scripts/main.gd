extends Node3D
## Game controller: title/hideout <-> raid loop, spawning, scams, witnesses, AI
## coordination (attack tokens, radio), heat, extraction and feedback effects.

const PlayerScript := preload("res://scripts/player.gd")
const KidScript := preload("res://scripts/kid.gd")
const ParentScript := preload("res://scripts/parent.gd")
const HudScript := preload("res://scripts/hud.gd")
const HubScript := preload("res://scripts/hub.gd")

const MAX_PARENTS := 12
const EXTRACT_RADIUS := 3.0
const EXTRACT_TIME := 5.0
const ACTIVE_EXTRACTS := 2
const WITNESS_RANGE := 9.0
const RADIO_RANGE := 30.0

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
var attackers: Array = []
var awareness := 0
var alert_cd := 0.0
var talking_to: Node = null


func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_build_environment()

	hud = HudScript.new()
	hud.main = self
	hud.visible = false
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	hub = HubScript.new()
	hub.main = self
	hub.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hub)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# --- Hideout actions ---------------------------------------------------------

func _show_hub() -> void:
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hub.show_hub()


func hub_sell() -> void:
	var n := GameState.stash.size()
	var total := GameState.sell_stash()
	Sfx.play("cash")
	hub.set_report("Flipped %d cards for $%d. Capitalism!" % [n, total])


func hub_sell_card(i: int) -> void:
	if i >= GameState.stash.size():
		return
	var c: Dictionary = GameState.stash[i]
	var v := GameState.sell_card(i)
	Sfx.play("cash")
	hub.set_report("Sold %s for $%d." % [c["name"], v])


func hub_buy_junk() -> void:
	if GameState.buy_junk():
		Sfx.play("cash", 0.1, -4.0)


func hub_buy_sticker() -> void:
	if GameState.buy_sticker():
		Sfx.play("cash", 0.1, -4.0)


func hub_buy_weapon(id: String) -> void:
	if GameState.buy_weapon(id):
		Sfx.play("cash")
		hub.set_report("Bought the %s. It's equipped." % GameState.WEAPONS[id]["name"])
	else:
		hub.set_report("Can't afford that yet.", UI.BAD)


func hub_equip(id: String) -> void:
	GameState.equip_weapon(id)
	GameState.save_game()


func hub_upgrade(id: String) -> void:
	if GameState.buy_upgrade(id):
		Sfx.play("cash")
		hub.set_report("%s upgraded to level %d." % [GameState.UPGRADES[id]["name"], GameState.upgrades[id]])


func hub_win() -> void:
	if not GameState.try_spend(GameState.WIN_COST):
		hub.set_report("You need $%d for the Empire." % GameState.WIN_COST, UI.BAD)
		return
	GameState.won = true
	GameState.save_game()
	GameState.changed.emit()
	Sfx.play("extract")
	hub.set_report("YOU DID IT. \"Card Shark's Collectibles Emporium\" is open, right across from Dragon's Den. " +
		"The kids still don't know. Scams: %d, extracts: %d, parents KO'd: %d. Keep hustling if you like." % [
			GameState.scams, GameState.extracts, GameState.knockouts], UI.ACCENT)


# --- Raid lifecycle ----------------------------------------------------------

func start_raid(id: String) -> void:
	if not GameState.start_raid(id):
		hub.set_report("Can't afford the entry fee.", UI.BAD)
		return
	var loc: Dictionary = GameState.LOCATIONS[id]
	level = Node3D.new()
	add_child(level)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	layout = Levels.build(id, level)

	player = PlayerScript.new()
	player.main = self
	player.position = layout["spawn"]
	level.add_child(player)
	player.rotation.y = layout["spawn_yaw"]
	hud.set_player(player)

	for i in loc["kids"]:
		spawn_kid()
	var guard := spawn_parent(loc["guard"])
	if guard:
		guard.patrol = layout["patrol"]
		guard.global_position = layout["patrol"][0] + Vector3(0, 0.1, 0)

	extracts.clear()
	var options: Array = layout["extracts"].duplicate()
	options.shuffle()
	for i in mini(ACTIVE_EXTRACTS, options.size()):
		_add_extract(options[i])
	extract_progress = 0.0
	kid_respawn_timer = 0.0
	raid_cooldown = 0.0
	attackers.clear()
	awareness = 0
	raid_over = false
	Engine.time_scale = 1.0

	hub.visible = false
	hud.visible = true
	hud.close_all()
	_set_menu_mode(false)
	var names := []
	for e in extracts:
		names.append(e["name"])
	GameState.say("Raid started at %s. Extracts open: %s" % [loc["name"], ", ".join(names)], UI.GOOD)


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
	Engine.time_scale = 1.0
	get_tree().paused = false
	var loc_name: String = GameState.LOCATIONS[GameState.location_id]["name"]
	if success:
		var r := GameState.extract()
		Sfx.play("extract", 0.0)
		hub.set_report("EXTRACTED from %s via %s!  Secured %d cards worth $%d. They're in your STASH." % [
			loc_name, reason, r["cards"], r["value"]], UI.GOOD)
	else:
		var r := GameState.lose_raid()
		Sfx.play("fail", 0.0)
		hub.set_report("%s  Lost %d cards ($%d), %d junk cards and %d stickers. Cash and stash are safe." % [
			reason, r["cards"], r["value"], r["junk"], r["stickers"]], UI.BAD)
	GameState.heat = 0.0
	GameState.health = GameState.max_health()
	player = null
	talking_to = null
	level.queue_free()
	level = null
	extracts.clear()
	attackers.clear()
	hud.close_all()
	_show_hub()


func player_died() -> void:
	_end_raid(false, "GROUNDED! The parents caught you at %s." % GameState.LOCATIONS[GameState.location_id]["name"])


func abandon_raid() -> void:
	_end_raid(false, "You bailed on the raid.")


# --- Spawning ----------------------------------------------------------------

func spawn_kid() -> void:
	var kid := KidScript.new()
	kid.player = player
	var b: Rect2 = layout["kid_bounds"]
	kid.bounds = b
	kid.pois = layout["pois"]
	kid.rarity_bonus = GameState.LOCATIONS[GameState.location_id]["rarity_bonus"]
	var start: Vector3 = layout["pois"][randi() % layout["pois"].size()]
	kid.position = start + Vector3(randf_range(-2, 2), 0.1, randf_range(-2, 2))
	kid.cried.connect(_on_kid_cried)
	level.add_child(kid)


func spawn_parent(type_id: String, reason := "") -> Node:
	if level == null or get_tree().get_nodes_in_group("parents").size() >= MAX_PARENTS:
		return null
	var p := ParentScript.new()
	p.setup(type_id)
	p.player = player
	p.main = self
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
		GameState.say(reason, Color(1, 0.55, 0.45))
	return p


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
	var p := spawn_parent(t, "%s's %s is on the way!" % [kid.kid_name, ParentScript.TYPES[t]["name"]])
	if p:
		p.begin_investigate(kid.global_position)
	if GameState.stars() >= 3 and randf() < 0.5:
		var p2 := spawn_parent(_parent_type_for_heat())
		if p2:
			p2.begin_investigate(kid.global_position)
	# Adults already nearby come to check on the crying.
	for other in get_tree().get_nodes_in_group("parents"):
		if other != p and other.global_position.distance_to(kid.global_position) < 20.0:
			other.alert_to(kid.global_position)


# --- AI coordination ---------------------------------------------------------

func max_attackers() -> int:
	return 2 + (1 if GameState.stars() >= 4 else 0)


func request_attack_token(p: Node) -> bool:
	attackers = attackers.filter(func(a): return is_instance_valid(a) and a.has_token)
	if attackers.has(p):
		return true
	if attackers.size() >= max_attackers():
		return false
	attackers.append(p)
	return true


func release_attack_token(p: Node) -> void:
	attackers.erase(p)


func on_parent_spotted(p: Node) -> void:
	if alert_cd <= 0.0:
		Sfx.play("alert", 0.0, -2.0)
		alert_cd = 3.0
	# Parents radio each other ("the mom group chat") once heat is up; guards always do.
	if GameState.stars() >= 2 or p.is_guard():
		for other in get_tree().get_nodes_in_group("parents"):
			if other != p and other.global_position.distance_to(p.global_position) < RADIO_RANGE:
				other.alert_to(player.global_position)


func on_parry(attacker: Node) -> void:
	GameState.say("PARRY!", UI.ACCENT)
	hud.hit_marker(true)
	if attacker and attacker.has_method("parried"):
		attacker.parried()
	player._hitstop(0.12)


func on_player_hit_landed(big: bool) -> void:
	hud.hit_marker(big)


func on_player_hurt(blocked: bool, from_pos: Vector3) -> void:
	hud.flash_damage(blocked)
	hud.damage_from(from_pos)
	# An unblocked smack sets your extraction countdown back.
	if not blocked:
		extract_progress = maxf(extract_progress - 0.25, 0.0)


# --- Raid loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if raid_over or get_tree().paused:
		return
	var gs := GameState
	alert_cd -= delta
	gs.raid_time_left -= delta
	if gs.raid_time_left <= 0.0:
		_end_raid(false, "TIME'S UP! The place closed and your mom dragged you home.")
		return

	var parents := get_tree().get_nodes_in_group("parents")
	var hunting := 0
	awareness = 0
	var markers := []
	for p in parents:
		var a: int = p.awareness()
		awareness = maxi(awareness, a)
		if not p.is_guard():
			hunting += 1
		if a >= 1:
			markers.append({"pos": p.global_position, "color": UI.BAD if a == 2 else UI.ACCENT})
	gs.heat = maxf(gs.heat - delta * (0.4 if hunting > 0 else 1.6), 0.0)

	raid_cooldown -= delta
	if gs.heat >= 99.0 and raid_cooldown <= 0.0:
		raid_cooldown = 25.0
		gs.say("!!! PTA RAID !!! The whole parent council is here!", UI.BAD)
		Sfx.play("alert", 0.0, 2.0)
		for i in 4:
			var p := spawn_parent(_parent_type_for_heat())
			if p:
				p.begin_chase(player.global_position)
		gs.heat = 70.0

	var kids := get_tree().get_nodes_in_group("kids").size()
	if kids < gs.LOCATIONS[gs.location_id]["kids"]:
		kid_respawn_timer -= delta
		if kid_respawn_timer <= 0.0:
			kid_respawn_timer = 5.0
			spawn_kid()

	var extracting := _update_extraction(delta, markers)
	if raid_over:
		return
	hud.set_markers(markers)
	hud.set_status(awareness)

	var t: Node = player.interact_target
	if extracting:
		hud.set_prompt("EXTRACTING... stay in the zone!", "")
	elif hud.any_menu_open() or t == null:
		hud.set_prompt("")
	else:
		var wary := "  (wary!)" if t.wary > 0.0 else ""
		hud.set_prompt("Trade with %s  -  %s %s%s" % [t.kid_name, gs.rarity_name(t.card), t.card["name"], wary])
	hud.set_target("kid" if t else ("enemy" if _enemy_in_reach() else ""))
	hud.refresh(delta, player)


func _enemy_in_reach() -> bool:
	var w := GameState.weapon()
	var fwd := -player.global_transform.basis.z
	for p in get_tree().get_nodes_in_group("parents"):
		var to: Vector3 = p.global_position - player.global_position
		to.y = 0
		if to.length() < w["range"] + p.radius and to.normalized().dot(Vector3(fwd.x, 0, fwd.z).normalized()) > cos(deg_to_rad(w["arc"])):
			return true
	return false


## Returns true while the player is standing in an extract zone.
func _update_extraction(delta: float, markers: Array) -> bool:
	var inside := ""
	for e in extracts:
		var d := Vector2(player.global_position.x - e["pos"].x, player.global_position.z - e["pos"].z).length()
		e["label"].text = "EXTRACT: %s\n%dm" % [e["name"], d]
		markers.append({"pos": e["pos"], "color": UI.GOOD, "text": "%dm" % d})
		if d < EXTRACT_RADIUS:
			inside = e["name"]
	if inside != "":
		extract_progress += delta / EXTRACT_TIME
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
	get_viewport().set_input_as_handled()
	if hud.trade_panel.visible:
		close_menus()
	elif hud.settings.visible:
		hud._settings_closed()
	elif hud.pause_panel.visible:
		resume()
	else:
		_set_menu_mode(true)
		hud.show_pause()


func _set_menu_mode(on: bool) -> void:
	if player:
		player.input_locked = on
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	hud.crosshair.visible = not on


func resume() -> void:
	hud.close_all()
	_set_menu_mode(false)


func interact(target: Node) -> void:
	if hud.any_menu_open() or raid_over:
		return
	if target.can_trade():
		talking_to = target
		target.start_talking()
		_set_menu_mode(true)
		var warning := ""
		if target.wary > 0.0:
			warning = "\n\n%s saw you scam someone and is WARY (-20%% odds)." % target.kid_name
		hud.open_trade(target, _tactics_for(target), warning)


func close_menus() -> void:
	if talking_to and is_instance_valid(talking_to):
		talking_to.stop_talking()
	talking_to = null
	hud.close_all()
	_set_menu_mode(false)


func spawn_hit_spark(at: Vector3) -> void:
	if level == null:
		return
	var s := Shapes.sphere(level, 0.12, Vector3.ZERO, Color(1, 0.9, 0.4))
	s.material_override = Shapes.mat(Color(1, 0.9, 0.4), 4.0)
	s.global_position = at
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 2.5, 0.1)
	tw.tween_callback(s.queue_free)


func spawn_damage_number(at: Vector3, amount: float, big: bool) -> void:
	if level == null:
		return
	var l := Label3D.new()
	l.text = "%d" % roundi(amount)
	l.font_size = 72 if big else 52
	l.pixel_size = 0.004
	l.outline_size = 14
	l.modulate = UI.ACCENT if big else Color.WHITE
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = UI.bold_font()
	level.add_child(l)
	l.global_position = at + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", at.y + 0.9, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
	spawn_hit_spark(at)


# --- Scamming ----------------------------------------------------------------

func _tactics_for(kid: Node) -> Array:
	var gs := GameState
	var penalty: float = kid.card["rarity"] * 0.07 + (0.2 if kid.wary > 0.0 else 0.0)
	var list := [
		{"id": "junk", "label": "Offer a \"super rare\" junk card", "base": 0.6, "heat": 8.0, "cry": 0.25,
			"cost_text": "Costs 1 junk card  ·  low heat", "available": gs.junk > 0},
		{"id": "sticker", "label": "Holo-sticker forgery", "base": 0.9, "heat": 4.0, "cry": 0.1,
			"cost_text": "Costs 1 junk + 1 sticker  ·  barely any heat", "available": gs.junk > 0 and gs.stickers > 0},
		{"id": "ufo", "label": "\"Whoa, is that a UFO?!\" (swipe it)", "base": 0.75, "heat": 22.0, "cry": 1.0,
			"cost_text": "Free  ·  the kid WILL cry  ·  high heat", "available": true},
	]
	for t in list:
		t["chance"] = clampf(t["base"] + gs.scam_bonus() - penalty, 0.05, 0.97)
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
		gs.say("Scammed %s out of a %s %s! ($%d)" % [kid.kid_name, gs.rarity_name(card), card["name"], gs.card_sell_value(card)],
			gs.rarity_color(card))
		if randf() < tactic["cry"]:
			kid.cry()
		else:
			kid.become_scammed()
	else:
		gs.add_heat(tactic["heat"] + 12.0)
		gs.say("%s saw right through you!" % kid.kid_name, UI.BAD)
		kid.cry()
	_check_witnesses(kid)
	gs.changed.emit()


func _check_witnesses(victim: Node) -> void:
	for k in get_tree().get_nodes_in_group("kids"):
		if k != victim and k.global_position.distance_to(victim.global_position) < WITNESS_RANGE:
			k.witness()
	for p in get_tree().get_nodes_in_group("parents"):
		if p.is_guard() and p.awareness() < 2 and p.witnessed_scam():
			GameState.add_heat(15.0)
			GameState.say("%s saw that!" % p.data["name"], UI.BAD)
