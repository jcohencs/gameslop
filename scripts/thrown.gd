extends Node3D
## Something an adult throws in Wave Mode (specs/004): a fastball (straight) or a water
## balloon (arcs, splashes). Sweeps against world + player only (layers 1 and 2), so it can
## never hit kids or other adults.

const MASK := 1 | 2
const GRAVITY := 14.0
const LIFETIME := 5.0

var velocity := Vector3.ZERO
var gravity := 0.0
var damage := 10.0
var splash := 0.0
var kind := "fastball"
var age := 0.0
var done := false


func launch(from: Vector3, vel: Vector3, g: float, dmg: float, splash_r: float, k: String) -> void:
	global_position = from
	velocity = vel
	gravity = g
	damage = dmg
	splash = splash_r
	kind = k
	name = "Thrown"
	add_to_group("thrown")
	if kind == "balloon":
		var b := Shapes.sphere(self, 0.14, Vector3.ZERO, Color(0.3, 0.6, 1.0))
		b.scale = Vector3(1, 1.15, 1)
		b.material_override = Shapes.mat(Color(0.3, 0.6, 1.0), 0.3)
		Shapes.sphere(self, 0.03, Vector3(0, 0.16, 0), Color(0.25, 0.5, 0.9))
		Art.outline(b, 0.01)
	else:
		var ball := Shapes.sphere(self, 0.075, Vector3.ZERO, Color(0.98, 0.98, 0.95))
		Art.outline(ball, 0.008)
		var seam := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.078
		seam.mesh = tm
		seam.material_override = Shapes.mat(Color(0.9, 0.15, 0.15))
		add_child(seam)


func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	velocity.y -= gravity * delta
	var next := global_position + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, next, MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_impact(hit["position"], hit["collider"])
	elif age > LIFETIME:
		queue_free()
	else:
		global_position = next
		rotate_x(delta * 14.0)


func _impact(at: Vector3, collider: Object) -> void:
	done = true
	var dir := Vector3(velocity.x, 0, velocity.z).normalized()
	var player := get_tree().get_first_node_in_group("player")
	var direct: bool = collider != null and collider == player
	if direct:
		player.take_damage(damage, dir, null)
	elif splash > 0.0 and player and player.global_position.distance_to(at) < splash:
		player.take_damage(damage * 0.6, (player.global_position - at).normalized(), null)
	var parent := get_parent()
	if kind == "balloon":
		Art.splash(parent, at, Color(0.45, 0.75, 1.0), maxf(splash, 1.0))
		Sfx.play_at("splat", at, parent)
	else:
		Art.impact_puff(parent, at, Color(1, 1, 0.9), 8)
		Sfx.play_at("punch", at, parent, -4.0)
	queue_free()
