extends CharacterBody3D
## An angry adult. State machine with perception (vision cone + line of sight + hearing),
## navmesh pathing, attack tokens (so they surround you instead of dog-piling),
## telegraphed swings, parry/stagger reactions and procedural animation.

enum State { PATROL, INVESTIGATE, SEARCH, CHASE, ENGAGE, WINDUP, RECOVER, STAGGER, FLEE, KO, BLINDED }

const GRAVITY := 18.0
const ATTACK_RANGE := 1.75
const ENGAGE_RANGE := 3.6
const WINDUP_TIME := 0.5
const RECOVER_TIME := 0.4
const VIEW_RANGE := 24.0
const VIEW_COS := 0.5            # ~60 degree half-angle
const MEMORY := 3.5              # seconds they keep chasing after losing sight
const SEARCH_TIME := 9.0

const TYPES := {
	"mom": {"name": "Soccer Mom", "hp": 55.0, "speed": 6.2, "damage": 8.0, "attack_cd": 1.0, "height": 1.75,
		"shirt": Color(1.0, 0.45, 0.7), "pants": Color(0.9, 0.9, 0.92), "opts": {"hair": Color(0.95, 0.82, 0.35), "girth": 0.9},
		"reward": [10, 25], "flee": 0.4,
		"taunts": ["I WANT YOUR MANAGER!", "That's MY baby's card!", "I'm calling the HOA!"]},
	"dad": {"name": "Angry Dad", "hp": 90.0, "speed": 5.4, "damage": 12.0, "attack_cd": 1.2, "height": 1.95,
		"shirt": Color(0.3, 0.45, 0.9), "pants": Color(0.75, 0.65, 0.45), "opts": {"cap": Color(0.15, 0.3, 0.15), "girth": 1.15},
		"reward": [15, 40], "flee": 0.0,
		"taunts": ["HEY! KID-SCAMMER!", "I didn't drive here for this!", "You want a piece of me?!"]},
	"pta": {"name": "PTA President", "hp": 160.0, "speed": 5.0, "damage": 16.0, "attack_cd": 1.3, "height": 2.0,
		"shirt": Color(0.55, 0.25, 0.8), "pants": Color(0.2, 0.15, 0.25), "opts": {"glasses": true, "hair": Color(0.35, 0.2, 0.1)},
		"reward": [40, 80], "flee": 0.0,
		"taunts": ["This is going in the NEWSLETTER!", "Motion to destroy you: PASSED."]},
	"coach": {"name": "Gym Coach", "hp": 300.0, "speed": 4.6, "damage": 24.0, "attack_cd": 1.5, "height": 2.35,
		"shirt": Color(0.85, 0.15, 0.15), "pants": Color(0.15, 0.15, 0.6), "opts": {"cap": Color(0.85, 0.15, 0.15), "whistle": Color(0.95, 0.9, 0.2), "girth": 1.3},
		"reward": [80, 150], "flee": 0.0,
		"taunts": ["GIVE ME TWENTY, SCAMMER!", "*TWEEEEEET*", "DODGEBALL TIME!"]},
	# Patrolling guards: they watch for scams instead of showing up angry.
	"monitor": {"name": "Recess Monitor", "hp": 90.0, "speed": 5.2, "damage": 10.0, "attack_cd": 1.1, "height": 1.8,
		"shirt": Color(1.0, 0.55, 0.1), "pants": Color(0.3, 0.3, 0.35), "opts": {"whistle": Color(0.9, 0.9, 0.9), "hair": Color(0.25, 0.15, 0.1)},
		"reward": [20, 35], "flee": 0.0, "guard": true,
		"taunts": ["No running! ...no SCAMMING!", "*TWEET* Detention!"]},
	"owner": {"name": "Gary (Store Owner)", "hp": 150.0, "speed": 5.0, "damage": 14.0, "attack_cd": 1.2, "height": 1.9,
		"shirt": Color(0.2, 0.55, 0.3), "pants": Color(0.25, 0.25, 0.3), "opts": {"glasses": true, "girth": 1.3},
		"reward": [50, 90], "flee": 0.0, "guard": true,
		"taunts": ["NOT IN MY STORE!", "You're banned from locals. FOREVER.", "That's a judge call: YOU LOSE."]},
	"cop": {"name": "Mall Cop", "hp": 200.0, "speed": 5.6, "damage": 18.0, "attack_cd": 1.2, "height": 1.95,
		"shirt": Color(0.15, 0.2, 0.4), "pants": Color(0.12, 0.12, 0.2), "opts": {"cap": Color(0.1, 0.12, 0.3), "badge": Color(1, 0.85, 0.2), "girth": 1.2},
		"reward": [60, 110], "flee": 0.0, "guard": true,
		"taunts": ["FREEZE! Mall security!", "I've trained for this my whole life.", "Code 12! Card scammer!"]},
}

var kind: String = "dad"
var data: Dictionary
var hp: float
var radius: float
var player: Node3D
var main: Node
var state := State.CHASE
var rig: Rig
var agent: NavigationAgent3D
var label: Label3D
var hp_bar: MeshInstance3D
var hp_fill: MeshInstance3D
var patrol: Array = []
var patrol_i := 0

var state_t := 0.0
var attack_timer := 0.0
var stun_timer := 0.0
var taunt_timer := 0.0
var think_timer := 0.0
var memory_timer := 0.0
var last_seen := Vector3.ZERO
var move_target := Vector3.ZERO
var sees_player := false
var circle_side := 1.0
var has_token := false
var knockback := Vector3.ZERO
var label_hold := 0.0
var blind_timer := 0.0
var stumble := Vector3.ZERO


func setup(type_id: String) -> void:
	kind = type_id
	data = TYPES[kind]


func is_guard() -> bool:
	return data.get("guard", false)


func is_fighting() -> bool:
	return state in [State.ENGAGE, State.WINDUP, State.RECOVER]


## 0 = unaware, 1 = searching, 2 = has eyes on the player.
func awareness() -> int:
	if state in [State.CHASE, State.ENGAGE, State.WINDUP, State.RECOVER] and sees_player:
		return 2
	if state in [State.INVESTIGATE, State.SEARCH, State.CHASE, State.ENGAGE, State.BLINDED]:
		return 1
	return 0


func _ready() -> void:
	add_to_group("parents")
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	if data.is_empty():
		data = TYPES[kind]
	hp = data["hp"]
	var h: float = data["height"]
	radius = h * 0.17
	var opts: Dictionary = data["opts"].duplicate()
	opts["brows"] = Color(0.2, 0.1, 0.05)
	rig = Rig.new()
	add_child(rig)
	rig.build(h, data["shirt"], data["pants"], Color(0.95, 0.78, 0.62).darkened(randf() * 0.4), opts)
	Shapes.capsule_collider(self, h, radius)

	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.radius = 0.4
	agent.height = h
	add_child(agent)

	label = Shapes.label(self, "", Vector3(0, h + 0.45, 0), Color(1, 0.6, 0.5), 26)
	hp_bar = _bar(Color(0.1, 0.1, 0.1, 0.8), Vector3(0, h + 0.22, 0), 0.0)
	hp_fill = _bar(Color(0.95, 0.25, 0.25), Vector3(0, h + 0.22, 0), 0.001)
	hp_bar.visible = false
	hp_fill.visible = false
	circle_side = 1.0 if randf() < 0.5 else -1.0
	taunt_timer = randf_range(2.0, 5.0)
	if is_guard():
		_set_state(State.PATROL)
	_refresh_label()


func _bar(color: Color, pos: Vector3, depth_bias: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.07)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 1 if depth_bias > 0.0 else 0
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _refresh_label() -> void:
	if label_hold > 0.0:
		return
	match state:
		State.KO:
			label.text = "K.O.!"
			label.modulate = Color(1, 1, 0.4)
		State.STAGGER:
			label.text = "@_@\n" + data["name"]
			label.modulate = Color(1, 0.9, 0.5)
		State.BLINDED:
			label.text = "MY EYES!!\n" + data["name"]
			label.modulate = Color(0.95, 0.85, 0.55)
		State.FLEE:
			label.text = "\"I'm calling my LAWYER!\""
			label.modulate = Color(0.7, 0.8, 1)
		State.PATROL:
			label.text = data["name"]
			label.modulate = Color(0.85, 0.9, 1.0)
		State.INVESTIGATE, State.SEARCH:
			label.text = "?\n" + data["name"]
			label.modulate = Color(1, 0.85, 0.3)
		_:
			label.text = "!\n" + data["name"]
			label.modulate = Color(1, 0.45, 0.4)


func _say(text: String, hold := 1.8) -> void:
	label.text = "\"%s\"" % text
	label.modulate = Color(1, 1, 1)
	label_hold = hold


func _set_state(s: State) -> void:
	if state == s:
		return
	if has_token and s != State.WINDUP and s != State.RECOVER and s != State.ENGAGE:
		_release_token()
	state = s
	state_t = 0.0
	match s:
		State.WINDUP:
			rig.play("windup", WINDUP_TIME + 0.05, 0.12)
		State.STAGGER:
			rig.play("dazed", stun_timer, 0.08)
		State.BLINDED:
			rig.play("cry", -1.0, 0.08)  # rubbing their eyes
		State.INVESTIGATE, State.SEARCH, State.PATROL, State.CHASE:
			if rig.current_action() in ["dazed", "cry"]:
				rig.clear_action()
	_refresh_label()


func _release_token() -> void:
	has_token = false
	if main:
		main.release_attack_token(self)


# --- Perception --------------------------------------------------------------

func _eye() -> Vector3:
	return global_position + Vector3(0, data["height"] * 0.9, 0)


func _can_see_player() -> bool:
	if player == null:
		return false
	var to: Vector3 = player.global_position - global_position
	var dist := to.length()
	var alert := state in [State.CHASE, State.ENGAGE, State.WINDUP, State.RECOVER]
	var range_m := VIEW_RANGE * GameState.stealth_mult() * (1.3 if alert else 1.0)
	if dist > range_m:
		return false
	var fwd := -global_transform.basis.z
	var flat := Vector3(to.x, 0, to.z).normalized()
	if dist > 2.5 and not alert and fwd.dot(flat) < VIEW_COS:
		return false
	var q := PhysicsRayQueryParameters3D.create(_eye(), player.global_position + Vector3(0, 1.5, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _can_hear_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) < player.noise


## Fresh arrivals: head for a spot (a crying kid) or straight at the player.
func begin_investigate(pos: Vector3) -> void:
	last_seen = pos
	move_target = pos
	_set_state(State.INVESTIGATE)


func begin_chase(pos: Vector3) -> void:
	last_seen = pos
	memory_timer = MEMORY * 2.0
	_set_state(State.CHASE)


## Called when a kid cries or a parent radios in: go check out a spot.
func alert_to(pos: Vector3, urgent := false) -> void:
	if state in [State.KO, State.FLEE, State.STAGGER, State.CHASE, State.ENGAGE, State.WINDUP, State.RECOVER]:
		return
	last_seen = pos
	move_target = pos
	if urgent:
		memory_timer = MEMORY
		_set_state(State.CHASE)
	else:
		_set_state(State.INVESTIGATE)


## Guards call this when they catch you scamming in plain sight.
func witnessed_scam() -> bool:
	if state == State.KO or not _can_see_player():
		return false
	_spot_player()
	_say(data["taunts"][0])
	return true


func _spot_player() -> void:
	var was_alert := state in [State.CHASE, State.ENGAGE, State.WINDUP, State.RECOVER]
	last_seen = player.global_position
	memory_timer = MEMORY
	if not was_alert:
		_set_state(State.CHASE)
		rig.play("point", 0.6)
		if main:
			main.on_parent_spotted(self)


# --- Damage ------------------------------------------------------------------

func take_damage(amount: float, dir := Vector3.ZERO, knock := 4.0, stun := 0.25) -> void:
	if state == State.KO:
		return
	hp -= amount
	rig.flash(Color.WHITE)
	knockback += Vector3(dir.x, 0, dir.z).normalized() * knock
	_update_hp_bar()
	if hp <= 0.0:
		_die()
		return
	if player:
		last_seen = player.global_position
		memory_timer = MEMORY
	if hp < data["hp"] * 0.2 and randf() < data["flee"]:
		_set_state(State.FLEE)
		return
	if state == State.BLINDED:
		# Still can't see: flinch, keep rubbing their eyes.
		rig.play("flinch", 0.25, 0.05)
		return
	stun_timer = maxf(stun_timer, stun)
	if stun >= 0.5:
		_set_state(State.STAGGER)
	else:
		# Light hits interrupt a windup and make them flinch, but they keep coming.
		rig.play("flinch", 0.3, 0.05)
		if state == State.WINDUP:
			_set_state(State.RECOVER)
		elif state in [State.PATROL, State.INVESTIGATE, State.SEARCH]:
			_spot_player()


## Pocket sand to the face: can't see, stumbles around, loses track of you.
func blind(duration: float, from_dir := Vector3.ZERO) -> void:
	if state == State.KO:
		return
	blind_timer = maxf(blind_timer, duration)
	knockback += Vector3(from_dir.x, 0, from_dir.z).normalized() * 2.0
	stumble = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	sees_player = false
	_set_state(State.BLINDED)
	_say("MY EYES!", 1.2)


func parried() -> void:
	stun_timer = 1.4
	knockback += -global_transform.basis.z * -4.0
	_set_state(State.STAGGER)
	_say("WHAT?!", 1.0)


func _update_hp_bar() -> void:
	var frac := clampf(hp / data["hp"], 0.0, 1.0)
	hp_bar.visible = frac < 1.0 and state != State.KO
	hp_fill.visible = hp_bar.visible
	hp_fill.scale.x = maxf(frac, 0.001)


func _die() -> void:
	_set_state(State.KO)
	remove_from_group("parents")
	collision_layer = 0
	collision_mask = 1
	hp_bar.visible = false
	hp_fill.visible = false
	var r: Array = data["reward"]
	var cash := randi_range(r[0], r[1])
	GameState.cash += cash
	GameState.knockouts += 1
	GameState.changed.emit()
	GameState.say("Knocked out %s! Looted their wallet: +$%d" % [data["name"], cash], Color(1, 0.9, 0.3))
	Sfx.play_at("ko", global_position + Vector3.UP, get_parent())
	Sfx.play("cash", 0.02, -6.0)
	rig.play("flinch", 0.4, 0.05)
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", -PI / 2, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(queue_free)


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	state_t += delta
	attack_timer -= delta
	taunt_timer -= delta
	label_hold -= delta
	if label_hold <= 0.0 and label_hold > -delta * 1.5:
		_refresh_label()
	if state == State.KO:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		rig.tick(delta, 0.0, true)
		return

	# Perception runs a few times a second.
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = 0.15
		sees_player = _can_see_player() and state != State.BLINDED
		if sees_player or (_can_hear_player() and not (state in [State.FLEE, State.BLINDED])):
			if state in [State.PATROL, State.INVESTIGATE, State.SEARCH]:
				_spot_player()
			last_seen = player.global_position
			memory_timer = MEMORY

	var speed: float = data["speed"]
	var desired := Vector3.ZERO
	var to_player := Vector3.ZERO
	var dist := 999.0
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0
		dist = to_player.length()
	var face := Vector3.ZERO

	match state:
		State.PATROL:
			if patrol.is_empty():
				desired = Vector3.ZERO
			else:
				var p: Vector3 = patrol[patrol_i]
				if _flat_dist(p) < 1.0:
					patrol_i = (patrol_i + 1) % patrol.size()
				desired = _nav_dir(patrol[patrol_i]) * speed * 0.4
		State.INVESTIGATE:
			desired = _nav_dir(move_target) * speed * 0.75
			if _flat_dist(move_target) < 1.5 or state_t > 15.0:
				_set_state(State.SEARCH)
		State.SEARCH:
			if _flat_dist(move_target) < 1.2 or state_t > 0.0 and fmod(state_t, 3.0) < 0.02:
				move_target = last_seen + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
			desired = _nav_dir(move_target) * speed * 0.5
			if state_t > SEARCH_TIME:
				if is_guard():
					_set_state(State.PATROL)
				elif player:
					# The kids point you out: head to roughly where the player is now.
					alert_to(player.global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
		State.CHASE:
			memory_timer -= delta
			if memory_timer <= 0.0 and not sees_player:
				move_target = last_seen
				_set_state(State.SEARCH)
			elif dist < ENGAGE_RANGE and sees_player:
				_set_state(State.ENGAGE)
			else:
				desired = _nav_dir(last_seen if not sees_player else player.global_position) * speed
				face = to_player
		State.ENGAGE:
			face = to_player
			memory_timer -= delta
			if dist > ENGAGE_RANGE + 1.5 or (memory_timer <= 0.0 and not sees_player):
				_set_state(State.CHASE)
			else:
				if not has_token and attack_timer <= 0.0 and main and main.request_attack_token(self):
					has_token = true
				if has_token:
					if dist > ATTACK_RANGE * 0.9:
						desired = to_player.normalized() * speed
					elif attack_timer <= 0.0:
						_set_state(State.WINDUP)
				else:
					# Circle the player at a distance, waiting for a turn.
					var radial := to_player.normalized()
					var tangent := radial.cross(Vector3.UP) * circle_side
					var keep := (dist - 3.0) * 1.5
					desired = (tangent * speed * 0.45 + radial * keep).limit_length(speed * 0.6)
					if is_on_wall() and state_t > 0.5:
						circle_side = -circle_side
						state_t = 0.0
		State.WINDUP:
			face = to_player
			desired = to_player.normalized() * speed * 0.15
			if state_t >= WINDUP_TIME:
				_strike(dist, to_player)
		State.RECOVER:
			face = to_player
			desired = -to_player.normalized() * speed * 0.3  # back off after swinging
			if state_t >= RECOVER_TIME:
				_release_token()
				attack_timer = data["attack_cd"] * randf_range(0.8, 1.3)
				_set_state(State.ENGAGE)
		State.STAGGER:
			stun_timer -= delta
			if stun_timer <= 0.0:
				_set_state(State.CHASE)
				memory_timer = MEMORY
		State.BLINDED:
			blind_timer -= delta
			if fmod(state_t, 0.8) < delta:
				stumble = stumble.rotated(Vector3.UP, randf_range(-1.5, 1.5))
			desired = stumble * speed * 0.3
			if rig.current_action() == "":
				rig.play("cry", -1.0, 0.1)
			if blind_timer <= 0.0:
				# They lost you: search around where you were standing before.
				move_target = last_seen
				_set_state(State.SEARCH)
		State.FLEE:
			if player:
				desired = -to_player.normalized() * speed * 1.1
			if state_t > 6.0:
				queue_free()
				return

	# Separation so they don't stack into one blob.
	for other in get_tree().get_nodes_in_group("parents"):
		if other == self:
			continue
		var off: Vector3 = global_position - other.global_position
		off.y = 0
		var d := off.length()
		if d < 1.3 and d > 0.01:
			desired += off.normalized() * (1.3 - d) * 4.0

	if face.length() < 0.01 and Vector3(desired.x, 0, desired.z).length() > 0.3:
		face = desired
	if face.length() > 0.01:
		var target_yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 10.0, 1.0))

	if taunt_timer <= 0.0 and state in [State.CHASE, State.ENGAGE]:
		taunt_timer = randf_range(5.0, 9.0)
		var t: Array = data["taunts"]
		_say(t[randi() % t.size()])
		if randf() < 0.4:
			rig.play("talk", 1.2)

	var horiz := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3(desired.x, 0, desired.z), 40.0 * delta)
	velocity.x = horiz.x + knockback.x
	velocity.z = horiz.z + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, 22.0 * delta)
	move_and_slide()
	velocity.x -= knockback.x
	velocity.z -= knockback.z
	rig.tick(delta, horiz.length(), is_on_floor())


func _strike(dist: float, to_player: Vector3) -> void:
	rig.play("swing", 0.35, 0.03)
	Sfx.play_at("whoosh", global_position + Vector3.UP * 1.4, get_parent(), -3.0)
	_set_state(State.RECOVER)
	var fwd := -global_transform.basis.z
	if dist < ATTACK_RANGE + 0.5 and fwd.dot(to_player.normalized()) > 0.4:
		var result: String = player.take_damage(data["damage"], to_player.normalized(), self)
		if result == "parry":
			parried()


func _flat_dist(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


## Direction toward a target, following the navmesh when one is available.
func _nav_dir(target: Vector3) -> Vector3:
	var next := target
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		agent.target_position = target
		next = agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05 or agent.is_navigation_finished():
		dir = target - global_position
		dir.y = 0
	return dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
