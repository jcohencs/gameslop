extends CharacterBody3D
## First-person player: responsive mouse look, movement with stamina, melee combos,
## charged heavy attacks, blocking + parrying, and interaction.

const ViewmodelScript := preload("res://scripts/viewmodel.gd")

const WALK_SPEED := 5.5
const SPRINT_SPEED := 9.0
const BLOCK_SPEED := 3.0
const ACCEL := 60.0
const AIR_ACCEL := 15.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const EYE_HEIGHT := 1.6
const INTERACT_RANGE := 3.0
const COMBO_WINDOW := 0.55
const CHARGE_START := 0.3      # hold this long after an attack to begin charging
const CHARGE_FULL := 0.55      # charge time needed for a heavy
const BUFFER_TIME := 0.25      # early clicks are queued this long
const PARRY_WINDOW := 0.18
const BLOCK_REDUCTION := 0.25
const STAMINA_REGEN := 32.0
const SPRINT_DRAIN := 16.0
const HEAVY_STAMINA := 22.0

var main: Node
var input_locked := true
var head: Node3D
var camera: Camera3D
var viewmodel: Node3D

var attack_cd := 0.0
var combo := 0
var combo_timer := 0.0
var buffered := 0.0
var hold_time := 0.0
var charge := 0.0
var holding := false
var blocking := false
var block_time := 0.0
var guard_broken := 0.0
var stamina_delay := 0.0
var hurt_cd := 0.0
var knockback := Vector3.ZERO
var shake := 0.0
var was_on_floor := true
var fall_speed := 0.0
var sprinting := false
var last_attack_time := -10.0
var noise := 0.0               # how far away parents can hear you (m)
var interact_target: Node = null
var _time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	Input.use_accumulated_input = false
	Shapes.capsule_collider(self, 1.8, 0.35)

	head = Node3D.new()
	head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = GameState.fov
	camera.near = 0.02
	head.add_child(camera)
	camera.current = true

	viewmodel = ViewmodelScript.new()
	camera.add_child(viewmodel)
	viewmodel.set_weapon(GameState.weapon_id)
	GameState.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if viewmodel.kind != GameState.weapon()["kind"] or _shown_weapon != GameState.weapon_id:
		_shown_weapon = GameState.weapon_id
		viewmodel.set_weapon(GameState.weapon_id)
		combo = 0

var _shown_weapon := "knuckles"


func _input(event: InputEvent) -> void:
	# Mouse look lives in _input (not _unhandled_input) so UI never eats it.
	if input_locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sens := GameState.mouse_sensitivity * 0.01
		var rel: Vector2 = event.relative
		rotate_y(-rel.x * sens)
		var dy := rel.y * (-1.0 if GameState.invert_y else 1.0)
		head.rotation.x = clampf(head.rotation.x - dy * sens, -1.5, 1.5)
		viewmodel.feed_mouse(Vector2(rel.x, dy))


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and interact_target:
		main.interact(interact_target)
	elif event.is_action_pressed("weapon_next"):
		GameState.cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		GameState.cycle_weapon(-1)
	else:
		for i in GameState.WEAPON_ORDER.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				GameState.equip_weapon(GameState.WEAPON_ORDER[i])


func _physics_process(delta: float) -> void:
	_time += delta
	attack_cd -= delta
	combo_timer -= delta
	buffered -= delta
	hurt_cd -= delta
	guard_broken -= delta
	stamina_delay -= delta
	if combo_timer <= 0.0:
		combo = 0

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		fall_speed = maxf(fall_speed, -velocity.y)

	var active := not input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var move := Vector2.ZERO
	if not input_locked:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor() and GameState.stamina > 8.0:
			velocity.y = JUMP_VELOCITY
			_use_stamina(8.0)

	# Blocking (with parry window right after raising the guard).
	var want_block := active and Input.is_action_pressed("block") and guard_broken <= 0.0
	if want_block and not blocking:
		block_time = _time
	blocking = want_block
	viewmodel.set_block(blocking)

	# Movement with acceleration for snappy-but-smooth control.
	sprinting = active and Input.is_action_pressed("sprint") and not blocking and move.y < 0.0 and GameState.stamina > 1.0
	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
		_use_stamina(SPRINT_DRAIN * delta)
	elif blocking or guard_broken > 0.0:
		speed = BLOCK_SPEED
	speed *= GameState.speed_mult()
	var dir := (transform.basis * Vector3(move.x, 0, move.y)).normalized()
	var target := dir * speed
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(target, accel * delta)
	velocity.x = flat.x + knockback.x
	velocity.z = flat.z + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	velocity.x -= knockback.x
	velocity.z -= knockback.z

	# Landing dip.
	if is_on_floor() and not was_on_floor:
		viewmodel.land(clampf(fall_speed / 8.0, 0.2, 1.5))
		shake = maxf(shake, clampf(fall_speed / 30.0, 0.0, 0.4))
		fall_speed = 0.0
	was_on_floor = is_on_floor()

	if active:
		_handle_attack_input(delta)
	else:
		holding = false
		charge = 0.0
		viewmodel.set_charging(false)

	# Stamina regen.
	if stamina_delay <= 0.0 and not sprinting:
		GameState.stamina = minf(GameState.stamina + STAMINA_REGEN * delta, GameState.max_stamina())

	# Noise for AI hearing.
	var hspeed := Vector3(velocity.x, 0, velocity.z).length()
	var target_noise := 2.0 + hspeed * (1.4 if sprinting else 0.7)
	if _time - last_attack_time < 1.0:
		target_noise = maxf(target_noise, 11.0)
	noise = lerpf(noise, target_noise, minf(delta * 4.0, 1.0))

	_update_camera(delta, move, hspeed)
	viewmodel.tick(delta, hspeed, sprinting, is_on_floor())
	_update_interact_target()


func _handle_attack_input(delta: float) -> void:
	if guard_broken > 0.0 or blocking:
		holding = false
		charge = 0.0
		viewmodel.set_charging(false)
		return
	if Input.is_action_just_pressed("attack"):
		buffered = BUFFER_TIME
		holding = true
		hold_time = 0.0
		charge = 0.0
	if buffered > 0.0 and attack_cd <= 0.0:
		buffered = 0.0
		_start_attack(false)
	if holding:
		if Input.is_action_pressed("attack"):
			hold_time += delta
			if hold_time > CHARGE_START and attack_cd <= 0.05 and GameState.stamina >= HEAVY_STAMINA * 0.5:
				charge += delta
				viewmodel.set_charging(true)
		else:
			holding = false
			if charge >= CHARGE_FULL:
				_start_attack(true)
			charge = 0.0
			viewmodel.set_charging(false)


func charge_fraction() -> float:
	return clampf(charge / CHARGE_FULL, 0.0, 1.0)


func _start_attack(heavy: bool) -> void:
	var w := GameState.weapon()
	var tired: bool = GameState.stamina < w["stamina"]
	var cost: float = HEAVY_STAMINA if heavy else w["stamina"]
	_use_stamina(cost)
	var mult: float
	if heavy:
		mult = w["heavy"]
		attack_cd = w["rate"] * 1.6
		combo = 0
	else:
		var chain: Array = w["combo"]
		mult = chain[combo % chain.size()]
		attack_cd = w["rate"] * (1.6 if tired else 1.0)
		if combo % chain.size() == chain.size() - 1:
			attack_cd *= 1.35  # finisher recovery
	if tired:
		mult *= 0.6
	var delay: float = viewmodel.attack(combo % 3, heavy)
	last_attack_time = _time
	get_tree().create_timer(delay, false).timeout.connect(_resolve_hit.bind(mult, heavy, combo % 3))
	if not heavy:
		combo += 1
	combo_timer = attack_cd + COMBO_WINDOW


func _resolve_hit(mult: float, heavy: bool, combo_step: int) -> void:
	if not is_inside_tree() or main.raid_over:
		return
	var w := GameState.weapon()
	var forward := -camera.global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0, forward.z).normalized()
	var reach: float = w["range"] * (1.2 if heavy else 1.0)
	var cos_arc := cos(deg_to_rad(w["arc"] * (1.25 if heavy else 1.0)))
	var hits := 0
	var finisher := combo_step == 2 or heavy
	for p in get_tree().get_nodes_in_group("parents"):
		var to: Vector3 = p.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > reach + p.radius:
			continue
		if flat.length() > 0.4 and flat.normalized().dot(flat_fwd) < cos_arc:
			continue
		var dmg: float = w["damage"] * mult * GameState.damage_mult()
		var knock: float = w["knock"] * (2.0 if heavy else (1.4 if finisher else 1.0))
		var stun: float = w["stun"] * (2.5 if heavy else (1.5 if finisher else 1.0))
		p.take_damage(dmg, flat.normalized(), knock, stun)
		main.spawn_damage_number(p.global_position + Vector3(0, p.data["height"] * 0.9, 0), dmg, heavy or finisher)
		hits += 1
	if hits > 0:
		Sfx.play("heavy" if heavy else ("slash" if w["kind"] == "sword" else "punch"))
		viewmodel.on_impact()
		shake = maxf(shake, 0.5 if heavy else 0.3)
		main.on_player_hit_landed(heavy or finisher)
		_hitstop(0.09 if heavy else (0.06 if finisher else 0.035))


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _use_stamina(amount: float) -> void:
	GameState.stamina = maxf(GameState.stamina - amount, 0.0)
	stamina_delay = 0.7


func _update_camera(delta: float, move: Vector2, hspeed: float) -> void:
	var target_fov: float = GameState.fov + (8.0 if sprinting else 0.0) - charge_fraction() * 6.0
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 8.0, 1.0))
	# Strafe tilt.
	camera.rotation.z = lerpf(camera.rotation.z, -move.x * 0.025, minf(delta * 8.0, 1.0))
	shake = maxf(shake - delta * 3.0, 0.0)
	var bob := 0.0
	if is_on_floor() and hspeed > 0.5:
		bob = sin(_time * hspeed * 1.6) * 0.025 * clampf(hspeed / WALK_SPEED, 0.0, 1.5)
	camera.position = Vector3(randf_range(-1, 1) * shake * 0.04, bob + randf_range(-1, 1) * shake * 0.04, 0)


func _update_interact_target() -> void:
	var best: Node = null
	var best_score := -1.0
	var forward := -camera.global_transform.basis.z
	for kid in get_tree().get_nodes_in_group("kids"):
		if not kid.can_trade():
			continue
		var to: Vector3 = kid.global_position + Vector3(0, 0.7, 0) - camera.global_position
		var d := to.length()
		if d > INTERACT_RANGE:
			continue
		var facing := to.normalized().dot(forward)
		if facing < 0.6:
			continue
		var score := facing - d * 0.1
		if score > best_score:
			best_score = score
			best = kid
	interact_target = best


## Called by parents. Returns "parry", "blocked" or "hit".
func take_damage(amount: float, from_dir := Vector3.ZERO, attacker: Node = null) -> String:
	if main.raid_over:
		return "hit"
	if blocking and _time - block_time <= PARRY_WINDOW and attacker:
		Sfx.play("block", 0.05, 2.0)
		shake = 0.25
		main.on_parry(attacker)
		return "parry"
	if hurt_cd > 0.0:
		return "hit"
	hurt_cd = 0.4
	var result := "hit"
	if blocking:
		var cost := amount * 1.3
		if GameState.stamina >= cost:
			_use_stamina(cost)
			amount *= BLOCK_REDUCTION
			result = "blocked"
			Sfx.play("block")
		else:
			# Guard break!
			GameState.stamina = 0.0
			guard_broken = 0.9
			blocking = false
			viewmodel.set_block(false)
			GameState.say("GUARD BROKEN!", Color(1, 0.5, 0.3))
	if result == "hit":
		Sfx.play("hurt")
		viewmodel.flinch()
	GameState.damage(amount)
	knockback = Vector3(from_dir.x, 0, from_dir.z).normalized() * (2.5 if result == "blocked" else 7.0)
	shake = maxf(shake, 0.4 if result == "blocked" else 0.9)
	var src := global_position - from_dir * 2.0
	main.on_player_hurt(result == "blocked", src)
	if GameState.health <= 0.0:
		main.player_died()
	return result
