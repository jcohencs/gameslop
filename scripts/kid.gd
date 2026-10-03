extends CharacterBody3D
## A kid with one trading card. Hangs out at points of interest, chats with other kids,
## gets wary after witnessing a scam, cheers at fights, flees danger, and runs crying to
## the nearest grown-up when scammed.

signal cried(kid: Node)

enum State { WANDER, HANGOUT, TALKING, CRYING, SCAMMED, FLEE }

const GRAVITY := 18.0
const KID_NAMES := ["Timmy", "Ava", "Brayden", "Kaylee", "Jayden", "Mia", "Noah", "Zoe",
	"Liam", "Emma", "Tucker", "Lily", "Max", "Harper", "Oliver", "Chloe", "Dakota", "Milo"]
const CRY_LINES := ["WAAAAH! MOMMY!", "I'M TELLING MY DAD!", "THAT WAS MY BEST CARD!", "SCAMMER!!", "MOOOOOM!"]
const CHEER_LINES := ["FIGHT! FIGHT!", "WORLDSTAR!", "OHHHHH!", "Get him, mom!"]

var kid_name: String
var card: Dictionary
var state := State.WANDER
var target := Vector3.ZERO
var state_timer := 0.0
var bounds := Rect2(-24, -24, 48, 48)  # x/z wander area, set by the level
var pois: Array = []                    # hangout spots, set by the level
var rarity_bonus := 0.0
var wary := 0.0                         # > 0 after witnessing a scam
var cheering := 0.0
var label: Label3D
var rig: Rig
var agent: NavigationAgent3D
var player: Node3D
var think := 0.0
var friend: Node = null


func _ready() -> void:
	add_to_group("kids")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	kid_name = KID_NAMES[randi() % KID_NAMES.size()]
	card = GameState.roll_card(rarity_bonus)
	var opts := {"backpack": Color.from_hsv(randf(), 0.5, 0.6)}
	if randf() < 0.5:
		opts["hair"] = Color.from_hsv(randf_range(0.03, 0.12), 0.6, randf_range(0.15, 0.9))
	elif randf() < 0.5:
		opts["cap"] = Color.from_hsv(randf(), 0.7, 0.8)
	if randf() < 0.2:
		opts["glasses"] = true
	rig = Rig.new()
	add_child(rig)
	rig.build(1.15, Color.from_hsv(randf(), 0.7, 0.95), Color.from_hsv(randf(), 0.4, 0.5),
		Color.from_hsv(0.07, randf_range(0.2, 0.6), randf_range(0.45, 0.95)), opts)
	Shapes.capsule_collider(self, 1.15, 0.22)
	agent = NavigationAgent3D.new()
	agent.radius = 0.3
	agent.height = 1.15
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.6
	add_child(agent)
	label = Shapes.label(self, "", Vector3(0, 1.5, 0), Color.WHITE, 26)
	_refresh_label()
	_pick_target()


func can_trade() -> bool:
	return state in [State.WANDER, State.HANGOUT, State.TALKING]


func _refresh_label() -> void:
	match state:
		State.CRYING:
			label.text = CRY_LINES[randi() % CRY_LINES.size()]
			label.modulate = Color(0.5, 0.75, 1.0)
		State.SCAMMED:
			label.text = "%s (sad)" % kid_name
			label.modulate = Color(0.55, 0.55, 0.6)
		State.FLEE:
			label.text = "AAAH!"
			label.modulate = Color(1, 0.8, 0.6)
		_:
			var w := "  (!) wary" if wary > 0.0 else ""
			label.text = "%s%s\n[%s] %s" % [kid_name, w, GameState.rarity_name(card), card["name"]]
			label.modulate = GameState.rarity_color(card)


func _pick_target() -> void:
	if not pois.is_empty() and randf() < 0.7:
		var p: Vector3 = pois[randi() % pois.size()]
		target = p + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	else:
		target = Vector3(randf_range(bounds.position.x, bounds.end.x), 0, randf_range(bounds.position.y, bounds.end.y))
	state = State.WANDER


## Saw the player scam someone nearby.
func witness() -> void:
	if not can_trade():
		return
	wary = 30.0
	rig.play("point", 0.8)
	_refresh_label()


## The player opened the trade menu with this kid.
func start_talking() -> void:
	if can_trade():
		state = State.TALKING
		rig.play("talk")


func stop_talking() -> void:
	if state == State.TALKING:
		state = State.HANGOUT
		state_timer = randf_range(1.0, 3.0)
		rig.clear_action()


func cry() -> void:
	state = State.CRYING
	state_timer = 8.0
	rig.play("cry")
	_refresh_label()
	cried.emit(self)
	Sfx.play_at("fail", global_position + Vector3.UP, get_parent(), -8.0)


func become_scammed() -> void:
	state = State.SCAMMED
	state_timer = 20.0
	rig.base_shirt = rig.base_shirt.lerp(Color(0.4, 0.4, 0.45), 0.6)
	rig.shirt_mat.albedo_color = rig.base_shirt
	rig.play("cry", 1.5)
	_pick_target()
	state = State.SCAMMED
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if wary > 0.0:
		wary -= delta
		if wary <= 0.0:
			_refresh_label()
	cheering -= delta

	think -= delta
	if think <= 0.0:
		think = 0.25
		_think()

	var speed := 2.0
	var dest := global_position
	var face := Vector3.ZERO
	match state:
		State.WANDER:
			dest = target
			if _flat_dist(target) < 0.8:
				state = State.HANGOUT
				state_timer = randf_range(3.0, 8.0)
				_find_friend()
		State.HANGOUT:
			state_timer -= delta
			if friend and is_instance_valid(friend):
				face = friend.global_position - global_position
			if cheering > 0.0 and player:
				face = player.global_position - global_position
			if state_timer <= 0.0:
				rig.clear_action()
				friend = null
				_pick_target()
		State.TALKING:
			if player:
				face = player.global_position - global_position
		State.CRYING:
			speed = 4.2
			state_timer -= delta
			var grown_up := _nearest_parent()
			if grown_up:
				dest = grown_up.global_position
				if _flat_dist(dest) < 2.0:
					dest = global_position
			elif player:
				dest = global_position + (global_position - player.global_position).normalized() * 4.0
			if state_timer <= 0.0:
				become_scammed()
		State.SCAMMED:
			speed = 1.1
			state_timer -= delta
			dest = target
			if _flat_dist(target) < 0.8:
				_pick_target()
				state = State.SCAMMED
			if state_timer <= 0.0:
				queue_free()
				return
		State.FLEE:
			speed = 4.5
			state_timer -= delta
			dest = target
			if state_timer <= 0.0:
				rig.clear_action()
				_pick_target()

	var dir := Vector3.ZERO
	if _flat_dist(dest) > 0.3:
		var next := dest
		if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			agent.target_position = dest
			next = agent.get_next_path_position()
		dir = next - global_position
		dir.y = 0
		if dir.length() < 0.05:
			dir = dest - global_position
			dir.y = 0
		dir = dir.normalized()
	if face.length() < 0.01:
		face = dir
	if face.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), minf(delta * 8.0, 1.0))
	var horiz := Vector3(velocity.x, 0, velocity.z).move_toward(dir * speed, 25.0 * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()
	# Stay inside the level.
	global_position.x = clampf(global_position.x, bounds.position.x - 2.0, bounds.end.x + 2.0)
	global_position.z = clampf(global_position.z, bounds.position.y - 2.0, bounds.end.y + 2.0)
	rig.tick(delta, horiz.length(), is_on_floor())


func _think() -> void:
	if not (state in [State.WANDER, State.HANGOUT]):
		return
	# React to nearby fights: flee if close, cheer if it's a safe distance away.
	for p in get_tree().get_nodes_in_group("parents"):
		if not p.is_fighting():
			continue
		var d := global_position.distance_to(p.global_position)
		if d < 4.5:
			state = State.FLEE
			state_timer = 2.0
			target = global_position + (global_position - p.global_position).normalized() * 6.0
			_refresh_label()
			return
		if d < 13.0 and cheering <= 0.0 and randf() < 0.3:
			state = State.HANGOUT
			state_timer = 3.0
			cheering = 3.0
			rig.play("cheer", 2.5)
			label.text = CHEER_LINES[randi() % CHEER_LINES.size()]
			get_tree().create_timer(2.5).timeout.connect(_refresh_label)
			return


func _find_friend() -> void:
	friend = null
	for k in get_tree().get_nodes_in_group("kids"):
		if k != self and k.state == State.HANGOUT and global_position.distance_to(k.global_position) < 3.0:
			friend = k
			break
	if friend and randf() < 0.7:
		rig.play("talk", state_timer)


func _nearest_parent() -> Node3D:
	var best: Node3D = null
	var best_d := 30.0
	for p in get_tree().get_nodes_in_group("parents"):
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _flat_dist(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()
