extends Node3D
## A realistic first-person hand (specs/005), built entirely in code: palm with thenar pads,
## four three-segment fingers and a three-segment thumb with knuckles and nails, a fingerless
## tactical glove with knuckle armor and a wrist strap. Fingers blend between data-driven poses,
## clench on punches, squeeze the trigger on shots and idle with tiny movements.
##
## Frame: the wrist is at +Z, fingers point -Z when open, +Y is the back of the hand (the palm
## faces -Y). side = 1 for the right hand (thumb toward -X), -1 for the left.

const FINGERS := [
	# [x at the knuckle line, knuckle z offset, segment lengths, base radius]
	[-0.026, 0.0, [0.042, 0.026, 0.021], 0.0098],   # index
	[-0.0085, -0.004, [0.046, 0.029, 0.022], 0.0102],  # middle
	[0.0095, -0.001, [0.043, 0.027, 0.021], 0.0096],  # ring
	[0.0265, 0.006, [0.034, 0.021, 0.018], 0.0085],  # pinky
]
const THUMB := [0.034, 0.03, 0.024]
const THUMB_R := 0.0125
const KNUCKLE_Z := -0.046
const TAPER := 0.88
const SPREAD_K := [1.5, 0.5, -0.5, -1.5]
const BLEND := 16.0

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
static var _leather: StandardMaterial3D
static var _armor: StandardMaterial3D
static var _nail: StandardMaterial3D
static var _fabric: StandardMaterial3D

## Fist center in model space: grips are oriented around this point.
const FIST_CENTER := Vector3(0, -0.014, -0.05)

var side := 1.0
var model: Node3D               # oriented per grip; everything else hangs off it
var knuckle_anchor: Node3D      # accessories (brass knuckles, gauntlet) attach here
var palm_anchor: Node3D         # held items (sand pouch) attach here
var fingers: Array = []         # [[j0, j1, j2], ...] index..pinky
var thumb: Array = []           # [metacarpal, proximal, distal]
var pose := "relaxed"
var squeeze_t := 0.0
var pulse_t := 0.0
var _cur := {}
var _target := {}
var _t := 0.0


func _ready() -> void:
	name = "Hand"
	scale = Vector3.ONE * 1.25  # chunky action-game proportions
	model = Node3D.new()
	add_child(model)
	_build()
	_target = POSES["relaxed"].duplicate(true)
	_cur = POSES["relaxed"].duplicate(true)
	_apply(0.0)


# --- Materials ------------------------------------------------------------------

## Fine bumpy normal map from value noise (pores, leather grain).
static func _detail_normal(period: int, seed_: int, strength: float) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var h := Art._vnoise(u, v, period, seed_) * 0.7 + Art._vnoise(u, v, period * 3, seed_ + 1) * 0.3
			img.set_pixel(x, y, Color(h, h, h))
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func skin_mat() -> StandardMaterial3D:
	if _skin == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.78, 0.52, 0.4)
		m.roughness = 0.55
		m.metallic_specular = 0.35
		m.normal_enabled = true
		m.normal_texture = _detail_normal(24, 51, 3.0)
		m.normal_scale = 0.5
		m.uv1_scale = Vector3(3, 3, 3)
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.3
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.6
		_skin = m
	return _skin


static func leather_mat() -> StandardMaterial3D:
	if _leather == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.095, 0.09)
		m.roughness = 0.42
		m.normal_enabled = true
		m.normal_texture = _detail_normal(40, 77, 4.0)
		m.normal_scale = 0.7
		m.uv1_scale = Vector3(4, 4, 4)
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.3
		_leather = m
	return _leather


static func armor_mat() -> StandardMaterial3D:
	if _armor == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.26, 0.28, 0.27)
		m.metallic = 0.75
		m.roughness = 0.32
		m.rim_enabled = true
		m.rim = 0.3
		_armor = m
	return _armor


static func fabric_mat() -> StandardMaterial3D:
	if _fabric == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.17, 0.19, 0.16)
		m.roughness = 0.9
		m.normal_enabled = true
		m.normal_texture = _detail_normal(64, 91, 3.0)
		m.normal_scale = 0.35
		m.uv1_scale = Vector3(3, 3, 3)
		m.rim_enabled = true
		m.rim = 0.2
		_fabric = m
	return _fabric


static func nail_mat() -> StandardMaterial3D:
	if _nail == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.8, 0.76)
		m.roughness = 0.2
		_nail = m
	return _nail


# --- Geometry --------------------------------------------------------------------

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 12
	c.rings = 4
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	c.radial_segments = 14
	return c


## One finger segment (tapered capsule along -Z) on a joint pivot.
func _segment(pivot: Node3D, length: float, r: float, nail: bool) -> void:
	_mesh(pivot, _capsule(r, length + r * 1.6), Vector3(0, 0, -length * 0.5), skin_mat(), Vector3(PI / 2, 0, 0))
	if nail:
		_mesh(pivot, _box(Vector3(r * 1.3, 0.0025, r * 1.35)), Vector3(0, r * 0.8, -length * 0.62), nail_mat(), Vector3(0.08, 0, 0))


func _build() -> void:
	var s := side
	var skin := skin_mat()
	# Palm: a flat block rounded by pads (thenar at the thumb, hypothenar at the pinky edge).
	_mesh(model, _box(Vector3(0.078, 0.026, 0.09)), Vector3(0, 0, 0.0), skin)
	_mesh(model, _sphere(0.045), Vector3(0, 0.001, -0.002), skin, Vector3.ZERO, Vector3(0.92, 0.36, 1.08))
	_mesh(model, _sphere(0.022), Vector3(-0.026 * s, -0.008, 0.016), skin, Vector3.ZERO, Vector3(1.0, 0.7, 1.45))
	_mesh(model, _sphere(0.018), Vector3(0.029 * s, -0.006, 0.012), skin, Vector3.ZERO, Vector3(0.9, 0.7, 1.6))
	# Wrist.
	_mesh(model, _cyl(0.025, 0.07, 0.027), Vector3(0, 0.0, 0.08), skin, Vector3(PI / 2, 0, 0), Vector3(1.15, 0.8, 1))

	# Fingers.
	fingers.clear()
	for f in FINGERS:
		var lens: Array = f[2]
		var r: float = f[3]
		var j0 := Node3D.new()
		j0.position = Vector3(f[0] * s, 0.002, KNUCKLE_Z + f[1])
		model.add_child(j0)
		_mesh(j0, _sphere(r * 1.12), Vector3(0, 0.002, 0), skin)  # knuckle
		_segment(j0, lens[0], r, false)
		var j1 := Node3D.new()
		j1.position = Vector3(0, 0, -lens[0])
		j0.add_child(j1)
		_mesh(j1, _sphere(r * 0.86), Vector3(0, r * 0.25, 0), skin)
		_segment(j1, lens[1], r * TAPER, false)
		var j2 := Node3D.new()
		j2.position = Vector3(0, 0, -lens[1])
		j1.add_child(j2)
		_mesh(j2, _sphere(r * 0.76), Vector3(0, r * 0.2, 0), skin)
		_segment(j2, lens[2], r * TAPER * TAPER, true)
		# Fingerless glove: a leather sleeve over the base of each finger.
		_mesh(j0, _cyl(r * 1.22, lens[0] * 0.5), Vector3(0, 0, -lens[0] * 0.22), leather_mat(), Vector3(PI / 2, 0, 0))
		fingers.append([j0, j1, j2])

	# Thumb: angled out from the palm, rolled so it folds across the palm.
	var base := Node3D.new()
	base.position = Vector3(-0.034 * s, -0.007, 0.022)
	base.rotation = Vector3(0, 0.62 * s, 1.0 * s)
	model.add_child(base)
	var t0 := Node3D.new()
	base.add_child(t0)
	_segment(t0, THUMB[0], THUMB_R, false)
	var t1 := Node3D.new()
	t1.position = Vector3(0, 0, -THUMB[0])
	t0.add_child(t1)
	_mesh(t1, _sphere(THUMB_R * 0.9), Vector3.ZERO, skin)
	_segment(t1, THUMB[1], THUMB_R * 0.92, false)
	var t2 := Node3D.new()
	t2.position = Vector3(0, 0, -THUMB[1])
	t1.add_child(t2)
	_mesh(t2, _sphere(THUMB_R * 0.8), Vector3.ZERO, skin)
	_segment(t2, THUMB[2], THUMB_R * 0.85, true)
	_mesh(t0, _cyl(THUMB_R * 1.2, THUMB[0] * 0.8), Vector3(0, 0, -THUMB[0] * 0.4), leather_mat(), Vector3(PI / 2, 0, 0))
	thumb = [t0, t1, t2]

	# Glove shell over the palm and back of the hand, armor plates and the wrist strap.
	var lm := leather_mat()
	_mesh(model, _box(Vector3(0.083, 0.03, 0.074)), Vector3(0, 0, 0.008), lm)
	_mesh(model, _sphere(0.046), Vector3(0, 0.002, 0.004), lm, Vector3.ZERO, Vector3(0.95, 0.4, 0.86))
	var am := armor_mat()
	_mesh(model, _box(Vector3(0.056, 0.008, 0.046)), Vector3(0.002 * s, 0.018, 0.006), am, Vector3(0.05, 0, 0))
	_mesh(model, _box(Vector3(0.082, 0.012, 0.016)), Vector3(0, 0.016, KNUCKLE_Z + 0.004), am)
	for f in FINGERS:
		_mesh(model, _sphere(0.0072), Vector3(f[0] * s, 0.022, KNUCKLE_Z + f[1] * 0.5), am, Vector3.ZERO, Vector3(1, 0.7, 1))
	_mesh(model, _cyl(0.031, 0.016), Vector3(0, 0, 0.046), lm, Vector3(PI / 2, 0, 0), Vector3(1.12, 0.85, 1))
	_mesh(model, _box(Vector3(0.016, 0.006, 0.018)), Vector3(0, 0.025, 0.046), am)

	# Forearm: rolled sleeve and cuff (part of the model so it follows every grip).
	var fm := fabric_mat()
	_mesh(model, _cyl(0.037, 0.44, 0.047), Vector3(0, -0.002, 0.35), fm, Vector3(-PI / 2, 0, 0), Vector3(1.1, 0.9, 1))
	_mesh(model, _cyl(0.041, 0.035), Vector3(0, -0.002, 0.132), fm, Vector3(PI / 2, 0, 0), Vector3(1.12, 0.92, 1))
	if side < 0.0:
		# A cheap digital watch on the left wrist.
		_mesh(model, _cyl(0.029, 0.016), Vector3(0, 0, 0.097), leather_mat(), Vector3(PI / 2, 0, 0), Vector3(1.1, 0.85, 1))
		_mesh(model, _box(Vector3(0.024, 0.009, 0.026)), Vector3(0, 0.026, 0.097), armor_mat())
		var face := StandardMaterial3D.new()
		face.albedo_color = Color(0.4, 1.0, 0.5)
		face.emission_enabled = true
		face.emission = Color(0.4, 1.0, 0.5)
		face.emission_energy_multiplier = 1.5
		_mesh(model, _box(Vector3(0.017, 0.002, 0.018)), Vector3(0, 0.031, 0.097), face)

	knuckle_anchor = Node3D.new()
	knuckle_anchor.position = Vector3(0, 0.004, KNUCKLE_Z - 0.006)
	model.add_child(knuckle_anchor)
	palm_anchor = Node3D.new()
	palm_anchor.position = Vector3(0, -0.032, -0.03)
	model.add_child(palm_anchor)


# --- Grip orientation ------------------------------------------------------------------

## Orients the whole hand + forearm with a basis expressed in the arm's frame, keeping the fist
## centered on the arm pivot (so held props and arm poses stay put).
func orient(b: Basis) -> void:
	model.transform = Transform3D(b, -(b * FIST_CENTER))


## Basis presets. Punch: palm down, knuckles forward. Thumb up: a pistol or sword grip with the
## palm facing inward. Palm up: the support hand under a blaster's fore-grip (left hand).
func punch_basis() -> Basis:
	# Rolled inward (thumb side up) and tipped up a little, so you see the curled fingers.
	return Basis(Vector3(0, 0, 1), -0.75 * side) * Basis(Vector3(1, 0, 0), 0.15)


func thumb_up_basis() -> Basis:
	var x := Vector3(0, -side, 0)
	var y := Vector3(side, 0, 0)
	return Basis(x, y, x.cross(y))


static func palm_up_basis() -> Basis:
	# Forearm runs back, down and to the left; the palm faces up under the fore-grip.
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
		_apply(0.0)


## Trigger pull: the index finger curls in for a moment.
func squeeze() -> void:
	squeeze_t = 1.0


## Punch clench: every finger tightens for a moment.
func pulse() -> void:
	pulse_t = 1.0


## Total curl of finger i (0 = index) across its three joints, for tests.
func finger_curl(i: int) -> float:
	return -(fingers[i][0].rotation.x + fingers[i][1].rotation.x + fingers[i][2].rotation.x)


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


func _apply(t: float) -> void:
	for i in fingers.size():
		var c: Array = _cur["f"][i]
		var idle := sin(t * 1.3 + i * 1.7) * 0.025
		var extra := pulse_t * 0.12
		if i == 0:
			extra += squeeze_t * 0.55
		fingers[i][0].rotation = Vector3(-(c[0] + idle + extra), _cur["spread"] * SPREAD_K[i] * side, 0)
		fingers[i][1].rotation.x = -(c[1] + idle * 0.6 + extra)
		fingers[i][2].rotation.x = -(c[2] + extra * 0.6)
	var tc: Array = _cur["thumb"]
	thumb[0].rotation.x = -(tc[0] + pulse_t * 0.08)
	thumb[1].rotation.x = -tc[1]
	thumb[2].rotation.x = -tc[2]
