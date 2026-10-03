extends CharacterBody3D
## An angry parent hunting the player. Punch them out to loot their wallet.

const GRAVITY := 18.0
const ATTACK_RANGE := 1.8
const WINDUP := 0.4

const TYPES := {
	"mom": {"name": "Soccer Mom", "hp": 50.0, "speed": 6.4, "damage": 8.0, "attack_cd": 1.1,
		"color": Color(1.0, 0.45, 0.7), "height": 1.75, "reward": [10, 25],
		"taunts": ["I WANT YOUR MANAGER!", "That's MY baby's card!", "I'm calling the HOA!"]},
	"dad": {"name": "Angry Dad", "hp": 85.0, "speed": 5.4, "damage": 12.0, "attack_cd": 1.2,
		"color": Color(0.3, 0.45, 0.9), "height": 1.95, "reward": [15, 40],
		"taunts": ["HEY! YOU! KID-SCAMMER!", "I didn't drive here for this!", "You want a piece of me?!"]},
	"pta": {"name": "PTA President", "hp": 160.0, "speed": 4.9, "damage": 16.0, "attack_cd": 1.3,
		"color": Color(0.6, 0.3, 0.85), "height": 2.05, "reward": [40, 80],
		"taunts": ["This is going in the NEWSLETTER!", "Motion to destroy you: PASSED."]},
	"coach": {"name": "Gym Coach", "hp": 300.0, "speed": 4.4, "damage": 24.0, "attack_cd": 1.5,
		"color": Color(0.85, 0.15, 0.15), "height": 2.5, "reward": [80, 150],
		"taunts": ["GIVE ME TWENTY, SCAMMER!", "*TWEEEEEET*", "DODGEBALL TIME!"]},
}

var kind: String = "dad"
var data: Dictionary
var hp: float
var radius: float
var player: Node3D
var label: Label3D
var body_mat: StandardMaterial3D
var base_color: Color
var arm: MeshInstance3D
var attack_timer := 0.0
var windup_timer := 0.0
var stun_timer := 0.0
var flash_timer := 0.0
var taunt_timer := 0.0
var dead := false
var stuck_dir := 0.0
var knockback := Vector3.ZERO


func setup(type_id: String) -> void:
	kind = type_id
	data = TYPES[kind]


func _ready() -> void:
	add_to_group("parents")
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	if data.is_empty():
		data = TYPES[kind]
	hp = data["hp"]
	var h: float = data["height"]
	radius = h * 0.18
	base_color = data["color"]
	var body := Shapes.person(self, h, base_color, Color(0.95, 0.78, 0.62))
	body_mat = body.material_override
	# Angry eyebrows.
	Shapes.box(self, Vector3(h * 0.2, h * 0.025, 0.04), Vector3(0, h * 0.92, -h * 0.13), Color(0.2, 0.1, 0.05))
	if kind == "mom":
		Shapes.sphere(self, h * 0.11, Vector3(0, h * 0.98, h * 0.08), Color(0.95, 0.85, 0.3)) # the haircut
	elif kind == "coach":
		Shapes.sphere(self, h * 0.03, Vector3(0, h * 0.65, -h * 0.16), Color(0.9, 0.9, 0.2)) # whistle
	# Swinging arm (purse / fist).
	arm = Shapes.box(self, Vector3(h * 0.08, h * 0.08, h * 0.35), Vector3(h * 0.2, h * 0.5, -h * 0.1), base_color.darkened(0.2))
	Shapes.capsule_collider(self, h, radius)
	label = Shapes.label(self, "", Vector3(0, h + 0.35, 0), Color(1, 0.6, 0.5), 30)
	_refresh_label()
	taunt_timer = randf_range(1.0, 4.0)


func _refresh_label() -> void:
	if dead:
		label.text = "K.O.!"
		label.modulate = Color(1, 1, 0.4)
	elif stun_timer > 0.0:
		label.text = "%s\nHP %d  *dazed*" % [data["name"], ceili(hp)]
	else:
		label.text = "%s\nHP %d" % [data["name"], ceili(hp)]


func take_damage(amount: float, dir := Vector3.ZERO, knock := 4.0, stun := 0.25) -> void:
	if dead:
		return
	hp -= amount
	flash_timer = 0.08
	body_mat.albedo_color = Color.WHITE
	knockback += Vector3(dir.x, 0, dir.z).normalized() * knock
	# Getting punched interrupts their swing.
	stun_timer = maxf(stun_timer, stun)
	windup_timer = 0.0
	arm.position.z = -data["height"] * 0.1
	if hp <= 0.0:
		_die()
	else:
		_refresh_label()


func _die() -> void:
	dead = true
	remove_from_group("parents")
	collision_layer = 0
	collision_mask = 1
	_refresh_label()
	var r: Array = data["reward"]
	var cash := randi_range(r[0], r[1])
	GameState.cash += cash
	GameState.knockouts += 1
	GameState.changed.emit()
	GameState.say("Knocked out a %s! Looted their wallet: +$%d" % [data["name"], cash], Color(1, 0.9, 0.3))
	body_mat.albedo_color = base_color.darkened(0.4)
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -PI / 2, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			body_mat.albedo_color = base_color
	if dead:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	attack_timer -= delta
	taunt_timer -= delta
	var to_player := Vector3.ZERO
	var dist := 999.0
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0
		dist = to_player.length()

	if taunt_timer <= 0.0 and stun_timer <= 0.0:
		taunt_timer = randf_range(4.0, 8.0)
		var t: Array = data["taunts"]
		label.text = "\"%s\"" % t[randi() % t.size()]
		get_tree().create_timer(1.8).timeout.connect(_refresh_label)

	var dir := Vector3.ZERO
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer <= 0.0:
			_refresh_label()
	elif windup_timer > 0.0:
		# Telegraphed swing: arm pulls back, then strikes. Block (RMB) or back off!
		windup_timer -= delta
		arm.position.z = lerpf(arm.position.z, data["height"] * 0.15, delta * 10.0)
		if windup_timer <= 0.0:
			arm.position.z = -data["height"] * 0.35
			if dist < ATTACK_RANGE + 0.4:
				player.take_damage(data["damage"], to_player.normalized())
			get_tree().create_timer(0.15).timeout.connect(_reset_arm)
	else:
		if dist < ATTACK_RANGE and attack_timer <= 0.0 and player and player.has_method("take_damage"):
			attack_timer = data["attack_cd"]
			windup_timer = WINDUP
		elif dist > ATTACK_RANGE * 0.8 and dist < 999.0:
			dir = to_player.normalized()
			# Crude obstacle avoidance: slide sideways when blocked.
			if is_on_wall():
				if stuck_dir == 0.0:
					stuck_dir = 1.0 if randf() < 0.5 else -1.0
			else:
				stuck_dir = move_toward(stuck_dir, 0.0, delta * 0.5)
			if stuck_dir != 0.0:
				dir = (dir + dir.cross(Vector3.UP) * stuck_dir * 1.5).normalized()
		if to_player.length() > 0.01:
			var look := global_position + to_player
			look_at(Vector3(look.x, global_position.y, look.z), Vector3.UP)

	velocity.x = dir.x * data["speed"] + knockback.x
	velocity.z = dir.z * data["speed"] + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	move_and_slide()


func _reset_arm() -> void:
	if not dead:
		arm.position.z = -data["height"] * 0.1
