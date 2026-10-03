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


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await idle(5)
	var gs := GameState
	check(main.hub.visible and main.raid_over, "starts in the hideout")

	# Hub shopping.
	gs.cash = 2000
	main.hub_buy_junk()
	main.hub_buy_sticker()
	check(gs.junk == 20 and gs.stickers == 1, "buy supplies")
	main.hub_buy_fist("brass")
	check(gs.fists_owned["brass"] and gs.fist_id == "brass", "buy + equip brass knuckles")
	gs.buy_upgrade("tongue")
	gs.buy_upgrade("protein")
	check(gs.upgrades["tongue"] == 1 and gs.upgrades["protein"] == 1, "buy upgrades")

	# Every level builds and starts.
	for id in gs.LOCATIONS:
		main.start_raid(id)
		await frames(10)
		check(not main.raid_over and main.level != null, "raid starts: " + id)
		check(get_tree().get_nodes_in_group("kids").size() == gs.LOCATIONS[id]["kids"], "kids spawned: " + id)
		check(main.extracts.size() == main.ACTIVE_EXTRACTS, "extracts active: " + id)
		check(main.player.is_on_floor() or main.player.global_position.y > -1.0, "player didn't fall through: " + id)
		main._end_raid(false, "test abort")
		await idle(2)
	check(main.hub.visible, "back to hub after raid")

	# A real raid at the locals.
	gs.junk = 10
	gs.stickers = 3
	main.start_raid("locals")
	await frames(10)
	for tactic in ["junk", "sticker", "ufo"]:
		var kid = _tradeable_kid()
		main.interact(kid)
		check(main.hud.trade_panel.visible, "trade menu opens (%s)" % tactic)
		main.do_trade(kid, tactic)
		check(not main.hud.trade_panel.visible, "trade menu closes (%s)" % tactic)
	await frames(5)
	check(get_tree().get_nodes_in_group("parents").size() >= 1, "crying kid summons a parent")

	# Punch a parent standing right in front of us.
	var p = get_tree().get_nodes_in_group("parents")[0]
	var fwd: Vector3 = -main.player.global_transform.basis.z
	p.global_position = main.player.global_position + fwd * 1.5
	await frames(1)
	var hp_before: float = p.hp
	main.player.punch_cd = 0.0
	main.player.try_punch()
	check(p.hp < hp_before and p.stun_timer > 0.0, "punch damages + stuns parent")
	# Behind us: should not be hit.
	p.global_position = main.player.global_position - fwd * 1.5
	await frames(1)
	hp_before = p.hp
	main.player.punch_cd = 0.0
	main.player.try_punch()
	check(p.hp == hp_before, "punch misses parent behind you")
	p.take_damage(9999.0)
	check(p.dead, "parent knocked out")

	# Blocking reduces damage.
	main.player.hurt_cd = 0.0
	var h0 := gs.health
	main.player.blocking = true
	main.player.take_damage(20.0)
	var blocked := h0 - gs.health
	main.player.blocking = false
	main.player.hurt_cd = 0.0
	h0 = gs.health
	main.player.take_damage(20.0)
	check(blocked < h0 - gs.health and blocked > 0.0, "block reduces damage")

	# Extract.
	var carried: int = gs.binder.size()
	check(carried >= 1, "binder has cards")
	for par in get_tree().get_nodes_in_group("parents"):
		par.take_damage(9999.0)
	gs.heat = 0.0
	main.player.global_position = main.extracts[0]["pos"] + Vector3(0, 0.2, 0)
	for i in 150:
		await get_tree().create_timer(0.1).timeout
		if main.raid_over:
			break
	check(main.raid_over and gs.stash.size() == carried and gs.binder.is_empty(), "extraction moves binder to stash")
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
	check(main.raid_over and gs.binder.is_empty() and gs.stash.is_empty() and gs.junk == 0, "death loses binder + supplies")

	# Timer running out loses too.
	main.start_raid("playground")
	await frames(3)
	gs.raid_time_left = 0.01
	await idle(3)
	check(main.raid_over, "raid timer runs out")

	# PTA raid at max heat.
	main.start_raid("playground")
	await frames(3)
	gs.heat = 100.0
	await idle(3)
	check(get_tree().get_nodes_in_group("parents").size() >= 4, "PTA raid at max heat")
	main._end_raid(false, "test")
	await idle(2)

	gs.cash = gs.WIN_COST
	main.hub_win()
	check(gs.won, "win")

	await idle(30)
	print("\nSMOKE TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


func _tradeable_kid() -> Node:
	for k in get_tree().get_nodes_in_group("kids"):
		if k.can_trade():
			return k
	return null
