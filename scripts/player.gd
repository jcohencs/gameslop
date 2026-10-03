extends CharacterBody3D
## Third-person, over-the-shoulder player: movement, aiming, guns, interaction.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 6.5
const GRAVITY := 18.0
const MOUSE_SENS := 0.0025
const INTERACT_RANGE := 2.6
const SHOT_MASK := 1 | 8  # world + parents (bullets pass through kids)

const RocketScript := preload("res://scripts/rocket.gd")

var main: Node
var input_locked := true
var pitch_pivot: Node3D
var camera: Camera3D
var gun: MeshInstance3D
var muzzle: Node3D

var weapon_id := "pistol"
var ammo := {}
var fire_cd := 0.0
var reload_timer := 0.0
var hurt_cd := 0.0
var knockback := Vector3.ZERO
var interact_target: Node = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	Shapes.person(self, 1.8, Color(0.15, 0.15, 0.18), Color(0.95, 0.8, 0.65))
	# Shady sunglasses.
	Shapes.box(self, Vector3(0.32, 0.07, 0.05), Vector3(0, 1.57, -0.23), Color.BLACK)
	Shapes.capsule_collider(self, 1.8, 0.35)

	pitch_pivot = Node3D.new()
	pitch_pivot.position = Vector3(0, 1.55, 0)
	add_child(pitch_pivot)

	var arm := SpringArm3D.new()
	arm.spring_length = 3.6
	arm.collision_mask = 1
	arm.margin = 0.2
	arm.position = Vector3(0.7, 0.15, 0)
	arm.add_excluded_object(get_rid())
	pitch_pivot.add_child(arm)

	camera = Camera3D.new()
	camera.fov = 75
	arm.add_child(camera)
	camera.current = true

	gun = Shapes.box(pitch_pivot, Vector3(0.1, 0.14, 0.55), Vector3(0.38, -0.35, -0.45), Color.BLACK)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0, -0.3)
	gun.add_child(muzzle)

	for id in GameState.WEAPONS:
		ammo[id] = GameState.WEAPONS[id]["mag"]
	equip("pistol")


func weapon() -> Dictionary:
	return GameState.WEAPONS[weapon_id]


func equip(id: String) -> void:
	if not GameState.weapons_owned.get(id, false):
		return
	weapon_id = id
	reload_timer = 0.0
	var w := weapon()
	var m: StandardMaterial3D = gun.material_override
	m.albedo_color = w["color"]
	var bm: BoxMesh = gun.mesh
	bm.size = Vector3(0.18, 0.18, 0.9) if w["rocket"] else (Vector3(0.12, 0.14, 0.75) if id == "shotgun" else Vector3(0.1, 0.14, 0.55))
	GameState.changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - event.relative.y * MOUSE_SENS, -1.2, 1.0)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and interact_target:
		main.interact(interact_target)
	elif event.is_action_pressed("reload"):
		start_reload()
	else:
		for id in GameState.WEAPONS:
			if event.is_action_pressed("weapon_%d" % GameState.WEAPONS[id]["key"]):
				equip(id)


func _physics_process(delta: float) -> void:
	fire_cd -= delta
	hurt_cd -= delta
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			ammo[weapon_id] = weapon()["mag"]
			GameState.changed.emit()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var move := Vector2.ZERO
	if not input_locked:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	var dir := (transform.basis * Vector3(move.x, 0, move.y)).normalized()
	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED) * GameState.speed_mult()
	velocity.x = dir.x * speed + knockback.x
	velocity.z = dir.z * speed + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()

	if not input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var w := weapon()
		var trigger := Input.is_action_pressed("shoot") if w["auto"] else Input.is_action_just_pressed("shoot")
		if trigger:
			try_fire()

	_update_interact_target()


func _update_interact_target() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for kid in get_tree().get_nodes_in_group("kids"):
		if kid.can_trade():
			var d := global_position.distance_to(kid.global_position)
			if d < best_d:
				best_d = d
				best = kid
	for van in get_tree().get_nodes_in_group("shop"):
		if global_position.distance_to(van.global_position) < 5.0:
			best = van
	interact_target = best


func start_reload() -> void:
	if reload_timer > 0.0 or ammo[weapon_id] >= weapon()["mag"]:
		return
	reload_timer = weapon()["reload"]
	GameState.changed.emit()


func try_fire() -> void:
	if fire_cd > 0.0 or reload_timer > 0.0:
		return
	if ammo[weapon_id] <= 0:
		start_reload()
		return
	var w := weapon()
	fire_cd = w["rate"]
	ammo[weapon_id] -= 1
	GameState.changed.emit()

	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(vp_center)
	var forward := camera.project_ray_normal(vp_center)
	# Recoil kick.
	pitch_pivot.rotation.x = minf(pitch_pivot.rotation.x + 0.012 * w["pellets"] * (4.0 if w["rocket"] else 1.0), 1.0)

	if w["rocket"]:
		var target := _raycast(origin, origin + forward * 200.0)
		var aim_point: Vector3 = target["position"] if target else origin + forward * 200.0
		var rocket := RocketScript.new()
		get_parent().add_child(rocket)
		rocket.launch(muzzle.global_position, (aim_point - muzzle.global_position).normalized(), w["damage"], self)
	else:
		for i in w["pellets"]:
			var spread: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * w["spread"]
			var d: Vector3 = (forward + spread).normalized()
			var hit := _raycast(origin, origin + d * 120.0)
			var end: Vector3 = origin + d * 120.0
			if hit:
				end = hit["position"]
				if hit["collider"].has_method("take_damage"):
					hit["collider"].take_damage(w["damage"], d)
				else:
					main.spawn_impact(end)
			main.spawn_tracer(muzzle.global_position, end)
	main.spawn_muzzle_flash(muzzle.global_position)

	if ammo[weapon_id] <= 0:
		start_reload()


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, SHOT_MASK, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if hurt_cd > 0.0 or main.game_over:
		return
	hurt_cd = 0.5
	GameState.damage(amount)
	knockback = Vector3(from_dir.x, 0, from_dir.z).normalized() * 9.0
	main.flash_damage()
	if GameState.health <= 0.0:
		main.player_died()
