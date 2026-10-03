extends CharacterBody3D
## A playground kid with one trading card. Wanders, trades, cries, runs off.

signal cried(kid: Node)

enum State { WANDER, CRYING, SCAMMED }

const GRAVITY := 18.0
const KID_NAMES := ["Timmy", "Ava", "Brayden", "Kaylee", "Jayden", "Mia", "Noah", "Zoe",
	"Liam", "Emma", "Tucker", "Lily", "Max", "Harper", "Oliver", "Chloe"]
const CRY_LINES := ["WAAAAH! MOMMY!", "I'M TELLING MY DAD!", "THAT WAS MY BEST CARD!", "SCAMMER!!", "MOOOOOM!"]

var kid_name: String
var card: Dictionary
var state := State.WANDER
var target := Vector3.ZERO
var wait := 0.0
var state_timer := 0.0
var bounds := 26.0
var label: Label3D
var shirt_mat: StandardMaterial3D
var player: Node3D


func _ready() -> void:
	add_to_group("kids")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	kid_name = KID_NAMES[randi() % KID_NAMES.size()]
	card = GameState.roll_card()
	var shirt := Color.from_hsv(randf(), 0.7, 0.95)
	var body := Shapes.person(self, 1.15, shirt, Color.from_hsv(0.07, randf_range(0.2, 0.6), randf_range(0.45, 0.95)))
	shirt_mat = body.material_override
	# A little backpack.
	Shapes.box(self, Vector3(0.3, 0.32, 0.14), Vector3(0, 0.6, 0.2), Color.from_hsv(randf(), 0.5, 0.6))
	Shapes.capsule_collider(self, 1.15, 0.22)
	label = Shapes.label(self, "", Vector3(0, 1.55, 0), Color.WHITE, 40)
	_refresh_label()
	_pick_target()


func can_trade() -> bool:
	return state == State.WANDER


func _refresh_label() -> void:
	match state:
		State.WANDER:
			label.text = "%s\n[%s] %s" % [kid_name, GameState.rarity_name(card), card["name"]]
			label.modulate = GameState.rarity_color(card)
		State.CRYING:
			label.text = CRY_LINES[randi() % CRY_LINES.size()]
			label.modulate = Color(0.5, 0.75, 1.0)
		State.SCAMMED:
			label.text = "%s (sad)" % kid_name
			label.modulate = Color(0.55, 0.55, 0.6)


func _pick_target() -> void:
	target = Vector3(randf_range(-bounds, bounds), 0, randf_range(-bounds, bounds))
	wait = randf_range(0.5, 3.0)


func cry() -> void:
	state = State.CRYING
	state_timer = 7.0
	_refresh_label()
	cried.emit(self)


func become_scammed() -> void:
	state = State.SCAMMED
	state_timer = 20.0
	shirt_mat.albedo_color = shirt_mat.albedo_color.lerp(Color(0.4, 0.4, 0.45), 0.7)
	_refresh_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var flat := Vector3.ZERO
	var speed := 2.2
	match state:
		State.WANDER:
			if wait > 0.0:
				wait -= delta
			else:
				flat = target - global_position
				flat.y = 0
				if flat.length() < 0.6 or is_on_wall():
					_pick_target()
					flat = Vector3.ZERO
		State.CRYING:
			speed = 4.5
			state_timer -= delta
			if player:
				flat = global_position - player.global_position
				flat.y = 0
			if is_on_wall():
				flat = flat.rotated(Vector3.UP, PI / 2)
			if state_timer <= 0.0:
				become_scammed()
		State.SCAMMED:
			speed = 1.2
			state_timer -= delta
			flat = target - global_position
			flat.y = 0
			if flat.length() < 0.6:
				_pick_target()
			if state_timer <= 0.0:
				queue_free()
				return
	if flat.length() > 0.01:
		flat = flat.normalized()
		var look := global_position + flat
		look_at(Vector3(look.x, global_position.y, look.z), Vector3.UP)
	velocity.x = flat.x * speed
	velocity.z = flat.z * speed
	# Clamp to the playground.
	global_position.x = clampf(global_position.x, -28.0, 28.0)
	global_position.z = clampf(global_position.z, -28.0, 28.0)
	move_and_slide()
