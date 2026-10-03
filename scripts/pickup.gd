extends Node3D
## Wave Mode pickup dropped by a knocked-out adult: a box of foam darts (ammo for every blaster)
## or a juice box (health). Bobs and spins, blinks before it expires.

const RADIUS := 1.5
const HEAL := 25.0

var kind := "ammo"
var life := 20.0
var main: Node
var _t := 0.0
var _model: Node3D


func _ready() -> void:
	add_to_group("pickups")
	name = "Pickup"
	_model = Node3D.new()
	add_child(_model)
	if kind == "health":
		# Juice box with a straw.
		Shapes.box(_model, Vector3(0.22, 0.32, 0.14), Vector3.ZERO, Color(0.55, 0.3, 0.85))
		Shapes.box(_model, Vector3(0.23, 0.12, 0.15), Vector3(0, 0.02, 0), Color(1.0, 0.6, 0.2))
		var straw := Shapes.cylinder(_model, 0.012, 0.18, Vector3(0.05, 0.22, 0), Color(1, 1, 1))
		straw.rotation.z = -0.3
	else:
		Shapes.box(_model, Vector3(0.36, 0.2, 0.24), Vector3.ZERO, Color(1.0, 0.55, 0.1))
		Shapes.box(_model, Vector3(0.37, 0.06, 0.25), Vector3(0, 0.03, 0), Color(0.2, 0.45, 1.0))
		for i in 3:
			var d := Shapes.cylinder(_model, 0.02, 0.12, Vector3(-0.08 + i * 0.08, 0.15, 0), Color(1.0, 0.6, 0.15))
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in _model.get_children():
		if c is GeometryInstance3D:
			Art.outline(c, 0.01)
	var glow := Shapes.cylinder(self, 0.45, 0.02, Vector3(0, -0.45, 0), Color.WHITE)
	glow.material_override = Art.glow_mat(Color(0.4, 1.0, 0.5, 0.45) if kind == "health" else Color(1.0, 0.75, 0.3, 0.45), 1.5)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	_model.position.y = sin(_t * 3.0) * 0.08
	_model.rotation.y += delta * 2.0
	_model.visible = life > 4.0 or fmod(_t, 0.3) < 0.18
	if life <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position - Vector3(0, 0.5, 0)) < RADIUS:
		collect(player)


func collect(player: Node) -> void:
	if kind == "health":
		GameState.health = minf(GameState.max_health(), GameState.health + HEAL)
		GameState.changed.emit()
		Art.pop_word(get_parent(), global_position + Vector3(0, 0.6, 0), "+%d HP" % HEAL, Color(0.5, 1, 0.55), 70)
	else:
		if player.get("gunplay"):
			player.gunplay.add_ammo_pack()
		Art.pop_word(get_parent(), global_position + Vector3(0, 0.6, 0), "+AMMO", Color(1.0, 0.8, 0.3), 70)
	Sfx.play("pickup")
	queue_free()
