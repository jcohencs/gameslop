class_name Rig
extends Node3D
## Jointed humanoid built from primitives, animated procedurally.
## Locomotion (walk/run/idle) is computed every frame and an optional action pose
## (windup, swing, flinch, cry, talk, cheer, point, dazed) is blended on top.
##
## Joint conventions (rig faces -Z): positive X rotation swings arms/legs forward,
## elbows bend forward with positive values, knees bend with negative values.
## Shoulder Z: negative moves the left arm outward, positive moves the right arm outward.

const ACTIONS := ["windup", "swing", "flinch", "cry", "talk", "cheer", "point", "dazed", "block"]

var height := 1.8
var hips: Node3D
var torso: Node3D
var head: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var hand_r: Node3D  # attach props here
var hand_l: Node3D
var shirt_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D
var base_shirt: Color

var _leg_len := 0.0
var _phase := 0.0
var _speed := 0.0
var _t := 0.0
var _action := ""
var _action_t := 0.0
var _action_len := -1.0   # < 0 = loop until cleared
var _weight := 0.0
var _fade := 0.12
var _flash := 0.0


func build(h: float, shirt: Color, pants: Color, skin: Color, opts := {}) -> void:
	height = h
	base_shirt = shirt
	shirt_mat = Shapes.mat(shirt)
	skin_mat = Shapes.mat(skin)
	var pants_mat := Shapes.mat(pants)
	var shoe_mat := Shapes.mat(opts.get("shoes", Color(0.12, 0.12, 0.14)))
	var thigh := h * 0.24
	var shin := h * 0.22
	_leg_len = thigh + shin
	var torso_len := h * 0.3
	var upper := h * 0.17
	var fore := h * 0.16
	var limb_r := h * 0.045
	var head_r := h * 0.105
	var girth: float = opts.get("girth", 1.0)

	hips = _pivot(self, Vector3(0, _leg_len, 0))
	torso = _pivot(hips, Vector3.ZERO)
	_part(torso, _capsule(h * 0.12 * girth, torso_len + h * 0.06), Vector3(0, torso_len * 0.5, 0), shirt_mat)
	# Belt line / hips block.
	_part(hips, _box(Vector3(h * 0.22 * girth, h * 0.07, h * 0.14 * girth)), Vector3(0, 0, 0), pants_mat)

	head = _pivot(torso, Vector3(0, torso_len + h * 0.02, 0))
	_part(head, _capsule(h * 0.035, h * 0.06), Vector3(0, h * 0.02, 0), skin_mat) # neck
	_part(head, _sphere(head_r), Vector3(0, head_r + h * 0.03, 0), skin_mat)
	var eye_y := head_r * 1.15 + h * 0.03
	var eye_mat := Shapes.mat(Color(0.05, 0.05, 0.05))
	_part(head, _sphere(head_r * 0.16), Vector3(-head_r * 0.38, eye_y, -head_r * 0.88), eye_mat)
	_part(head, _sphere(head_r * 0.16), Vector3(head_r * 0.38, eye_y, -head_r * 0.88), eye_mat)
	if opts.has("brows"):
		_part(head, _box(Vector3(head_r * 1.3, head_r * 0.12, head_r * 0.15)), Vector3(0, eye_y + head_r * 0.28, -head_r * 0.85),
			Shapes.mat(opts["brows"])).rotation.z = 0.0
	if opts.has("hair"):
		_part(head, _sphere(head_r * 1.05), Vector3(0, head_r * 1.35 + h * 0.03, head_r * 0.12), Shapes.mat(opts["hair"]))
	if opts.has("cap"):
		var cap_mat := Shapes.mat(opts["cap"])
		_part(head, _cylinder(head_r * 1.02, head_r * 0.5), Vector3(0, head_r * 1.75 + h * 0.03, 0), cap_mat)
		_part(head, _box(Vector3(head_r * 1.4, head_r * 0.08, head_r * 1.0)), Vector3(0, head_r * 1.55 + h * 0.03, -head_r * 0.9), cap_mat)
	if opts.has("ears"):
		# Mascot costume: big round ears and a snout.
		var ear_mat := Shapes.mat(opts["ears"])
		for side in [-1, 1]:
			var ear := _part(head, _sphere(head_r * 0.55), Vector3(side * head_r * 0.85, head_r * 1.9 + h * 0.03, 0), ear_mat)
			ear.scale = Vector3(1, 1, 0.35)
			_part(head, _sphere(head_r * 0.32), Vector3(side * head_r * 0.85, head_r * 1.9 + h * 0.03, -head_r * 0.12), Shapes.mat(Color(1.0, 0.7, 0.75)))
		_part(head, _sphere(head_r * 0.42), Vector3(0, head_r * 0.85 + h * 0.03, -head_r * 0.85), ear_mat)
		_part(head, _sphere(head_r * 0.12), Vector3(0, head_r * 0.95 + h * 0.03, -head_r * 1.25), Shapes.mat(Color(0.1, 0.05, 0.05)))
	if opts.has("party_hat"):
		var hat := CylinderMesh.new()
		hat.top_radius = 0.0
		hat.bottom_radius = head_r * 0.45
		hat.height = head_r * 1.1
		_part(head, hat, Vector3(0, head_r * 2.4 + h * 0.03, 0), Shapes.mat(opts["party_hat"]))
	if opts.get("glasses", false):
		_part(head, _box(Vector3(head_r * 1.5, head_r * 0.22, head_r * 0.1)), Vector3(0, eye_y, -head_r * 0.98), Shapes.mat(Color(0.05, 0.05, 0.05)))
	if opts.has("backpack"):
		_part(torso, _box(Vector3(h * 0.2, h * 0.24, h * 0.1)), Vector3(0, torso_len * 0.55, h * 0.12), Shapes.mat(opts["backpack"]))
	if opts.has("badge"):
		_part(torso, _box(Vector3(h * 0.05, h * 0.05, h * 0.02)), Vector3(-h * 0.06, torso_len * 0.75, -h * 0.12), Shapes.mat(opts["badge"], 1.0))
	if opts.has("whistle"):
		_part(torso, _sphere(h * 0.02), Vector3(0, torso_len * 0.8, -h * 0.125), Shapes.mat(opts["whistle"]))

	var sh_w := h * 0.15 * girth
	shoulder_l = _pivot(torso, Vector3(-sh_w, torso_len * 0.92, 0))
	shoulder_r = _pivot(torso, Vector3(sh_w, torso_len * 0.92, 0))
	for side in [shoulder_l, shoulder_r]:
		_part(side, _capsule(limb_r * 1.1, upper + limb_r), Vector3(0, -upper * 0.5, 0), shirt_mat)
	elbow_l = _pivot(shoulder_l, Vector3(0, -upper, 0))
	elbow_r = _pivot(shoulder_r, Vector3(0, -upper, 0))
	for e in [elbow_l, elbow_r]:
		_part(e, _capsule(limb_r, fore + limb_r), Vector3(0, -fore * 0.5, 0), skin_mat)
	hand_l = _pivot(elbow_l, Vector3(0, -fore, 0))
	hand_r = _pivot(elbow_r, Vector3(0, -fore, 0))
	_part(hand_l, _sphere(limb_r * 1.35), Vector3.ZERO, skin_mat)
	_part(hand_r, _sphere(limb_r * 1.35), Vector3.ZERO, skin_mat)

	leg_l = _pivot(hips, Vector3(-h * 0.065 * girth, 0, 0))
	leg_r = _pivot(hips, Vector3(h * 0.065 * girth, 0, 0))
	for leg in [leg_l, leg_r]:
		_part(leg, _capsule(limb_r * 1.3, thigh + limb_r), Vector3(0, -thigh * 0.5, 0), pants_mat)
	knee_l = _pivot(leg_l, Vector3(0, -thigh, 0))
	knee_r = _pivot(leg_r, Vector3(0, -thigh, 0))
	for k in [knee_l, knee_r]:
		_part(k, _capsule(limb_r * 1.15, shin + limb_r), Vector3(0, -shin * 0.5, 0), pants_mat)
		_part(k, _box(Vector3(limb_r * 2.4, limb_r * 1.4, limb_r * 4.0)), Vector3(0, -shin, -limb_r * 0.9), shoe_mat)


# --- Building helpers --------------------------------------------------------

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m

func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _cylinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return m


# --- Animation API -----------------------------------------------------------

## Play an action pose. duration < 0 loops until clear_action() / another action.
func play(action: String, duration := -1.0, fade := 0.12) -> void:
	if action == _action and duration < 0.0 and _action_len < 0.0:
		return
	_action = action
	_action_t = 0.0
	_action_len = duration
	_fade = maxf(fade, 0.01)

func clear_action() -> void:
	_action_len = _action_t  # fade out from now

func current_action() -> String:
	return _action if _weight > 0.01 else ""

func flash(color := Color.WHITE, time := 0.08) -> void:
	_flash = time
	shirt_mat.albedo_color = color
	skin_mat.emission_enabled = true
	skin_mat.emission = color
	skin_mat.emission_energy_multiplier = 0.6


## Call every frame with the horizontal speed in m/s.
func tick(delta: float, speed: float, on_floor := true) -> void:
	_t += delta
	_speed = lerpf(_speed, speed, minf(delta * 10.0, 1.0))
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			shirt_mat.albedo_color = base_shirt
			skin_mat.emission_enabled = false

	# Action weight envelope.
	var target_w := 0.0
	if _action != "":
		_action_t += delta
		target_w = 1.0
		if _action_len >= 0.0 and _action_t >= _action_len:
			target_w = 0.0
	_weight = move_toward(_weight, target_w, delta / _fade)
	if _weight <= 0.0 and target_w == 0.0:
		_action = ""

	var pose := _locomotion(delta, on_floor)
	if _action != "" and _weight > 0.0:
		var act := _action_pose(_action, _action_t)
		var w := _weight * _weight * (3.0 - 2.0 * _weight)  # smoothstep
		for k in act:
			pose[k] = lerpf(pose.get(k, 0.0), act[k], w)
	_apply(pose)


func _locomotion(delta: float, on_floor: bool) -> Dictionary:
	var stride := height * 0.55
	var run := clampf(_speed / (height * 3.5), 0.0, 1.0)  # 0 walk .. 1 run
	_phase += delta * (_speed / maxf(stride, 0.1)) * PI
	var amp := clampf(_speed / 3.0, 0.0, 1.0) * lerpf(0.55, 0.9, run)
	var s := sin(_phase)
	var c := cos(_phase)
	var breathe := sin(_t * 2.2) * 0.03
	var p := {
		"hip_l": s * amp, "hip_r": -s * amp,
		"kn_l": -maxf(0.0, -c) * amp * 1.4 - 0.05, "kn_r": -maxf(0.0, c) * amp * 1.4 - 0.05,
		"sh_l_x": -s * amp * 0.8 + breathe, "sh_r_x": s * amp * 0.8 + breathe,
		"sh_l_z": -0.08 - run * 0.1, "sh_r_z": 0.08 + run * 0.1,
		"el_l": 0.25 + run * 0.9, "el_r": 0.25 + run * 0.9,
		"torso_x": -run * 0.25 - amp * 0.08, "torso_y": s * amp * 0.12, "torso_z": 0.0,
		"head_x": run * 0.15, "head_y": 0.0, "head_z": 0.0,
		"bob": absf(c) * amp * height * 0.03 + breathe * height * 0.05,
	}
	if not on_floor:
		p["hip_l"] = 0.5
		p["hip_r"] = -0.2
		p["kn_l"] = -0.9
		p["kn_r"] = -0.4
		p["sh_l_z"] = -0.6
		p["sh_r_z"] = 0.6
	return p


func _action_pose(action: String, t: float) -> Dictionary:
	match action:
		"windup":
			# Arm cocked back over the shoulder, body twisted away.
			return {"sh_r_x": -2.1, "sh_r_z": 0.35, "el_r": 1.5, "torso_y": 0.5, "torso_x": 0.1,
				"sh_l_x": 0.6, "el_l": 0.8, "head_y": -0.3}
		"swing":
			# Haymaker follow-through.
			var k := clampf(t / 0.12, 0.0, 1.0)
			return {"sh_r_x": lerpf(-2.1, 1.6, k), "sh_r_z": lerpf(0.35, -0.3, k), "el_r": lerpf(1.5, 0.1, k),
				"torso_y": lerpf(0.5, -0.6, k), "torso_x": -0.25, "sh_l_x": -0.4, "head_y": 0.2}
		"flinch":
			var k := 1.0 - clampf(t / 0.3, 0.0, 1.0)
			return {"torso_x": 0.45 * k, "head_x": 0.4 * k, "sh_l_x": 1.2 * k, "sh_r_x": 1.2 * k,
				"el_l": 1.6 * k, "el_r": 1.6 * k, "torso_z": 0.15 * k}
		"cry":
			var shake := sin(t * 28.0) * 0.06
			return {"sh_l_x": 1.35, "sh_r_x": 1.35, "sh_l_z": 0.35, "sh_r_z": -0.35, "el_l": 2.05, "el_r": 2.05,
				"head_x": -0.35 + shake, "torso_x": -0.25, "torso_z": shake}
		"talk":
			return {"sh_r_x": 0.7 + sin(t * 6.0) * 0.35, "el_r": 1.3 + sin(t * 6.0 + 1.0) * 0.3, "sh_r_z": -0.2,
				"head_x": sin(t * 5.0) * 0.12, "head_y": sin(t * 1.3) * 0.25}
		"cheer":
			var bounce := absf(sin(t * 9.0))
			return {"sh_l_x": 2.8, "sh_r_x": 2.8, "sh_l_z": -0.4, "sh_r_z": 0.4, "el_l": 0.3 * bounce, "el_r": 0.3 * bounce,
				"bob": bounce * height * 0.06, "head_x": 0.25}
		"point":
			return {"sh_r_x": 1.55, "el_r": 0.0, "sh_r_z": 0.1, "torso_y": -0.2, "sh_l_x": 0.3, "sh_l_z": 0.4, "el_l": 1.8}
		"dazed":
			return {"torso_z": sin(t * 7.0) * 0.18, "torso_x": cos(t * 7.0) * 0.12 + 0.1, "head_z": sin(t * 7.0 + 1.0) * 0.3,
				"sh_l_z": -0.5, "sh_r_z": 0.5, "el_l": 0.2, "el_r": 0.2, "kn_l": -0.25, "kn_r": -0.25}
		"block":
			return {"sh_l_x": 1.5, "sh_r_x": 1.5, "sh_l_z": 0.45, "sh_r_z": -0.45, "el_l": 1.9, "el_r": 1.9, "torso_x": -0.15}
	return {}


func _apply(p: Dictionary) -> void:
	hips.position.y = _leg_len + p.get("bob", 0.0)
	torso.rotation = Vector3(p.get("torso_x", 0.0), p.get("torso_y", 0.0), p.get("torso_z", 0.0))
	head.rotation = Vector3(p.get("head_x", 0.0), p.get("head_y", 0.0), p.get("head_z", 0.0))
	shoulder_l.rotation = Vector3(p.get("sh_l_x", 0.0), 0, p.get("sh_l_z", 0.0))
	shoulder_r.rotation = Vector3(p.get("sh_r_x", 0.0), 0, p.get("sh_r_z", 0.0))
	elbow_l.rotation.x = p.get("el_l", 0.0)
	elbow_r.rotation.x = p.get("el_r", 0.0)
	leg_l.rotation.x = p.get("hip_l", 0.0)
	leg_r.rotation.x = p.get("hip_r", 0.0)
	knee_l.rotation.x = p.get("kn_l", 0.0)
	knee_r.rotation.x = p.get("kn_r", 0.0)
