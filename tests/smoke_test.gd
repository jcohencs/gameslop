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


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(5)
	main._start()
	check(main.started and not main.player.input_locked, "game starts")
	await frames(30)
	check(get_tree().get_nodes_in_group("kids").size() == main.KID_COUNT, "kids spawned")

	# Scam every tactic.
	GameState.stickers = 3
	GameState.upgrades["tongue"] = 5
	for tactic in ["junk", "sticker", "ufo"]:
		var kid = _tradeable_kid()
		main.interact(kid)
		check(main.hud.trade_panel.visible, "trade menu opens (%s)" % tactic)
		main.do_trade(kid, tactic)
		check(not main.hud.trade_panel.visible, "trade menu closes (%s)" % tactic)
	check(GameState.junk == 8 and GameState.stickers == 2, "junk/sticker spent")
	await frames(5)
	check(get_tree().get_nodes_in_group("parents").size() >= 1, "crying kid summons a parent")
	check(GameState.heat > 0.0, "heat rises")

	# Guns: pistol hitscan at a parent placed in front of the camera.
	var p = get_tree().get_nodes_in_group("parents")[0]
	var cam: Camera3D = main.player.camera
	main.player.pitch_pivot.rotation.x = 0.0
	await frames(1)
	var c := get_viewport().get_visible_rect().size * 0.5
	var aim := cam.project_ray_origin(c) + cam.project_ray_normal(c) * 8.0
	p.global_position = Vector3(aim.x, main.player.global_position.y, aim.z)
	await frames(1)
	var hp_before: float = p.hp
	for i in 20:
		main.player.fire_cd = 0.0
		main.player.try_fire()
		await frames(1)
	check(not is_instance_valid(p) or p.hp < hp_before or p.dead, "pistol damages parent")
	check(main.player.ammo["pistol"] < 12 or main.player.reload_timer > 0.0, "ammo used")

	for id in ["shotgun", "smg", "rocket"]:
		GameState.cash = 10000
		main.shop_weapon(id)
		check(GameState.weapons_owned[id] and main.player.weapon_id == id, "buy+equip " + id)
		main.player.fire_cd = 0.0
		main.player.reload_timer = 0.0
		main.player.try_fire()
		await frames(10)

	# Kill one directly -> loot.
	main.spawn_parent("coach")
	await frames(2)
	var coach = get_tree().get_nodes_in_group("parents")[-1]
	var cash_before := GameState.cash
	coach.take_damage(9999.0, Vector3.FORWARD)
	check(coach.dead and GameState.cash > cash_before, "KO loots wallet")

	# Shop.
	main.interact(get_tree().get_first_node_in_group("shop"))
	check(main.hud.shop_panel.visible, "shop opens")
	await frames(2)
	var value := GameState.collection_value()
	cash_before = GameState.cash
	main.shop_sell()
	check(GameState.cards.is_empty() and GameState.cash == cash_before + value, "sell all")
	for id in GameState.UPGRADES:
		main.shop_upgrade(id)
	check(GameState.upgrades["armor"] == 1 and GameState.upgrades["shoes"] == 1, "upgrades bought")
	main.shop_buy_junk()
	main.shop_buy_sticker()
	await frames(2)
	main.close_menus()
	check(not main.hud.shop_panel.visible and not main.player.input_locked, "shop closes")

	# Raid.
	GameState.heat = 100.0
	for i in 3:
		await get_tree().process_frame
	check(get_tree().get_nodes_in_group("parents").size() >= 4, "PTA raid at max heat")

	# Parent melee damage + death.
	main.player.hurt_cd = 0.0
	var hp := GameState.health
	main.player.take_damage(10.0)
	check(GameState.health < hp, "player takes damage")
	main.player.hurt_cd = 0.0
	main.player.take_damage(99999.0)
	check(main.game_over and main.hud.overlay.visible, "death shows grounded screen")
	await frames(2)
	main._respawn()
	check(not main.game_over and GameState.health == GameState.max_health(), "respawn")

	GameState.cash = GameState.WIN_COST
	main.shop_win()
	check(GameState.won, "win")

	await frames(120)
	print("\nSMOKE TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


func _tradeable_kid() -> Node:
	for k in get_tree().get_nodes_in_group("kids"):
		if k.can_trade():
			return k
	return null
