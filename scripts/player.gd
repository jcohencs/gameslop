extends CharacterBody3D
## First-person player: movement, fists (punch/block), interaction.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0025
const INTERACT_RANGE := 2.8
const EYE_HEIGHT := 1.6
const BLOCK_REDUCTION := 0.3  # damage multiplier while blocking

var main: Node
var input_locked := true
var head: Node3D
var camera: Camera3D
var hands: Array[MeshInstance3D] = []
var hand_rest: Array[Vector3] = [Vector3(-0.26, -0.27, -0.6), Vector3(0.26, -0.27, -0.6)]

var punch_cd := 0.0
var next_hand := 1
var hurt_cd := 0.0
var knockback := Vector3.ZERO
var blocking := false
var bob_t := 0.0
var shake := 0.0
var interact_target: Node = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	Shapes.capsule_collider(self, 1.8, 0.35)

	head = Node3D.new()
	head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80
	camera.near = 0.03
	head.add_child(camera)
	camera.current = true

	# Viewmodel fists, parented to the camera so they follow the view.
	for i in 2:
		var fist := Shapes.sphere(camera, 0.11, hand_rest[i], Color.WHITE)
		fist.scale = Vector3(1.0, 0.85, 1.25)
		fist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Sleeve.
		var sleeve := Shapes.cylinder(fist, 0.042, 0.4, Vector3(0, -0.02, 0.24), Color(0.15, 0.15, 0.18))
		sleeve.rotation.x = PI / 2
		sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hands.append(fist)
	refresh_fists()
	GameState.changed.connect(refresh_fists)


func refresh_fists() -> void:
	var f := GameState.fist()
	for h in hands:
		var m: StandardMaterial3D = h.material_override
		m.albedo_color = f["color"]
		m.metallic = 0.8 if GameState.fist_id in ["brass", "gauntlet"] else 0.0
		m.roughness = 0.3 if GameState.fist_id in ["brass", "gauntlet"] else 0.8
		var s: float = f["size"] * 0.42
		var sm: SphereMesh = h.mesh
		sm.radius = s
		sm.height = s * 2.0


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and interact_target:
		main.interact(interact_target)
	else:
		for id in GameState.FISTS:
			if event.is_action_pressed("weapon_%d" % GameState.FISTS[id]["key"]):
				GameState.equip_fist(id)


func _physics_process(delta: float) -> void:
	punch_cd -= delta
	hurt_cd -= delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var move := Vector2.ZERO
	blocking = false
	if not input_locked:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		blocking = Input.is_action_pressed("block")
	var dir := (transform.basis * Vector3(move.x, 0, move.y)).normalized()
	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") and not blocking else WALK_SPEED) * GameState.speed_mult()
	if blocking:
		speed *= 0.5
	velocity.x = dir.x * speed + knockback.x
	velocity.z = dir.z * speed + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()

	if not input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not blocking:
		if Input.is_action_pressed("punch"):
			try_punch()

	_animate_view(delta, dir.length() > 0.1 and is_on_floor(), speed)
	_update_interact_target()


func _animate_view(delta: float, moving: bool, speed: float) -> void:
	if moving:
		bob_t += delta * speed * 1.6
	var bob := Vector3(cos(bob_t * 0.5) * 0.015, absf(sin(bob_t * 0.5)) * 0.025, 0) if moving else Vector3.ZERO
	shake = maxf(shake - delta * 4.0, 0.0)
	camera.position = bob + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.05
	# Guard up (fists together in front of the face) or drift back to rest between punches.
	if blocking or punch_cd < -0.05:
		for i in 2:
			var target := Vector3(-0.09 + 0.18 * i, -0.1, -0.42) if blocking else hand_rest[i]
			hands[i].position = hands[i].position.lerp(target, minf(delta * 18.0, 1.0))


func _update_interact_target() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for kid in get_tree().get_nodes_in_group("kids"):
		if kid.can_trade():
			var d := global_position.distance_to(kid.global_position)
			if d < best_d:
				best_d = d
				best = kid
	interact_target = best


func try_punch() -> void:
	if punch_cd > 0.0:
		return
	var f := GameState.fist()
	punch_cd = f["rate"]
	_animate_punch(next_hand)
	next_hand = 1 - next_hand

	var forward := -camera.global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0, forward.z).normalized()
	var origin := global_position
	var hit_any := false
	var cos_arc := cos(deg_to_rad(f["arc"]))
	for p in get_tree().get_nodes_in_group("parents"):
		var to: Vector3 = p.global_position - origin
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > f["range"] + p.radius:
			continue
		if flat.length() > 0.3 and flat.normalized().dot(flat_fwd) < cos_arc:
			continue
		p.take_damage(f["damage"] * GameState.damage_mult(), flat.normalized(), f["knock"], f["stun"])
		hit_any = true
	if hit_any:
		shake = 0.6
		main.spawn_hit_spark(camera.global_position + forward * 1.2)


func _animate_punch(i: int) -> void:
	var h := hands[i]
	var tw := create_tween()
	var jab := Vector3(-0.06 + 0.12 * (1 - i), -0.15, -1.0)
	tw.tween_property(h, "position", jab, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "position", hand_rest[i], 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if hurt_cd > 0.0 or main.raid_over:
		return
	hurt_cd = 0.5
	if blocking:
		amount *= BLOCK_REDUCTION
	GameState.damage(amount)
	knockback = Vector3(from_dir.x, 0, from_dir.z).normalized() * (3.0 if blocking else 8.0)
	shake = 1.0
	main.on_player_hurt(blocking)
	if GameState.health <= 0.0:
		main.player_died()
