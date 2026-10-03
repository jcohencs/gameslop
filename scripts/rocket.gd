extends Node3D
## Bake-Sale Bazooka projectile. Splash-damages parents on impact.

const SPEED := 32.0
const RADIUS := 4.5
const LIFETIME := 3.0
const MASK := 1 | 8

var dir := Vector3.FORWARD
var damage := 100.0
var shooter: CollisionObject3D
var age := 0.0
var exploded := false


func launch(from: Vector3, direction: Vector3, dmg: float, by: CollisionObject3D) -> void:
	global_position = from
	dir = direction
	damage = dmg
	shooter = by
	var body := Shapes.cylinder(self, 0.09, 0.5, Vector3.ZERO, Color(0.9, 0.85, 0.7))
	body.rotation.x = PI / 2
	# Glowing "cupcake" warhead.
	var tip := Shapes.sphere(self, 0.13, Vector3(0, 0, -0.28), Color(1.0, 0.4, 0.7))
	tip.material_override = Shapes.mat(Color(1.0, 0.4, 0.7), 2.0)
	look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	if exploded:
		return
	age += delta
	var next := global_position + dir * SPEED * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, next, MASK)
	if shooter:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		explode(hit["position"])
	elif age > LIFETIME:
		explode(global_position)
	else:
		global_position = next


func explode(at: Vector3) -> void:
	exploded = true
	for p in get_tree().get_nodes_in_group("parents"):
		var d: float = p.global_position.distance_to(at)
		if d < RADIUS:
			var falloff := 1.0 - d / RADIUS * 0.6
			p.take_damage(damage * falloff, (p.global_position - at).normalized())
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.spawn_explosion(at, RADIUS)
	queue_free()
