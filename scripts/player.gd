extends CharacterBody3D
## First-person player with STRAFTAT/Quake-style movement (ground friction, air
## strafing, bunny hopping, crouch-sliding), melee combos, charged heavies (the only
## thing that costs stamina), block/parry, pocket sand, and interaction.

const ViewmodelScript := preload("res://scripts/viewmodel.gd")

# Movement tuning lives in GameState.MOVEMENT (m/s); copied into these vars in _ready().
# Air strafing works like Source: wish speed is capped in the air, so turning the mouse
# while holding a strafe key keeps adding (a little) speed.
const JUMP_BUFFER := 0.12
const GRAVITY := 18.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
const EYE_STAND := 1.6
const EYE_CROUCH := 0.85

# Combat.
const INTERACT_RANGE := 3.0
const COMBO_WINDOW := 0.55
const TAP_TIME := 0.16          # holding longer than this starts a charge
const CHARGE_FULL := 0.5        # charge time needed for a heavy
const BUFFER_TIME := 0.25
const PARRY_WINDOW := 0.18
const BLOCK_REDUCTION := 0.25
const HEAVY_STAMINA := 25.0
const STAMINA_REGEN := 18.0

var main: Node
var input_locked := true
var head: Node3D
var camera: Camera3D
var viewmodel: Node3D
var collider: CollisionShape3D
var capsule: CapsuleShape3D

var attack_cd := 0.0
var combo := 0
var combo_timer := 0.0
var buffered := 0.0
var hold_time := 0.0
var charge := 0.0
var holding := false
var blocking := false
var block_time := 0.0
var hurt_cd := 0.0
var shake := 0.0

var crouching := false
var sliding := false
var slide_boost_cd := 0.0
var jump_buffer := 0.0
var was_on_floor := true
var fall_speed := 0.0
var sprinting := false

var run_speed: float
var sprint_speed: float
var crouch_speed: float
var ground_accel: float
var air_accel: float
var air_cap: float
var friction: float
var stop_speed: float
var slide_start_speed: float
var slide_boost: float
var slide_boost_cd_time: float
var slide_friction: float
var slide_min_speed: float
var max_speed: float
var jump_velocity: float
var noise_crouch: float
var noise_run: float
var noise_sprint: float
var last_attack_time := -10.0
var noise := 0.0               # how far away parents can hear you (m)
var interact_target: Node = null
var _time := 0.0
var _shown_weapon := ""
var _eye := EYE_STAND


func _ready() -> void:
	_load_movement_profile()
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3
	Input.use_accumulated_input = false
	collider = Shapes.capsule_collider(self, STAND_HEIGHT, 0.35)
	capsule = collider.shape

	head = Node3D.new()
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = GameState.fov
	camera.near = 0.02
	head.add_child(camera)
	camera.current = true

	viewmodel = ViewmodelScript.new()
	camera.add_child(viewmodel)
	_shown_weapon = GameState.weapon_id
	viewmodel.set_weapon(GameState.weapon_id)
	GameState.changed.connect(_on_state_changed)


func _load_movement_profile() -> void:
	var m: Dictionary = GameState.MOVEMENT
	run_speed = m["run_speed"]
	sprint_speed = m["sprint_speed"]
	crouch_speed = m["crouch_speed"]
	ground_accel = m["ground_accel"]
	air_accel = m["air_accel"]
	air_cap = m["air_cap"]
	friction = m["friction"]
	stop_speed = m["stop_speed"]
	slide_start_speed = m["slide_start_speed"]
	slide_boost = m["slide_boost"]
	slide_boost_cd_time = m["slide_boost_cd"]
	slide_friction = m["slide_friction"]
	slide_min_speed = m["slide_min_speed"]
	max_speed = m["max_speed"]
	jump_velocity = m["jump_velocity"]
	noise_crouch = m["noise_crouch"]
	noise_run = m["noise_run"]
	noise_sprint = m["noise_sprint"]


func _on_state_changed() -> void:
	if _shown_weapon != GameState.weapon_id:
		_shown_weapon = GameState.weapon_id
		viewmodel.set_weapon(GameState.weapon_id)
		combo = 0
		charge = 0.0
		holding = false


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
	elif event.is_action_pressed("throw_sand"):
		if GameState.weapons_owned["sand"]:
			throw_sand()
		else:
			GameState.say("You don't own Pocket Sand. Buy it at the van!", UI.BAD)
	elif event.is_action_pressed("weapon_next"):
		GameState.cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		GameState.cycle_weapon(-1)
	else:
		for i in GameState.WEAPON_ORDER.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				GameState.equip_weapon(GameState.WEAPON_ORDER[i])


# --- Movement ----------------------------------------------------------------

func hspeed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	_time += delta
	attack_cd -= delta
	combo_timer -= delta
	buffered -= delta
	hurt_cd -= delta
	slide_boost_cd -= delta
	jump_buffer -= delta
	if combo_timer <= 0.0:
		combo = 0

	var active := not input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var move := Vector2.ZERO
	var want_crouch := false
	var jump_held := false
	var sprint_held := false
	if not input_locked:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		want_crouch = Input.is_action_pressed("crouch")
		jump_held = Input.is_action_pressed("jump")
		sprint_held = Input.is_action_pressed("sprint")
		if Input.is_action_just_pressed("jump"):
			jump_buffer = JUMP_BUFFER

	# Blocking (with parry window right after raising the guard).
	var want_block := active and Input.is_action_pressed("block")
	if want_block and not blocking:
		block_time = _time
	blocking = want_block
	viewmodel.set_block(blocking)

	var on_floor := is_on_floor()
	var wishdir := (transform.basis * Vector3(move.x, 0, move.y))
	wishdir.y = 0
	wishdir = wishdir.normalized()

	_update_crouch(want_crouch, on_floor, delta)

	# Sprint is a held state checked on the ground AND in the air, so holding
	# Shift + Space keeps sprint speed through a chain of bunny hops.
	sprinting = sprint_held and move.y < 0.0 and not crouching and not sliding
	var wishspeed := run_speed
	if crouching and not sliding:
		wishspeed = crouch_speed
	elif sprinting:
		wishspeed = sprint_speed
	if blocking:
		wishspeed *= 0.55
	if charge > 0.0:
		wishspeed *= 0.75
	wishspeed *= GameState.speed_mult()

	# Jump: buffered presses and held space both work, so bunny hopping is just
	# "hold space + strafe". Jumping on the landing frame skips ground friction.
	var jumping := on_floor and (jump_buffer > 0.0 or jump_held)
	if on_floor:
		if jumping:
			# Bhop: jump on the landing frame with no friction, and bring speed along the
			# input direction straight up to the wish speed (never down), so holding
			# Shift + Space sprint-hops at sprint speed even from a standstill.
			jump_buffer = 0.0
			if not sliding:
				_accelerate(wishdir, wishspeed, 1.0 / maxf(delta, 0.001), delta)
			velocity.y = jump_velocity
			if sliding:
				_end_slide()
			on_floor = false
		elif sliding:
			_apply_friction(slide_friction, delta)
			_accelerate(wishdir, 2.0, 4.0, delta)  # slight steering
			if hspeed() < slide_min_speed:
				_end_slide()
		else:
			_apply_friction(friction, delta)
			_accelerate(wishdir, wishspeed, ground_accel, delta)
	if not on_floor:
		velocity.y -= GRAVITY * delta
		fall_speed = maxf(fall_speed, -velocity.y)
		_air_accelerate(wishdir, wishspeed, delta)

	_clamp_speed()
	move_and_slide()

	# Landing.
	if is_on_floor() and not was_on_floor:
		viewmodel.land(clampf(fall_speed / 8.0, 0.2, 1.5))
		shake = maxf(shake, clampf(fall_speed / 30.0, 0.0, 0.4))
		fall_speed = 0.0
		# Landing with crouch held and speed turns straight into a slide.
		if want_crouch and hspeed() > slide_start_speed:
			_start_slide()
	was_on_floor = is_on_floor()

	if not input_locked:
		_handle_attack_input(delta)
	else:
		holding = false
		charge = 0.0
		viewmodel.set_charging(false)

	GameState.stamina = minf(GameState.stamina + STAMINA_REGEN * delta, GameState.max_stamina())

	# Noise for AI hearing: speed-based; crouch-walking is quiet, sprinting is loud.
	var hs := hspeed()
	var noise_k := noise_run
	if crouching and not sliding:
		noise_k = noise_crouch
	elif sprinting:
		noise_k = noise_sprint
	var target_noise := 2.0 + hs * noise_k
	if sliding:
		target_noise += 3.0
	if _time - last_attack_time < 1.0:
		target_noise = maxf(target_noise, 11.0)
	noise = lerpf(noise, target_noise, minf(delta * 4.0, 1.0))

	_update_camera(delta, move, hs)
	viewmodel.tick(delta, hs, sprinting or sliding, is_on_floor())
	_update_interact_target()


func _accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void:
	var current := velocity.dot(wishdir)
	var add := wishspeed - current
	if add <= 0.0 or wishdir == Vector3.ZERO:
		return
	velocity += wishdir * minf(accel * wishspeed * delta, add)


func _air_accelerate(wishdir: Vector3, wishspeed: float, delta: float) -> void:
	if wishdir == Vector3.ZERO:
		return
	var current := velocity.dot(wishdir)
	var add := minf(wishspeed, air_cap) - current
	if add <= 0.0:
		return
	velocity += wishdir * minf(air_accel * wishspeed * delta, add)


func _apply_friction(amount: float, delta: float) -> void:
	var speed := hspeed()
	if speed < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(speed, stop_speed) * amount * delta
	var k := maxf(speed - drop, 0.0) / speed
	velocity.x *= k
	velocity.z *= k


## Hard horizontal speed cap (MOVEMENT.max_speed).
func _clamp_speed() -> void:
	var h := Vector2(velocity.x, velocity.z)
	if h.length() > max_speed:
		h = h.normalized() * max_speed
		velocity.x = h.x
		velocity.z = h.y


func _update_crouch(want: bool, on_floor: bool, delta: float) -> void:
	if want and not crouching:
		crouching = true
		if on_floor and hspeed() > slide_start_speed:
			_start_slide()
	elif not want and crouching and _can_stand():
		crouching = false
		if sliding:
			_end_slide()
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	if not is_equal_approx(capsule.height, target_h):
		capsule.height = move_toward(capsule.height, target_h, delta * 8.0)
		collider.position.y = capsule.height * 0.5
	var target_eye := EYE_CROUCH if crouching else EYE_STAND
	_eye = lerpf(_eye, target_eye, minf(delta * 14.0, 1.0))
	head.position.y = _eye


func _can_stand() -> bool:
	var from := global_position + Vector3(0, CROUCH_HEIGHT * 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, STAND_HEIGHT - CROUCH_HEIGHT + 0.1, 0), 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _start_slide() -> void:
	if sliding:
		return
	sliding = true
	if slide_boost_cd <= 0.0:
		slide_boost_cd = slide_boost_cd_time
		var h := Vector2(velocity.x, velocity.z)
		var boosted := h.normalized() * minf(h.length() + slide_boost, max_speed)
		velocity.x = boosted.x
		velocity.z = boosted.y
	Sfx.play("whoosh", 0.05, -6.0)
	viewmodel.set_sliding(true)


func _end_slide() -> void:
	sliding = false
	viewmodel.set_sliding(false)


# --- Combat ------------------------------------------------------------------

func _handle_attack_input(delta: float) -> void:
	var w := GameState.weapon()
	if blocking:
		holding = false
		charge = 0.0
		viewmodel.set_charging(false)
		return
	if w["kind"] == "sand":
		if Input.is_action_just_pressed("attack"):
			throw_sand()
		return
	if Input.is_action_just_pressed("attack"):
		holding = true
		hold_time = 0.0
		charge = 0.0
	if holding:
		if Input.is_action_pressed("attack"):
			hold_time += delta
			# Past a tap: start charging (needs stamina for the heavy).
			if hold_time > TAP_TIME and attack_cd <= 0.0 and GameState.stamina >= HEAVY_STAMINA:
				charge += delta
				viewmodel.set_charging(true)
		else:
			holding = false
			if charge >= CHARGE_FULL:
				_start_attack(true)
			else:
				buffered = BUFFER_TIME  # tap (or a cancelled charge) = light attack
			charge = 0.0
			viewmodel.set_charging(false)
	if buffered > 0.0 and attack_cd <= 0.0 and not holding:
		buffered = 0.0
		_start_attack(false)


func charge_fraction() -> float:
	return clampf(charge / CHARGE_FULL, 0.0, 1.0)


func _start_attack(heavy: bool) -> void:
	var w := GameState.weapon()
	var mult: float
	if heavy:
		GameState.stamina = maxf(GameState.stamina - HEAVY_STAMINA, 0.0)
		mult = w["heavy"]
		attack_cd = w["rate"] * 1.6
		combo = 0
	else:
		var chain: Array = w["combo"]
		mult = chain[combo % chain.size()]
		attack_cd = w["rate"]
		if combo % chain.size() == chain.size() - 1:
			attack_cd *= 1.35  # finisher recovery
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
	var flat_fwd := _flat_forward()
	var reach: float = w["range"] * (1.2 if heavy else 1.0)
	var cos_arc := cos(deg_to_rad(w["arc"] * (1.25 if heavy else 1.0)))
	var hits := 0
	var finisher := combo_step == 2 or heavy
	# Momentum hits harder: sliding/bhopping into someone adds damage and knockback.
	var momentum := clampf((hspeed() - run_speed) / (max_speed - run_speed), 0.0, 0.6)
	for p in get_tree().get_nodes_in_group("parents"):
		var to: Vector3 = p.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > reach + p.radius:
			continue
		if flat.length() > 0.4 and flat.normalized().dot(flat_fwd) < cos_arc:
			continue
		var dmg: float = w["damage"] * mult * GameState.damage_mult() * (1.0 + momentum)
		var knock: float = w["knock"] * (2.0 if heavy else (1.4 if finisher else 1.0)) * (1.0 + momentum * 2.0)
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


func _flat_forward() -> Vector3:
	var f := -camera.global_transform.basis.z
	return Vector3(f.x, 0, f.z).normalized()


## POCKET SAND! Blinds every parent in a cone in front of you.
func throw_sand() -> void:
	if attack_cd > 0.0:
		return
	if GameState.sand <= 0:
		GameState.say("Out of pocket sand! Buy packets at the van.", UI.BAD)
		return
	var w: Dictionary = GameState.WEAPONS["sand"]
	GameState.sand -= 1
	GameState.changed.emit()
	attack_cd = w["rate"]
	last_attack_time = _time
	viewmodel.throw_sand()
	Sfx.play("whoosh", 0.0, 2.0)
	GameState.say("POCKET SAND!", Color(0.95, 0.85, 0.55))
	var fwd := -camera.global_transform.basis.z
	main.spawn_sand_cloud(camera.global_position + fwd * 0.6, fwd)
	var flat_fwd := _flat_forward()
	var cos_arc := cos(deg_to_rad(w["arc"]))
	var hits := 0
	for p in get_tree().get_nodes_in_group("parents"):
		var to: Vector3 = p.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > w["range"] + p.radius:
			continue
		if flat.length() > 0.5 and flat.normalized().dot(flat_fwd) < cos_arc:
			continue
		p.blind(w["blind"], flat.normalized())
		hits += 1
	if hits > 0:
		main.on_player_hit_landed(true)


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _update_camera(delta: float, move: Vector2, hs: float) -> void:
	# FOV widens across the run-speed .. cap range (up to +12 degrees).
	var speed_fov := clampf((hs - run_speed) / (max_speed - run_speed), 0.0, 1.0) * 12.0
	var target_fov: float = GameState.fov + speed_fov - charge_fraction() * 6.0
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * 8.0, 1.0))
	# Strafe tilt, extra roll while sliding.
	var roll := -move.x * 0.025 + (0.07 if sliding else 0.0)
	camera.rotation.z = lerpf(camera.rotation.z, roll, minf(delta * 8.0, 1.0))
	shake = maxf(shake - delta * 3.0, 0.0)
	var bob := 0.0
	if is_on_floor() and hs > 0.5 and not sliding:
		bob = sin(_time * minf(hs, 10.0) * 1.6) * 0.025 * clampf(hs / run_speed, 0.0, 1.3)
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
		amount *= BLOCK_REDUCTION
		result = "blocked"
		Sfx.play("block")
	else:
		Sfx.play("hurt")
		viewmodel.flinch()
	GameState.damage(amount)
	var push := Vector3(from_dir.x, 0, from_dir.z).normalized() * (2.5 if blocking else 7.0)
	velocity += push + Vector3(0, 0.0 if blocking else 1.5, 0)
	_clamp_speed()
	shake = maxf(shake, 0.4 if blocking else 0.9)
	main.on_player_hurt(blocking, global_position - from_dir * 2.0)
	if GameState.health <= 0.0:
		main.player_died()
	return result
