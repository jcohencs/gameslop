extends Node3D
## Builds the playground, spawns everyone, and runs the scam/heat/fight loop.

const PlayerScript := preload("res://scripts/player.gd")
const KidScript := preload("res://scripts/kid.gd")
const ParentScript := preload("res://scripts/parent.gd")
const HudScript := preload("res://scripts/hud.gd")

const KID_COUNT := 9
const MAX_PARENTS := 14
const ARENA := 30.0
const VAN_POS := Vector3(22, 0, 22)
const SPAWN_POS := Vector3(18, 0.1, 18)

var player: CharacterBody3D
var hud: CanvasLayer
var game_over := false
var kid_respawn_timer := 0.0
var raid_cooldown := 0.0
var started := false


func _ready() -> void:
	add_to_group("main")
	randomize()
	GameState.reset()
	_build_environment()
	_build_playground()
	_build_van()

	player = PlayerScript.new()
	player.main = self
	player.position = SPAWN_POS
	add_child(player)
	player.rotation.y = PI * 0.25

	for i in KID_COUNT:
		spawn_kid()

	hud = HudScript.new()
	hud.main = self
	add_child(hud)
	_show_title()


# --- World -------------------------------------------------------------------

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
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_playground() -> void:
	# Ground.
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	add_child(ground)
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(120, 1, 120)
	gcs.shape = gshape
	gcs.position.y = -0.5
	ground.add_child(gcs)
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	grass.mesh = plane
	grass.material_override = Shapes.mat(Color(0.22, 0.45, 0.18))
	ground.add_child(grass)
	# Blacktop area for the court.
	Shapes.box(self, Vector3(18, 0.02, 12), Vector3(-14, 0.01, 12), Color(0.22, 0.22, 0.25))
	Shapes.box(self, Vector3(0.2, 0.03, 12), Vector3(-14, 0.02, 12), Color.WHITE)

	# Fence.
	var fence_col := Color(0.6, 0.6, 0.65)
	Shapes.solid_box(self, Vector3(ARENA * 2, 2.2, 0.3), Vector3(0, 1.1, -ARENA), fence_col)
	Shapes.solid_box(self, Vector3(ARENA * 2, 2.2, 0.3), Vector3(0, 1.1, ARENA), fence_col)
	Shapes.solid_box(self, Vector3(0.3, 2.2, ARENA * 2), Vector3(-ARENA, 1.1, 0), fence_col)
	Shapes.solid_box(self, Vector3(0.3, 2.2, ARENA * 2), Vector3(ARENA, 1.1, 0), fence_col)

	# School building.
	Shapes.solid_box(self, Vector3(30, 9, 8), Vector3(0, 4.5, -25.5), Color(0.75, 0.45, 0.35))
	Shapes.box(self, Vector3(3, 4, 0.2), Vector3(0, 2, -21.4), Color(0.35, 0.2, 0.12))
	for x in [-11, -6, 6, 11]:
		Shapes.box(self, Vector3(3, 2, 0.15), Vector3(x, 5.5, -21.45), Color(0.6, 0.85, 1.0))
	Shapes.label(self, "SPRINGFIELD-ISH ELEMENTARY", Vector3(0, 8, -21.3), Color(1, 1, 0.8), 160).billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Sandbox.
	Shapes.solid_box(self, Vector3(6, 0.4, 0.3), Vector3(8, 0.2, -6), Color(0.6, 0.4, 0.2))
	Shapes.solid_box(self, Vector3(6, 0.4, 0.3), Vector3(8, 0.2, 0), Color(0.6, 0.4, 0.2))
	Shapes.solid_box(self, Vector3(0.3, 0.4, 6), Vector3(5, 0.2, -3), Color(0.6, 0.4, 0.2))
	Shapes.solid_box(self, Vector3(0.3, 0.4, 6), Vector3(11, 0.2, -3), Color(0.6, 0.4, 0.2))
	Shapes.box(self, Vector3(5.7, 0.05, 5.7), Vector3(8, 0.03, -3), Color(0.93, 0.85, 0.6))

	# Slide: ladder tower + ramp.
	Shapes.solid_box(self, Vector3(2, 3, 2), Vector3(-8, 1.5, -8), Color(0.95, 0.75, 0.2))
	Shapes.solid_box(self, Vector3(1.4, 0.2, 5), Vector3(-8, 1.6, -4.0), Color(0.9, 0.2, 0.2)).rotation.x = deg_to_rad(-30)

	# Swing set.
	for x in [-1.5, 3.5]:
		Shapes.solid_cylinder(self, 0.1, 3, Vector3(x, 1.5, 8), Color(0.3, 0.4, 0.9))
	Shapes.box(self, Vector3(5.2, 0.15, 0.15), Vector3(1, 3, 8), Color(0.3, 0.4, 0.9))
	for x in [0, 2]:
		Shapes.box(self, Vector3(0.03, 2.2, 0.03), Vector3(x, 1.9, 8), Color(0.2, 0.2, 0.2))
		Shapes.box(self, Vector3(0.6, 0.06, 0.3), Vector3(x, 0.8, 8), Color(0.15, 0.15, 0.15))

	# Jungle gym.
	for x in [0, 2, 4]:
		for z in [0, 2]:
			Shapes.solid_cylinder(self, 0.08, 2.4, Vector3(-20 + x, 1.2, -8 + z), Color(0.2, 0.75, 0.3))
	Shapes.solid_box(self, Vector3(4.4, 0.15, 2.4), Vector3(-18, 2.4, -7), Color(0.2, 0.75, 0.3))

	# Benches, trees, trash cans for cover.
	for b in [Vector3(-4, 0.25, 18), Vector3(4, 0.25, 18), Vector3(18, 0.25, -4)]:
		Shapes.solid_box(self, Vector3(2.4, 0.5, 0.6), b, Color(0.55, 0.35, 0.2))
	for t in [Vector3(-24, 0, 20), Vector3(-22, 0, -14), Vector3(24, 0, -10), Vector3(14, 0, 8),
			Vector3(-6, 0, 24), Vector3(-26, 0, 2), Vector3(25, 0, 6)]:
		Shapes.solid_cylinder(self, 0.35, 3, t + Vector3(0, 1.5, 0), Color(0.45, 0.3, 0.15))
		Shapes.sphere(self, 2.0, t + Vector3(0, 4, 0), Color(0.2, 0.55, 0.2))
	for c in [Vector3(10, 0.5, 14), Vector3(-12, 0.5, 2), Vector3(20, 0.5, -18)]:
		Shapes.solid_cylinder(self, 0.4, 1.0, c, Color(0.3, 0.35, 0.3))


func _build_van() -> void:
	var van := Node3D.new()
	van.position = VAN_POS
	van.rotation.y = PI * 0.25
	van.add_to_group("shop")
	add_child(van)
	Shapes.solid_box(van, Vector3(2.4, 2.4, 5), Vector3(0, 1.5, 0), Color(0.92, 0.92, 0.88))
	Shapes.box(van, Vector3(2.42, 0.5, 5.02), Vector3(0, 1.4, 0), Color(0.6, 0.2, 0.7))
	Shapes.box(van, Vector3(2.0, 0.8, 0.05), Vector3(0, 2.1, -2.51), Color(0.3, 0.45, 0.6))
	for x in [-1.2, 1.2]:
		for z in [-1.6, 1.6]:
			var w := Shapes.cylinder(van, 0.4, 0.3, Vector3(x, 0.4, z), Color(0.1, 0.1, 0.1))
			w.rotation.z = PI / 2
	var sign_label := Shapes.label(van, "FREE CANDY*\n*card exchange", Vector3(1.25, 1.9, 0), Color(1, 0.9, 0.2), 90)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_label.rotation.y = PI / 2
	Shapes.label(van, "SHADY VAN\n[E] Shop", Vector3(0, 3.6, 0), Color(1, 0.85, 0.3), 56)


# --- Spawning ----------------------------------------------------------------

func spawn_kid() -> void:
	var kid := KidScript.new()
	kid.player = player
	var pos := Vector3.ZERO
	for attempt in 10:
		pos = Vector3(randf_range(-24, 24), 0.1, randf_range(-18, 24))
		if pos.distance_to(VAN_POS) > 8.0:
			break
	kid.position = pos
	kid.cried.connect(_on_kid_cried)
	add_child(kid)


func spawn_parent(type_id: String, reason := "") -> void:
	if get_tree().get_nodes_in_group("parents").size() >= MAX_PARENTS:
		return
	var p := ParentScript.new()
	p.setup(type_id)
	p.player = player
	p.main = self
	# Arrive from the school gates / edges, away from the player.
	var pos := Vector3.ZERO
	for attempt in 12:
		var side := randi() % 4
		var t := randf_range(-ARENA + 3, ARENA - 3)
		match side:
			0: pos = Vector3(t, 0.1, -20.0)
			1: pos = Vector3(t, 0.1, ARENA - 2)
			2: pos = Vector3(-ARENA + 2, 0.1, t)
			_: pos = Vector3(ARENA - 2, 0.1, t)
		if pos.distance_to(player.global_position) > 14.0:
			break
	p.position = pos
	add_child(p)
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


# --- Main loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not started or game_over:
		return
	var parents := get_tree().get_nodes_in_group("parents").size()
	GameState.heat = maxf(GameState.heat - delta * (0.4 if parents > 0 else 1.6), 0.0)

	raid_cooldown -= delta
	if GameState.heat >= 99.0 and raid_cooldown <= 0.0:
		raid_cooldown = 25.0
		GameState.say("!!! PTA RAID !!! The whole parent council is here!", Color(1, 0.2, 0.2))
		for i in 4 + int(GameState.knockouts / 10.0):
			spawn_parent(_parent_type_for_heat())
		GameState.heat = 70.0

	var kids := get_tree().get_nodes_in_group("kids").size()
	if kids < KID_COUNT:
		kid_respawn_timer -= delta
		if kid_respawn_timer <= 0.0:
			kid_respawn_timer = 4.0
			spawn_kid()

	# Interaction prompt.
	var t: Node = player.interact_target
	if hud.any_menu_open():
		hud.set_prompt("")
	elif t == null:
		hud.set_prompt("")
	elif t.is_in_group("shop"):
		hud.set_prompt("[E] Open the Shady Van shop")
	else:
		hud.set_prompt("[E] \"Hey kid, wanna trade?\"  (%s has a %s)" % [t.kid_name, GameState.rarity_name(t.card)])
	hud.refresh_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if hud.trade_panel.visible or hud.shop_panel.visible:
			close_menus()
		elif started and not game_over and not hud.overlay.visible:
			_set_menu_mode(true)
			hud.show_overlay("PAUSED\n\n" + _controls_text(), "Resume", _resume)


func _set_menu_mode(on: bool) -> void:
	player.input_locked = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	hud.crosshair.visible = not on


func _resume() -> void:
	hud.hide_overlay()
	_set_menu_mode(false)


func interact(target: Node) -> void:
	if hud.any_menu_open():
		return
	if target.is_in_group("shop"):
		_set_menu_mode(true)
		hud.open_shop()
	elif target.can_trade():
		_set_menu_mode(true)
		hud.open_trade(target, _tactics_for(target))


func close_menus() -> void:
	hud.close_all()
	if not hud.overlay.visible:
		_set_menu_mode(false)


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
		if gs.cards.size() >= gs.capacity():
			t["available"] = false
			t["cost_text"] = "BINDER FULL - go sell!"
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
		gs.add_card(card)
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


# --- Shop actions ------------------------------------------------------------

func shop_sell() -> void:
	var n := GameState.cards.size()
	var total := GameState.sell_all()
	GameState.say("Flipped %d cards for $%d. Capitalism!" % [n, total], Color(0.5, 1, 0.5))


func shop_buy_junk() -> void:
	if GameState.try_spend(GameState.JUNK_PACK_COST):
		GameState.junk += GameState.JUNK_PACK_SIZE
		GameState.changed.emit()


func shop_buy_sticker() -> void:
	if GameState.try_spend(GameState.STICKER_COST):
		GameState.stickers += 1
		GameState.changed.emit()


func shop_heal() -> void:
	var cost := ceili((GameState.max_health() - GameState.health) * 0.5)
	if cost > 0 and GameState.try_spend(cost):
		GameState.health = GameState.max_health()
		GameState.changed.emit()


func shop_upgrade(id: String) -> void:
	GameState.buy_upgrade(id)


func shop_weapon(id: String) -> void:
	if GameState.buy_weapon(id):
		player.equip(id)


func shop_win() -> void:
	if not GameState.try_spend(GameState.WIN_COST):
		return
	GameState.won = true
	hud.close_all()
	hud.show_overlay("YOU DID IT.\n\nYou opened \"Card Shark's Collectibles Emporium\" across the street from the school. " +
		"The kids still don't know.\n\nScams: %d\nParents knocked out: %d\nTimes grounded: %d\n\nKeep hustling?" % [
			GameState.scams, GameState.knockouts, GameState.deaths], "Keep playing", _resume)


# --- Death -------------------------------------------------------------------

func player_died() -> void:
	game_over = true
	var lost := GameState.on_death()
	for p in get_tree().get_nodes_in_group("parents"):
		p.queue_free()
	hud.close_all()
	_set_menu_mode(true)
	hud.show_overlay("GROUNDED!\n\nThe parents caught you and confiscated your stuff.\nLost $%d and %d cards." % [lost["cash"], lost["cards"]],
		"Respawn at the van", _respawn)


func _respawn() -> void:
	game_over = false
	player.global_position = SPAWN_POS
	player.velocity = Vector3.ZERO
	hud.hide_overlay()
	_set_menu_mode(false)


func flash_damage() -> void:
	hud.flash_damage()


# --- Title -------------------------------------------------------------------

func _controls_text() -> String:
	return "WASD move  |  Shift sprint  |  Space jump  |  Mouse aim\nLeft click shoot  |  R reload  |  1-4 switch guns\nE trade with kids / open van shop  |  Esc pause"


func _show_title() -> void:
	_set_menu_mode(true)
	hud.show_overlay("CARD SHARK: PLAYGROUND HUSTLE\n\n" +
		"Walk up to kids and \"trade\" them out of their best cards. Sell the loot at the Shady Van, " +
		"buy upgrades and guns. Every crying kid sends a parent after you, and at max heat the PTA raids.\n\n" +
		"Earn $%d to buy your own Card Shop Empire.\n\n" % GameState.WIN_COST + _controls_text(),
		"Start hustling", _start)


func _start() -> void:
	started = true
	_resume()


# --- Effects -----------------------------------------------------------------

func spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mi.mesh = mesh
	var m := Shapes.mat(Color(1, 0.9, 0.4), 4.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_fade_and_free(mi, 0.06)


func spawn_muzzle_flash(at: Vector3) -> void:
	var s := Shapes.sphere(self, 0.12, Vector3.ZERO, Color(1, 0.8, 0.3))
	s.material_override = Shapes.mat(Color(1, 0.8, 0.3), 6.0)
	s.global_position = at
	_fade_and_free(s, 0.05)


func spawn_impact(at: Vector3) -> void:
	var s := Shapes.sphere(self, 0.08, Vector3.ZERO, Color(0.8, 0.7, 0.5))
	s.global_position = at
	_fade_and_free(s, 0.25)


func spawn_explosion(at: Vector3, radius: float) -> void:
	var s := Shapes.sphere(self, 1.0, Vector3.ZERO, Color(1, 0.5, 0.2))
	var m := Shapes.mat(Color(1, 0.5, 0.15), 5.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material_override = m
	s.global_position = at
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * radius, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.3)
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	add_child(light)
	light.global_position = at + Vector3.UP
	_fade_and_free(light, 0.3)


func _fade_and_free(n: Node, t: float) -> void:
	get_tree().create_timer(t).timeout.connect(n.queue_free)
