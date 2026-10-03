class_name Arena
## Sunnyvale Rec Center gym, the Wave Mode arena (specs/004). A ceilinged gym with a glossy
## court, a balcony running track reached by ramps, bleachers of cheering kids behind a safety
## net, a stage, cover props, hanging lights, high windows with light shafts (High quality),
## spawn doors and a live wave scoreboard. Same layout contract as Levels' builders.

const SpectatorScript := preload("res://scripts/spectator.gd")

const HALF_X := 24.0
const HALF_Z := 17.0
const WALL_H := 10.0
const BALCONY_Y := 3.2
const BALCONY_Z := 13.0     # inner edge of the balcony
const RAMP_X := 20.0
const RAMP_BOTTOM_Z := 5.0
const RAMP_W := 2.6


static func build(root: Node3D) -> Dictionary:
	_shell(root)
	_court_lines(root)
	_balcony(root)
	var seats := _bleachers(root)
	_stage(root)
	var doors := _doors(root)
	_cover(root)
	_lights(root)
	_decor(root)
	var board := _scoreboard(root)
	_spectators(root, seats)
	return {
		"half": HALF_X + 2.0,
		"spawn": Vector3(-14, 0.1, 0), "spawn_yaw": -PI / 2,
		"doors": doors,
		"parent_spawns": doors,
		"cover": [Vector3(-8, 0, -6.4), Vector3(8, 0, 6.4), Vector3(0, 0, -7.2), Vector3(-12, 0, 7.2), Vector3(12, 0, -7.2)],
		"balcony": AABB(Vector3(-HALF_X, BALCONY_Y - 0.1, BALCONY_Z), Vector3(HALF_X * 2, 3, HALF_Z - BALCONY_Z)),
		"indoor": AABB(Vector3(-HALF_X, 0, -HALF_Z), Vector3(HALF_X * 2, 8, HALF_Z * 2)),
		"scoreboard": board,
		"kid_bounds": Rect2(-10, -10, 20, 20),
		"pois": [Vector3.ZERO],
		"patrol": [Vector3.ZERO],
		"extracts": [],
	}


static func _solid(root: Node3D, size: Vector3, pos: Vector3, color: Color, tex := "") -> StaticBody3D:
	return Shapes.solid_box(root, size, pos, color, 0.0, tex)


# --- Structure -------------------------------------------------------------------

static func _shell(root: Node3D) -> void:
	# Glossy maple court (reflects on High via SSR).
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	root.add_child(floor_body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(HALF_X * 2 + 4, 1, HALF_Z * 2 + 4)
	cs.shape = shape
	cs.position.y = -0.5
	floor_body.add_child(cs)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_X * 2, HALF_Z * 2)
	floor_mesh.mesh = plane
	var fm := Art.textured(Color(0.93, 0.72, 0.48), "wood")
	fm.roughness = 0.18
	fm.metallic_specular = 0.8
	floor_mesh.material_override = fm
	floor_body.add_child(floor_mesh)

	# Walls: painted block upper, padded lower band.
	var wall := Color(0.92, 0.88, 0.8)
	for z in [-HALF_Z, HALF_Z]:
		_solid(root, Vector3(HALF_X * 2 + 0.8, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, z + signf(z) * 0.2), wall, "brick")
		Shapes.box(root, Vector3(HALF_X * 2, 2.0, 0.15), Vector3(0, 1.0, z - signf(z) * 0.08), Color(0.15, 0.3, 0.7))
		Shapes.box(root, Vector3(HALF_X * 2, 0.25, 0.16), Vector3(0, 2.1, z - signf(z) * 0.08), Color(0.95, 0.75, 0.1))
	for x in [-HALF_X, HALF_X]:
		_solid(root, Vector3(0.4, WALL_H, HALF_Z * 2), Vector3(x + signf(x) * 0.2, WALL_H * 0.5, 0), wall, "brick")
		Shapes.box(root, Vector3(0.15, 2.0, HALF_Z * 2), Vector3(x - signf(x) * 0.08, 1.0, 0), Color(0.15, 0.3, 0.7))
		Shapes.box(root, Vector3(0.16, 0.25, HALF_Z * 2), Vector3(x - signf(x) * 0.08, 2.1, 0), Color(0.95, 0.75, 0.1))

	# Ceiling with steel trusses. It doesn't cast sun shadows: the gym is lit by its lamps.
	var ceiling := Shapes.box(root, Vector3(HALF_X * 2 + 1, 0.3, HALF_Z * 2 + 1), Vector3(0, WALL_H + 0.15, 0), Color(0.55, 0.55, 0.58))
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 9:
		var x := -HALF_X + 3.0 + i * 5.25
		var beam := Shapes.box(root, Vector3(0.35, 0.6, HALF_Z * 2), Vector3(x, WALL_H - 0.3, 0), Color(0.3, 0.33, 0.38))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var web := Shapes.box(root, Vector3(0.12, 0.12, HALF_Z * 2), Vector3(x, WALL_H - 1.0, 0), Color(0.3, 0.33, 0.38))
		web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _court_lines(root: Node3D) -> void:
	var line := Color(0.98, 0.98, 0.95)
	var key := Color(0.75, 0.2, 0.15)
	var w := 0.09
	var y := 0.006
	var lx := 19.0
	var lz := 11.0
	for z in [-lz, lz]:
		Shapes.box(root, Vector3(lx * 2, 0.01, w), Vector3(0, y, z), line)
	for x in [-lx, lx]:
		Shapes.box(root, Vector3(w, 0.01, lz * 2), Vector3(x, y, 0), line)
	Shapes.box(root, Vector3(w, 0.01, lz * 2), Vector3(0, y, 0), line)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.9
	tm.outer_radius = 3.0
	tm.rings = 48
	ring.mesh = tm
	ring.material_override = Shapes.mat(line)
	ring.scale = Vector3(1, 0.05, 1)
	ring.position = Vector3(0, y, 0)
	root.add_child(ring)
	var center := Shapes.cylinder(root, 1.2, 0.012, Vector3(0, y, 0), key)
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Painted keys and three-point arcs at both ends.
	for sx in [-1.0, 1.0]:
		var kx: float = sx * (lx - 2.9)
		Shapes.box(root, Vector3(5.8, 0.008, 4.8), Vector3(kx, y - 0.001, 0), key)
		for i in 15:
			var a := -PI / 2 + i * PI / 14.0
			var px: float = sx * lx - sx * cos(a) * 7.0
			var pz: float = sin(a) * 7.0
			var seg := Shapes.box(root, Vector3(w, 0.01, 1.6), Vector3(px, y, pz), line)
			seg.rotation.y = -sx * a


static func _balcony(root: Node3D) -> void:
	var depth := HALF_Z - BALCONY_Z
	var slab := _solid(root, Vector3(HALF_X * 2, 0.3, depth), Vector3(0, BALCONY_Y - 0.15, BALCONY_Z + depth * 0.5), Color(0.35, 0.38, 0.45))
	slab.name = "Balcony"
	# Red rubber running track with lane lines.
	Shapes.box(root, Vector3(HALF_X * 2, 0.02, depth - 0.2), Vector3(0, BALCONY_Y + 0.01, BALCONY_Z + depth * 0.5), Color(0.75, 0.25, 0.2))
	for i in 3:
		Shapes.box(root, Vector3(HALF_X * 2, 0.025, 0.05), Vector3(0, BALCONY_Y + 0.015, BALCONY_Z + 1.0 + i), Color(0.98, 0.98, 0.95))
	# Support pillars.
	for i in 7:
		var x := -18.0 + i * 6.0
		Shapes.solid_cylinder(root, 0.25, BALCONY_Y - 0.3, Vector3(x, (BALCONY_Y - 0.3) * 0.5, BALCONY_Z + 0.3), Color(0.3, 0.33, 0.38))
	# Railing with gaps where the ramps arrive.
	var gaps := [[-RAMP_X - RAMP_W * 0.5, -RAMP_X + RAMP_W * 0.5], [RAMP_X - RAMP_W * 0.5, RAMP_X + RAMP_W * 0.5]]
	var runs := [[-HALF_X, gaps[0][0]], [gaps[0][1], gaps[1][0]], [gaps[1][1], HALF_X]]
	for run in runs:
		var a: float = run[0]
		var b: float = run[1]
		var len := b - a
		var mid := (a + b) * 0.5
		var rail := _solid(root, Vector3(len, 1.15, 0.1), Vector3(mid, BALCONY_Y + 0.575, BALCONY_Z), Color(0.85, 0.75, 0.2))
		rail.get_child(0).visible = false
		Shapes.box(root, Vector3(len, 0.08, 0.12), Vector3(mid, BALCONY_Y + 1.12, BALCONY_Z), Color(0.95, 0.75, 0.1))
		Shapes.box(root, Vector3(len, 0.05, 0.06), Vector3(mid, BALCONY_Y + 0.6, BALCONY_Z), Color(0.95, 0.75, 0.1))
		for k in int(len / 1.2) + 1:
			Shapes.cylinder(root, 0.03, 1.15, Vector3(a + k * len / maxf(int(len / 1.2), 1), BALCONY_Y + 0.575, BALCONY_Z), Color(0.95, 0.75, 0.1))
	# Ramps up to the balcony at both ends.
	var rise := BALCONY_Y
	var run_len := BALCONY_Z - RAMP_BOTTOM_Z
	var length := sqrt(rise * rise + run_len * run_len)
	var angle := atan(rise / run_len)
	for sx in [-1.0, 1.0]:
		var ramp := _solid(root, Vector3(RAMP_W, 0.3, length), Vector3(sx * RAMP_X, rise * 0.5 - 0.12, RAMP_BOTTOM_Z + run_len * 0.5), Color(0.35, 0.38, 0.45))
		ramp.rotation.x = -angle
		ramp.name = "Ramp"
		for side in [-1.0, 1.0]:
			var r2 := Shapes.box(root, Vector3(0.08, 0.08, length), Vector3(sx * RAMP_X + side * RAMP_W * 0.5, rise * 0.5 + 0.9, RAMP_BOTTOM_Z + run_len * 0.5), Color(0.95, 0.75, 0.1))
			r2.rotation.x = -angle


## North-side bleachers with a safety net in front. Returns world seat positions.
static func _bleachers(root: Node3D) -> Array:
	# Rows climb toward the north wall (rot PI), the front row nearest the court.
	var b := Props.bleachers(root, Vector3(0, 0, -HALF_Z + 2.8), 26.0, 4, PI)
	var seats := []
	for s in b.get_meta("seats"):
		seats.append(b.to_global(s) if b.is_inside_tree() else b.transform * s)
	Props.fence(root, Vector3(-14, 0, -12.6), Vector3(14, 0, -12.6), 3.0)
	for x in [-14.0, 14.0]:
		Props.fence(root, Vector3(x, 0, -12.6), Vector3(x, 0, -HALF_Z), 3.0)
	return seats


static func _stage(root: Node3D) -> void:
	var sx := -HALF_X + 2.5
	_solid(root, Vector3(5.0, 1.0, 14.0), Vector3(sx, 0.5, 0), Color(0.55, 0.38, 0.22), "wood")
	Shapes.box(root, Vector3(0.1, 0.9, 14.0), Vector3(sx + 2.5, 0.45, 0), Color(0.25, 0.15, 0.1))
	# Steps up to the stage.
	var steps := _solid(root, Vector3(2.4, 0.25, 3.0), Vector3(sx + 3.0, 0.5, 0), Color(0.5, 0.35, 0.2), "wood")
	steps.rotation.z = -0.38
	# Velvet curtains with folds and a valance.
	var red := Color(0.6, 0.06, 0.1)
	for i in 14:
		var fold := Shapes.box(root, Vector3(0.3, 7.0, 1.05), Vector3(-HALF_X + 0.35 + (i % 2) * 0.15, 4.5, -6.5 + i * 1.0), red.lightened((i % 2) * 0.08))
		fold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Shapes.box(root, Vector3(0.5, 1.0, 14.6), Vector3(-HALF_X + 0.6, 8.3, 0), red.darkened(0.2))
	Shapes.box(root, Vector3(0.52, 0.12, 14.6), Vector3(-HALF_X + 0.6, 7.75, 0), Color(0.95, 0.75, 0.2))
	# Lectern.
	Shapes.solid_box(root, Vector3(0.7, 1.2, 0.5), Vector3(sx + 1.2, 1.6, 0), Color(0.4, 0.25, 0.14), PI / 2)
	Props.banner(root, Vector3(-HALF_X + 0.9, 6.2, 0), 6.0, 1.2, Color(0.15, 0.3, 0.7), "ASSEMBLY TODAY", -PI / 2)


## Spawn doors (with EXIT signs). Returns positions just inside each door.
static func _doors(root: Node3D) -> Array:
	# [door position on the wall, yaw that turns the prop's -Z front into the gym, spawn spot]
	var spots := [
		[Vector3(-20.5, 0, -HALF_Z + 0.25), PI, Vector3(-20.5, 0.1, -15.0)],
		[Vector3(20.5, 0, -HALF_Z + 0.25), PI, Vector3(20.5, 0.1, -15.0)],
		[Vector3(HALF_X - 0.25, 0, -8.0), PI / 2, Vector3(22.0, 0.1, -8.0)],
		[Vector3(HALF_X - 0.25, 0, 8.0), PI / 2, Vector3(22.0, 0.1, 8.0)],
		[Vector3(0, 0, HALF_Z - 0.25), 0.0, Vector3(0, 0.1, 15.3)],
		[Vector3(-HALF_X + 0.25, 0, 11.0), -PI / 2, Vector3(-22.0, 0.1, 11.0)],
	]
	var out := []
	for s in spots:
		var pos: Vector3 = s[0]
		var front_yaw: float = s[1]
		for side in [-0.62, 0.62]:
			var offset := Vector3(side, 0, 0).rotated(Vector3.UP, front_yaw)
			Props.door(root, pos + offset, 1.2, 2.6, front_yaw, Color(0.3, 0.45, 0.65))
		var sign_pos := pos + Vector3(0, 3.1, 0) + Vector3(0, 0, -0.1).rotated(Vector3.UP, front_yaw)
		var sign_box := Shapes.box(root, Vector3(0.9, 0.35, 0.1), sign_pos, Color(0.1, 0.1, 0.1))
		sign_box.rotation.y = front_yaw
		var l := Shapes.label(root, "EXIT", sign_pos + Vector3(0, 0, -0.07).rotated(Vector3.UP, front_yaw), Color(1, 0.25, 0.2), 60)
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.rotation.y = front_yaw + PI
		l.modulate = Color(1.0, 0.3, 0.25)
		out.append(s[2])
	return out


static func _cover(root: Node3D) -> void:
	Props.gym_mats(root, Vector3(-8, 0, -5.2), 0.1, 5)
	Props.gym_mats(root, Vector3(8, 0, 5.2), -0.15, 5)
	Props.gym_mats(root, Vector3(4, 0, -9.0), PI / 2, 3)
	Props.gym_mats(root, Vector3(-4, 0, 9.0), PI / 2, 3)
	Props.vault_box(root, Vector3(0, 0, -6.0), 0.0)
	Props.vault_box(root, Vector3(-12, 0, 6.0), PI / 2)
	Props.vault_box(root, Vector3(12, 0, -6.0), PI / 2)
	Props.ball_cart(root, Vector3(6, 0, -2.0), 0.4)
	Props.ball_cart(root, Vector3(-6, 0, 2.5), -0.3)
	Props.gym_mats(root, Vector3(15, 0, 2.0), 0.0, 2)
	Props.gym_mats(root, Vector3(-16, 0, -4.0), 0.0, 2)
	for p in [Vector3(-2, 0, 3), Vector3(2.5, 0, 3.4), Vector3(10, 0, -1), Vector3(-10, 0, -1.5), Vector3(17, 0, -10), Vector3(-17, 0, 9)]:
		Props.cone(root, p)


static func _lights(root: Node3D) -> void:
	for x in [-14.0, -4.5, 4.5, 14.0]:
		for z in [-6.0, 4.0]:
			Props.hanging_light(root, Vector3(x, 8.4, z), true, WALL_H - 8.4)
	# High windows along both long walls; on High, warm light shafts pour through them.
	for i in 6:
		var x := -17.5 + i * 7.0
		Props.window(root, Vector3(x, 7.6, -HALF_Z + 0.05), 3.2, 1.7, PI)
		Props.window(root, Vector3(x, 7.6, HALF_Z - 0.05), 3.2, 1.7, 0.0)
		if Art.q("volumetric") and i % 2 == 0:
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.88, 0.65)
			spot.light_energy = 2.2
			spot.light_volumetric_fog_energy = 3.0
			spot.spot_range = 18.0
			spot.spot_angle = 16.0
			spot.position = Vector3(x, 7.6, HALF_Z - 0.6)
			root.add_child(spot)
			spot.rotation = Vector3(-0.85, 0.25, 0)


static func _decor(root: Node3D) -> void:
	# The home hoop (east end) and a raised one over the stage.
	Props.hoop(root, Vector3(HALF_X - 2.3, 0, 0), PI / 2)
	var hp := Props.hoop(root, Vector3(-HALF_X + 6.0, 1.0, 0), -PI / 2)
	hp.scale = Vector3(0.9, 0.9, 0.9)
	Props.banner(root, Vector3(HALF_X - 0.12, 7.0, -11.0), 3.0, 2.2, Color(0.15, 0.3, 0.75), "SHARKS\n1998\nCHAMPS", PI / 2)
	Props.banner(root, Vector3(HALF_X - 0.12, 7.0, 11.0), 3.0, 2.2, Color(0.85, 0.2, 0.2), "GO\nSHARKS!", PI / 2)
	Props.banner(root, Vector3(-HALF_X + 0.12, 7.0, -12.0), 3.0, 2.2, Color(0.95, 0.65, 0.1), "PTA\nBAKE SALE\nFRIDAY", -PI / 2)
	Props.banner(root, Vector3(-HALF_X + 0.12, 7.0, 12.5), 3.0, 2.2, Color(0.3, 0.7, 0.35), "NO\nRUNNING\n(lol)", -PI / 2)
	Props.vending(root, Vector3(HALF_X - 0.7, 0, -13.0), PI / 2, Color(0.2, 0.45, 0.85))
	Props.vending(root, Vector3(HALF_X - 0.7, 0, 13.0), PI / 2, Color(0.85, 0.15, 0.15))
	Props.trash_can(root, Vector3(HALF_X - 0.7, 0, -11.2), Color(0.2, 0.35, 0.65))
	Props.trash_can(root, Vector3(-HALF_X + 0.7, 0, -9.5))
	Props.bench(root, Vector3(HALF_X - 0.8, 0, -4.0), PI / 2, Color(0.35, 0.55, 0.8))
	Props.bench(root, Vector3(HALF_X - 0.8, 0, 4.0), PI / 2, Color(0.35, 0.55, 0.8))
	Props.plant(root, Vector3(-HALF_X + 0.8, 0, -14.5))
	Props.plant(root, Vector3(HALF_X - 0.8, 0, 15.8))
	Props.ball_cart(root, Vector3(-18, 0, -14.6), 0.0)
	# Trophy case and a water fountain on the end walls.
	var case := Shapes.solid_box(root, Vector3(0.6, 2.0, 3.0), Vector3(HALF_X - 0.35, 1.0, 15.0), Color(0.45, 0.28, 0.16), 0.0)
	var cg := Shapes.box(case, Vector3(0.05, 1.6, 2.7), Vector3(-0.31, 0.1, 0), Color.WHITE)
	cg.material_override = Props.glass_mat()
	for i in 4:
		var cup := Shapes.cylinder(case, 0.12, 0.3, Vector3(-0.1, -0.3 + (i % 2) * 0.7, -0.9 + i * 0.6), Color(0.95, 0.78, 0.2))
		cup.material_override = Shapes.mat(Color(0.95, 0.78, 0.2), 0.5)
		(cup.mesh as CylinderMesh).bottom_radius = 0.05


## The wave scoreboard above the bleachers. Returns the label main updates each wave.
static func _scoreboard(root: Node3D) -> Label3D:
	var pos := Vector3(0, 7.2, -HALF_Z + 0.35)
	var board := Shapes.box(root, Vector3(7.0, 2.6, 0.35), pos, Color(0.08, 0.08, 0.1))
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Shapes.box(root, Vector3(7.3, 0.15, 0.4), pos + Vector3(0, 1.35, 0), Color(0.95, 0.75, 0.1))
	var head := Shapes.label(root, "HOME: YOU          AWAY: PARENTS", pos + Vector3(0, 0.85, 0.2), Color(1, 0.85, 0.3), 70)
	head.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var l := Shapes.label(root, "GET READY", pos + Vector3(0, -0.15, 0.2), Color(1.0, 0.35, 0.25), 220)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.name = "Scoreboard"
	l.outline_size = 0
	l.modulate = Color(1.0, 0.35, 0.25)
	return l


## Cheering kids in the bleachers: rigs only, no collision (they can't be hit).
static func _spectators(root: Node3D, seats: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var picks := seats.duplicate()
	picks.shuffle()
	for i in mini(14, picks.size()):
		var s := SpectatorScript.new()
		s.name = "Spectator"
		s.shirt = Color.from_hsv(rng.randf(), 0.65, 0.95)
		s.add_to_group("spectators")
		root.add_child(s)
		s.global_position = picks[i]
		s.rotation.y = PI
