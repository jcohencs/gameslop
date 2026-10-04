extends Node3D
## A realistic first-person hand (specs/005). The skin is one continuous, anatomically shaped mesh
## generated from a signed distance field (scripts/hand_mesh.gd) and skinned to a 16-bone
## skeleton, so fingers bend smoothly like real skin. Curved glossy nails ride on the fingertip
## bones; a folded cloth sleeve, rolled cuff and a digital watch (left wrist) finish the forearm.
## Fingers blend between data-driven poses, clench on punches, squeeze the trigger on shots and
## idle with tiny movements.
##
## Frame: the wrist is at +Z, fingers point -Z when open, +Y is the back of the hand (the palm
## faces -Y). side = 1 for the right hand (thumb toward -X), -1 for the left.

const HandMesh := preload("res://scripts/hand_mesh.gd")

const SPREAD_K := [1.5, 0.5, -0.5, -1.5]
const BLEND := 16.0
## Fist center in model space: grips are oriented around this point.
const FIST_CENTER := Vector3(0, -0.014, -0.05)

## Curl (radians) per joint for index, middle, ring, pinky; thumb [metacarpal, proximal, distal].
const POSES := {
	"open": {"f": [[0.08, 0.1, 0.06], [0.06, 0.08, 0.05], [0.08, 0.1, 0.06], [0.1, 0.12, 0.08]], "thumb": [0.1, 0.08, 0.05], "spread": 0.1},
	"relaxed": {"f": [[0.3, 0.45, 0.3], [0.35, 0.5, 0.32], [0.42, 0.55, 0.35], [0.5, 0.62, 0.4]], "thumb": [0.25, 0.25, 0.2], "spread": 0.04},
	"fist": {"f": [[1.5, 1.62, 1.0], [1.55, 1.65, 1.0], [1.58, 1.65, 1.0], [1.6, 1.62, 0.95]], "thumb": [0.55, 0.95, 0.65], "spread": -0.02},
	"tight": {"f": [[1.62, 1.75, 1.1], [1.65, 1.78, 1.1], [1.68, 1.75, 1.1], [1.7, 1.72, 1.05]], "thumb": [0.65, 1.05, 0.75], "spread": -0.03},
	"grip": {"f": [[1.25, 1.45, 0.95], [1.3, 1.48, 0.95], [1.35, 1.5, 0.95], [1.4, 1.5, 0.9]], "thumb": [0.45, 0.6, 0.45], "spread": 0.0},
	"trigger": {"f": [[0.45, 0.9, 0.55], [1.3, 1.5, 0.95], [1.35, 1.52, 0.95], [1.4, 1.5, 0.9]], "thumb": [0.4, 0.55, 0.35], "spread": 0.0},
	"support": {"f": [[0.75, 0.95, 0.6], [0.8, 1.0, 0.62], [0.85, 1.0, 0.62], [0.9, 1.0, 0.6]], "thumb": [0.3, 0.35, 0.25], "spread": 0.03},
	"throw": {"f": [[0.0, 0.02, 0.0], [-0.03, 0.0, 0.0], [0.0, 0.02, 0.0], [0.05, 0.05, 0.02]], "thumb": [-0.1, 0.0, 0.0], "spread": 0.2},
}

static var _skin: StandardMaterial3D
static var _nail: StandardMaterial3D
static var _fabric: StandardMaterial3D
static var _steel: StandardMaterial3D

var side := 1.0
var model: Node3D               # oriented per grip; everything else hangs off it
var skeleton: Skeleton3D
var skin_mesh: MeshInstance3D
var knuckle_anchor: Node3D      # accessories (brass knuckles, gauntlet) attach here
var palm_anchor: Node3D         # held items (sand pouch) attach here
var fingers: Array = []         # [[bone, bone, bone], ...] index..pinky
var thumb: Array = []           # [metacarpal, proximal, distal] bones
var pose := "relaxed"
var squeeze_t := 0.0
var pulse_t := 0.0
var _rest_local: Array = []     # per bone, rest transform relative to its parent
var _applied: Array = []        # per finger, the three curl angles last applied
var _cur := {}
var _target := {}
var _t := 0.0


func _ready() -> void:
	name = "Hand"
	scale = Vector3.ONE * 1.18
	model = Node3D.new()
	add_child(model)
	_build_skeleton()
	_build_forearm()
	knuckle_anchor = Node3D.new()
	knuckle_anchor.position = Vector3(0, 0.004, -0.058)
	model.add_child(knuckle_anchor)
	palm_anchor = Node3D.new()
	palm_anchor.position = Vector3(0, -0.032, -0.03)
	model.add_child(palm_anchor)
	_target = POSES["relaxed"].duplicate(true)
	_cur = POSES["relaxed"].duplicate(true)
	_apply(0.0)


# --- Materials ------------------------------------------------------------------

## Fine bumpy normal map from value noise (pores, cloth weave).
static func _detail_normal(period: int, seed_: int, strength: float) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var h := Art._vnoise(u, v, period, seed_) * 0.6 + Art._vnoise(u, v, period * 3, seed_ + 1) * 0.4
			img.set_pixel(x, y, Color(h, h, h))
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Skin: painted per vertex (tone variation, knuckles, creases, veins) with a soft subsurface
## glow. (A pore normal map was tried and dropped: at viewmodel distance it only read as fuzz.)
static func skin_mat() -> StandardMaterial3D:
	if _skin == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_color = Color(1, 1, 1)
		m.roughness = 0.58
		m.metallic_specular = 0.32
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.35
		m.subsurf_scatter_skin_mode = true
		_skin = m
	return _skin


static func nail_mat() -> StandardMaterial3D:
	if _nail == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.18
		m.metallic_specular = 0.6
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		m.clearcoat_roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_nail = m
	return _nail


static func fabric_mat() -> StandardMaterial3D:
	if _fabric == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.22, 0.19)
		m.roughness = 0.92
		m.normal_enabled = true
		m.normal_texture = _detail_normal(96, 91, 3.5)
		m.normal_scale = 0.5
		m.uv1_scale = Vector3(2, 6, 1)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_fabric = m
	return _fabric


static func steel_mat() -> StandardMaterial3D:
	if _steel == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.32, 0.33, 0.35)
		m.metallic = 0.85
		m.roughness = 0.3
		_steel = m
	return _steel


# --- Skeleton and skin ----------------------------------------------------------------

func _mirror(t: Transform3D) -> Transform3D:
	if side > 0.0:
		return t
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return Transform3D(m * t.basis * m, Vector3(-t.origin.x, t.origin.y, t.origin.z))


func _build_skeleton() -> void:
	var sk := HandMesh.skeleton_rest()
	var rest: Array = sk["rest"]
	var parent: Array = sk["parent"]
	skeleton = Skeleton3D.new()
	model.add_child(skeleton)
	var glob := []
	for i in rest.size():
		glob.append(_mirror(rest[i]))
	var skin := Skin.new()
	for i in rest.size():
		skeleton.add_bone("b%d" % i)
		var local: Transform3D = glob[i]
		if parent[i] >= 0:
			skeleton.set_bone_parent(i, parent[i])
			local = (glob[parent[i]] as Transform3D).affine_inverse() * glob[i]
		skeleton.set_bone_rest(i, local)
		skeleton.reset_bone_pose(i)
		_rest_local.append(local)
		skin.add_bind(i, (glob[i] as Transform3D).affine_inverse())
	fingers.clear()
	for f in 4:
		fingers.append([1 + f * 3, 2 + f * 3, 3 + f * 3])
		_applied.append([0.0, 0.0, 0.0])
	thumb = [13, 14, 15]
	var meshes: Array = HandMesh.meshes()
	skin_mesh = MeshInstance3D.new()
	skin_mesh.name = "Skin"
	skin_mesh.mesh = meshes[0] if side > 0.0 else meshes[1]
	skin_mesh.material_override = skin_mat()
	skin_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skin_mesh.extra_cull_margin = 0.5
	skeleton.add_child(skin_mesh)
	skin_mesh.skin = skin
	skin_mesh.skeleton = NodePath("..")
	for spot in meshes[2]:
		_add_nail(spot)


## A curved nail plate with a pale lunula at the base and a whiter free edge.
func _add_nail(spot: Array) -> void:
	var bone: int = spot[0]
	var surf: Vector3 = spot[1]
	var w: float = spot[2]
	var l: float = spot[3]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 7
	var nz := 7
	var pts := []
	for iz in nz:
		var row := []
		for ix in nx:
			var u := float(ix) / (nx - 1) * 2.0 - 1.0
			var v := float(iz) / (nz - 1)
			var x := u * w * 0.5
			var z := (0.5 - v) * l
			var y := -u * u * w * 0.28 + 0.0007
			var tip := clampf((v - 0.82) / 0.18, 0.0, 1.0)
			var lun := clampf(1.0 - v / 0.22, 0.0, 1.0) * clampf(1.0 - absf(u) * 1.2, 0.0, 1.0)
			var c := Color(0.92, 0.72, 0.68).lerp(Color(0.98, 0.94, 0.9), maxf(tip, lun * 0.8))
			row.append([Vector3(x, y, z), c])
		pts.append(row)
	for iz in nz - 1:
		for ix in nx - 1:
			for q in [[iz, ix], [iz + 1, ix], [iz + 1, ix + 1], [iz, ix], [iz + 1, ix + 1], [iz, ix + 1]]:
				var pt: Array = pts[q[0]][q[1]]
				st.set_color(pt[1])
				st.add_vertex(pt[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = nail_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var att := BoneAttachment3D.new()
	skeleton.add_child(att)
	att.bone_idx = bone
	att.add_child(mi)
	var p := surf
	p.x *= side
	mi.position = p
	mi.rotation.x = -0.06


# --- Forearm -------------------------------------------------------------------------

## Lofted cloth sleeve with folds, a rolled cuff, and (left wrist) a digital watch.
func _build_forearm() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 22
	var segs := 28
	var grid := []
	for i in rings:
		var t := float(i) / (rings - 1)
		var z := lerpf(0.118, 0.56, t)
		var row := []
		for j in segs + 1:
			var a := float(j) / segs * TAU
			var fold := 0.05 * sin(a * 3.0 + t * 9.0) * (1.0 - t * 0.5) + 0.035 * (Art._vnoise(a / TAU * 3.0, t * 4.0, 3, 17) - 0.5) * 2.0
			var r := lerpf(0.035, 0.046, t) * (1.0 + fold)
			row.append([Vector3(cos(a) * r * 1.12, sin(a) * r * 0.9 - 0.002, z), Vector2(float(j) / segs, t)])
		grid.append(row)
	for i in rings - 1:
		for j in segs:
			for q in [[i, j], [i, j + 1], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i + 1, j]]:
				var pt: Array = grid[q[0]][q[1]]
				st.set_uv(pt[1])
				st.add_vertex(pt[0])
	st.generate_normals()
	st.generate_tangents()
	var sleeve := MeshInstance3D.new()
	sleeve.name = "Sleeve"
	sleeve.mesh = st.commit()
	sleeve.material_override = fabric_mat()
	sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(sleeve)
	# Rolled cuff: a fat ring at the sleeve's edge.
	var cuff := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.029
	tm.outer_radius = 0.041
	tm.rings = 32
	tm.ring_segments = 12
	cuff.mesh = tm
	cuff.material_override = fabric_mat()
	cuff.position = Vector3(0, -0.002, 0.123)
	cuff.rotation.x = PI / 2
	cuff.scale = Vector3(1.12, 1.0, 0.92)
	cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(cuff)
	if side < 0.0:
		_build_watch()


func _build_watch() -> void:
	var w := Node3D.new()
	w.name = "Watch"
	w.position = Vector3(0, 0, 0.098)
	model.add_child(w)
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0255
	tm.outer_radius = 0.0285
	tm.rings = 32
	band.mesh = tm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.08, 0.08, 0.09)
	bm.roughness = 0.6
	band.material_override = bm
	band.rotation.x = PI / 2
	band.scale = Vector3(1.12, 1.0, 0.78)
	w.add_child(band)
	var case_mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0145
	cm.bottom_radius = 0.0155
	cm.height = 0.008
	case_mi.mesh = cm
	case_mi.material_override = steel_mat()
	case_mi.position = Vector3(0, 0.0235, 0)
	w.add_child(case_mi)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0115
	fm.bottom_radius = 0.0115
	fm.height = 0.002
	face.mesh = fm
	var lcd := StandardMaterial3D.new()
	lcd.albedo_color = Color(0.25, 0.3, 0.22)
	lcd.emission_enabled = true
	lcd.emission = Color(0.35, 0.85, 0.45)
	lcd.emission_energy_multiplier = 0.6
	lcd.roughness = 0.05
	face.material_override = lcd
	face.position = Vector3(0, 0.0275, 0)
	w.add_child(face)
	for i in 3:
		var btn := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.003, 0.0025, 0.004)
		btn.mesh = b
		btn.material_override = steel_mat()
		btn.position = Vector3((0.016 if i < 2 else -0.016), 0.0235, -0.004 + (i % 2) * 0.008)
		w.add_child(btn)


# --- Grip orientation ------------------------------------------------------------------

## Orients the whole hand + forearm with a basis expressed in the arm's frame, keeping the fist
## centered on the arm pivot (so held props and arm poses stay put).
func orient(b: Basis) -> void:
	model.transform = Transform3D(b, -(b * FIST_CENTER))


## Basis presets. Punch: rolled inward and tipped up so the curled fingers show. Thumb up: a
## pistol or sword grip with the palm facing inward. Palm up: the support hand (left).
func punch_basis() -> Basis:
	return Basis(Vector3(0, 0, 1), -0.75 * side) * Basis(Vector3(1, 0, 0), 0.15)


func thumb_up_basis() -> Basis:
	var x := Vector3(0, -side, 0)
	var y := Vector3(side, 0, 0)
	return Basis(x, y, x.cross(y))


static func palm_up_basis() -> Basis:
	var z := Vector3(-0.55, -0.4, 0.75).normalized()
	var y := Vector3(0, -1, 0)
	y = (y - z * y.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


func clear_accessories() -> void:
	for a in [knuckle_anchor, palm_anchor]:
		for c in a.get_children():
			c.queue_free()
	model.visible = true


# --- Poses --------------------------------------------------------------------------

func set_pose(p: String, instant := false) -> void:
	if not POSES.has(p):
		return
	pose = p
	_target = POSES[p].duplicate(true)
	if instant:
		_cur = POSES[p].duplicate(true)
		_apply(_t)


## Trigger pull: the index finger curls in for a moment.
func squeeze() -> void:
	squeeze_t = 1.0


## Punch clench: every finger tightens for a moment.
func pulse() -> void:
	pulse_t = 1.0


## Total curl of finger i (0 = index) across its three joints, for tests.
func finger_curl(i: int) -> float:
	var a: Array = _applied[i]
	return a[0] + a[1] + a[2]


func _process(delta: float) -> void:
	_t += delta
	squeeze_t = move_toward(squeeze_t, 0.0, delta * 6.0)
	pulse_t = move_toward(pulse_t, 0.0, delta * 5.0)
	var k := minf(delta * BLEND, 1.0)
	for i in 4:
		for j in 3:
			_cur["f"][i][j] = lerpf(_cur["f"][i][j], _target["f"][i][j], k)
	for j in 3:
		_cur["thumb"][j] = lerpf(_cur["thumb"][j], _target["thumb"][j], k)
	_cur["spread"] = lerpf(_cur["spread"], _target["spread"], k)
	_apply(_t)


func _bone(b: int, curl: float, spread := 0.0) -> void:
	var rb: Basis = (_rest_local[b] as Transform3D).basis
	var r := rb * Basis(Vector3.UP, spread) * Basis(Vector3.RIGHT, -curl)
	skeleton.set_bone_pose_rotation(b, r.get_rotation_quaternion())


func _apply(t: float) -> void:
	for i in fingers.size():
		var c: Array = _cur["f"][i]
		var idle := sin(t * 1.3 + i * 1.7) * 0.025
		var extra := pulse_t * 0.12
		if i == 0:
			extra += squeeze_t * 0.55
		var a0: float = c[0] + idle + extra
		var a1: float = c[1] + idle * 0.6 + extra
		var a2: float = c[2] + extra * 0.6
		_bone(fingers[i][0], a0, _cur["spread"] * SPREAD_K[i] * side)
		_bone(fingers[i][1], a1)
		_bone(fingers[i][2], a2)
		_applied[i] = [a0, a1, a2]
	var tc: Array = _cur["thumb"]
	_bone(thumb[0], tc[0] + pulse_t * 0.08)
	_bone(thumb[1], tc[1])
	_bone(thumb[2], tc[2])
