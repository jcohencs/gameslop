extends Node3D
## Rubber Chicken Launcher round (Wave Mode, specs/004): an arcing squeaky chicken that bursts
## into feathers and splash-knocks adults. Only world + adults are swept (layers 1 and 8), and
## splash only ever touches the "parents" group, so kids are never affected.

const MASK := 1 | 8
const GRAVITY := 9.0
const LIFETIME := 4.0

var velocity := Vector3.ZERO
var damage := 110.0
var radius := 4.0
var knock := 12.0
var shooter: CollisionObject3D
var age := 0.0
var exploded := false
var _spin := 0.0


func launch(from: Vector3, direction: Vector3, b: Dictionary, by: CollisionObject3D) -> void:
	global_position = from
	velocity = direction.normalized() * float(b.get("speed", 26.0)) + Vector3(0, 1.5, 0)
	damage = b["damage"]
	radius = b.get("splash", 4.0)
	knock = b["knock"]
	shooter = by
	name = "Chicken"
	# A rubber chicken: yellow body, head, red comb, orange beak.
	var body := Shapes.capsule(self, 0.09, 0.32, Vector3.ZERO, Color(1.0, 0.85, 0.15))
	body.rotation.x = PI / 2
	Shapes.sphere(self, 0.075, Vector3(0, 0.07, -0.17), Color(1.0, 0.88, 0.2))
	Shapes.box(self, Vector3(0.02, 0.06, 0.08), Vector3(0, 0.15, -0.17), Color(0.95, 0.15, 0.15))
	var beak := Shapes.cylinder(self, 0.0, 0.07, Vector3(0, 0.06, -0.25), Color(1.0, 0.5, 0.1))
	(beak.mesh as CylinderMesh).bottom_radius = 0.03
	beak.rotation.x = -PI / 2
	for c in get_children():
		if c is GeometryInstance3D:
			Art.outline(c, 0.008)


func _physics_process(delta: float) -> void:
	if exploded:
		return
	age += delta
	velocity.y -= GRAVITY * delta
	var next := global_position + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, next, MASK)
	if shooter:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		explode(hit["position"])
	elif age > LIFETIME:
		explode(global_position)
	else:
		if velocity.length() > 0.1:
			look_at(next, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)
		_spin += delta * 12.0
		rotate_object_local(Vector3.FORWARD, _spin)
		global_position = next


func explode(at: Vector3) -> void:
	exploded = true
	var main := get_tree().get_first_node_in_group("main")
	var hit := 0
	for p in get_tree().get_nodes_in_group("parents"):
		var d: float = p.global_position.distance_to(at)
		if d < radius + p.radius:
			var falloff := 1.0 - clampf(d / radius, 0.0, 1.0) * 0.6
			var away: Vector3 = p.global_position - at
			p.shot(damage * falloff, Vector3(away.x, 0, away.z).normalized(), knock * falloff, false, "chicken")
			if main:
				main.on_shot_hit(p, p.global_position + Vector3(0, p.data["height"] * 0.7, 0), damage * falloff, false, "chicken")
			hit += 1
	if main:
		main.spawn_explosion(at, radius)
	queue_free()
