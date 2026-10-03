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
	var guard = get_tree().get_nodes_in_group("parents")[0]
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

	# Movement: slide boost, bunny hop keeps speed, air strafing gains speed.
	pl.global_position = Vector3(0, 0.1, 12)
	pl.rotation.y = 0.0
	pl.velocity = Vector3.ZERO
	await frames(10)
	pl.velocity = Vector3(0, 0, -8.0)
	await frames(1)
	Input.action_press("crouch")
	await frames(2)
	check(pl.sliding and pl.hspeed() > 9.0, "crouch at speed = slide with boost")
	Input.action_release("crouch")
	await frames(20)
	pl.velocity = Vector3(0, 0, -9.0)
	Input.action_press("jump")
	for i in 70:
		pl.velocity.x = 0.0
		await frames(1)
	var hop_speed: float = pl.hspeed()
	Input.action_release("jump")
	check(hop_speed > 7.5, "bunny hopping keeps your speed (%.1f m/s)" % hop_speed)
	pl.velocity = Vector3(8.0, 0, 0)
	var before: float = pl.hspeed()
	for i in 30:
		pl._air_accelerate(Vector3(0, 0, -1).rotated(Vector3.UP, i * 0.02), pl.RUN_SPEED, 1.0 / 60.0)
	check(pl.hspeed() > before, "air strafing gains speed")
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
	var carried: int = gs.binder.size()
	check(carried >= 1, "binder has cards")
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
