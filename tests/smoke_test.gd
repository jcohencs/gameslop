extends Node
## Headless smoke test: godot --headless --path . res://tests/smoke.tscn

var main: Node
var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		failures += 1
		printerr("FAIL  ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await idle(5)
	var gs := GameState
	check(main.hub.visible and main.hub.title_view.visible and main.raid_over, "starts on the title screen")
	main.hub._new_game()
	await idle(2)
	check(main.hub.hub_view.visible, "new game opens the hideout")

	# Hideout shopping.
	gs.cash = 3000
	main.hub_buy_junk()
	main.hub_buy_sticker()
	check(gs.junk == 20 and gs.stickers == 1, "buy supplies")
	main.hub_buy_weapon("brass")
	check(gs.weapons_owned["brass"] and gs.weapon_id == "brass", "buy + equip brass knuckles")
	main.hub_buy_weapon("katana")
	check(gs.weapons_owned["katana"] and gs.weapon_id == "katana", "buy + equip katana")
	main.hub_upgrade("tongue")
	main.hub_upgrade("cardio")
	check(gs.upgrades["tongue"] == 1 and gs.max_stamina() == 125.0, "buy upgrades")
	await idle(3)

	# Save / load round trip.
	gs.save_game()
	var saved_cash := gs.cash
	gs.cash = 1
	gs.load_game()
	check(gs.cash == saved_cash and gs.weapons_owned["katana"], "save/load round trip")

	# Every level builds, has a navmesh and starts.
	for id in gs.LOCATIONS:
		main.start_raid(id)
		await frames(10)
		check(not main.raid_over and main.level != null, "raid starts: " + id)
		check(get_tree().get_nodes_in_group("kids").size() == gs.LOCATIONS[id]["kids"], "kids spawned: " + id)
		check(main.extracts.size() == main.ACTIVE_EXTRACTS, "extracts active: " + id)
		var guards := get_tree().get_nodes_in_group("parents").filter(func(p): return p.is_guard())
		check(guards.size() == 1, "guard patrols: " + id)
		var map: RID = main.level.get_world_3d().navigation_map
		var path := NavigationServer3D.map_get_path(map, main.layout["spawn"], main.layout["pois"][0], true)
		check(path.size() >= 2, "navmesh path exists: " + id)
		main._end_raid(false, "test abort")
		await idle(2)
	check(main.hub.visible, "back to hub after raid")

	# A real raid at the locals.
	gs.junk = 10
	gs.stickers = 3
	main.start_raid("locals")
	await frames(10)
	var guard = get_tree().get_nodes_in_group("parents").filter(func(p): return p.is_guard())[0]
	# Put the guard far away so he doesn't see this first scam.
	guard.global_position = Vector3(-20, 0.1, -20)
	for tactic in ["junk", "sticker", "ufo"]:
		var kid = _tradeable_kid()
		main.interact(kid)
		check(main.hud.trade_panel.visible and get_tree().paused, "trade menu opens + pauses (%s)" % tactic)
		main.do_trade(kid, tactic)
		check(not main.hud.trade_panel.visible and not get_tree().paused, "trade menu closes (%s)" % tactic)
	await frames(5)
	var hunters := get_tree().get_nodes_in_group("parents").filter(func(p): return not p.is_guard())
	check(hunters.size() >= 1, "crying kid summons a parent")

	# Witnesses: kids near a scam become wary.
	var victim = _tradeable_kid()
	var bystander = null
	for k in get_tree().get_nodes_in_group("kids"):
		if k != victim and k.can_trade():
			bystander = k
			break
	bystander.global_position = victim.global_position + Vector3(2, 0, 0)
	main.do_trade(victim, "ufo")
	check(bystander.wary > 0.0, "nearby kid witnesses the scam and gets wary")

	# Guard catches a scam in plain sight.
	var victim2 = _tradeable_kid()
	if victim2 == null:
		main.spawn_kid()
		await frames(2)
		victim2 = _tradeable_kid()
	guard.global_position = main.player.global_position + Vector3(0, 0, -6)
	guard.look_at(main.player.global_position, Vector3.UP)
	guard.rotation.x = 0
	await frames(2)
	var heat_before := gs.heat
	main.do_trade(victim2, "ufo")
	check(guard.awareness() >= 1 and gs.heat > heat_before, "guard witnesses scam and gives chase")

	# AI perception: a parent investigating notices the player in front of them.
	var dad = main.spawn_parent("dad")
	await frames(1)
	dad.global_position = main.player.global_position + Vector3(0, 0, -8)
	dad.begin_investigate(dad.global_position + Vector3(0, 0, 10))
	dad.look_at(main.player.global_position, Vector3.UP)
	dad.rotation.x = 0
	for i in 20:
		await frames(1)
		if dad.awareness() == 2:
			break
	check(dad.awareness() == 2, "parent spots the player (vision + LOS)")

	# Attack tokens: never more than the allowed number swing at once.
	await frames(60)
	check(main.attackers.size() <= main.max_attackers(), "attack tokens limit simultaneous attackers")

	# Clear the field for combat tests.
	for p in get_tree().get_nodes_in_group("parents"):
		p.take_damage(99999.0)
	await frames(2)
	var target = main.spawn_parent("pta")
	await frames(1)
	var fwd: Vector3 = -main.player.global_transform.basis.z
	target.global_position = main.player.global_position + fwd * 1.8
	target.begin_chase(main.player.global_position)
	await frames(1)

	# Light combo with the katana.
	var hp0: float = target.hp
	main.player.attack_cd = 0.0
	main.player._start_attack(false)
	await wait(0.3)
	check(target.hp < hp0, "katana slash damages parent")
	check(main.player.combo == 1, "combo advances")
	target.global_position = main.player.global_position + fwd * 1.8
	hp0 = target.hp
	main.player.attack_cd = 0.0
	main.player._start_attack(true)
	await wait(0.35)
	check(target.hp < hp0 and target.stun_timer > 0.0, "heavy attack damages + staggers")

	# Behind the player: not hit.
	target.global_position = main.player.global_position - fwd * 1.8
	await frames(1)
	hp0 = target.hp
	main.player.attack_cd = 0.0
	main.player._start_attack(false)
	await wait(0.3)
	check(target.hp == hp0, "attack misses parent behind you")

	# Fists swap + punch.
	gs.equip_weapon("brass")
	await frames(2)
	check(main.player.viewmodel.kind == "fist", "viewmodel swaps to fists")
	target.global_position = main.player.global_position + fwd * 1.5
	await frames(1)
	hp0 = target.hp
	main.player.attack_cd = 0.0
	main.player._start_attack(false)
	await wait(0.25)
	check(target.hp < hp0, "punch damages parent")

	# Blocking, parrying, guard break.
	main.player.hurt_cd = 0.0
	main.player.blocking = true
	main.player.block_time = -10.0
	var h0 := gs.health
	var r: String = main.player.take_damage(20.0, Vector3.FORWARD, target)
	var blocked := h0 - gs.health
	check(r == "blocked" and blocked > 0.0 and blocked < 20.0, "block reduces damage")
	main.player.hurt_cd = 0.0
	main.player.block_time = main.player._time
	h0 = gs.health
	r = main.player.take_damage(20.0, Vector3.FORWARD, target)
	check(r == "parry" and gs.health == h0 and target.stun_timer > 1.0, "parry negates damage + stuns attacker")
	main.player.blocking = false

	target.take_damage(99999.0)
	check(target.state == target.State.KO, "parent knocked out")

	# Charge attack through the real input path: hold LMB, release when full.
	target = main.spawn_parent("coach")
	await frames(1)
	target.begin_chase(main.player.global_position)
	gs.stamina = gs.max_stamina()
	await wait(0.6)
	hp0 = target.hp
	var pl = main.player
	pl.attack_cd = 0.0
	Input.action_press("attack")
	for i in 50:
		target.global_position = main.player.global_position + fwd * 1.5
		await frames(1)
	check(pl.charge >= pl.CHARGE_FULL, "holding attack charges a heavy")
	Input.action_release("attack")
	await frames(1)
	check(gs.stamina < gs.max_stamina() - 20.0, "heavy spends stamina")
	await wait(0.35)
	check(target.hp < hp0, "released charge lands a heavy hit")
	# A quick tap is a light attack and costs no stamina.
	await wait(0.6)
	gs.stamina = gs.max_stamina()
	pl.attack_cd = 0.0
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(2)
	check(pl.attack_cd > 0.0 and gs.stamina == gs.max_stamina(), "tap = free light attack")

	# Pocket sand blinds parents in front.
	await wait(0.6)
	gs.weapons_owned["sand"] = true
	gs.sand = 2
	pl.attack_cd = 0.0
	target.stun_timer = 0.0
	target.global_position = main.player.global_position + fwd * 3.0
	target.begin_chase(main.player.global_position)
	await frames(1)
	pl.throw_sand()
	check(gs.sand == 1 and target.state == target.State.BLINDED, "pocket sand blinds the parent")
	check(target.awareness() < 2, "blinded parent can't see you")
	target.take_damage(99999.0)

	# Movement retune (specs/001-movement-retune): run/sprint speeds, sprint-bhop,
	# speed cap, small rate-limited slide boost, gentle air strafing, free stamina.
	# Open strip of the parking lot (z = 18, x from -18 toward +x), away from kids and cars.
	for par in get_tree().get_nodes_in_group("parents"):
		par.take_damage(99999.0)
	var lane := Vector3(-18, 0.1, 18.5)
	pl.global_position = lane
	pl.rotation.y = -PI / 2  # face +X
	pl.velocity = Vector3.ZERO
	await frames(10)
	gs.stamina = gs.max_stamina()
	var stamina_before := gs.stamina
	Input.action_press("move_forward")
	await frames(60)
	var run_v: float = pl.hspeed()
	check(run_v >= 4.5 and run_v <= 5.5, "sustained run speed 4.5-5.5 m/s (%.2f)" % run_v)
	Input.action_press("sprint")
	await frames(60)
	var sprint_v: float = pl.hspeed()
	check(sprint_v >= 6.3 and sprint_v <= 7.3, "sustained sprint speed 6.3-7.3 m/s (%.2f)" % sprint_v)
	pl.global_position = lane
	Input.action_press("jump")
	var min_hop := 99.0
	for i in 180:
		await frames(1)
		pl.velocity.z = 0.0
		min_hop = minf(min_hop, pl.hspeed())
	Input.action_release("jump")
	check(min_hop >= 6.5, "sprint + bhop keeps >= 6.5 m/s for 3 s (min %.2f)" % min_hop)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await frames(30)
	# Sprint-hopping from a standstill reaches sprint speed quickly.
	pl.global_position = lane
	pl.velocity = Vector3.ZERO
	await frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	Input.action_press("jump")
	await frames(90)
	var hop_start_v: float = pl.hspeed()
	Input.action_release("jump")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(hop_start_v >= 6.3 and hop_start_v <= 7.3, "Shift + Space from standstill sprint-hops at sprint speed (%.2f)" % hop_start_v)
	for i in 120:  # let them land and the slide-boost cooldown expire
		await frames(1)
		if pl.is_on_floor() and i > 70:
			break
	# Slide boost is small and rate-limited.
	pl.global_position = lane
	pl.velocity = Vector3(6.8, 0, 0)
	await frames(1)
	var pre_slide: float = pl.hspeed()
	Input.action_press("crouch")
	await frames(2)
	var boost: float = pl.hspeed() - pre_slide
	check(pl.sliding and boost > 0.5 and boost <= 2.5, "slide from sprint adds a small boost (+%.2f m/s)" % boost)
	Input.action_release("crouch")
	await frames(3)
	pl.velocity = Vector3(6.8, 0, 0)
	await frames(1)
	pre_slide = pl.hspeed()
	Input.action_press("crouch")
	await frames(2)
	check(pl.hspeed() <= pre_slide + 0.05, "second slide within 1 s adds no boost")
	Input.action_release("crouch")
	await frames(20)
	check(gs.stamina == stamina_before, "movement never spends stamina")
	# Hard cap.
	pl.velocity = Vector3(40, 0, 0)
	pl._clamp_speed()
	check(pl.hspeed() <= 12.0 + 0.001, "speed is capped at 12 m/s")
	# Air strafing still gains speed, but gently, and never past the cap.
	pl.velocity = Vector3(6.8, 0, 0)
	var before: float = pl.hspeed()
	for i in 30:
		pl._air_accelerate(Vector3(0, 0, -1).rotated(Vector3.UP, i * 0.02), pl.sprint_speed, 1.0 / 60.0)
	var gain: float = pl.hspeed() - before
	check(gain > 0.0 and gain < 1.0, "air strafing gains speed gradually (+%.2f over 30 frames)" % gain)
	for i in 2000:
		pl._air_accelerate(Vector3(0, 0, -1).rotated(Vector3.UP, i * 0.02), pl.sprint_speed, 1.0 / 60.0)
		pl._clamp_speed()
	check(pl.hspeed() <= 12.0 + 0.001, "air strafing stays under the cap")
	pl.velocity = Vector3.ZERO

	# Pause menu.
	main._set_menu_mode(true)
	main.hud.show_pause()
	check(get_tree().paused and main.hud.pause_panel.visible, "pause menu")
	main.resume()
	check(not get_tree().paused, "resume")

	# Extract.
	for par in get_tree().get_nodes_in_group("parents"):
		par.take_damage(99999.0)
	gs.heat = 0.0
	# Trades are chance-based; make sure the extract test carries at least one card.
	if gs.binder.is_empty():
		var spare = _tradeable_kid()
		if spare == null:
			spare = main.spawn_kid()
			await frames(2)
		gs.add_to_binder(spare.card)
	var carried: int = gs.binder.size()
	check(carried >= 1, "binder has cards (%d)" % carried)
	main.player.global_position = main.extracts[0]["pos"] + Vector3(0, 0.2, 0)
	for i in 150:
		await wait(0.1)
		if main.raid_over:
			break
	check(main.raid_over and gs.stash.size() == carried and gs.binder.is_empty(), "extraction moves binder to stash")
	await idle(2)
	var cash := gs.cash
	var value := gs.cards_value(gs.stash)
	main.hub_sell()
	check(gs.cash == cash + value and gs.stash.is_empty(), "sell stash")

	# Death loses the binder.
	main.start_raid("playground")
	await frames(5)
	gs.binder.append(gs.roll_card())
	main.player.hurt_cd = 0.0
	main.player.take_damage(99999.0)
	await idle(2)
	check(main.raid_over and gs.binder.is_empty() and gs.junk == 0, "knockout loses binder + supplies")

	# Timer running out / abandoning.
	main.start_raid("playground")
	await frames(3)
	gs.raid_time_left = 0.01
	await idle(3)
	check(main.raid_over, "raid timer runs out")
	main.start_raid("playground")
	await frames(3)
	main.abandon_raid()
	check(main.raid_over, "abandon raid")

	# PTA raid at max heat.
	main.start_raid("playground")
	await frames(3)
	gs.heat = 100.0
	await idle(3)
	check(get_tree().get_nodes_in_group("parents").size() >= 5, "PTA raid at max heat")
	main._end_raid(false, "test")
	await idle(2)

	# --- Content expansion 1 (specs/002-content-expansion-1) ---
	gs.cash = 5000
	# Collector orders (SC-001, SC-002).
	check(gs.orders.size() == 3, "hideout has 3 collector orders")
	gs.stash.clear()
	gs.orders[0] = {"kind": "rarity", "rarity": 3, "count": 2, "card_name": "", "reward": 100, "title": "t", "filled": false}
	check(gs.fulfill_order(0) == 0, "unfillable order pays nothing")
	var holo := {"name": "Charzard", "rarity": 3, "value": 150, "art": 1}
	var lego := {"name": "Mewthree", "rarity": 4, "value": 500, "art": 2}
	var common := {"name": "Squirtel", "rarity": 0, "value": 3, "art": 3}
	gs.stash = [lego, common, holo]
	var removed_value := gs.card_sell_value(holo) + gs.card_sell_value(lego)
	var cash0 := gs.cash
	var pay := gs.fulfill_order(0)
	check(pay >= removed_value * 1.5 and gs.cash == cash0 + pay, "order pays >= 1.5x the cards' value ($%d for $%d)" % [pay, removed_value])
	check(gs.stash.size() == 1 and gs.stash[0]["name"] == "Squirtel" and gs.orders[0]["filled"], "order removes the qualifying cards")
	var orders_before := str(gs.orders)
	main.start_raid("playground")
	await frames(3)
	main.abandon_raid()
	await idle(2)
	check(str(gs.orders) != orders_before, "orders reroll after a raid")
	orders_before = str(gs.orders)
	main.start_raid("playground")
	await frames(3)
	main.player.hurt_cd = 0.0
	main.player.take_damage(99999.0)
	await idle(2)
	check(str(gs.orders) != orders_before, "orders reroll after a knockout")
	gs.save_game()
	var saved_orders: Array = gs.orders.duplicate(true)
	gs.orders = []
	gs.load_game()
	check(gs.orders == saved_orders, "orders survive save/load")
	gs.cash = 5000

	# Whale + raid modifier every raid (SC-003).
	var whale_ok := true
	var mods_seen := {}
	for i in 10:
		main.start_raid(["playground", "locals", "pizza", "mall"][i % 4])
		await frames(3)
		var whales := get_tree().get_nodes_in_group("kids").filter(func(k): return k.whale)
		var chaperones := get_tree().get_nodes_in_group("parents").filter(func(p): return p.whale_kid != null)
		if whales.size() != 1 or whales[0].card["rarity"] != 4 or chaperones.size() != 1 or gs.raid_modifier == "":
			whale_ok = false
		mods_seen[gs.raid_modifier] = true
		main._end_raid(false, "test")
		await idle(2)
		gs.cash = 5000
	check(whale_ok, "10 raids: exactly 1 whale (Legendary) + chaperone + 1 modifier each")
	check(gs.raid_modifier == "", "modifier clears after the raid")
	gs.raid_modifier = "bake_sale"
	var bake: float = gs.mod("sight", 1.0)
	gs.raid_modifier = "report_card"
	var report: float = gs.mod("heat_decay", 1.0)
	gs.raid_modifier = "free_refills"
	var refills: float = gs.mod("kid_respawn", 1.0)
	gs.raid_modifier = "holo_hype"
	var hype: float = gs.mod("rarity_bonus", 0.0)
	check(bake == 0.7 and report == 0.5 and refills == 0.5 and hype == 1.0 and gs.mod("sight", 1.0) == 1.0, "modifier effects are wired")
	gs.raid_modifier = ""

	# New scam tactics (SC-006).
	main.start_raid("locals")
	await frames(10)
	for par in get_tree().get_nodes_in_group("parents"):
		par.global_position = Vector3(-20, 0.1, -20)
	var tk = _tradeable_kid()
	check(main._tactics_for(tk).size() == 5, "trade screen offers 5 tactics")
	var parents_before := get_tree().get_nodes_in_group("parents").size()
	var sob_heat := gs.heat
	for i in 20:
		var k = _tradeable_kid()
		if k == null:
			main.spawn_kid()
			await frames(2)
			k = _tradeable_kid()
		k.wary = 0.0
		gs.binder.clear()
		main.do_trade(k, "sob")
	await frames(3)
	check(gs.heat <= sob_heat + 0.001, "Sob Story never adds heat")
	check(get_tree().get_nodes_in_group("parents").size() == parents_before, "Sob Story never makes a kid cry (no parents summoned)")
	gs.junk = 2
	tk = _tradeable_kid()
	if tk == null:
		main.spawn_kid()
		await frames(2)
		tk = _tradeable_kid()
	var bundle: Dictionary = main._tactics_for(tk).filter(func(t): return t["id"] == "bundle")[0]
	check(not bundle["available"], "Bundle Deal unavailable with 2 junk")
	gs.junk = 5
	gs.binder.clear()
	main.do_trade(tk, "bundle")
	check(gs.junk == 2, "Bundle Deal spends 3 junk")
	main._end_raid(false, "test")
	await idle(2)
	gs.cash = 5000

	# Pizza Party Palace ball pit (SC-004, SC-005).
	main.start_raid("pizza")
	await frames(10)
	var guards2 := get_tree().get_nodes_in_group("parents").filter(func(p): return p.is_guard())
	check(guards2.size() == 1 and guards2[0].kind == "cheesy", "Cheesy the Rat guards the pizza place")
	# Patrolling guards ignore a player who hasn't done anything (low heat)...
	var cheesy = guards2[0]
	gs.heat = 0.0
	cheesy.global_position = main.player.global_position + Vector3(0, 0, -5)
	cheesy.look_at(main.player.global_position, Vector3.UP)
	cheesy.rotation.x = 0
	cheesy.begin_patrol([cheesy.global_position])
	await frames(20)
	check(cheesy.awareness() == 0, "patrolling guard ignores a clean player")
	# ...but react once heat is up.
	gs.heat = 40.0
	cheesy.look_at(main.player.global_position, Vector3.UP)
	cheesy.rotation.x = 0
	await frames(20)
	check(cheesy.awareness() >= 1, "patrolling guard reacts when heat is up")
	gs.heat = 0.0
	cheesy.begin_patrol([Vector3(15, 0, 15)])
	cheesy.global_position = Vector3(15, 0.1, 15)
	var pit: AABB = main.layout["ball_pits"][0]
	var pit_center := Vector3(pit.get_center().x, 0.1, pit.get_center().z)
	main.player.global_position = pit_center
	await frames(2)
	await idle(2)
	main.player.velocity = Vector3(9, 0, 0)
	await frames(2)
	check(main.player.in_ball_pit and main.player.hspeed() <= 2.5 + 0.01, "ball pit caps speed at 2.5 m/s (%.2f)" % main.player.hspeed())
	main.player.velocity = Vector3.ZERO
	var watcher = main.spawn_parent("dad")
	await frames(1)
	watcher.global_position = pit_center + Vector3(0, 0, -4)
	watcher.look_at(pit_center, Vector3.UP)
	watcher.rotation.x = 0
	watcher.begin_chase(pit_center)
	check(not watcher._can_see_player(), "adult 4 m away can't see you in the ball pit")
	watcher.global_position = pit_center + Vector3(0, 0, -1.5)
	check(watcher._can_see_player(), "adult 1.5 m away still sees you in the ball pit")

	# Nana (SC-007).
	gs.heat = 0.0
	var nana_low := false
	for i in 30:
		if main._parent_type_for_heat() == "nana":
			nana_low = true
	gs.heat = 100.0
	var nana_high := false
	for i in 60:
		if main._parent_type_for_heat() == "nana":
			nana_high = true
	check(not nana_low and nana_high, "Nana only shows up at 3+ stars")
	var nana = main.spawn_parent("nana")
	await frames(1)
	check(nana.reach > 2.5 and nana.windup_time >= 0.75 and nana.data["hp"] > main.ParentScript.TYPES["pta"]["hp"], "Nana: long reach, long wind-up, tanky")
	main._end_raid(false, "test")
	await idle(2)

	# --- Graphics overhaul (specs/003-graphics-overhaul) ---
	gs.cash = 5000
	gs.graphics_quality = "high"
	# Textures (SC-003).
	var tex_ok := true
	for tn in Art.TEXTURES:
		var t: ImageTexture = Art.tex(tn)
		if t == null or t.get_width() != Art.TEX_SIZE or Art.tex(tn) != t:
			tex_ok = false
	check(Art.TEXTURES.size() >= 7 and tex_ok, "7 procedural textures generated + cached")
	# Moods distinct (SC-002).
	var mood_keys := {}
	for id in gs.LOCATIONS:
		var m: Dictionary = Art.MOODS[id]
		mood_keys[str(m["sun_color"]) + str(m["sky_top"])] = true
	check(mood_keys.size() == gs.LOCATIONS.size(), "every location has a distinct lighting mood")
	# Per-location: mood applied, >= 2 textures, clouds; High: outlines + shadows.
	var outline_ok := true
	var tex_count_ok := true
	var clouds_ok := true
	var looks := {}
	var mood_ok := true
	for id in gs.LOCATIONS:
		main.start_raid(id)
		await frames(3)
		mood_ok = mood_ok and main.sun.light_color == Art.MOODS[id]["sun_color"] and main.sun.shadow_enabled
		var used := {}
		for mi in main.level.find_children("*", "MeshInstance3D", true, false):
			var mat = mi.material_override
			if mat is StandardMaterial3D and mat.albedo_texture != null:
				used[mat.albedo_texture.get_rid()] = true
		tex_count_ok = tex_count_ok and used.size() >= 2
		clouds_ok = clouds_ok and main.level.find_child("Clouds", true, false) != null
		for k in get_tree().get_nodes_in_group("kids"):
			looks[k.rig.look] = true
		for c in get_tree().get_nodes_in_group("kids") + get_tree().get_nodes_in_group("parents"):
			var parts: Array = c.rig.find_children("*", "MeshInstance3D", true, false)
			if parts.filter(func(mi): return mi.material_overlay != null).size() < 10:
				outline_ok = false
		main._end_raid(false, "test")
		await idle(2)
		gs.cash = 5000
	check(mood_ok, "each raid applies its mood (sun color, shadows on High)")
	check(tex_count_ok, "each location uses >= 2 procedural textures")
	check(clouds_ok, "every location has clouds")
	check(outline_ok, "High: all characters have ink outlines")
	check(main.sun.light_color == Art.MOODS["default"]["sun_color"], "hideout returns to the default mood")

	# Playground grass at High, then Low quality profile (SC-005).
	main.start_raid("playground")
	await frames(3)
	var grass_high: int = main.level.find_child("Grass", true, false).multimesh.instance_count
	check(grass_high == Art.QUALITY["high"]["grass"], "High grass density (%d tufts)" % grass_high)
	# Expressions (SC-004) + effects (SC-006).
	for par in get_tree().get_nodes_in_group("parents"):
		par.global_position = Vector3(-25, 0.1, -25)
	var angry = main.spawn_parent("dad")
	await frames(1)
	angry.global_position = main.player.global_position + (-main.player.global_transform.basis.z) * 5.0
	angry.look_at(main.player.global_position, Vector3.UP)
	angry.rotation.x = 0
	angry.begin_chase(main.player.global_position)
	await wait(0.5)
	check(angry.rig.mood == "angry", "alerted adult turns angry within 0.5 s")
	angry.take_damage(1.0, Vector3.FORWARD, 2.0, 1.5)
	check(angry.dizzy != null and is_instance_valid(angry.dizzy), "stunned adult gets dizzy stars")
	angry.take_damage(99999.0)
	check(angry.dizzy != null, "KO'd adult keeps dizzy stars")
	var sad_kid = _tradeable_kid()
	sad_kid.cry()
	check(sad_kid.rig.mood == "sad" and sad_kid.tears != null and sad_kid.tears.emitting, "crying kid is sad with tears")
	check(looks.size() >= 4, "kids show varied hair/looks (%d across 41 kids)" % looks.size())
	var whale = get_tree().get_nodes_in_group("kids").filter(func(k): return k.whale)[0]
	check(whale.find_child("Sparkles", true, false) != null, "whale has gold sparkles")
	var sparks_before: int = main.level.find_children("Spark", "CPUParticles3D", true, false).size()
	main.spawn_hit_spark(main.player.global_position + Vector3(0, 1, -1))
	check(main.level.find_children("Spark", "CPUParticles3D", true, false).size() > sparks_before, "hit spawns a spark burst")
	var ex_node: Node3D = main.extracts[0]["label"].get_parent()
	check(ex_node.has_meta("pulse") and (ex_node.get_meta("pulse") as Tween).is_running(), "extract beams pulse")
	main._end_raid(false, "test")
	await idle(2)
	gs.cash = 5000
	main.start_raid("locals")
	await frames(3)
	var dust := main.level.find_child("DustMotes", true, false) as CPUParticles3D
	var dust_high: int = dust.amount if dust else 0
	check(dust != null, "indoor location has dust motes")
	main._end_raid(false, "test")
	await idle(2)

	# Low quality.
	gs.graphics_quality = "low"
	gs.save_settings()
	gs.graphics_quality = "high"
	gs.load_settings()
	check(gs.graphics_quality == "low", "graphics quality persists in settings")
	gs.cash = 5000
	main.start_raid("locals")
	await frames(3)
	var dust_low: int = (main.level.find_child("DustMotes", true, false) as CPUParticles3D).amount
	var any_outline := false
	for c in get_tree().get_nodes_in_group("kids") + get_tree().get_nodes_in_group("parents"):
		for mi in c.rig.find_children("*", "MeshInstance3D", true, false):
			if mi.material_overlay != null:
				any_outline = true
	check(not any_outline and not main.sun.shadow_enabled, "Low: no outlines, no shadows")
	check(dust_low <= dust_high * 0.5, "Low: particles cut by at least half (%d vs %d)" % [dust_low, dust_high])
	main._end_raid(false, "test")
	await idle(2)
	gs.cash = 5000
	main.start_raid("playground")
	await frames(3)
	var grass_low: int = main.level.find_child("Grass", true, false).multimesh.instance_count
	check(grass_low <= grass_high * 0.25, "Low: grass <= 25%% of High (%d vs %d)" % [grass_low, grass_high])
	main._end_raid(false, "test")
	await idle(2)
	gs.graphics_quality = "high"
	gs.save_settings()

	gs.cash = gs.WIN_COST
	main.hub_win()
	check(gs.won, "win")

	gs.delete_save()
	await idle(10)
	print("\nSMOKE TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


func _tradeable_kid() -> Node:
	for k in get_tree().get_nodes_in_group("kids"):
		if k.can_trade():
			return k
	return null
