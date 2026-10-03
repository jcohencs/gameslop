class_name Props
## Prop kit (specs/004): reusable, detailed level dressing built from primitives. Every prop
## root is in the "props" group with meta "prop_kind". Blocking props are StaticBody3D roots
## (so the navmesh routes around them); small decor is a plain Node3D and never blocks.
## Props face -Z (their "front") before rot_y is applied.

const METAL := Color(0.55, 0.57, 0.62)
const DARK := Color(0.12, 0.12, 0.14)
const WOOD := Color(0.72, 0.5, 0.3)
const GLASS := Color(0.55, 0.78, 0.95, 0.38)

static var _chain_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D


# --- Helpers -------------------------------------------------------------------

static func _make(parent: Node, kind: String, pos: Vector3, rot_y := 0.0, solid := Vector3.ZERO, center := Vector3(INF, 0, 0)) -> Node3D:
	var root: Node3D
	if solid != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = solid
		cs.shape = sh
		cs.position = Vector3(0, solid.y * 0.5, 0) if center.x == INF else center
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	root.name = "Prop_" + kind
	root.position = pos
	root.rotation.y = rot_y
	root.add_to_group("props")
	root.set_meta("prop_kind", kind)
	parent.add_child(root)
	return root


static func _b(root: Node3D, size: Vector3, pos: Vector3, color: Color, tex := "") -> MeshInstance3D:
	return Shapes.box(root, size, pos, color, tex)


static func _c(root: Node3D, r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Shapes.cylinder(root, r, h, pos, color)
	mi.rotation = rot
	return mi


static func _glow(mi: MeshInstance3D, color: Color, energy := 2.0) -> MeshInstance3D:
	mi.material_override = Shapes.mat(color, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func glass_mat() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = Shapes.mat(GLASS, 0.15)
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.roughness = 0.05
		_glass_mat.metallic_specular = 1.0
	return _glass_mat


static func _glass(root: Node3D, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := _b(root, size, pos, GLASS)
	mi.material_override = glass_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## See-through chain-link (procedural diamond mesh with alpha scissor).
static func chain_mat() -> StandardMaterial3D:
	if _chain_mat:
		return _chain_mat
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var a := absf(fposmod(u + v, 1.0) - 0.5) < 0.06 or absf(fposmod(u - v, 1.0) - 0.5) < 0.06
			img.set_pixel(x, y, Color(0.75, 0.77, 0.8, 1.0 if a else 0.0))
	img.generate_mipmaps()
	var m := Art.toon(StandardMaterial3D.new())
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.4
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	_chain_mat = m
	return m


static func count(root: Node) -> int:
	return root.get_tree().get_nodes_in_group("props").filter(func(p): return root.is_ancestor_of(p)).size()


static func kinds(root: Node) -> Dictionary:
	var out := {}
	for p in root.get_tree().get_nodes_in_group("props"):
		if root.is_ancestor_of(p):
			out[p.get_meta("prop_kind")] = true
	return out


# --- Outdoor -------------------------------------------------------------------

static func picnic_table(parent: Node, pos: Vector3, rot_y := 0.0, top := WOOD) -> Node3D:
	var r := _make(parent, "picnic_table", pos, rot_y, Vector3(1.9, 0.8, 1.6))
	_b(r, Vector3(1.9, 0.07, 0.8), Vector3(0, 0.76, 0), top, "wood")
	for z in [-0.6, 0.6]:
		_b(r, Vector3(1.9, 0.05, 0.3), Vector3(0, 0.45, z), top.darkened(0.1), "wood")
	for x in [-0.75, 0.75]:
		for z in [-1, 1]:
			var leg := _b(r, Vector3(0.07, 0.95, 0.07), Vector3(x, 0.42, z * 0.32), top.darkened(0.25))
			leg.rotation.x = z * 0.55
		_b(r, Vector3(0.06, 0.06, 1.5), Vector3(x, 0.4, 0), top.darkened(0.25))
	return r


static func trash_can(parent: Node, pos: Vector3, color := Color(0.2, 0.45, 0.3)) -> Node3D:
	var r := _make(parent, "trash_can", pos, 0.0, Vector3(0.62, 0.95, 0.62))
	_c(r, 0.3, 0.9, Vector3(0, 0.45, 0), color)
	for y in [0.2, 0.7]:
		_c(r, 0.315, 0.05, Vector3(0, y, 0), color.darkened(0.3))
	var lid := _c(r, 0.33, 0.06, Vector3(0, 0.93, 0), color.darkened(0.15))
	lid.rotation.z = 0.05
	Shapes.sphere(r, 0.18, Vector3(0.05, 0.95, 0.05), DARK)
	return r


static func bench(parent: Node, pos: Vector3, rot_y := 0.0, color := WOOD) -> Node3D:
	var r := _make(parent, "bench", pos, rot_y, Vector3(1.8, 0.5, 0.6))
	for i in 4:
		_b(r, Vector3(1.8, 0.04, 0.11), Vector3(0, 0.46, -0.2 + i * 0.13), color, "wood")
	for i in 3:
		_b(r, Vector3(1.8, 0.1, 0.035), Vector3(0, 0.62 + i * 0.13, 0.3), color, "wood")
	for x in [-0.8, 0.8]:
		_b(r, Vector3(0.05, 0.46, 0.5), Vector3(x, 0.23, 0.0), DARK)
		_b(r, Vector3(0.05, 0.5, 0.05), Vector3(x, 0.7, 0.3), DARK)
	return r


## A run of chain-link fence from a to b (solid, see-through).
static func fence(parent: Node, a: Vector3, b: Vector3, height := 2.2) -> Node3D:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var yaw := atan2(-(b - a).x, -(b - a).z) + PI / 2
	var r := _make(parent, "fence", Vector3(mid.x, 0, mid.z), yaw, Vector3(length, height, 0.2))
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, height - 0.1, 0.02)
	panel.mesh = bm
	panel.material_override = chain_mat()
	panel.position = Vector3(0, height * 0.5, 0)
	r.add_child(panel)
	var posts := maxi(int(length / 2.5), 1)
	for i in posts + 1:
		_c(r, 0.04, height, Vector3(-length * 0.5 + i * length / posts, height * 0.5, 0), METAL)
	_c(r, 0.03, length, Vector3(0, height, 0), METAL, Vector3(0, 0, PI / 2))
	return r


static func hoop(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "hoop", pos, rot_y, Vector3(0.3, 3.0, 0.3))
	_c(r, 0.09, 3.2, Vector3(0, 1.6, 0.6), Color(0.2, 0.3, 0.6))
	_b(r, Vector3(0.1, 0.1, 0.65), Vector3(0, 3.1, 0.28), Color(0.2, 0.3, 0.6))
	_b(r, Vector3(1.8, 1.05, 0.05), Vector3(0, 3.35, 0.0), Color(0.97, 0.97, 0.97))
	_b(r, Vector3(0.6, 0.45, 0.06), Vector3(0, 3.15, -0.005), Color(0.9, 0.2, 0.15))
	_b(r, Vector3(0.5, 0.35, 0.07), Vector3(0, 3.15, -0.01), Color(0.97, 0.97, 0.97))
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.25
	rim.mesh = tm
	rim.material_override = Shapes.mat(Color(1.0, 0.45, 0.1))
	rim.position = Vector3(0, 3.05, -0.28)
	r.add_child(rim)
	var net := _c(r, 0.23, 0.42, Vector3(0, 2.83, -0.28), Color.WHITE)
	(net.mesh as CylinderMesh).bottom_radius = 0.15
	net.material_override = chain_mat()
	return r


## A car, or a minivan with van = true (taller, longer cabin).
static func car(parent: Node, pos: Vector3, color: Color, rot_y := 0.0, van := false) -> Node3D:
	var cab_h := 0.95 if van else 0.55
	var cab_len := 3.3 if van else 2.2
	var r := _make(parent, "car", pos, rot_y, Vector3(2.0, 0.9 + cab_h, 4.3))
	_b(r, Vector3(1.95, 0.6, 4.2), Vector3(0, 0.6, 0), color)
	_b(r, Vector3(1.97, 0.12, 4.22), Vector3(0, 0.36, 0), color.darkened(0.35))
	_b(r, Vector3(1.75, cab_h, cab_len), Vector3(0, 0.9 + cab_h * 0.5, 0.25 + (0.4 if van else 0.0)), color.lightened(0.05))
	_glass(r, Vector3(1.77, cab_h * 0.7, cab_len - 0.15), Vector3(0, 0.95 + cab_h * 0.5, 0.25 + (0.4 if van else 0.0)))
	var shield := _glass(r, Vector3(1.65, 0.05, 0.75), Vector3(0, 0.82 + cab_h * 0.55, -1.05 + (-0.3 if van else 0.0)))
	shield.rotation.x = 0.85
	for x in [-0.95, 0.95]:
		for z in [-1.35, 1.35]:
			_c(r, 0.36, 0.26, Vector3(x, 0.36, z), DARK, Vector3(0, 0, PI / 2))
			_c(r, 0.18, 0.28, Vector3(x * 1.01, 0.36, z), METAL, Vector3(0, 0, PI / 2))
	for x in [-0.65, 0.65]:
		_glow(_b(r, Vector3(0.35, 0.15, 0.05), Vector3(x, 0.72, -2.11), Color(1.0, 0.97, 0.8)), Color(1.0, 0.97, 0.8), 1.5)
		_glow(_b(r, Vector3(0.35, 0.13, 0.05), Vector3(x, 0.72, 2.11), Color(0.95, 0.1, 0.1)), Color(0.95, 0.1, 0.1), 1.2)
	for z in [-2.12, 2.12]:
		_b(r, Vector3(2.0, 0.18, 0.08), Vector3(0, 0.42, z), METAL)
	return r


static func bus(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var yellow := Color(0.98, 0.75, 0.08)
	var r := _make(parent, "bus", pos, rot_y, Vector3(2.6, 3.0, 9.0))
	_b(r, Vector3(2.6, 2.3, 8.0), Vector3(0, 1.55, 0.5), yellow)
	_b(r, Vector3(2.4, 1.0, 1.2), Vector3(0, 1.0, -4.1), yellow)
	_b(r, Vector3(2.62, 0.12, 8.0), Vector3(0, 1.3, 0.5), DARK)
	_b(r, Vector3(2.62, 0.12, 8.0), Vector3(0, 0.75, 0.5), DARK)
	for side in [-1, 1]:
		for i in 6:
			_glass(r, Vector3(0.04, 0.65, 0.95), Vector3(side * 1.3, 2.15, -2.6 + i * 1.2))
		for z in [-3.2, 2.9]:
			_c(r, 0.5, 0.35, Vector3(side * 1.2, 0.5, z), DARK, Vector3(0, 0, PI / 2))
	_glass(r, Vector3(2.3, 0.8, 0.05), Vector3(0, 2.15, -3.51))
	var sign_arm := _b(r, Vector3(0.05, 0.05, 0.4), Vector3(-1.35, 1.7, -2.8), DARK)
	sign_arm.rotation.y = 0.3
	var stop := _c(r, 0.28, 0.04, Vector3(-1.5, 1.7, -2.75), Color(0.9, 0.1, 0.1), Vector3(0, 0, PI / 2))
	(stop.mesh as CylinderMesh).radial_segments = 8
	for x in [-0.8, 0.8]:
		_glow(_c(r, 0.13, 0.05, Vector3(x, 1.05, -4.72), Color(1, 0.95, 0.75), Vector3(PI / 2, 0, 0)), Color(1, 0.95, 0.75), 1.5)
	var l := Shapes.label(r, "SCHOOL BUS", Vector3(0, 2.9, -3.55), DARK, 64)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI
	return r


static func hydrant(parent: Node, pos: Vector3) -> Node3D:
	var r := _make(parent, "hydrant", pos)
	var red := Color(0.85, 0.12, 0.1)
	_c(r, 0.13, 0.6, Vector3(0, 0.3, 0), red)
	Shapes.sphere(r, 0.14, Vector3(0, 0.62, 0), red)
	_c(r, 0.16, 0.06, Vector3(0, 0.05, 0), red.darkened(0.2))
	for x in [-1, 1]:
		_c(r, 0.05, 0.12, Vector3(x * 0.16, 0.4, 0), Color(0.9, 0.85, 0.2), Vector3(0, 0, PI / 2))
	return r


static func cone(parent: Node, pos: Vector3) -> Node3D:
	var r := _make(parent, "cone", pos)
	var c := _c(r, 0.0, 0.55, Vector3(0, 0.3, 0), Color(1.0, 0.45, 0.05))
	(c.mesh as CylinderMesh).bottom_radius = 0.16
	var band := _c(r, 0.0, 0.1, Vector3(0, 0.38, 0), Color.WHITE)
	(band.mesh as CylinderMesh).top_radius = 0.075
	(band.mesh as CylinderMesh).bottom_radius = 0.1
	_b(r, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.02, 0), Color(1.0, 0.45, 0.05))
	return r


static func bike_rack(parent: Node, pos: Vector3, rot_y := 0.0, bikes := 2) -> Node3D:
	var r := _make(parent, "bike_rack", pos, rot_y)
	for i in 5:
		var x := -1.0 + i * 0.5
		for z in [-0.25, 0.25]:
			_c(r, 0.025, 0.7, Vector3(x, 0.35, z), METAL)
		_c(r, 0.025, 0.5, Vector3(x, 0.7, 0), METAL, Vector3(PI / 2, 0, 0))
	for i in bikes:
		var x := -0.75 + i * 1.0
		var col := Color.from_hsv(0.1 + i * 0.4, 0.8, 0.9)
		for z in [-0.5, 0.5]:
			var w := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.28
			tm.outer_radius = 0.32
			w.mesh = tm
			w.material_override = Shapes.mat(DARK)
			w.position = Vector3(x, 0.32, z)
			w.rotation.z = PI / 2
			r.add_child(w)
		var bar := _c(r, 0.025, 1.0, Vector3(x, 0.55, 0), col, Vector3(PI / 2, 0, 0))
		bar.rotation.x = PI / 2 - 0.25
		_b(r, Vector3(0.1, 0.04, 0.22), Vector3(x, 0.78, 0.35), DARK)
		_c(r, 0.02, 0.45, Vector3(x, 0.85, -0.42), METAL, Vector3(0, 0, PI / 2))
	return r


static func flagpole(parent: Node, pos: Vector3, height := 7.0) -> Node3D:
	var r := _make(parent, "flagpole", pos, 0.0, Vector3(0.3, height, 0.3))
	_c(r, 0.06, height, Vector3(0, height * 0.5, 0), METAL)
	Shapes.sphere(r, 0.12, Vector3(0, height + 0.05, 0), Color(0.95, 0.8, 0.2))
	_c(r, 0.4, 0.3, Vector3(0, 0.15, 0), Color(0.6, 0.6, 0.62))
	var flag := Node3D.new()
	flag.position = Vector3(0, height - 0.6, 0)
	r.add_child(flag)
	# A made-up school flag: Sunnyvale stripes and a star.
	for i in 3:
		_b(flag, Vector3(1.6, 0.3, 0.02), Vector3(0.82, 0.3 - i * 0.3, 0), [Color(0.2, 0.4, 0.85), Color(0.98, 0.98, 0.98), Color(0.95, 0.75, 0.1)][i])
	var tw := flag.create_tween().set_loops()
	tw.tween_property(flag, "rotation:y", 0.18, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flag, "rotation:y", -0.12, 1.3).set_trans(Tween.TRANS_SINE)
	return r


static func bus_shelter(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "bus_shelter", pos, rot_y)
	_b(r, Vector3(3.2, 0.12, 1.6), Vector3(0, 2.5, 0), Color(0.2, 0.3, 0.55))
	for x in [-1.5, 1.5]:
		_c(r, 0.05, 2.5, Vector3(x, 1.25, 0.65), METAL)
		_c(r, 0.05, 2.5, Vector3(x, 1.25, -0.65), METAL)
	_glass(r, Vector3(3.0, 2.0, 0.04), Vector3(0, 1.3, 0.7))
	_glass(r, Vector3(0.04, 2.0, 1.3), Vector3(-1.5, 1.3, 0.0))
	_b(r, Vector3(2.2, 0.06, 0.4), Vector3(0, 0.48, 0.45), WOOD, "wood")
	_glow(_b(r, Vector3(0.9, 1.3, 0.05), Vector3(1.0, 1.4, 0.66), Color(1.0, 0.9, 0.6)), Color(1.0, 0.9, 0.6), 0.8)
	var l := Shapes.label(r, "BUS", Vector3(-0.8, 2.8, -0.82), Color(1, 1, 1), 70)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI
	return r


static func vending(parent: Node, pos: Vector3, rot_y := 0.0, color := Color(0.85, 0.15, 0.15)) -> Node3D:
	var r := _make(parent, "vending", pos, rot_y, Vector3(1.0, 1.95, 0.85))
	_b(r, Vector3(1.0, 1.95, 0.85), Vector3(0, 0.975, 0), color)
	_glow(_b(r, Vector3(0.62, 1.35, 0.02), Vector3(-0.12, 1.15, -0.43), Color(0.85, 0.95, 1.0)), Color(0.85, 0.95, 1.0), 0.8)
	for row in 5:
		for col in 4:
			var can := _c(r, 0.045, 0.14, Vector3(-0.33 + col * 0.14, 0.65 + row * 0.25, -0.4), Color.from_hsv(randf(), 0.7, 0.95))
			can.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_b(r, Vector3(0.22, 0.6, 0.03), Vector3(0.36, 1.2, -0.43), DARK)
	_b(r, Vector3(0.7, 0.15, 0.04), Vector3(-0.12, 0.25, -0.44), DARK)
	var l := Shapes.label(r, "SODA", Vector3(-0.12, 1.92, -0.44), Color.WHITE, 46)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI
	return r


# --- Indoor --------------------------------------------------------------------

static func arcade(parent: Node, pos: Vector3, rot_y := 0.0, color := Color(0.15, 0.15, 0.25)) -> Node3D:
	var r := _make(parent, "arcade", pos, rot_y, Vector3(1.0, 2.0, 0.95))
	var hue := randf()
	for x in [-0.47, 0.47]:
		var side := _b(r, Vector3(0.06, 2.0, 0.95), Vector3(x, 1.0, 0), color)
		side.material_override = Shapes.mat(color)
		_glow(_b(r, Vector3(0.065, 1.6, 0.06), Vector3(x, 1.0, -0.45), Color.from_hsv(hue, 0.8, 1.0)), Color.from_hsv(hue, 0.8, 1.0), 1.5)
	_b(r, Vector3(0.9, 0.9, 0.85), Vector3(0, 0.45, 0.05), color.darkened(0.2))
	_b(r, Vector3(0.9, 0.08, 0.4), Vector3(0, 0.95, -0.25), DARK)
	Shapes.sphere(r, 0.04, Vector3(-0.2, 1.06, -0.3), Color(0.9, 0.1, 0.1))
	_c(r, 0.01, 0.1, Vector3(-0.2, 1.0, -0.3), DARK)
	for i in 3:
		_glow(_c(r, 0.03, 0.03, Vector3(0.05 + i * 0.1, 1.0, -0.3), Color.from_hsv(i / 3.0, 0.8, 1.0)), Color.from_hsv(i / 3.0, 0.8, 1.0), 1.0)
	var screen := _glow(_b(r, Vector3(0.78, 0.6, 0.04), Vector3(0, 1.4, -0.2), Color.from_hsv(hue + 0.5, 0.6, 1.0)), Color.from_hsv(hue + 0.5, 0.6, 1.0), 2.0)
	screen.rotation.x = -0.25
	_b(r, Vector3(0.9, 0.7, 0.5), Vector3(0, 1.45, 0.2), color)
	_glow(_b(r, Vector3(0.92, 0.25, 0.3), Vector3(0, 1.9, -0.25), Color.from_hsv(hue, 0.6, 1.0)), Color.from_hsv(hue, 0.6, 1.0), 1.8)
	return r


## Shop facade: glass window with goods, a door, a striped awning and a sign.
static func storefront(parent: Node, pos: Vector3, width: float, title: String, color: Color, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "storefront", pos, rot_y)
	_b(r, Vector3(width, 0.5, 0.15), Vector3(0, 3.75, 0), color.darkened(0.2))
	for x in [-width * 0.5 + 0.1, width * 0.5 - 0.1]:
		_b(r, Vector3(0.2, 3.5, 0.15), Vector3(x, 1.75, 0), color.darkened(0.2))
	_glass(r, Vector3(width * 0.6, 2.4, 0.05), Vector3(-width * 0.17, 1.5, -0.02))
	_b(r, Vector3(width * 0.6, 0.3, 0.2), Vector3(-width * 0.17, 0.15, 0), color.darkened(0.35))
	# Goods on display.
	for i in 4:
		var gx := -width * 0.17 - width * 0.22 + i * width * 0.15
		_b(r, Vector3(0.4, 0.5 + (i % 2) * 0.3, 0.3), Vector3(gx, 0.55 + (i % 2) * 0.15, 0.35), Color.from_hsv(randf(), 0.6, 0.9))
	_b(r, Vector3(1.4, 2.8, 0.08), Vector3(width * 0.3, 1.4, 0.0), color.darkened(0.45))
	_glass(r, Vector3(1.1, 2.0, 0.09), Vector3(width * 0.3, 1.5, -0.01))
	for i in int(width / 0.6):
		var stripe := _b(r, Vector3(0.6, 0.06, 1.1), Vector3(-width * 0.5 + 0.3 + i * 0.6, 3.25, -0.5), Color.WHITE if i % 2 == 0 else color)
		stripe.rotation.x = -0.35
	var l := Shapes.label(r, title, Vector3(0, 3.75, -0.1), Color.WHITE, 110)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI
	l.modulate = Color(1, 1, 0.92)
	return r


static func plant(parent: Node, pos: Vector3, size := 1.0) -> Node3D:
	var r := _make(parent, "plant", pos)
	var pot := _c(r, 0.32 * size, 0.55 * size, Vector3(0, 0.27 * size, 0), Color(0.75, 0.42, 0.25))
	(pot.mesh as CylinderMesh).bottom_radius = 0.22 * size
	_c(r, 0.3 * size, 0.04, Vector3(0, 0.53 * size, 0), Color(0.3, 0.2, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 7.0 + pos.z * 13.0)
	for i in 6:
		var a := i * TAU / 6.0 + rng.randf() * 0.4
		var leaf := Shapes.sphere(r, 0.2 * size, Vector3(cos(a) * 0.2, 0.85 + rng.randf() * 0.35, sin(a) * 0.2) * size, Color(0.2, 0.55, 0.25).lightened(rng.randf() * 0.2))
		leaf.scale = Vector3(0.6, 1.4, 0.6)
		leaf.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	return r


static func ceiling_light(parent: Node, pos: Vector3, size := Vector2(1.2, 0.6), light := false) -> Node3D:
	var r := _make(parent, "ceiling_light", pos)
	_b(r, Vector3(size.x + 0.08, 0.06, size.y + 0.08), Vector3.ZERO, Color(0.85, 0.85, 0.85))
	_glow(_b(r, Vector3(size.x, 0.04, size.y), Vector3(0, -0.03, 0), Color(1.0, 0.98, 0.92)), Color(1.0, 0.98, 0.92), 2.5)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.95, 0.85)
		l.light_energy = 0.8
		l.omni_range = 8.0
		l.position = Vector3(0, -0.4, 0)
		r.add_child(l)
	return r


static func window(parent: Node, pos: Vector3, w: float, h: float, rot_y := 0.0, frame := Color(0.95, 0.95, 0.92)) -> Node3D:
	var r := _make(parent, "window", pos, rot_y)
	_glass(r, Vector3(w, h, 0.04), Vector3.ZERO)
	_glow(_b(r, Vector3(w - 0.1, h - 0.1, 0.01), Vector3(0, 0, 0.03), Color(0.75, 0.88, 1.0)), Color(0.75, 0.88, 1.0), 0.35)
	for y in [-h * 0.5, h * 0.5]:
		_b(r, Vector3(w + 0.16, 0.1, 0.12), Vector3(0, y, -0.02), frame)
	for x in [-w * 0.5, w * 0.5]:
		_b(r, Vector3(0.1, h, 0.12), Vector3(x, 0, -0.02), frame)
	_b(r, Vector3(0.06, h, 0.08), Vector3(0, 0, -0.03), frame)
	_b(r, Vector3(w, 0.06, 0.08), Vector3(0, 0, -0.03), frame)
	_b(r, Vector3(w + 0.3, 0.07, 0.25), Vector3(0, -h * 0.5 - 0.06, -0.08), frame.darkened(0.1))
	return r


static func door(parent: Node, pos: Vector3, w := 1.2, h := 2.3, rot_y := 0.0, color := Color(0.35, 0.22, 0.14)) -> Node3D:
	var r := _make(parent, "door", pos, rot_y)
	_b(r, Vector3(w, h, 0.08), Vector3(0, h * 0.5, 0), color)
	_b(r, Vector3(w + 0.2, 0.12, 0.14), Vector3(0, h + 0.05, -0.02), Color(0.9, 0.9, 0.88))
	for x in [-w * 0.5 - 0.05, w * 0.5 + 0.05]:
		_b(r, Vector3(0.1, h, 0.14), Vector3(x, h * 0.5, -0.02), Color(0.9, 0.9, 0.88))
	_glass(r, Vector3(w * 0.5, h * 0.3, 0.1), Vector3(0, h * 0.7, 0))
	Shapes.sphere(r, 0.05, Vector3(w * 0.36, h * 0.45, -0.07), Color(0.9, 0.75, 0.3))
	return r


## Flat roof with a parapet, AC units and vents.
static func roof(parent: Node, center: Vector3, size: Vector2, color := Color(0.5, 0.5, 0.52)) -> Node3D:
	var r := _make(parent, "roof", center)
	_b(r, Vector3(size.x, 0.25, size.y), Vector3.ZERO, color)
	var trim := color.darkened(0.3)
	for z in [-size.y * 0.5, size.y * 0.5]:
		_b(r, Vector3(size.x + 0.3, 0.55, 0.3), Vector3(0, 0.25, z), trim)
	for x in [-size.x * 0.5, size.x * 0.5]:
		_b(r, Vector3(0.3, 0.55, size.y), Vector3(x, 0.25, 0), trim)
	for i in 2:
		var ax := -size.x * 0.25 + i * size.x * 0.4
		_b(r, Vector3(1.6, 0.9, 1.2), Vector3(ax, 0.55, size.y * 0.1), Color(0.78, 0.8, 0.82))
		_c(r, 0.35, 0.05, Vector3(ax, 1.02, size.y * 0.1), DARK)
	_c(r, 0.12, 0.8, Vector3(size.x * 0.3, 0.5, -size.y * 0.2), METAL)
	return r


## Raised concrete sidewalk with a curb edge (walkable).
static func curb(parent: Node, center: Vector3, size: Vector2) -> Node3D:
	var r := _make(parent, "curb", center, 0.0, Vector3(size.x, 0.15, size.y))
	_b(r, Vector3(size.x, 0.15, size.y), Vector3(0, 0.075, 0), Color(0.78, 0.77, 0.74), "concrete")
	return r


# --- Gym -----------------------------------------------------------------------

static func gym_mats(parent: Node, pos: Vector3, rot_y := 0.0, stack := 4) -> Node3D:
	var h := 0.22 * stack
	var r := _make(parent, "gym_mats", pos, rot_y, Vector3(2.0, h, 1.2))
	for i in stack:
		var m := _b(r, Vector3(2.0 - (i % 2) * 0.06, 0.2, 1.2), Vector3(randf_range(-0.04, 0.04), 0.11 + i * 0.22, 0), Color(0.15, 0.35, 0.8) if i % 2 == 0 else Color(0.85, 0.15, 0.2))
		m.rotation.y = randf_range(-0.04, 0.04)
	return r


static func vault_box(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "vault_box", pos, rot_y, Vector3(1.7, 1.15, 0.9))
	for i in 4:
		var k := 1.0 - i * 0.07
		_b(r, Vector3(1.7 * k, 0.24, 0.9 * k), Vector3(0, 0.12 + i * 0.25, 0), WOOD.lightened(0.05 * (i % 2)), "wood")
	_b(r, Vector3(1.45, 0.12, 0.72), Vector3(0, 1.08, 0), Color(0.8, 0.2, 0.15))
	return r


static func ball_cart(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "ball_cart", pos, rot_y, Vector3(1.2, 1.0, 0.7))
	for x in [-0.58, 0.58]:
		for z in [-0.33, 0.33]:
			_c(r, 0.02, 0.9, Vector3(x, 0.55, z), METAL)
			Shapes.sphere(r, 0.06, Vector3(x, 0.07, z), DARK)
	for y in [0.15, 0.95]:
		_b(r, Vector3(1.2, 0.03, 0.03), Vector3(0, y, -0.33), METAL)
		_b(r, Vector3(1.2, 0.03, 0.03), Vector3(0, y, 0.33), METAL)
		_b(r, Vector3(0.03, 0.03, 0.7), Vector3(-0.58, y, 0), METAL)
		_b(r, Vector3(0.03, 0.03, 0.7), Vector3(0.58, y, 0), METAL)
	var cols := [Color(1.0, 0.45, 0.1), Color(0.9, 0.15, 0.15), Color(0.95, 0.95, 0.95), Color(0.2, 0.5, 1.0)]
	for i in 9:
		Shapes.sphere(r, 0.17, Vector3(-0.38 + (i % 3) * 0.38, 0.35 + (i / 3) * 0.2, -0.15 + (i % 2) * 0.3), cols[i % cols.size()])
	return r


## Stepped bleachers. Returns the root; seat positions (local) are in meta "seats".
static func bleachers(parent: Node, pos: Vector3, width: float, rows := 4, rot_y := 0.0) -> Node3D:
	var depth := rows * 0.8
	var r := _make(parent, "bleachers", pos, rot_y)
	var seats := []
	for i in rows:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		r.add_child(body)
		var h := 0.45 + i * 0.45
		var sz := Vector3(width, h, 0.8)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		cs.shape = sh
		cs.position = Vector3(0, h * 0.5, i * 0.8)
		body.add_child(cs)
		_b(r, Vector3(width, 0.1, 0.8), Vector3(0, h - 0.05, i * 0.8), WOOD, "wood")
		_b(r, Vector3(width, h - 0.1, 0.06), Vector3(0, (h - 0.1) * 0.5, i * 0.8 - 0.37), Color(0.3, 0.32, 0.38))
		for s in int(width / 0.9):
			seats.append(Vector3(-width * 0.5 + 0.45 + s * 0.9, h, i * 0.8))
	for x in [-width * 0.5, width * 0.5]:
		_b(r, Vector3(0.08, 0.08, depth), Vector3(x, 0.45 * rows + 0.6, depth * 0.5 - 0.4), METAL).rotation.x = -atan(0.45 / 0.8)
	r.set_meta("seats", seats)
	return r


static func hanging_light(parent: Node, pos: Vector3, light := true, cable := 2.0) -> Node3D:
	var r := _make(parent, "hanging_light", pos)
	_c(r, 0.015, cable, Vector3(0, cable * 0.5, 0), DARK)
	var shade := _c(r, 0.12, 0.45, Vector3(0, -0.15, 0), Color(0.25, 0.28, 0.3))
	(shade.mesh as CylinderMesh).bottom_radius = 0.55
	_glow(Shapes.sphere(r, 0.22, Vector3(0, -0.36, 0), Color(1.0, 0.95, 0.8)), Color(1.0, 0.95, 0.8), 4.0)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.92, 0.78)
		l.light_energy = 1.4
		l.omni_range = 13.0
		l.omni_attenuation = 1.2
		l.position = Vector3(0, -0.8, 0)
		r.add_child(l)
	return r


static func banner(parent: Node, pos: Vector3, w: float, h: float, color: Color, text: String, rot_y := 0.0) -> Node3D:
	var r := _make(parent, "banner", pos, rot_y)
	_b(r, Vector3(w, h, 0.03), Vector3.ZERO, color)
	_b(r, Vector3(w + 0.2, 0.06, 0.06), Vector3(0, h * 0.5 + 0.03, 0), Color(0.85, 0.75, 0.3))
	var tip := _c(r, 0.0, h * 0.3, Vector3(0, -h * 0.5 - h * 0.15, 0), color)
	(tip.mesh as CylinderMesh).bottom_radius = w * 0.5
	(tip.mesh as CylinderMesh).radial_segments = 3
	tip.rotation.y = PI / 6
	var l := Shapes.label(r, text, Vector3(0, 0, -0.03), Color.WHITE, 72)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation.y = PI
	return r
