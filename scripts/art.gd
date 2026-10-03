class_name Art
## Visual toolkit (specs/003-graphics-overhaul): toon materials, ink outlines, procedural
## textures, per-location lighting moods, grass, clouds, trees, and particle effects.
## Everything is generated in code (Constitution X). Scales with GameState.graphics_quality.

const QUALITY := {
	"high": {"outlines": true, "shadows": true, "grass": 3500, "particles": 1.0, "ssao": true,
		"ssr": true, "volumetric": true, "decals": 120},
	"low": {"outlines": false, "shadows": false, "grass": 700, "particles": 0.4, "ssao": false,
		"ssr": false, "volumetric": false, "decals": 40},
}

## Procedural textures: world size in meters of one repeat.
const TEXTURES := {
	"grass": {"scale": 3.0}, "asphalt": {"scale": 4.0}, "tiles": {"scale": 4.0}, "wood": {"scale": 3.0},
	"brick": {"scale": 2.5}, "carpet": {"scale": 2.0}, "concrete": {"scale": 5.0},
}
const TEX_SIZE := 128

## Lighting moods per location (applied at raid start) plus the hideout default.
const MOODS := {
	"default": {"sun_rot": Vector3(-55, -35, 0), "sun_color": Color(1.0, 0.97, 0.92), "sun_energy": 1.0,
		"sky_top": Color(0.3, 0.55, 0.95), "sky_horizon": Color(0.75, 0.85, 1.0), "ground": Color(0.6, 0.7, 0.6),
		"ambient": 0.45, "fog": false, "fog_color": Color(0.8, 0.85, 0.9), "fog_density": 0.0,
		"contrast": 1.05, "saturation": 1.1, "glow": 0.4, "exposure": 0.9},
	"playground": {"sun_rot": Vector3(-62, -30, 0), "sun_color": Color(1.0, 0.96, 0.85), "sun_energy": 1.0,
		"sky_top": Color(0.22, 0.5, 0.98), "sky_horizon": Color(0.7, 0.86, 1.0), "ground": Color(0.45, 0.65, 0.4),
		"ambient": 0.5, "fog": true, "fog_color": Color(0.75, 0.86, 1.0), "fog_density": 0.004,
		"contrast": 1.08, "saturation": 1.1, "glow": 0.3, "exposure": 0.82},
	"locals": {"sun_rot": Vector3(-18, -70, 0), "sun_color": Color(1.0, 0.68, 0.38), "sun_energy": 1.1,
		"sky_top": Color(0.35, 0.3, 0.6), "sky_horizon": Color(1.0, 0.6, 0.4), "ground": Color(0.45, 0.35, 0.3),
		"ambient": 0.55, "fog": true, "fog_color": Color(0.95, 0.6, 0.45), "fog_density": 0.01,
		"contrast": 1.1, "saturation": 1.15, "glow": 0.6, "exposure": 0.95},
	"pizza": {"sun_rot": Vector3(-70, 20, 0), "sun_color": Color(1.0, 0.85, 1.0), "sun_energy": 0.95,
		"sky_top": Color(0.45, 0.2, 0.7), "sky_horizon": Color(0.3, 0.85, 0.9), "ground": Color(0.5, 0.3, 0.5),
		"ambient": 0.6, "fog": true, "fog_color": Color(0.8, 0.5, 0.9), "fog_density": 0.008,
		"contrast": 1.12, "saturation": 1.35, "glow": 0.8, "exposure": 0.95},
	"mall": {"sun_rot": Vector3(-75, -10, 0), "sun_color": Color(0.9, 0.96, 1.0), "sun_energy": 1.05,
		"sky_top": Color(0.4, 0.6, 0.88), "sky_horizon": Color(0.74, 0.84, 0.95), "ground": Color(0.5, 0.52, 0.56),
		"ambient": 0.4, "fog": true, "fog_color": Color(0.85, 0.9, 0.97), "fog_density": 0.005,
		"contrast": 1.12, "saturation": 1.2, "glow": 0.3, "exposure": 0.72},
	# Rec Center gym (Wave Mode): indoors under a ceiling, warm lamps, hazy air for light shafts.
	"arena": {"sun_rot": Vector3(-35, 60, 0), "sun_color": Color(1.0, 0.88, 0.7), "sun_energy": 0.4,
		"sky_top": Color(0.5, 0.42, 0.35), "sky_horizon": Color(0.95, 0.82, 0.62), "ground": Color(0.45, 0.35, 0.25),
		"ambient": 0.7, "fog": true, "fog_color": Color(0.95, 0.85, 0.7), "fog_density": 0.006,
		"contrast": 1.1, "saturation": 1.15, "glow": 0.55, "exposure": 0.85,
		"ssr": true, "volumetric": true, "vol_density": 0.018},
}

static var _tex_cache := {}
static var _outline_cache := {}
static var _grass_shader: Shader
static var _particle_mat: StandardMaterial3D
static var _decals: Array = []      # paint splats, oldest first (capped by q("decals"))
static var _darts: Array = []       # stuck foam darts, oldest first
const MAX_DARTS := 60


## Value from the active quality profile.
static func q(key: String):
	var prof: Dictionary = QUALITY.get(GameState.graphics_quality, QUALITY["high"])
	return prof[key]


static func particle_amount(base: int) -> int:
	return maxi(1, int(round(base * float(q("particles")))))


# --- Materials ----------------------------------------------------------------

## Cel-banded lighting with a soft rim highlight.
static func toon(m: StandardMaterial3D) -> StandardMaterial3D:
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


## Toon material with a world-space tiling procedural texture (tinted by color).
static func textured(color: Color, tex_name: String) -> StandardMaterial3D:
	var m := toon(StandardMaterial3D.new())
	m.albedo_color = color
	m.roughness = 0.85
	m.albedo_texture = tex(tex_name)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(TEXTURES[tex_name]["scale"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Inverted-hull ink outline material (shared per thickness).
static func outline_mat(amount: float) -> StandardMaterial3D:
	var key := roundi(amount * 1000.0)
	if _outline_cache.has(key):
		return _outline_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.06, 0.04, 0.08)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = amount
	_outline_cache[key] = m
	return m


## Adds an ink outline to a mesh when the quality profile allows it.
static func outline(mi: GeometryInstance3D, amount := 0.015) -> void:
	if q("outlines"):
		mi.material_overlay = outline_mat(amount)


# --- Procedural textures -----------------------------------------------------------

static func tex(tex_name: String) -> ImageTexture:
	if _tex_cache.has(tex_name):
		return _tex_cache[tex_name]
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			img.set_pixel(x, y, _pixel(tex_name, float(x) / TEX_SIZE, float(y) / TEX_SIZE))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[tex_name] = t
	return t


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Tileable value noise; u, v in [0, 1).
static func _vnoise(u: float, v: float, period: int, s: int) -> float:
	var x := u * period
	var y := v * period
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(posmod(xi, period), posmod(yi, period), s)
	var b := _hash(posmod(xi + 1, period), posmod(yi, period), s)
	var c := _hash(posmod(xi, period), posmod(yi + 1, period), s)
	var d := _hash(posmod(xi + 1, period), posmod(yi + 1, period), s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _fbm(u: float, v: float, period: int, s: int) -> float:
	return _vnoise(u, v, period, s) * 0.6 + _vnoise(u, v, period * 2, s + 7) * 0.3 + _vnoise(u, v, period * 4, s + 13) * 0.1


static func _pixel(tex_name: String, u: float, v: float) -> Color:
	match tex_name:
		"grass":
			var base := 0.72 + 0.28 * _fbm(u, v, 4, 1)
			var blades := _vnoise(u * 1.0, v * 0.25, 48, 2)
			var k := base - (0.18 if blades > 0.72 else 0.0)
			return Color(k * 0.88, k, k * 0.8)
		"asphalt":
			var k := 0.5 + 0.18 * _fbm(u, v, 6, 3)
			var speck := _hash(int(u * TEX_SIZE), int(v * TEX_SIZE), 4)
			if speck > 0.94:
				k += 0.28
			elif speck < 0.05:
				k -= 0.18
			return Color(k, k, k * 1.03)
		"tiles":
			var gu := fposmod(u * 4.0, 1.0)
			var gv := fposmod(v * 4.0, 1.0)
			if gu < 0.045 or gv < 0.045:
				return Color(0.58, 0.56, 0.54)
			var tint := _hash(int(u * 4.0), int(v * 4.0), 5) * 0.08
			var k := 0.9 + tint - 0.05 * _fbm(u, v, 8, 6)
			return Color(k, k, k)
		"wood":
			var plank := int(v * 4.0)
			var pv := fposmod(v * 4.0, 1.0)
			var offset := _hash(plank, 0, 7)
			var pu := fposmod(u + offset, 1.0)
			if pv < 0.035 or (pu < 0.012):
				return Color(0.42, 0.3, 0.2)
			var grain := sin((pv * 18.0 + _fbm(u, v, 4, 8) * 6.0) * PI) * 0.5 + 0.5
			var k := 0.78 + 0.12 * grain + 0.08 * offset
			return Color(k, k * 0.82, k * 0.62)
		"brick":
			var row := int(v * 8.0)
			var bv := fposmod(v * 8.0, 1.0)
			var bu := fposmod(u * 4.0 + (0.5 if row % 2 == 1 else 0.0), 1.0)
			if bv < 0.1 or bu < 0.05:
				return Color(0.86, 0.84, 0.8)
			var col := int(u * 4.0 + (0.5 if row % 2 == 1 else 0.0))
			var k := 0.72 + 0.16 * _hash(col, row, 9) + 0.1 * _fbm(u, v, 8, 10)
			return Color(k, k * 0.72, k * 0.62)
		"carpet":
			var cu := fposmod(u * 8.0 + (0.5 if int(v * 8.0) % 2 == 1 else 0.0), 1.0) - 0.5
			var cv := fposmod(v * 8.0, 1.0) - 0.5
			var dist := sqrt(cu * cu + cv * cv)
			var squig := sin((u * 6.0 + v * 4.0) * TAU + _fbm(u, v, 4, 11) * 6.0)
			if dist < 0.18:
				var pick := _hash(int(u * 8.0), int(v * 8.0), 12)
				return Color(1, 0.35, 0.35) if pick < 0.33 else (Color(0.35, 0.6, 1) if pick < 0.66 else Color(1, 0.85, 0.3))
			if absf(squig) < 0.12:
				return Color(0.45, 0.95, 0.7)
			return Color(0.22, 0.2, 0.42)
		"concrete":
			var k := 0.78 + 0.14 * _fbm(u, v, 3, 14)
			# Short, faint hairline cracks (only where a second noise allows).
			if absf(_vnoise(u, v, 5, 15) - 0.5) < 0.01 and _vnoise(u, v, 3, 16) > 0.62:
				k -= 0.1
			return Color(k, k, k * 0.98)
	return Color.WHITE


# --- Lighting moods ----------------------------------------------------------------

static func apply_mood(env: Environment, sky_mat: ProceduralSkyMaterial, sun: DirectionalLight3D, id: String) -> void:
	var m: Dictionary = MOODS.get(id, MOODS["default"])
	sun.rotation_degrees = m["sun_rot"]
	sun.light_color = m["sun_color"]
	sun.light_energy = m["sun_energy"]
	sun.shadow_enabled = q("shadows")
	sky_mat.sky_top_color = m["sky_top"]
	sky_mat.sky_horizon_color = m["sky_horizon"]
	sky_mat.ground_horizon_color = m["sky_horizon"].lerp(m["ground"], 0.5)
	sky_mat.ground_bottom_color = m["ground"]
	sky_mat.sun_angle_max = 30.0
	env.ambient_light_energy = m["ambient"]
	env.fog_enabled = m["fog"]
	env.fog_light_color = m["fog_color"]
	env.fog_density = m["fog_density"]
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = m["contrast"]
	env.adjustment_saturation = m["saturation"]
	env.glow_enabled = true
	env.glow_intensity = m["glow"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = m["exposure"]
	env.ssao_enabled = q("ssao")
	env.ssao_intensity = 1.2
	# Forward+ only extras (Compatibility ignores them): glossy-floor reflections and light shafts.
	env.ssr_enabled = q("ssr") and m.get("ssr", false)
	env.ssr_max_steps = 48
	env.volumetric_fog_enabled = q("volumetric") and m.get("volumetric", false)
	env.volumetric_fog_density = m.get("vol_density", 0.01)
	env.volumetric_fog_albedo = m["fog_color"]
	env.volumetric_fog_length = 40.0


# --- Environment builders ---------------------------------------------------------

static func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var ang := i * PI / 3.0
		var side := Vector3(cos(ang), 0, sin(ang)) * 0.06
		var lean := Vector3(-sin(ang), 0, cos(ang)) * 0.05
		var top := Vector3(0, 0.38, 0) + lean
		st.set_color(Color(0.55, 0.55, 0.55))
		st.set_uv(Vector2(0, 0))
		st.add_vertex(-side)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(side)
		st.set_color(Color(1, 1, 1))
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(top)
	return st.commit()


static func _grass_material() -> ShaderMaterial:
	if _grass_shader == null:
		_grass_shader = Shader.new()
		_grass_shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 2.2 + w.x * 0.6 + w.z * 0.45) * 0.09 * UV.y;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}
void fragment() {
	ALBEDO = COLOR.rgb;
}"""
	var m := ShaderMaterial.new()
	m.shader = _grass_shader
	return m


## Wind-swaying grass scattered over rects (x/z), skipping exclude rects.
static func grass(parent: Node3D, rects: Array, exclude: Array, base: Color, count := -1) -> MultiMeshInstance3D:
	if count < 0:
		count = q("grass")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_tuft_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while placed.size() < count and tries < count * 4:
		tries += 1
		var r: Rect2 = rects[rng.randi() % rects.size()]
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		var blocked := false
		for e in exclude:
			var er: Rect2 = e
			if er.has_point(p):
				blocked = true
				break
		if blocked:
			continue
		var s := rng.randf_range(0.7, 1.4)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		placed.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		colors.append(base.lightened(rng.randf_range(-0.1, 0.25)))
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "Grass"
	parent.add_child(mmi)
	return mmi


## Slowly drifting cartoon clouds ringing the sky.
static func clouds(parent: Node3D, tint := Color.WHITE) -> Node3D:
	var root := Node3D.new()
	root.name = "Clouds"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var m := toon(StandardMaterial3D.new())
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = tint
	m.emission_energy_multiplier = 0.35
	for i in 9:
		var cloud := Node3D.new()
		var ang := i * TAU / 9.0 + rng.randf() * 0.4
		var dist := rng.randf_range(75, 95)
		cloud.position = Vector3(cos(ang) * dist, rng.randf_range(32, 46), sin(ang) * dist)
		root.add_child(cloud)
		for j in rng.randi_range(3, 5):
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := rng.randf_range(4.0, 7.5)
			sm.radius = r
			sm.height = r * 2.0
			puff.mesh = sm
			puff.material_override = m
			puff.position = Vector3(rng.randf_range(-8, 8), rng.randf_range(-1.5, 2.0), rng.randf_range(-3, 3))
			puff.scale = Vector3(1.3, 0.7, 1.0)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(puff)
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "rotation:y", TAU, 900.0).from(0.0)
	return root


## Fuller tree: trunk (solid), a few branches and a cluster of foliage puffs.
static func tree(parent: Node3D, pos: Vector3, size := 1.0, leaf := Color(0.22, 0.55, 0.22)) -> void:
	Shapes.solid_cylinder(parent, 0.32 * size, 3.0 * size, pos + Vector3(0, 1.5 * size, 0), Color(0.45, 0.3, 0.16))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31.0 + pos.z * 17.0)
	for i in 6:
		var off := Vector3(rng.randf_range(-1.3, 1.3), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.3, 1.3)) * size
		var r := rng.randf_range(1.0, 1.6) * size
		var puff := Shapes.sphere(parent, r, pos + Vector3(0, 3.8 * size, 0) + off, leaf.lightened(rng.randf_range(-0.12, 0.15)))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Decorative bush (does not block movement).
static func bush(parent: Node3D, pos: Vector3, color := Color(0.25, 0.55, 0.25)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 13.0 + pos.z * 29.0)
	for i in 3:
		var r := rng.randf_range(0.45, 0.7)
		Shapes.sphere(parent, r, pos + Vector3(rng.randf_range(-0.5, 0.5), r * 0.7, rng.randf_range(-0.5, 0.5)),
			color.lightened(rng.randf_range(-0.1, 0.15)))


## Lamp post: solid pole, glowing bulb, small light.
static func lamp_post(parent: Node3D, pos: Vector3, light := true) -> void:
	Shapes.solid_cylinder(parent, 0.09, 3.6, pos + Vector3(0, 1.8, 0), Color(0.18, 0.2, 0.24))
	Shapes.box(parent, Vector3(0.7, 0.08, 0.12), pos + Vector3(0.3, 3.55, 0), Color(0.18, 0.2, 0.24))
	var bulb := Shapes.sphere(parent, 0.18, pos + Vector3(0.55, 3.4, 0), Color(1, 0.92, 0.6))
	bulb.material_override = Shapes.mat(Color(1, 0.92, 0.6), 3.0)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.85, 0.6)
		l.light_energy = 1.2
		l.omni_range = 7.0
		l.position = pos + Vector3(0.55, 3.2, 0)
		parent.add_child(l)


# --- Particle effects ------------------------------------------------------------------

static func _pmat(color: Color, glow := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot_tex()
	return m


## Soft round dot so particles read as glints, not squares.
static func _dot_tex() -> ImageTexture:
	if _tex_cache.has("_dot"):
		return _tex_cache["_dot"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_tex_cache["_dot"] = t
	return t


static func _quad(size: float) -> QuadMesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	return qm


static func _particles(amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = particle_amount(amount)
	p.lifetime = lifetime
	p.mesh = _quad(size)
	p.material_override = _pmat(color)
	p.name = "FX"
	return p


## One-shot spark burst at a hit.
static func spark(parent: Node, pos: Vector3) -> CPUParticles3D:
	var p := _particles(16, 0.4, Color(1, 0.9, 0.35), 0.14)
	p.one_shot = true
	p.explosiveness = 0.95  # exactly 1.0 can skip the burst on CPU particles
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.name = "Spark"
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.8, false).timeout.connect(p.queue_free)
	return p


## Flat five-point star in the XY plane (used billboarded).
static func _star_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := PI / 2 + i * TAU / 10.0
		var a1 := PI / 2 + (i + 1) * TAU / 10.0
		var r0 := r if i % 2 == 0 else r * 0.45
		var r1 := r if (i + 1) % 2 == 0 else r * 0.45
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
	return st.commit()


## Cartoon dizzy stars circling above a head. Caller frees the returned node.
static func dizzy_stars(node: Node3D, height: float) -> Node3D:
	var ring := Node3D.new()
	ring.name = "DizzyStars"
	ring.position = Vector3(0, height, 0)
	node.add_child(ring)
	var sm := Shapes.mat(Color(1, 0.88, 0.2), 2.5)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var star := MeshInstance3D.new()
		star.mesh = _star_mesh(0.13)
		star.material_override = sm
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := i * TAU / 3.0
		star.position = Vector3(cos(ang) * 0.38, 0.05 * sin(ang * 2.0), sin(ang) * 0.38)
		ring.add_child(star)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "rotation:y", TAU, 0.9).from(0.0)
	return ring


## Tear drops streaming from a crying face.
static func tears(node: Node3D, height: float) -> CPUParticles3D:
	var p := _particles(10, 0.55, Color(0.45, 0.75, 1.0), 0.06)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector3Array([Vector3(-0.08, 0, -0.1), Vector3(0.08, 0, -0.1)])
	p.direction = Vector3(0, 0.6, -1)
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -6, 0)
	p.name = "Tears"
	p.position = Vector3(0, height, 0)
	node.add_child(p)
	p.emitting = true
	return p


## Gold sparkles floating around the whale.
static func sparkles(node: Node3D) -> CPUParticles3D:
	var p := _particles(12, 1.3, Color(1, 0.85, 0.3), 0.08)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.name = "Sparkles"
	p.position = Vector3(0, 0.9, 0)
	node.add_child(p)
	p.emitting = true
	return p


## Slow dust motes drifting through an indoor volume.
static func dust_motes(parent: Node3D, box: AABB) -> CPUParticles3D:
	var p := _particles(70, 9.0, Color(1, 0.97, 0.85, 0.55), 0.05)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box.size * 0.5
	p.gravity = Vector3(0, 0.02, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.spread = 180.0
	p.preprocess = 6.0
	p.name = "DustMotes"
	parent.add_child(p)
	p.position = box.get_center()
	p.emitting = true
	return p


# --- Wave Mode shooter effects (specs/004) ----------------------------------------

## Unshaded glowing material for flashes, tracers and shockwaves.
static func glow_mat(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A quick star-shaped flash and light pop at a muzzle (parented so it follows the blaster).
static func muzzle_flash(muzzle: Node3D, color: Color, size := 0.09) -> void:
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh(size)
	var m := glow_mat(color.lightened(0.3), 4.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.material_override = m
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.rotation.z = randf() * TAU
	muzzle.add_child(star)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.5
	muzzle.add_child(light)
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector3(1.6, 1.6, 1.6), 0.06)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.06)
	tw.tween_callback(star.queue_free)
	tw.tween_callback(light.queue_free)


## A visible projectile that flies from a to b, then calls on_arrive (hit registration is
## instant hitscan; this is only what the player sees).
static func tracer(parent: Node, a: Vector3, b: Vector3, kind: String, color: Color, on_arrive: Callable) -> Node3D:
	var n := Node3D.new()
	n.name = "Tracer"
	parent.add_child(n)
	n.global_position = a
	var speed := 90.0
	match kind:
		"dart":
			var body := Shapes.cylinder(n, 0.018, 0.13, Vector3.ZERO, Color(1.0, 0.55, 0.1))
			body.rotation.x = PI / 2
			var tip := Shapes.sphere(n, 0.022, Vector3(0, 0, -0.07), Color(0.2, 0.45, 1.0))
			tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"paint":
			speed = 75.0
			var ball := Shapes.sphere(n, 0.035, Vector3.ZERO, color)
			ball.material_override = Shapes.mat(color, 0.6)
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"bubble":
			speed = 38.0
			var bub := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			bub.mesh = sm
			var bm := glow_mat(Color(0.7, 0.95, 1.0, 0.45), 0.8)
			bub.material_override = bm
			bub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(bub)
	if a.distance_to(b) > 0.01:
		n.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var t := clampf(a.distance_to(b) / speed, 0.02, 0.6)
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", b, t)
	tw.tween_callback(on_arrive)
	tw.tween_callback(n.queue_free)
	return n


static func _push_capped(list: Array, node: Node, cap: int) -> void:
	list.append(node)
	while list.size() > cap:
		var old: Node = list.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func _prune(list: Array) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)


## Paint splat stuck to a surface. Oldest splats are removed past the quality cap.
static func splat(parent: Node, pos: Vector3, normal: Vector3, color: Color) -> MeshInstance3D:
	_prune(_decals)
	var mi := MeshInstance3D.new()
	mi.name = "Splat"
	var cm := CylinderMesh.new()
	var r := randf_range(0.14, 0.3)
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.01
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = Shapes.mat(color.lightened(randf_range(-0.1, 0.1)), 0.15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	mi.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), pos + up * 0.012)
	mi.scale = Vector3(1.0, 1.0, randf_range(0.6, 1.0))
	_push_capped(_decals, mi, int(q("decals")))
	return mi


## A foam dart stuck in a wall, pointing along the shot.
static func stuck_dart(parent: Node, pos: Vector3, dir: Vector3) -> Node3D:
	_prune(_darts)
	var n := Node3D.new()
	n.name = "StuckDart"
	parent.add_child(n)
	n.global_position = pos - dir.normalized() * 0.05
	if dir.length() > 0.01:
		n.look_at(n.global_position + dir, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	var body := Shapes.cylinder(n, 0.018, 0.12, Vector3.ZERO, Color(1.0, 0.55, 0.1))
	body.rotation.x = PI / 2
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fin := Shapes.box(n, Vector3(0.05, 0.004, 0.03), Vector3(0, 0, 0.055), Color(0.2, 0.45, 1.0))
	fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_push_capped(_darts, n, MAX_DARTS)
	return n


static func decal_count() -> int:
	_prune(_decals)
	return _decals.size()


static func dart_count() -> int:
	_prune(_darts)
	return _darts.size()


## Small colored burst where a shot lands.
static func impact_puff(parent: Node, pos: Vector3, color: Color, amount := 10) -> void:
	var p := _particles(amount, 0.35, color, 0.1)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -6, 0)
	p.name = "Puff"
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.7, false).timeout.connect(p.queue_free)


## Water/goo splash: droplets plus a flat ring that spreads and fades.
static func splash(parent: Node, pos: Vector3, color: Color, radius := 1.0) -> void:
	impact_puff(parent, pos + Vector3(0, 0.2, 0), color, 18)
	ring_wave(parent, pos + Vector3(0, 0.05, 0), color, radius, 0.35)


## Expanding flat ring (explosions, megaphone blasts, splashes).
static func ring_wave(parent: Node, pos: Vector3, color: Color, radius: float, time := 0.4) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "RingWave"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 24
	mi.mesh = tm
	var m := glow_mat(Color(color, 0.7), 1.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, time)
	tw.tween_callback(mi.queue_free)


## Rubber chicken impact: a burst of feathers, a shockwave and a big cartoon word.
static func feathers(parent: Node, pos: Vector3, radius: float) -> void:
	var p := _particles(40, 1.4, Color(1.0, 0.95, 0.75), 0.14)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.name = "Feathers"
	parent.add_child(p)
	p.global_position = pos + Vector3(0, 0.4, 0)
	p.emitting = true
	p.get_tree().create_timer(1.8, false).timeout.connect(p.queue_free)
	impact_puff(parent, pos + Vector3(0, 0.3, 0), Color(1.0, 0.75, 0.2), 24)
	ring_wave(parent, pos + Vector3(0, 0.1, 0), Color(1.0, 0.85, 0.3), radius, 0.4)
	pop_word(parent, pos + Vector3(0, 1.4, 0), ["BWAK!", "BAWK!!", "SQUAWK!"][randi() % 3], Color(1.0, 0.85, 0.2), 120)


## Big cartoon word that pops up and floats away.
static func pop_word(parent: Node, pos: Vector3, text: String, color: Color, size := 90) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 18
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = UI.bold_font()
	parent.add_child(l)
	l.global_position = pos
	l.scale = Vector3(0.3, 0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", pos.y + 0.8, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.tween_callback(l.queue_free)


## Continuous water stream for the soaker (toggle .emitting).
static func water_stream(muzzle: Node3D) -> CPUParticles3D:
	var p := _particles(60, 0.55, Color(0.45, 0.75, 1.0, 0.85), 0.07)
	p.direction = Vector3(0, 0, -1)
	p.spread = 3.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.local_coords = false
	p.emitting = false
	p.name = "WaterStream"
	muzzle.add_child(p)
	return p


## Drips falling off a soaked adult (caller frees).
static func drips(node: Node3D, height: float) -> CPUParticles3D:
	var p := _particles(8, 0.5, Color(0.45, 0.75, 1.0), 0.06)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, height * 0.4, 0.3)
	p.gravity = Vector3(0, -9, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.2
	p.position = Vector3(0, height * 0.55, 0)
	p.name = "Drips"
	node.add_child(p)
	p.emitting = true
	return p
