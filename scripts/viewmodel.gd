extends Node3D
## First-person arms + weapon. Keyframed attack animations (jabs, hooks, slashes,
## charged heavies), guard, weapon sway that follows the mouse, bob and landing dip.

const IDLE_R := [Vector3(0.22, -0.25, -0.5), Vector3(0.1, 0.12, -0.05)]
const IDLE_L := [Vector3(-0.22, -0.25, -0.5), Vector3(0.1, -0.12, 0.05)]
const SWORD_IDLE := [Vector3(0.26, -0.3, -0.4), Vector3(0.25, 0.05, -0.15)]

var sway: Node3D
var arm_l: Node3D
var arm_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var sleeve_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D
var fist_mat: StandardMaterial3D
var weapon_root: Node3D
var blade: MeshInstance3D
var kind := "fist"
var trail_mat: StandardMaterial3D

var _tw_l: Tween
var _tw_r: Tween
var _sway_target := Vector2.ZERO
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _bob := Vector3.ZERO
var _dip := 0.0
var _blocking := false
var _charging := false
var _sliding := false
var _charge_t := 0.0
var _busy_l := 0.0
var _busy_r := 0.0
var _trail_time := 0.0
var _trail_cd := 0.0
var _kick := Vector3.ZERO

# Wave Mode blasters (specs/004).
const GUN_HIP := Vector3(0.18, -0.2, -0.46)
const GUN_AIM := Vector3(0.0, -0.125, -0.34)
var gun: Node3D = null
var muzzle: Node3D = null
var blaster_id := ""
var _gun_kick := 0.0
var _aim := 0.0
var _reload_t := 0.0
var _reload_len := 0.0


func _ready() -> void:
	sway = Node3D.new()
	add_child(sway)
	sleeve_mat = Shapes.mat(Color(0.14, 0.14, 0.17))
	skin_mat = Shapes.mat(Color(0.85, 0.62, 0.48))
	fist_mat = Shapes.mat(Color(0.85, 0.62, 0.48))
	arm_l = _arm()
	arm_r = _arm()
	hand_l = arm_l.get_child(-1)
	hand_r = arm_r.get_child(-1)
	_set_pose(arm_l, IDLE_L)
	_set_pose(arm_r, IDLE_R)
	trail_mat = Shapes.mat(Color(1, 1, 1, 0.35), 1.5)
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _arm() -> Node3D:
	var arm := Node3D.new()
	sway.add_child(arm)
	# Forearm extends from behind the camera (+Z) to the hand at the origin.
	var fore := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.032
	cm.height = 0.42
	fore.mesh = cm
	fore.material_override = sleeve_mat
	fore.rotation.x = PI / 2
	fore.position = Vector3(0, 0, 0.21)
	_no_shadow(fore)
	arm.add_child(fore)
	var cuff := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.036
	cyl.bottom_radius = 0.036
	cyl.height = 0.04
	cuff.mesh = cyl
	cuff.material_override = Shapes.mat(Color(0.95, 0.75, 0.2))
	cuff.rotation.x = PI / 2
	cuff.position = Vector3(0, 0, 0.045)
	_no_shadow(cuff)
	arm.add_child(cuff)
	var hand := Node3D.new()
	arm.add_child(hand)
	return arm


func _no_shadow(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


func set_weapon(id: String) -> void:
	var w: Dictionary = GameState.WEAPONS[id]
	_drop_gun()
	kind = w["kind"]
	_clear(hand_l)
	_clear(hand_r)
	blade = null
	weapon_root = null
	if kind == "fist":
		fist_mat = Shapes.mat(w["color"])
		if id in ["brass", "gauntlet"]:
			fist_mat.metallic = 0.85
			fist_mat.roughness = 0.25
		for h in [hand_l, hand_r]:
			_make_fist(h, id, w)
	elif kind == "sand":
		_make_fist(hand_l, "knuckles", GameState.WEAPONS["knuckles"])
		_make_fist(hand_r, "knuckles", GameState.WEAPONS["knuckles"])
		# A little drawstring pouch of sand.
		var pouch := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.04
		pm.height = 0.07
		pouch.mesh = pm
		pouch.material_override = Shapes.mat(Color(0.55, 0.4, 0.25))
		pouch.position = Vector3(0, 0.03, -0.02)
		_no_shadow(pouch)
		hand_r.add_child(pouch)
		var tie := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.008
		tm.bottom_radius = 0.015
		tm.height = 0.03
		tie.mesh = tm
		tie.material_override = Shapes.mat(Color(0.8, 0.2, 0.2))
		tie.position = Vector3(0, 0.075, -0.02)
		_no_shadow(tie)
		hand_r.add_child(tie)
	else:
		_make_fist(hand_l, "knuckles", GameState.WEAPONS["knuckles"])
		_make_fist(hand_r, "knuckles", GameState.WEAPONS["knuckles"])
		weapon_root = Node3D.new()
		hand_r.add_child(weapon_root)
		# Grip angled up and forward.
		weapon_root.rotation = Vector3(-1.1, 0, 0)
		var blade_len: float = w["blade"]
		var foam: bool = id == "foam"
		var handle := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.018
		hm.bottom_radius = 0.018
		hm.height = 0.22
		handle.mesh = hm
		handle.material_override = Shapes.mat(Color(0.25, 0.25, 0.28) if foam else Color(0.08, 0.06, 0.06))
		handle.position = Vector3(0, 0.02, 0)
		weapon_root.add_child(handle)
		var guard := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.2, 0.03, 0.05) if foam else Vector3(0.09, 0.02, 0.09)
		guard.mesh = gm
		guard.material_override = Shapes.mat(Color(0.2, 0.2, 0.25) if foam else Color(0.9, 0.7, 0.2))
		guard.position = Vector3(0, 0.14, 0)
		weapon_root.add_child(guard)
		blade = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, blade_len, 0.035) if foam else Vector3(0.035, blade_len, 0.008)
		blade.mesh = bm
		var bmat := Shapes.mat(w["color"])
		if not foam:
			bmat.metallic = 0.95
			bmat.roughness = 0.15
		blade.material_override = bmat
		blade.position = Vector3(0, 0.15 + blade_len / 2, 0)
		weapon_root.add_child(blade)
		for mi in [handle, guard, blade]:
			_no_shadow(mi)
	_return_to_idle(0.15)


func _make_fist(hand: Node3D, id: String, w: Dictionary) -> void:
	var size: float = w.get("size", 0.05) * 0.68
	var fist := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	fist.mesh = sm
	fist.scale = Vector3(1.0, 0.9, 1.15)
	fist.material_override = fist_mat if kind == "fist" else skin_mat
	_no_shadow(fist)
	hand.add_child(fist)
	if id == "brass":
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size * 2.2, size * 0.5, size * 0.6)
		bar.mesh = bm
		bar.material_override = fist_mat
		bar.position = Vector3(0, size * 0.25, -size * 0.95)
		_no_shadow(bar)
		hand.add_child(bar)
	elif id == "gauntlet":
		for i in 3:
			var gem := MeshInstance3D.new()
			var gsm := SphereMesh.new()
			gsm.radius = size * 0.22
			gsm.height = size * 0.44
			gem.mesh = gsm
			gem.material_override = Shapes.mat(Color.from_hsv(i / 3.0, 0.9, 1.0), 3.0)
			gem.position = Vector3((i - 1) * size * 0.6, size * 0.75, -size * 0.3)
			_no_shadow(gem)
			hand.add_child(gem)


# --- Blasters (Wave Mode) ----------------------------------------------------

func _drop_gun() -> void:
	if gun:
		gun.queue_free()
	gun = null
	muzzle = null
	blaster_id = ""


## Builds a toy blaster held in both hands. Barrels point along -Z.
func set_blaster(id: String) -> void:
	_drop_gun()
	kind = "blaster"
	blaster_id = id
	_clear(hand_l)
	_clear(hand_r)
	blade = null
	weapon_root = null
	for tw in [_tw_l, _tw_r]:
		if tw and tw.is_valid():
			tw.kill()
	_make_fist(hand_l, "knuckles", GameState.WEAPONS["knuckles"])
	_make_fist(hand_r, "knuckles", GameState.WEAPONS["knuckles"])
	gun = Node3D.new()
	gun.position = GUN_HIP
	gun.scale = Vector3.ONE * (0.8 if id == "dart" else 0.9)
	sway.add_child(gun)
	muzzle = Node3D.new()
	gun.add_child(muzzle)
	var b: Dictionary = GameState.BLASTERS[id]
	var col: Color = b["color"]
	match id:
		"dart":
			_gpart(_bx(0.05, 0.07, 0.2), Vector3(0, 0, -0.06), col)
			_gpart(_bx(0.054, 0.022, 0.17), Vector3(0, 0.045, -0.06), Color(1.0, 0.85, 0.2))
			_gpart(_cyl(0.017, 0.012, 0.11), Vector3(0, 0.01, -0.2), Color(0.2, 0.45, 1.0), Vector3(PI / 2, 0, 0))
			_gpart(_bx(0.042, 0.11, 0.05), Vector3(0, -0.075, 0.02), Color(0.2, 0.3, 0.6), Vector3(0.3, 0, 0))
			_gpart(_bx(0.01, 0.04, 0.05), Vector3(0, -0.04, -0.03), Color(0.95, 0.85, 0.2))
			muzzle.position = Vector3(0, 0.01, -0.27)
		"soaker":
			_gpart(_bx(0.06, 0.075, 0.34), Vector3(0, 0, -0.08), col)
			var tank := _gpart(_cyl(0.06, 0.06, 0.24), Vector3(0, 0.085, -0.02), Color(0.3, 0.6, 1.0), Vector3(PI / 2, 0, 0))
			var tm := Shapes.mat(Color(0.35, 0.65, 1.0, 0.65), 0.3)
			tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tank.material_override = tm
			_gpart(_cyl(0.014, 0.014, 0.14), Vector3(0, 0.0, -0.31), Color(1.0, 0.85, 0.2), Vector3(PI / 2, 0, 0))
			_gpart(_cyl(0.026, 0.026, 0.12), Vector3(0, -0.05, -0.2), Color(1.0, 0.5, 0.1), Vector3(PI / 2, 0, 0))
			_gpart(_bx(0.045, 0.11, 0.05), Vector3(0, -0.08, 0.04), Color(0.15, 0.4, 0.2), Vector3(0.3, 0, 0))
			muzzle.position = Vector3(0, 0, -0.39)
			Art.water_stream(muzzle)
		"paint":
			_gpart(_bx(0.055, 0.08, 0.36), Vector3(0, 0, -0.05), col)
			_gpart(_cyl(0.02, 0.02, 0.3), Vector3(0, 0.015, -0.36), Color(0.15, 0.15, 0.18), Vector3(PI / 2, 0, 0))
			_gpart(_sph(0.065), Vector3(0, 0.1, -0.03), Color(1.0, 0.85, 0.2))
			_gpart(_cyl(0.03, 0.03, 0.16), Vector3(0, -0.02, 0.2), Color(0.75, 0.78, 0.82), Vector3(PI / 2, 0, 0))
			_gpart(_bx(0.045, 0.11, 0.05), Vector3(0, -0.085, 0.05), Color(0.2, 0.15, 0.25), Vector3(0.3, 0, 0))
			_gpart(_bx(0.03, 0.05, 0.1), Vector3(0, -0.05, -0.2), Color(0.2, 0.15, 0.25))
			muzzle.position = Vector3(0, 0.015, -0.52)
		"bubble":
			_gpart(_bx(0.065, 0.08, 0.28), Vector3(0, 0, -0.02), Color(1.0, 0.6, 0.8))
			_gpart(_cyl(0.075, 0.03, 0.2), Vector3(0, 0.01, -0.25), col, Vector3(-PI / 2, 0, 0))
			var bub := _gpart(_sph(0.07), Vector3(0, 0.1, 0.0), Color(0.6, 0.9, 1.0))
			var bm := Shapes.mat(Color(0.6, 0.9, 1.0, 0.5), 0.6)
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bub.material_override = bm
			_gpart(_bx(0.045, 0.11, 0.05), Vector3(0, -0.085, 0.06), Color(0.55, 0.3, 0.6), Vector3(0.3, 0, 0))
			muzzle.position = Vector3(0, 0.01, -0.36)
		"chicken":
			_gpart(_cyl(0.062, 0.062, 0.52), Vector3(0, 0.02, -0.08), Color(0.35, 0.5, 0.3), Vector3(PI / 2, 0, 0))
			_gpart(_cyl(0.068, 0.068, 0.04), Vector3(0, 0.02, -0.33), Color(0.9, 0.75, 0.2), Vector3(PI / 2, 0, 0))
			_gpart(_sph(0.05), Vector3(0, 0.03, -0.35), col)
			_gpart(_bx(0.015, 0.04, 0.05), Vector3(0, 0.085, -0.35), Color(0.95, 0.15, 0.15))
			_gpart(_cyl(0.0, 0.02, 0.05), Vector3(0, 0.025, -0.4), Color(1.0, 0.5, 0.1), Vector3(-PI / 2, 0, 0))
			_gpart(_bx(0.03, 0.04, 0.08), Vector3(0, 0.1, -0.05), Color(0.2, 0.2, 0.22))
			_gpart(_bx(0.045, 0.11, 0.05), Vector3(0, -0.09, 0.02), Color(0.25, 0.3, 0.2), Vector3(0.3, 0, 0))
			muzzle.position = Vector3(0, 0.03, -0.4)


func _gpart(mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Shapes.mat(color)
	mi.position = pos
	mi.rotation = rot
	_no_shadow(mi)
	gun.add_child(mi)
	return mi


func _bx(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 14
	return m


func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func muzzle_position() -> Vector3:
	if muzzle and muzzle.is_inside_tree():
		return muzzle.global_position
	return global_position + -global_transform.basis.z * 0.5


func fire_kick(strength: float) -> void:
	_gun_kick = minf(_gun_kick + strength * 0.5, 1.0)


func set_aim(k: float) -> void:
	_aim = k


## Starts (t > 0) or cancels (t = 0) the reload animation.
func reload_anim(t: float) -> void:
	_reload_t = t
	_reload_len = t


func _tick_gun(delta: float) -> void:
	_gun_kick = move_toward(_gun_kick, 0.0, delta * 6.0)
	var p := 0.0
	if _reload_t > 0.0:
		_reload_t = maxf(_reload_t - delta, 0.0)
		p = sin((1.0 - _reload_t / maxf(_reload_len, 0.01)) * PI)
	var pos := GUN_HIP.lerp(GUN_AIM, _aim) + Vector3(0, 0.01, 0.07) * _gun_kick + Vector3(0, -0.05, 0.03) * p
	gun.position = pos
	gun.rotation = Vector3(0.18 * _gun_kick - 0.6 * p, 0.0, 0.5 * p)
	# Hands follow the blaster: right on the grip, left on the fore-grip (or the tank mid-reload).
	arm_r.position = pos + Vector3(0.0, -0.09, 0.07)
	arm_r.rotation = Vector3(0.35 + gun.rotation.x * 0.5, 0.1, gun.rotation.z * 0.5)
	# The pistol is cupped from below; long blasters are held by the fore-grip.
	var grip := Vector3(-0.03, -0.11, 0.03) if blaster_id == "dart" else Vector3(-0.045, -0.06, -0.21)
	var fore := grip.lerp(Vector3(-0.06, -0.14, -0.02), p)
	arm_l.position = pos + fore
	arm_l.rotation = Vector3(0.45, -0.85, 0.2)


# --- Pose helpers ------------------------------------------------------------

func _set_pose(arm: Node3D, pose: Array) -> void:
	arm.position = pose[0]
	arm.rotation = pose[1]


func _idle_pose(right: bool) -> Array:
	if _blocking:
		if kind == "sword":
			return [Vector3(0.05, -0.15, -0.45), Vector3(0.1, 0.2, 1.35)] if right else [Vector3(-0.1, -0.25, -0.38), Vector3(0.6, -0.5, 0.2)]
		return [Vector3(0.07, -0.05, -0.34), Vector3(1.1, 0.4, 0.6)] if right else [Vector3(-0.07, -0.06, -0.35), Vector3(1.1, -0.4, -0.6)]
	if _charging:
		if kind == "sword":
			return [Vector3(0.42, -0.05, -0.15), Vector3(0.9, 0.6, 0.6)] if right else IDLE_L
		return [Vector3(0.3, -0.38, -0.12), Vector3(-0.3, 0.3, 0.0)] if right else [Vector3(-0.12, -0.18, -0.4), Vector3(0.4, -0.2, -0.2)]
	if kind == "sword":
		return SWORD_IDLE if right else [Vector3(-0.28, -0.36, -0.36), Vector3(0.0, -0.15, 0.1)]
	return IDLE_R if right else IDLE_L


func _tween_arm(right: bool, keys: Array) -> float:
	## keys: [[time, pos, rot, trans?], ...]. Returns total length.
	var arm := arm_r if right else arm_l
	var old := _tw_r if right else _tw_l
	if old and old.is_valid():
		old.kill()
	var tw := create_tween()
	var total := 0.0
	for k in keys:
		var t: float = k[0]
		total += t
		tw.tween_property(arm, "position", k[1], t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(arm, "rotation", k[2], t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if right:
		_tw_r = tw
		_busy_r = total
	else:
		_tw_l = tw
		_busy_l = total
	return total


func _return_to_idle(t := 0.12) -> void:
	for right in [true, false]:
		var pose := _idle_pose(right)
		_tween_arm(right, [[t, pose[0], pose[1]]])
	_busy_l = 0.0
	_busy_r = 0.0


# --- Public API --------------------------------------------------------------

## Plays an attack. Returns the delay (s) until the impact frame.
func attack(combo: int, heavy: bool) -> float:
	_charging = false
	Sfx.play("whoosh", 0.12, -4.0)
	if kind == "sword":
		return _sword_attack(combo, heavy)
	return _fist_attack(combo, heavy)


func _fist_attack(combo: int, heavy: bool) -> float:
	var right := combo != 1
	var idle := _idle_pose(right)
	var s := 1.0 if right else -1.0
	if heavy:
		# Uppercut.
		_tween_arm(true, [[0.06, Vector3(0.2, -0.4, -0.3), Vector3(-0.4, 0.2, 0.0)],
			[0.08, Vector3(0.04, -0.02, -0.78), Vector3(1.0, 0.0, 0.0)],
			[0.12, Vector3(0.05, -0.04, -0.72), Vector3(0.9, 0.0, 0.0)],
			[0.2, idle[0], idle[1]]])
		return 0.13
	if combo == 2:
		# Hook from the right.
		_tween_arm(true, [[0.05, Vector3(0.42, -0.2, -0.35), Vector3(0.1, 0.7, -0.3)],
			[0.07, Vector3(-0.02, -0.14, -0.7), Vector3(0.15, -0.5, -0.6)],
			[0.17, idle[0], idle[1]]])
		return 0.11
	# Straight jab (alternating hands).
	_tween_arm(right, [[0.05, Vector3(0.05 * s, -0.15, -0.8), Vector3(0.05, -0.05 * s, 0.0)],
		[0.16, idle[0], idle[1]]])
	return 0.05


func _sword_attack(combo: int, heavy: bool) -> float:
	var idle := _idle_pose(true)
	_trail_time = 0.22
	if heavy:
		# Lunging thrust.
		_tween_arm(true, [[0.07, Vector3(0.3, -0.2, 0.05), Vector3(0.0, 0.3, 0.2)],
			[0.08, Vector3(0.02, -0.12, -1.0), Vector3(1.45, 0.0, 0.0)],
			[0.12, Vector3(0.02, -0.12, -0.95), Vector3(1.45, 0.0, 0.0)],
			[0.22, idle[0], idle[1]]])
		return 0.14
	match combo:
		0:  # Diagonal: upper-right to lower-left.
			_tween_arm(true, [[0.05, Vector3(0.45, 0.08, -0.35), Vector3(0.6, 0.7, 0.9)],
				[0.1, Vector3(-0.35, -0.38, -0.55), Vector3(0.9, -0.6, -1.0)],
				[0.2, idle[0], idle[1]]])
		1:  # Backhand: lower-left to upper-right.
			_tween_arm(true, [[0.05, Vector3(-0.35, -0.35, -0.45), Vector3(0.9, -0.6, -1.8)],
				[0.1, Vector3(0.45, 0.05, -0.5), Vector3(0.7, 0.6, -2.4)],
				[0.2, idle[0], idle[1]]])
		_:  # Overhead chop.
			_tween_arm(true, [[0.07, Vector3(0.12, 0.25, -0.2), Vector3(-0.3, 0.0, 0.1)],
				[0.1, Vector3(0.04, -0.42, -0.62), Vector3(1.6, 0.0, 0.0)],
				[0.24, idle[0], idle[1]]])
	return 0.1


func set_block(on: bool) -> void:
	if on == _blocking:
		return
	_blocking = on
	_return_to_idle(0.08)


func set_charging(on: bool) -> void:
	if on == _charging:
		return
	_charging = on
	# Always snap into (or out of) the wind-up pose, even mid-animation.
	_return_to_idle(0.18 if on else 0.1)


func set_sliding(on: bool) -> void:
	_sliding = on


## Fling a handful of sand: right arm whips forward and opens.
func throw_sand() -> float:
	_tween_arm(true, [[0.08, Vector3(0.3, -0.15, -0.15), Vector3(-0.6, 0.3, 0.3)],
		[0.08, Vector3(0.05, -0.05, -0.75), Vector3(0.6, -0.2, -0.3)],
		[0.25, IDLE_R[0], IDLE_R[1]]])
	return 0.16


func flinch() -> void:
	_kick += Vector3(randf_range(-0.04, 0.04), -0.06, 0.08)


func on_impact() -> void:
	## Called when an attack connects: small recoil.
	_kick += Vector3(0, 0.0, 0.05)


func feed_mouse(rel: Vector2) -> void:
	_sway_target += rel * 0.0009
	_sway_target = _sway_target.limit_length(0.09)


func land(strength: float) -> void:
	_dip = minf(_dip + strength * 0.05, 0.12)


func tick(delta: float, speed: float, sprinting: bool, on_floor: bool) -> void:
	_busy_l -= delta
	_busy_r -= delta
	# Sway: lag behind mouse movement, then spring back.
	_sway = _sway.lerp(_sway_target, minf(delta * 14.0, 1.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	# Bob.
	if on_floor and speed > 0.5:
		_bob_t += delta * speed * 1.25
		var amp := 0.012 * (1.8 if sprinting else 1.0)
		_bob = Vector3(cos(_bob_t) * amp, -absf(sin(_bob_t)) * amp * 1.2, 0)
	else:
		_bob = _bob.lerp(Vector3.ZERO, minf(delta * 6.0, 1.0))
	_dip = lerpf(_dip, 0.0, minf(delta * 8.0, 1.0))
	_kick = _kick.lerp(Vector3.ZERO, minf(delta * 12.0, 1.0))
	var sprint_drop := Vector3(0, -0.05, 0.04) if sprinting and not _blocking else Vector3.ZERO
	if _sliding:
		sprint_drop += Vector3(0.03, -0.04, 0.05)
	# Trembling wind-up while charging a heavy.
	var tremble := Vector3.ZERO
	if _charging:
		_charge_t += delta
		tremble = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * minf(_charge_t, 0.6) * 0.006
	else:
		_charge_t = 0.0
	if gun:
		_tick_gun(delta)
		sprint_drop *= 1.0 - _aim
	sway.position = _bob * (1.0 - _aim * 0.8) + Vector3(-_sway.x * 0.4, _sway.y * 0.4 - _dip, 0) + _kick + sprint_drop + tremble
	sway.rotation = Vector3(-_sway.y * 1.2 + (0.25 if sprinting and not _blocking and not _charging else 0.0), -_sway.x * 1.2,
		_sway.x * 0.8 + (0.18 if _sliding else 0.0))

	# Ghost trail for sword swings.
	if _trail_time > 0.0 and blade:
		_trail_time -= delta
		_trail_cd -= delta
		if _trail_cd <= 0.0:
			_trail_cd = 0.012
			var ghost := MeshInstance3D.new()
			ghost.mesh = blade.mesh
			var m := trail_mat.duplicate() as StandardMaterial3D
			ghost.material_override = m
			_no_shadow(ghost)
			add_child(ghost)
			ghost.global_transform = blade.global_transform
			var tw := ghost.create_tween()
			tw.tween_property(m, "albedo_color:a", 0.0, 0.12)
			tw.tween_callback(ghost.queue_free)
