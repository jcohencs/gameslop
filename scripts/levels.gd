class_name Levels
## Procedural level geometry. Each builder fills `root` and returns layout info:
## spawn, spawn_yaw, kid_bounds (Rect2 over x/z), extracts [{name, pos}], parent_spawns.


static func build(id: String, root: Node3D) -> Dictionary:
	match id:
		"locals":
			return _locals(root)
		"mall":
			return _mall(root)
		_:
			return _playground(root)


# --- Shared bits -------------------------------------------------------------

static func _ground(root: Node3D, size: float, color: Color) -> void:
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
	mi.material_override = Shapes.mat(color)
	ground.add_child(mi)


static func _perimeter(root: Node3D, half: float, height: float, color: Color) -> void:
	Shapes.solid_box(root, Vector3(half * 2, height, 0.4), Vector3(0, height / 2, -half), color)
	Shapes.solid_box(root, Vector3(half * 2, height, 0.4), Vector3(0, height / 2, half), color)
	Shapes.solid_box(root, Vector3(0.4, height, half * 2), Vector3(-half, height / 2, 0), color)
	Shapes.solid_box(root, Vector3(0.4, height, half * 2), Vector3(half, height / 2, 0), color)


static func _sign(root: Node3D, text: String, pos: Vector3, color: Color, size := 120, rot_y := 0.0) -> void:
	var l := Shapes.label(root, text, pos, color, size)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = rot_y


static func _tree(root: Node3D, pos: Vector3) -> void:
	Shapes.solid_cylinder(root, 0.35, 3, pos + Vector3(0, 1.5, 0), Color(0.45, 0.3, 0.15))
	Shapes.sphere(root, 2.0, pos + Vector3(0, 4, 0), Color(0.2, 0.5, 0.2))


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
	_ground(root, 120, Color(0.24, 0.48, 0.2))
	_perimeter(root, half, 2.2, Color(0.6, 0.6, 0.65))
	Shapes.box(root, Vector3(18, 0.02, 12), Vector3(-14, 0.01, 12), Color(0.22, 0.22, 0.25))
	Shapes.box(root, Vector3(0.2, 0.03, 12), Vector3(-14, 0.02, 12), Color.WHITE)

	# School building.
	Shapes.solid_box(root, Vector3(30, 9, 8), Vector3(0, 4.5, -25.5), Color(0.75, 0.45, 0.35))
	Shapes.box(root, Vector3(3, 4, 0.2), Vector3(0, 2, -21.4), Color(0.35, 0.2, 0.12))
	for x in [-11, -6, 6, 11]:
		Shapes.box(root, Vector3(3, 2, 0.15), Vector3(x, 5.5, -21.45), Color(0.6, 0.85, 1.0))
	_sign(root, "SUNNYVALE ELEMENTARY", Vector3(0, 8, -21.3), Color(1, 1, 0.8), 160)

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
		Shapes.solid_box(root, Vector3(2.4, 0.5, 0.6), b, Color(0.55, 0.35, 0.2))
	for t in [Vector3(-24, 0, 20), Vector3(-22, 0, -14), Vector3(24, 0, -10), Vector3(14, 0, 8),
			Vector3(-6, 0, 24), Vector3(-26, 0, 2), Vector3(25, 0, 6)]:
		_tree(root, t)

	# Extraction props.
	Shapes.solid_box(root, Vector3(2.6, 3, 9), Vector3(-26, 1.5, 24), Color(0.95, 0.75, 0.1)) # school bus
	Shapes.solid_box(root, Vector3(2.4, 2.6, 4.5), Vector3(26, 1.3, 22), Color(0.95, 0.95, 1.0)) # ice cream truck

	return {
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
	_ground(root, 100, Color(0.3, 0.3, 0.32)) # parking lot asphalt
	_perimeter(root, half, 2.5, Color(0.45, 0.4, 0.35))

	# Store floor and walls (x -15..15, z -16..6). Door gaps at the front and back.
	var wall := Color(0.55, 0.2, 0.25)
	Shapes.box(root, Vector3(30, 0.02, 22), Vector3(0, 0.01, -5), Color(0.36, 0.28, 0.22))
	Shapes.solid_box(root, Vector3(0.4, 4, 22), Vector3(-15, 2, -5), wall)
	Shapes.solid_box(root, Vector3(0.4, 4, 22), Vector3(15, 2, -5), wall)
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(-8.5, 2, 6), wall)
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(8.5, 2, 6), wall)
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(-8.5, 2, -16), wall)
	Shapes.solid_box(root, Vector3(13, 4, 0.4), Vector3(8.5, 2, -16), wall)
	Shapes.box(root, Vector3(30.4, 1.2, 0.5), Vector3(0, 4.6, 6), Color(0.15, 0.1, 0.2))
	_sign(root, "DRAGON'S DEN GAMES", Vector3(0, 4.6, 6.3), Color(1, 0.75, 0.2), 150)
	_sign(root, "FRIDAY NIGHT LOCALS\nentry: 1 binder", Vector3(0, 3.2, -15.7), Color(0.9, 0.9, 1.0), 110)

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
	_car(root, Vector3(-15.5, 0, 14), Color(0.7, 0.1, 0.1))
	_car(root, Vector3(-5.5, 0, 14), Color(0.2, 0.4, 0.8))
	_car(root, Vector3(15.5, 0, 14), Color(0.85, 0.85, 0.85))
	Shapes.solid_box(root, Vector3(2.3, 2.0, 5), Vector3(10.5, 1.0, 14), Color(0.55, 0.6, 0.5)) # the minivan
	# Back alley dumpster.
	Shapes.solid_box(root, Vector3(3, 1.6, 1.6), Vector3(-6, 0.8, -19), Color(0.15, 0.4, 0.2))
	Shapes.solid_box(root, Vector3(0.6, 2.4, 0.6), Vector3(-20, 1.2, 20), Color(0.2, 0.3, 0.6)) # bus stop pole

	return {
		"spawn": Vector3(0, 0.1, 18), "spawn_yaw": 0.0,
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
	_ground(root, 100, Color(0.5, 0.47, 0.43)) # tile
	_perimeter(root, half, 6.0, Color(0.62, 0.6, 0.56))
	# Checker tiles.
	for x in range(-24, 24, 4):
		for z in range(-24, 24, 4):
			if posmod(int((x + z) / 4.0), 2) == 0:
				Shapes.box(root, Vector3(4, 0.02, 4), Vector3(x + 2, 0.01, z + 2), Color(0.38, 0.36, 0.33))

	# Storefronts along the walls.
	var shops := [["CINNABUN", Color(0.9, 0.6, 0.3)], ["HOT TOPIK", Color(0.2, 0.2, 0.2)],
		["GAME STOPP", Color(0.8, 0.1, 0.1)], ["BUILD-A-BEAR-ISH", Color(0.6, 0.4, 0.8)],
		["ORANGE MAN JULIUS", Color(1, 0.55, 0.1)], ["PANDA EXPRESSO", Color(0.8, 0.15, 0.2)]]
	for s in 3:
		var x := -16.0 + s * 16.0
		Shapes.solid_box(root, Vector3(10, 4, 3), Vector3(x, 2, -24.4), shops[s][1])
		_sign(root, shops[s][0], Vector3(x, 4.5, -22.85), Color.WHITE, 110)
		Shapes.solid_box(root, Vector3(10, 4, 3), Vector3(x, 2, 24.4), shops[s + 3][1])
		_sign(root, shops[s + 3][0], Vector3(x, 4.5, 22.85), Color.WHITE, 110, PI)

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

	return {
		"spawn": Vector3(-22, 0.1, 18), "spawn_yaw": -PI * 0.25,
		"kid_bounds": Rect2(-20, -19, 40, 38),
		"extracts": [
			{"name": "Parking Garage", "pos": Vector3(23, 0, -20)},
			{"name": "Emergency Exit", "pos": Vector3(-23, 0, -20)},
			{"name": "Loading Dock", "pos": Vector3(23, 0, 20)},
		],
		"parent_spawns": [Vector3(-23, 0.1, 0), Vector3(23, 0.1, 0), Vector3(0, 0.1, -21), Vector3(0, 0.1, 21)],
	}
