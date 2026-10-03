class_name Levels
## Procedural level geometry. Each builder fills a NavigationRegion3D (which is then
## baked so the AI can path around obstacles) and returns layout info:
## half (arena half-size), spawn, spawn_yaw, kid_bounds (Rect2 over x/z),
## extracts [{name, pos}], parent_spawns, patrol (guard waypoints), pois (kid hangouts).


static func build(id: String, root: Node3D) -> Dictionary:
	var region := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	region.navigation_mesh = nm
	root.add_child(region)
	var info: Dictionary
	match id:
		"locals":
			info = _locals(region)
		"mall":
			info = _mall(region)
		"pizza":
			info = _pizza(region)
		"arena":
			info = Arena.build(region)
		_:
			info = _playground(region)
	var half: float = info["half"]
	nm.filter_baking_aabb = AABB(Vector3(-half, -1, -half), Vector3(half * 2, 6, half * 2))
	region.bake_navigation_mesh(false)
	return info


# --- Shared bits -------------------------------------------------------------

static func _ground(root: Node3D, size: float, color: Color, tex := "") -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	root.add_child(ground)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 1, size)
	cs.shape = shape
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	mi.material_override = Art.textured(color, tex) if tex != "" else Shapes.mat(color)
	ground.add_child(mi)


static func _perimeter(root: Node3D, half: float, height: float, color: Color, tex := "") -> void:
	Shapes.solid_box(root, Vector3(half * 2, height, 0.4), Vector3(0, height / 2, -half), color, 0.0, tex)
	Shapes.solid_box(root, Vector3(half * 2, height, 0.4), Vector3(0, height / 2, half), color, 0.0, tex)
	Shapes.solid_box(root, Vector3(0.4, height, half * 2), Vector3(-half, height / 2, 0), color, 0.0, tex)
	Shapes.solid_box(root, Vector3(0.4, height, half * 2), Vector3(half, height / 2, 0), color, 0.0, tex)


static func _sign(root: Node3D, text: String, pos: Vector3, color: Color, size := 120, rot_y := 0.0) -> void:
	var l := Shapes.label(root, text, pos, color, size)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = rot_y


static func _tree(root: Node3D, pos: Vector3) -> void:
	Art.tree(root, pos)


static func _car(root: Node3D, pos: Vector3, color: Color, rot_y := 0.0) -> void:
	var car := Shapes.solid_box(root, Vector3(2.0, 1.1, 4.2), pos + Vector3(0, 0.75, 0), color, rot_y)
	Shapes.box(car, Vector3(1.8, 0.7, 2.2), Vector3(0, 0.85, 0.2), color.darkened(0.15))
	Shapes.box(car, Vector3(1.82, 0.5, 2.0), Vector3(0, 0.9, 0.2), Color(0.5, 0.7, 0.85))


static func _table(root: Node3D, pos: Vector3, length: float, mat_color: Color) -> void:
	Shapes.solid_box(root, Vector3(length, 0.8, 1.4), pos + Vector3(0, 0.4, 0), Color(0.62, 0.62, 0.6))
	var n := int(length / 1.5)
	for i in n:
		var x := -length / 2 + 0.75 + i * 1.5
		Shapes.box(root, Vector3(1.2, 0.02, 0.6), pos + Vector3(x, 0.81, -0.35), mat_color)
		Shapes.box(root, Vector3(1.2, 0.02, 0.6), pos + Vector3(x, 0.81, 0.35), mat_color.darkened(0.3))


# --- Sunnyvale Playground ----------------------------------------------------

static func _playground(root: Node3D) -> Dictionary:
	var half := 30.0
	_ground(root, 120, Color(0.36, 0.6, 0.28), "grass")
	# See-through chain-link fence around the schoolyard (same footprint as a wall).
	for c in [[Vector3(-half, 0, -half), Vector3(half, 0, -half)], [Vector3(-half, 0, half), Vector3(half, 0, half)],
			[Vector3(-half, 0, -half), Vector3(-half, 0, half)], [Vector3(half, 0, -half), Vector3(half, 0, half)]]:
		Props.fence(root, c[0], c[1], 2.4)
	Shapes.box(root, Vector3(18, 0.02, 12), Vector3(-14, 0.01, 12), Color(0.55, 0.55, 0.6), "asphalt")
	Shapes.box(root, Vector3(0.2, 0.03, 12), Vector3(-14, 0.02, 12), Color.WHITE)

	# School building.
	Shapes.solid_box(root, Vector3(30, 9, 8), Vector3(0, 4.5, -25.5), Color(0.95, 0.6, 0.5), 0.0, "brick")
	Shapes.box(root, Vector3(3, 4, 0.2), Vector3(0, 2, -21.4), Color(0.35, 0.2, 0.12))
	for x in [-11, -6, 6, 11]:
		Props.window(root, Vector3(x, 5.6, -21.45), 3.0, 2.0, PI)
	for x in [-11, -6, 6, 11]:
		Props.window(root, Vector3(x, 2.1, -21.45), 3.0, 1.8, PI)
	_sign(root, "SUNNYVALE ELEMENTARY", Vector3(0, 8, -21.3), Color(1, 1, 0.8), 160)
	Props.roof(root, Vector3(0, 9.12, -25.5), Vector2(30.6, 8.6), Color(0.45, 0.42, 0.42))
	for side in [-0.62, 0.62]:
		Props.door(root, Vector3(side, 0, -21.42), 1.2, 3.2, PI, Color(0.25, 0.4, 0.7))
	Props.curb(root, Vector3(0, 0, -20.4), Vector2(8.0, 2.0))
	Props.flagpole(root, Vector3(6.5, 0, -19.6), 7.5)
	Props.bike_rack(root, Vector3(-6.5, 0, -19.6), 0.0, 2)

	# Sandbox.
	var wood := Color(0.6, 0.4, 0.2)
	Shapes.solid_box(root, Vector3(6, 0.4, 0.3), Vector3(8, 0.2, -6), wood)
	Shapes.solid_box(root, Vector3(6, 0.4, 0.3), Vector3(8, 0.2, 0), wood)
	Shapes.solid_box(root, Vector3(0.3, 0.4, 6), Vector3(5, 0.2, -3), wood)
	Shapes.solid_box(root, Vector3(0.3, 0.4, 6), Vector3(11, 0.2, -3), wood)
	Shapes.box(root, Vector3(5.7, 0.05, 5.7), Vector3(8, 0.03, -3), Color(0.93, 0.85, 0.6))

	# Slide.
	Shapes.solid_box(root, Vector3(2, 3, 2), Vector3(-8, 1.5, -8), Color(0.95, 0.75, 0.2))
	Shapes.solid_box(root, Vector3(1.4, 0.2, 5), Vector3(-8, 1.6, -4.0), Color(0.9, 0.2, 0.2)).rotation.x = deg_to_rad(-30)

	# Swings.
	for x in [-1.5, 3.5]:
		Shapes.solid_cylinder(root, 0.1, 3, Vector3(x, 1.5, 8), Color(0.3, 0.4, 0.9))
	Shapes.box(root, Vector3(5.2, 0.15, 0.15), Vector3(1, 3, 8), Color(0.3, 0.4, 0.9))
	for x in [0, 2]:
		Shapes.box(root, Vector3(0.03, 2.2, 0.03), Vector3(x, 1.9, 8), Color(0.2, 0.2, 0.2))
		Shapes.box(root, Vector3(0.6, 0.06, 0.3), Vector3(x, 0.8, 8), Color(0.15, 0.15, 0.15))

	# Jungle gym.
	for x in [0, 2, 4]:
		for z in [0, 2]:
			Shapes.solid_cylinder(root, 0.08, 2.4, Vector3(-20 + x, 1.2, -8 + z), Color(0.2, 0.75, 0.3))
	Shapes.solid_box(root, Vector3(4.4, 0.15, 2.4), Vector3(-18, 2.4, -7), Color(0.2, 0.75, 0.3))

	for b in [Vector3(-4, 0.25, 18), Vector3(4, 0.25, 18), Vector3(18, 0.25, -4)]:
		Shapes.solid_box(root, Vector3(2.4, 0.5, 0.6), b, Color(0.85, 0.6, 0.4), 0.0, "wood")
	for t in [Vector3(-24, 0, 20), Vector3(-22, 0, -14), Vector3(24, 0, -10), Vector3(14, 0, 8),
			Vector3(-6, 0, 24), Vector3(-26, 0, 2), Vector3(25, 0, 6)]:
		_tree(root, t)

	# Extraction props.
	Props.bus(root, Vector3(-26, 0, 24), PI)
	Shapes.solid_box(root, Vector3(2.4, 2.6, 4.5), Vector3(26, 1.3, 22), Color(0.88, 0.9, 0.96)) # ice cream truck
	for side in [-1, 1]:
		Shapes.box(root, Vector3(0.04, 0.35, 4.5), Vector3(26 + side * 1.21, 0.75, 22), Color(1.0, 0.45, 0.65))
		Shapes.box(root, Vector3(0.04, 0.9, 1.8), Vector3(26 + side * 1.21, 1.75, 22.4), Color(0.45, 0.75, 0.95))
		for wz in [20.4, 23.6]:
			Shapes.cylinder(root, 0.4, 0.3, Vector3(26 + side * 1.2, 0.4, wz), Color(0.12, 0.12, 0.14)).rotation.z = PI / 2
	Shapes.cylinder(root, 0.35, 0.9, Vector3(26, 3.05, 22), Color(0.85, 0.6, 0.3))
	Shapes.sphere(root, 0.5, Vector3(26, 3.6, 22), Color(1.0, 0.6, 0.75))

	# Dressing: swaying grass, bushes along the fence, lamp posts, clouds.
	Art.grass(root, [Rect2(-29, -21, 58, 50)], [Rect2(-23.5, 5.5, 19, 13), Rect2(4.5, -6.5, 7, 7), Rect2(-16, -21, 32, 1.5)],
		Color(0.35, 0.7, 0.3))
	for x in range(-26, 27, 6):
		Art.bush(root, Vector3(x, 0, 28.6))
	for z in [-14, -4, 14]:
		Art.bush(root, Vector3(-28.6, 0, z))
		Art.bush(root, Vector3(28.6, 0, z))
	for lp in [Vector3(-8, 0, 20), Vector3(10, 0, 20), Vector3(22, 0, -2), Vector3(-22, 0, -2)]:
		Art.lamp_post(root, lp, false)
	# Schoolyard furniture and a hoop on the blacktop.
	Props.picnic_table(root, Vector3(10, 0, 25.5), 0.0)
	Props.picnic_table(root, Vector3(15.5, 0, 25.5), 0.0)
	for tc in [Vector3(-3, 0, 17.6), Vector3(16, 0, -14.5), Vector3(-15.5, 0, 19.0), Vector3(12.8, 0, 25.6)]:
		Props.trash_can(root, tc)
	Props.hoop(root, Vector3(-22.4, 0, 12), -PI / 2)
	Shapes.box(root, Vector3(4.5, 0.025, 4.0), Vector3(-19.8, 0.02, 12), Color(0.85, 0.3, 0.25))
	Props.hydrant(root, Vector3(20.5, 0, 28.4))
	Props.cone(root, Vector3(-9, 0, 9))
	Props.cone(root, Vector3(-10.5, 0, 14.5))
	# The neighborhood past the fence: trees and houses so the fence has something behind it.
	for t in [Vector3(-38, 0, -10), Vector3(-36, 0, 18), Vector3(38, 0, 8), Vector3(36, 0, -22), Vector3(10, 0, 38), Vector3(-18, 0, 37)]:
		Art.tree(root, t, 1.3)
	for i in 5:
		var hx := -24.0 + i * 12.0
		var hc := Color.from_hsv(0.05 + i * 0.17, 0.35, 0.9)
		Shapes.box(root, Vector3(8, 5, 7), Vector3(hx, 2.5, 44), hc)
		var roof_mi := Shapes.box(root, Vector3(8.6, 0.4, 5.4), Vector3(hx, 5.9, 44), Color(0.55, 0.25, 0.2))
		roof_mi.rotation.x = 0.0
		Shapes.box(root, Vector3(1.4, 2.2, 0.1), Vector3(hx, 1.1, 40.45), Color(0.4, 0.25, 0.15))
	Art.clouds(root)

	return {
		"half": half,
		"patrol": [Vector3(15, 0, 12), Vector3(-10, 0, 14), Vector3(-16, 0, -12), Vector3(14, 0, -14), Vector3(0, 0, 2)],
		"pois": [Vector3(8, 0, -3), Vector3(1, 0, 9.5), Vector3(-8, 0, -5), Vector3(-18, 0, -5), Vector3(-14, 0, 12), Vector3(0, 0, 17)],
		"spawn": Vector3(18, 0.1, 16), "spawn_yaw": PI * 0.25,
		"kid_bounds": Rect2(-24, -18, 48, 42),
		"extracts": [
			{"name": "School Bus", "pos": Vector3(-23, 0, 24)},
			{"name": "Ice Cream Truck", "pos": Vector3(23, 0, 24)},
			{"name": "Hole in the Fence", "pos": Vector3(27, 0, -18)},
		],
		"parent_spawns": [Vector3(0, 0.1, -19), Vector3(-27, 0.1, 0), Vector3(27, 0.1, 0), Vector3(0, 0.1, 27)],
	}


# --- Friday Night Locals @ Dragon's Den Games --------------------------------

static func _locals(root: Node3D) -> Dictionary:
	var half := 24.0
	_ground(root, 100, Color(0.6, 0.6, 0.64), "asphalt") # parking lot
	_perimeter(root, half, 2.5, Color(0.8, 0.78, 0.75), "concrete")

	# Store floor and walls (x -15..15, z -16..6). Door gaps at the front and back.
	var wall := Color(0.85, 0.45, 0.42)
	Shapes.box(root, Vector3(30, 0.02, 22), Vector3(0, 0.01, -5), Color(0.75, 0.6, 0.45), "wood")
	Shapes.solid_box(root, Vector3(0.4, 4, 22), Vector3(-15, 2, -5), wall, 0.0, "brick")
	Shapes.solid_box(root, Vector3(0.4, 4, 22), Vector3(15, 2, -5), wall, 0.0, "brick")
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(-8.5, 2, 6), wall, 0.0, "brick")
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(8.5, 2, 6), wall, 0.0, "brick")
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(-8.5, 2, -16), wall, 0.0, "brick")
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(8.5, 2, -16), wall, 0.0, "brick")
	Shapes.box(root, Vector3(30.4, 1.2, 0.5), Vector3(0, 4.6, 6), Color(0.15, 0.1, 0.2))
	_sign(root, "DRAGON'S DEN GAMES", Vector3(0, 4.6, 6.3), Color(1, 0.75, 0.2), 150)
	_sign(root, "FRIDAY NIGHT LOCALS\nentry: 1 binder", Vector3(0, 3.2, -15.7), Color(0.9, 0.9, 1.0), 110)
	# Roof with AC units, a fluorescent-lit ceiling inside, glass front windows and a curb.
	Props.roof(root, Vector3(0, 4.12, -5), Vector2(30.6, 22.6), Color(0.42, 0.4, 0.42))
	for z in [-12.0, -6.5, -1.0]:
		for x in [-7.0, 7.0]:
			Props.ceiling_light(root, Vector3(x, 3.95, z), Vector2(2.4, 0.6), x < 0)
	Props.window(root, Vector3(-6.0, 2.2, 6.22), 3.4, 2.0, PI, Color(0.3, 0.2, 0.25))
	Props.window(root, Vector3(4.0, 2.2, 6.22), 3.4, 2.0, PI, Color(0.3, 0.2, 0.25))
	Props.curb(root, Vector3(0, 0, 7.5), Vector2(30.0, 2.6))
	Props.trash_can(root, Vector3(-3.4, 0.15, 7.4), Color(0.25, 0.25, 0.3))
	Props.trash_can(root, Vector3(3.4, 0.15, 7.4), Color(0.25, 0.25, 0.3))
	Props.vending(root, Vector3(13.5, 0.15, 7.3), PI, Color(0.15, 0.4, 0.85))
	Props.hydrant(root, Vector3(-16.5, 0, 8.2))

	# Tournament tables with play mats.
	var mats := [Color(0.2, 0.3, 0.7), Color(0.6, 0.15, 0.2), Color(0.2, 0.5, 0.3), Color(0.4, 0.2, 0.6)]
	var i := 0
	for z in [-11.0, -6.5, -2.0]:
		for x in [-7.0, 7.0]:
			_table(root, Vector3(x, 0, z), 9.0, mats[i % mats.size()])
			i += 1

	# Shelves of booster boxes along the side walls.
	for z in [-13.0, -9.0, -5.0, -1.0, 3.0]:
		for side in [-1, 1]:
			var x: float = side * 13.8
			Shapes.solid_box(root, Vector3(1.2, 2.4, 3.2), Vector3(x, 1.2, z), Color(0.35, 0.25, 0.18))
			for shelf in 3:
				Shapes.box(root, Vector3(1.25, 0.35, 2.9), Vector3(x, 0.5 + shelf * 0.75, z),
					Color.from_hsv(randf(), 0.7, 0.9))

	# Counter with register.
	Shapes.solid_box(root, Vector3(5, 1.1, 1.2), Vector3(9, 0.55, 2.5), Color(0.3, 0.2, 0.15))
	Shapes.box(root, Vector3(0.6, 0.4, 0.5), Vector3(8, 1.3, 2.5), Color(0.2, 0.2, 0.2))
	_sign(root, "NO REFUNDS\nNO SCAMMING", Vector3(9, 2.6, 5.75), Color(1, 0.4, 0.4), 70, PI)

	# Parking lot cars and lines.
	for x in [-18.0, -13.0, -8.0, 8.0, 13.0, 18.0]:
		Shapes.box(root, Vector3(0.15, 0.02, 5), Vector3(x + 2.5, 0.02, 14), Color(0.9, 0.9, 0.9))
	Props.car(root, Vector3(-15.5, 0, 14), Color(0.7, 0.1, 0.1))
	Props.car(root, Vector3(-5.5, 0, 14), Color(0.2, 0.4, 0.8), PI)
	Props.car(root, Vector3(15.5, 0, 14), Color(0.85, 0.85, 0.85))
	Props.car(root, Vector3(10.5, 0, 14), Color(0.55, 0.6, 0.5), PI, true)  # Mom's minivan
	# Back alley dumpster.
	Shapes.solid_box(root, Vector3(3, 1.6, 1.6), Vector3(-6, 0.8, -19), Color(0.15, 0.4, 0.2))
	Props.bus_shelter(root, Vector3(-21.0, 0, 22.2), 0.0)
	Props.cone(root, Vector3(0, 0, 10.5))
	Props.cone(root, Vector3(1.5, 0, 10.5))

	# Dressing: lot lamps (it's evening), tournament posters, folding chairs, clouds.
	for lp in [Vector3(-18, 0, 9), Vector3(-6, 0, 9), Vector3(6, 0, 9), Vector3(18, 0, 9)]:
		Art.lamp_post(root, lp)
	var poster_cols := [Color(0.95, 0.3, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.8, 0.2), Color(0.6, 0.9, 0.4)]
	for n in 4:
		var px := -13.0 + n * 3.0 if n < 2 else 7.0 + (n - 2) * 3.0
		Shapes.box(root, Vector3(1.6, 2.0, 0.05), Vector3(px, 2.0, 6.25), poster_cols[n])
		Shapes.box(root, Vector3(1.2, 0.8, 0.06), Vector3(px, 2.3, 6.26), Color(0.98, 0.95, 0.9))
	for z in [-11.0, -6.5, -2.0]:
		for x in [-10.0, -7.0, -4.0, 4.0, 7.0, 10.0]:
			for side in [-1.0, 1.0]:
				Shapes.box(root, Vector3(0.45, 0.45, 0.45), Vector3(x, 0.23, z + side * 1.15), Color(0.3, 0.32, 0.36))
	Art.clouds(root, Color(1.0, 0.82, 0.75))

	return {
		"half": half,
		"patrol": [Vector3(0, 0, 2), Vector3(-11, 0, -4), Vector3(-11, 0, -13.5), Vector3(11, 0, -13.5), Vector3(11, 0, -4), Vector3(0, 0, -8.7)],
		"pois": [Vector3(-7, 0, -9.3), Vector3(7, 0, -9.3), Vector3(-7, 0, -4.2), Vector3(7, 0, -4.2), Vector3(-7, 0, 0.2), Vector3(7, 0, 0.2), Vector3(11.5, 0, -1)],
		"spawn": Vector3(0, 0.1, 18), "spawn_yaw": 0.0,
		"indoor": AABB(Vector3(-15, 0, -16), Vector3(30, 4, 22)),
		"kid_bounds": Rect2(-11, -14, 22, 17),
		"extracts": [
			{"name": "Mom's Minivan", "pos": Vector3(10.5, 0, 18.5)},
			{"name": "Back Alley", "pos": Vector3(4, 0, -20)},
			{"name": "Bus Stop", "pos": Vector3(-20, 0, 17)},
		],
		"parent_spawns": [Vector3(-20, 0.1, 21), Vector3(20, 0.1, 21), Vector3(0, 0.1, 21), Vector3(-18, 0.1, -20), Vector3(18, 0.1, -20)],
	}


# --- Galleria Mall Food Court ------------------------------------------------

static func _mall(root: Node3D) -> Dictionary:
	var half := 26.0
	_ground(root, 100, Color(0.58, 0.56, 0.6), "tiles")
	_perimeter(root, half, 6.0, Color(0.74, 0.74, 0.76), "concrete")
	# Checker tiles.
	for x in range(-24, 24, 4):
		for z in range(-24, 24, 4):
			if posmod(int((x + z) / 4.0), 2) == 0:
				Shapes.box(root, Vector3(4, 0.02, 4), Vector3(x + 2, 0.01, z + 2), Color(0.55, 0.52, 0.5), "tiles")

	# Storefronts along the walls.
	var shops := [["CINNABUN", Color(0.9, 0.6, 0.3)], ["HOT TOPIK", Color(0.2, 0.2, 0.2)],
		["GAME STOPP", Color(0.8, 0.1, 0.1)], ["BUILD-A-BEAR-ISH", Color(0.6, 0.4, 0.8)],
		["ORANGE MAN JULIUS", Color(1, 0.55, 0.1)], ["PANDA EXPRESSO", Color(0.8, 0.15, 0.2)]]
	for s in 3:
		var x := -16.0 + s * 16.0
		Shapes.solid_box(root, Vector3(10, 4, 3), Vector3(x, 2, -24.4), shops[s][1])
		Props.storefront(root, Vector3(x, 0, -22.86), 10.0, shops[s][0], shops[s][1], PI)
		Shapes.solid_box(root, Vector3(10, 4, 3), Vector3(x, 2, 24.4), shops[s + 3][1])
		Props.storefront(root, Vector3(x, 0, 22.86), 10.0, shops[s + 3][0], shops[s + 3][1], 0.0)

	# Fountain.
	Shapes.solid_cylinder(root, 3.2, 0.8, Vector3(0, 0.4, 0), Color(0.75, 0.75, 0.8))
	var water := Shapes.cylinder(root, 2.9, 0.1, Vector3(0, 0.82, 0), Color(0.3, 0.6, 0.95))
	water.material_override = Shapes.mat(Color(0.3, 0.6, 0.95), 0.4)
	Shapes.solid_cylinder(root, 0.4, 2.4, Vector3(0, 1.2, 0), Color(0.75, 0.75, 0.8))

	# Food court tables with umbrellas.
	for pos in [Vector3(-12, 0, -10), Vector3(-6, 0, -12), Vector3(6, 0, -12), Vector3(12, 0, -10),
			Vector3(-12, 0, 10), Vector3(-6, 0, 12), Vector3(6, 0, 12), Vector3(12, 0, 10),
			Vector3(-14, 0, 0), Vector3(14, 0, 0)]:
		Shapes.solid_cylinder(root, 0.8, 0.8, pos + Vector3(0, 0.4, 0), Color(0.95, 0.95, 0.95))
		Shapes.cylinder(root, 0.05, 1.6, pos + Vector3(0, 1.4, 0), Color(0.3, 0.3, 0.3))
		var umb := Shapes.cylinder(root, 1.4, 0.1, pos + Vector3(0, 2.2, 0), Color.from_hsv(randf(), 0.6, 0.9))
		var cm: CylinderMesh = umb.mesh
		cm.top_radius = 0.05
		cm.height = 0.5

	# Kiosks.
	for pos in [Vector3(-7, 0, 0), Vector3(7, 0, 0), Vector3(0, 0, -7), Vector3(0, 0, 7)]:
		Shapes.solid_box(root, Vector3(2.5, 1.2, 2.5), pos + Vector3(0, 0.6, 0), Color(0.4, 0.3, 0.25))
	_sign(root, "PHONE CASES", Vector3(7, 1.9, 0), Color(0.4, 1, 1), 60)
	_sign(root, "SUNGLASSES", Vector3(-7, 1.9, 0), Color(1, 1, 0.4), 60)

	# Dressing: planters with bushes around the court, clouds over the skylight.
	for pos in [Vector3(-18, 0, -14), Vector3(18, 0, -14), Vector3(-18, 0, 14), Vector3(18, 0, 14)]:
		Shapes.solid_box(root, Vector3(2.4, 0.7, 2.4), pos + Vector3(0, 0.35, 0), Color(0.75, 0.73, 0.7), 0.0, "concrete")
		Art.bush(root, pos + Vector3(0, 0.6, 0), Color(0.25, 0.6, 0.3))
	# Benches around the fountain, bins, plants and vending machines along the walls.
	for i in 4:
		var a := PI / 4 + i * PI / 2
		Props.bench(root, Vector3(cos(a) * 5.2, 0, sin(a) * 5.2), -a + PI / 2, Color(0.55, 0.35, 0.2))
	for tc in [Vector3(-9, 0, -4.5), Vector3(9, 0, 4.5), Vector3(-20.5, 0, 8), Vector3(20.5, 0, -8)]:
		Props.trash_can(root, tc, Color(0.55, 0.55, 0.6))
	for pp in [Vector3(-9.5, 0, 2.5), Vector3(9.5, 0, -2.5), Vector3(-3, 0, -9.5), Vector3(3, 0, 9.5)]:
		Props.plant(root, pp, 1.1)
	Props.vending(root, Vector3(25.3, 0, -6), PI / 2, Color(0.85, 0.15, 0.15))
	Props.vending(root, Vector3(-25.3, 0, 6), -PI / 2, Color(0.15, 0.55, 0.3))
	# Glass skylight: a steel grid whose shadows fall across the food court.
	for i in 13:
		var c := -24.0 + i * 4.0
		var bx := Shapes.box(root, Vector3(0.25, 0.35, 52), Vector3(c, 6.2, 0), Color(0.85, 0.87, 0.9))
		var bz := Shapes.box(root, Vector3(52, 0.35, 0.25), Vector3(0, 6.2, c), Color(0.85, 0.87, 0.9))
		for b in [bx, bz]:
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	Art.clouds(root)

	return {
		"half": half,
		"patrol": [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(18, 0, 18), Vector3(-18, 0, 18), Vector3(0, 0, -4.5), Vector3(0, 0, 4.5)],
		"pois": [Vector3(-12, 0, -8.5), Vector3(-6, 0, -10.5), Vector3(6, 0, -10.5), Vector3(12, 0, -8.5), Vector3(-12, 0, 8.5),
			Vector3(6, 0, 10.5), Vector3(0, 0, 4), Vector3(-16, 0, -20), Vector3(0, 0, -20)],
		"spawn": Vector3(-22, 0.1, 18), "spawn_yaw": -PI * 0.25,
		"indoor": AABB(Vector3(-24, 0, -24), Vector3(48, 5, 48)),
		"kid_bounds": Rect2(-20, -19, 40, 38),
		"extracts": [
			{"name": "Parking Garage", "pos": Vector3(23, 0, -20)},
			{"name": "Emergency Exit", "pos": Vector3(-23, 0, -20)},
			{"name": "Loading Dock", "pos": Vector3(23, 0, 20)},
		],
		"parent_spawns": [Vector3(-23, 0.1, 0), Vector3(23, 0.1, 0), Vector3(0, 0.1, -21), Vector3(0, 0.1, 21)],
	}


# --- Pizza Party Palace -------------------------------------------------------

static func _pizza(root: Node3D) -> Dictionary:
	var half := 24.0
	_ground(root, 100, Color(0.85, 0.25, 0.25), "tiles")
	_perimeter(root, half, 5.0, Color(0.55, 0.4, 0.9), "brick")
	# Checkerboard party floor.
	for x in range(-24, 24, 3):
		for z in range(-24, 24, 3):
			if posmod(int((x + z) / 3.0), 2) == 0:
				Shapes.box(root, Vector3(3, 0.02, 3), Vector3(x + 1.5, 0.01, z + 1.5), Color(1.0, 0.85, 0.25), "tiles")

	# Stage with the animatronic band (north).
	Shapes.solid_box(root, Vector3(12, 0.6, 4), Vector3(0, 0.3, -21.5), Color.WHITE, 0.0, "carpet")
	for i in 3:
		var x := -4.0 + i * 4.0
		var bot := Shapes.solid_cylinder(root, 0.5, 1.6, Vector3(x, 1.4, -21.5), Color.from_hsv(i * 0.3, 0.6, 0.8))
		Shapes.sphere(bot, 0.45, Vector3(0, 1.1, 0), Color.from_hsv(i * 0.3, 0.5, 0.9))
	_sign(root, "PIZZA PARTY PALACE", Vector3(0, 4.2, -23.6), Color(1, 0.85, 0.2), 170)
	# Stage curtains and a valance behind the band.
	for i in 13:
		var fold := Shapes.box(root, Vector3(1.0, 3.6, 0.25), Vector3(-6.0 + i * 1.0, 2.4, -23.5 + (i % 2) * 0.12), Color(0.65, 0.08, 0.15).lightened((i % 2) * 0.08))
		fold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign(root, "HAPPY BIRTHDAY TYLER!!", Vector3(0, 3.3, -23.6), Color(1, 0.4, 0.8), 110)

	# Party tables with pizzas and party hats (center).
	for z in [-15.0, -10.5, -6.0]:
		Shapes.solid_box(root, Vector3(9, 0.8, 1.6), Vector3(0, 0.4, z), Color(0.9, 0.9, 0.95))
		for x in [-3.0, 0.0, 3.0]:
			Shapes.cylinder(root, 0.45, 0.04, Vector3(x, 0.83, z), Color(0.95, 0.65, 0.2))
			var hat := Shapes.cylinder(root, 0.12, 0.3, Vector3(x + 0.8, 0.95, z + 0.4), Color.from_hsv(randf(), 0.7, 0.9))
			(hat.mesh as CylinderMesh).top_radius = 0.0

	# Arcade cabinets (east): rows facing west, with light-up side trim and marquees.
	for row in 3:
		for i in 4:
			var pos := Vector3(9.5 + row * 4.0, 0, -4.0 + i * 3.2)
			Props.arcade(root, pos, PI / 2, Color.from_hsv(randf(), 0.35, 0.25))
	_sign(root, "ARCADE", Vector3(13.5, 3.2, -6.5), Color(0.4, 1, 1), 120)

	# Prize counter (southeast).
	Shapes.solid_box(root, Vector3(8, 1.1, 1.2), Vector3(14, 0.55, 17), Color(0.6, 0.15, 0.6))
	for i in 10:
		Shapes.sphere(root, 0.25, Vector3(10.6 + i * 0.75, 1.35, 17), Color.from_hsv(randf(), 0.6, 1.0))
	_sign(root, "PRIZES  (500 tickets)", Vector3(14, 2.6, 17.65), Color(1, 1, 0.5), 80, PI)

	# Kitchen half-wall (northeast), back door extract behind it.
	Shapes.solid_box(root, Vector3(0.4, 2.2, 8), Vector3(16.5, 1.1, -18), Color(0.85, 0.85, 0.85))
	Shapes.solid_box(root, Vector3(3, 1.0, 1.0), Vector3(20, 0.5, -14.5), Color(0.6, 0.6, 0.65))
	_sign(root, "KITCHEN", Vector3(16.3, 2.6, -18), Color(1, 1, 1), 80, -PI / 2)

	# The ball pit (west): knee-high walls with gaps, hundreds of balls, a slide tower.
	var pit := AABB(Vector3(-21, -1, -12), Vector3(12, 3, 16))
	var wall_col := Color(0.2, 0.6, 1.0)
	Shapes.solid_box(root, Vector3(12, 0.5, 0.3), Vector3(-15, 0.25, -12), wall_col)
	Shapes.solid_box(root, Vector3(12, 0.5, 0.3), Vector3(-15, 0.25, 4), wall_col)
	Shapes.solid_box(root, Vector3(0.3, 0.5, 5.5), Vector3(-9, 0.25, -9.25), wall_col)
	Shapes.solid_box(root, Vector3(0.3, 0.5, 5.5), Vector3(-9, 0.25, 1.25), wall_col)
	_ball_pit_balls(root, pit)
	Shapes.solid_box(root, Vector3(2, 3.2, 2), Vector3(-19, 1.6, -10), Color(1.0, 0.5, 0.1))
	Shapes.box(root, Vector3(1.2, 0.15, 4.5), Vector3(-17.2, 1.6, -7.6), Color(0.95, 0.2, 0.3)).rotation.x = deg_to_rad(-35)
	_sign(root, "BALL PIT", Vector3(-15, 2.8, 4.2), Color(0.5, 0.9, 1.0), 120)

	# Parking-lot exit doors (southwest).
	Shapes.box(root, Vector3(3, 2.6, 0.2), Vector3(-19, 1.3, 23.7), Color(0.4, 0.5, 0.6))
	_sign(root, "EXIT", Vector3(-19, 3.0, 23.6), Color(1, 0.3, 0.3), 100, PI)

	# Dressing: balloon bunches and streamers along the walls, clouds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for pos in [Vector3(-6, 0, -18.5), Vector3(6, 0, -18.5), Vector3(-6, 0, 12), Vector3(8, 0, 12), Vector3(-21, 0, 10)]:
		for i in 4:
			var b := Shapes.sphere(root, 0.32, pos + Vector3(rng.randf_range(-0.5, 0.5), 2.4 + rng.randf() * 0.7, rng.randf_range(-0.5, 0.5)),
				Color.from_hsv(rng.randf(), 0.75, 1.0))
			b.scale = Vector3(1, 1.2, 1)
		Shapes.box(root, Vector3(0.02, 2.4, 0.02), pos + Vector3(0, 1.2, 0), Color(0.9, 0.9, 0.9))
	for i in 12:
		var x := -22.0 + i * 4.0
		var streamer := Shapes.box(root, Vector3(3.8, 0.25, 0.04), Vector3(x, 4.4, -23.7), Color.from_hsv(i / 12.0, 0.7, 1.0))
		streamer.rotation.z = 0.12 if i % 2 == 0 else -0.12
	# A ceiling with light panels (it doesn't cast sun shadows: the party stays bright).
	var ceil := Shapes.box(root, Vector3(48.5, 0.3, 48.5), Vector3(0, 5.15, 0), Color(0.5, 0.45, 0.6), "tiles")
	ceil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-14.0, 0.0, 14.0]:
		for z in [-14.0, 0.0, 14.0]:
			Props.ceiling_light(root, Vector3(x, 4.98, z), Vector2(2.0, 2.0), false)
	for pp in [Vector3(-22.6, 0, -20), Vector3(22.6, 0, 8)]:
		Props.plant(root, pp)
	Props.trash_can(root, Vector3(4.5, 0, -18.5), Color(0.9, 0.3, 0.5))
	Props.trash_can(root, Vector3(-6, 0, 16), Color(0.9, 0.3, 0.5))
	Props.vending(root, Vector3(22.9, 0, 12.5), PI / 2, Color(0.95, 0.5, 0.1))
	Art.clouds(root, Color(1.0, 0.85, 1.0))

	return {
		"half": half,
		"patrol": [Vector3(0, 0, 0), Vector3(6, 0, -12), Vector3(14, 0, 8), Vector3(4, 0, 18), Vector3(-6, 0, 10), Vector3(-6, 0, -18)],
		"pois": [Vector3(-3, 0, -13), Vector3(3, 0, -8.3), Vector3(0, 0, -18.5), Vector3(11.5, 0, -2), Vector3(15.5, 0, 4),
			Vector3(14, 0, 15.5), Vector3(-15, 0, -4), Vector3(-12, 0, 0), Vector3(-4, 0, 12)],
		"spawn": Vector3(0, 0.1, 20), "spawn_yaw": 0.0,
		"indoor": AABB(Vector3(-23, 0, -23), Vector3(46, 4.5, 46)),
		"kid_bounds": Rect2(-20, -19, 40, 37),
		"extracts": [
			{"name": "Kitchen Back Door", "pos": Vector3(20.5, 0, -19)},
			{"name": "Parking Lot", "pos": Vector3(-19, 0, 21)},
			{"name": "Ball Pit Slide", "pos": Vector3(-17, 0, -6)},
		],
		"parent_spawns": [Vector3(0, 0.1, 22), Vector3(21, 0.1, -10), Vector3(-21, 0.1, 18), Vector3(21, 0.1, 21)],
		"ball_pits": [pit],
	}


static func _ball_pit_balls(root: Node3D, pit: AABB) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	ball.radial_segments = 8
	ball.rings = 4
	mm.mesh = ball
	mm.instance_count = 420
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var palette := [Color(1, 0.2, 0.2), Color(0.2, 0.5, 1), Color(1, 0.85, 0.1), Color(0.2, 0.85, 0.3), Color(0.9, 0.3, 0.9)]
	for i in mm.instance_count:
		var pos := Vector3(rng.randf_range(pit.position.x + 0.3, pit.end.x - 0.3), rng.randf_range(0.12, 0.55),
			rng.randf_range(pit.position.z + 0.3, pit.end.z - 0.3))
		mm.set_instance_transform(i, Transform3D(Basis(), pos))
		mm.set_instance_color(i, palette[i % palette.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.4
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
