extends RefCounted
## Anatomical hand mesh generator (specs/005, "extremely detailed" pass). The hand is a signed
## distance field: bones as tapered, slightly flattened round cones, joint bulges, knuckles,
## dorsal tendons and veins, thenar/hypothenar pads, fingertip pads and nail beds, all smoothly
## blended (which also forms the webbing between fingers). A narrow-band surface-nets mesher turns
## it into one continuous skin, every vertex is projected onto the exact surface, normals come
## from the field gradient, skin weights from distances to the bones, and skin color is painted
## per vertex (knuckle redness, palm tone, fingertip pink, veins, flexion creases, mottling).
##
## Model frame (right hand): wrist toward +Z, fingers toward -Z, +Y is the back of the hand,
## thumb toward -X. The left hand is a mirror image (see mirrored()).

const CELL := 0.0019            # fine grid spacing (m)
const COARSE := 4               # fine cells per coarse cell (narrow-band search)

const FINGERS := [
	# [knuckle x, knuckle z, segment lengths, base radius]
	[-0.0255, -0.046, [0.043, 0.026, 0.022], 0.0099],
	[-0.0085, -0.0505, [0.047, 0.029, 0.023], 0.0103],
	[0.0095, -0.0475, [0.044, 0.028, 0.022], 0.0097],
	[0.0262, -0.040, [0.035, 0.021, 0.019], 0.0086],
]
const THUMB_BASE := Vector3(-0.029, -0.007, 0.03)
const THUMB_YAW := 0.62
const THUMB_ROLL := 1.0
const THUMB := [0.04, 0.032, 0.027]
const THUMB_R := [0.0128, 0.0118, 0.0112]
const PALM_BONE_HEAD := Vector3(0, 0, 0.075)
const VEINS := [
	[Vector3(0.012, 0.0102, 0.07), Vector3(0.006, 0.0108, 0.03)], [Vector3(0.006, 0.0108, 0.03), Vector3(-0.012, 0.0106, -0.005)],
	[Vector3(0.006, 0.0108, 0.03), Vector3(0.017, 0.0104, -0.012)], [Vector3(-0.012, 0.0106, -0.005), Vector3(-0.018, 0.0098, -0.03)],
	[Vector3(-0.004, 0.0102, 0.075), Vector3(-0.015, 0.0104, 0.04)],
]

## Bone layout shared with hand.gd: 0 palm, 1-12 fingers (3 each, index..pinky), 13-15 thumb.
const BONE_COUNT := 16

static var _cache: Dictionary = {}

## Generated once (on a background thread at startup) and cached on disk; bump VERSION whenever
## the generator changes so stale caches are rebuilt.
const VERSION := 4
static var _thread: Thread
static var _worker: RefCounted
static var _right: ArrayMesh
static var _left: ArrayMesh
static var _nails: Array = []


static func cache_path() -> String:
	return "user://hand_mesh_v%d.res" % VERSION


## Kick off generation early (GameState calls this at launch) so hands are ready by the first raid.
static func start_async() -> void:
	if _right != null or _thread != null:
		return
	if FileAccess.file_exists(cache_path()):
		var m = ResourceLoader.load(cache_path(), "", ResourceLoader.CACHE_MODE_IGNORE)
		if m is ArrayMesh and (m as ArrayMesh).has_meta("nails"):
			_from_mesh(m)
			return
	_worker = load("res://scripts/hand_mesh.gd").new()
	_thread = Thread.new()
	_thread.start(_worker._run)


func _run() -> Dictionary:
	return build()


## [right mesh, left mesh, nail spots]. Blocks only if generation hasn't finished yet.
static func meshes() -> Array:
	if _right == null:
		var data: Dictionary
		if _thread != null:
			data = _thread.wait_to_finish()
			_thread = null
		else:
			data = build()
		_right = array_mesh(data)
		_right.set_meta("nails", data["nails"])
		ResourceSaver.save(_right, cache_path())
		_left = array_mesh(mirrored(data))
		_nails = data["nails"]
	return [_right, _left, _nails]


static func _from_mesh(m: ArrayMesh) -> void:
	var arr := m.surface_get_arrays(0)
	var data := {"verts": arr[Mesh.ARRAY_VERTEX], "normals": arr[Mesh.ARRAY_NORMAL], "colors": arr[Mesh.ARRAY_COLOR],
		"uvs": arr[Mesh.ARRAY_TEX_UV], "bones": arr[Mesh.ARRAY_BONES], "weights": arr[Mesh.ARRAY_WEIGHTS], "index": arr[Mesh.ARRAY_INDEX]}
	_right = m
	_left = array_mesh(mirrored(data))
	_nails = m.get_meta("nails")


# --- Skeleton description -------------------------------------------------------------

## Rest transforms (model space) and parents of every bone, plus segment endpoints for weights.
static func skeleton_rest() -> Dictionary:
	var rest := []
	var parent := []
	var seg_a := []
	var seg_b := []
	# Palm/wrist: one rigid bone.
	rest.append(Transform3D(Basis(), PALM_BONE_HEAD))
	parent.append(-1)
	seg_a.append(Vector3(0, 0, 0.16))
	seg_b.append(Vector3(0, 0, -0.03))
	for f in FINGERS:
		var lens: Array = f[2]
		var base := Vector3(f[0], 0.002, f[1])
		var b := Basis()
		var p := base
		for j in 3:
			rest.append(Transform3D(b, p))
			parent.append(0 if j == 0 else rest.size() - 2)
			var tip := p + b * Vector3(0, 0, -lens[j])
			seg_a.append(p)
			seg_b.append(tip)
			p = tip
	var tb := Basis(Vector3.UP, THUMB_YAW) * Basis(Vector3.BACK, THUMB_ROLL)
	var tp := THUMB_BASE
	for j in 3:
		rest.append(Transform3D(tb, tp))
		parent.append(0 if j == 0 else rest.size() - 2)
		var tip := tp + tb * Vector3(0, 0, -THUMB[j])
		seg_a.append(tp)
		seg_b.append(tip)
		tp = tip
	return {"rest": rest, "parent": parent, "seg_a": seg_a, "seg_b": seg_b}


# --- Signed distance field --------------------------------------------------------------

## Primitive kinds: 0 round cone along local -Z (r1 at 0, r2 at -h), 1 ellipsoid, 2 round box,
## 3 subtractive box (carves), each in its own local frame with a y-flattening factor.
static func _prims() -> Array:
	var sk := skeleton_rest()
	var rest: Array = sk["rest"]
	var out := []
	# Palm block and its dorsal dome.
	out.append(_p(2, Transform3D(Basis(), Vector3(0, 0, -0.002)), [Vector3(0.036, 0.0095, 0.043), 0.009], 1.0, 0.0))
	out.append(_p(1, Transform3D(Basis(), Vector3(0, 0.004, -0.004)), [Vector3(0.039, 0.012, 0.046)], 1.0, 0.006))
	# Thenar and hypothenar pads, palmar pads under the knuckles.
	out.append(_p(1, Transform3D(Basis(Vector3.UP, 0.35), Vector3(-0.025, -0.006, 0.017)), [Vector3(0.017, 0.012, 0.028)], 1.0, 0.009))
	out.append(_p(1, Transform3D(Basis(), Vector3(0.029, -0.0055, 0.008)), [Vector3(0.012, 0.0095, 0.032)], 1.0, 0.008))
	out.append(_p(1, Transform3D(Basis(), Vector3(0.0, -0.0075, -0.039)), [Vector3(0.037, 0.0075, 0.0105)], 1.0, 0.006))
	# Wrist with the ulnar head bump.
	out.append(_p(0, Transform3D(Basis(), Vector3(0, 0.0, 0.17)), [0.0285, 0.025, 0.13], 0.74, 0.012))
	out.append(_p(1, Transform3D(Basis(), Vector3(0.023, 0.005, 0.062)), [Vector3(0.006, 0.005, 0.006)], 1.0, 0.006))
	# Fingers.
	for i in FINGERS.size():
		var f: Array = FINGERS[i]
		var lens: Array = f[2]
		var r: float = f[3]
		var radii := [[r, r * 0.88], [r * 0.87, r * 0.79], [r * 0.77, r * 0.7]]
		for j in 3:
			var xf: Transform3D = rest[1 + i * 3 + j]
			out.append(_p(0, xf, [radii[j][0], radii[j][1], lens[j]], 0.86, 0.0035 if j > 0 else 0.007))
		var k0: Transform3D = rest[1 + i * 3]
		var k1: Transform3D = rest[2 + i * 3]
		var k2: Transform3D = rest[3 + i * 3]
		# Knuckle (metacarpal head), joint bulges, dorsal tendon to the wrist.
		out.append(_p(1, k0.translated_local(Vector3(0, 0.0035, 0.002)), [Vector3(r * 1.12, r * 1.0, r * 1.1)], 1.0, 0.0045))
		out.append(_p(1, k1, [Vector3(r * 0.95, r * 0.85, r * 0.9)], 1.0, 0.003))
		out.append(_p(1, k2, [Vector3(r * 0.82, r * 0.72, r * 0.78)], 1.0, 0.0025))
		var tend_a := Vector3(f[0] * 0.55, 0.0095, 0.04)
		out.append(_seg(tend_a, k0.origin + Vector3(0, 0.0075, 0.004), 0.0021, 0.0019, 1.0, 0.0045))
		# Fingertip pad and the flattened nail bed.
		var tip_l: float = lens[2]
		out.append(_p(1, k2.translated_local(Vector3(0, -r * 0.22, -tip_l * 0.68)), [Vector3(r * 0.74, r * 0.6, r * 0.82)], 1.0, 0.003))
		out.append(_p(3, k2.translated_local(Vector3(0, r * 0.66 + 0.004, -tip_l * 0.6)), [Vector3(r * 0.62, 0.004, tip_l * 0.36), 0.0], 1.0, 0.0012))
	# Thumb.
	for j in 3:
		var xf: Transform3D = rest[13 + j]
		var r1: float = THUMB_R[j]
		var r2: float = THUMB_R[j] * (0.92 if j < 2 else 0.8)
		out.append(_p(0, xf, [r1, r2, THUMB[j]], 0.88, 0.009 if j == 0 else 0.0035))
		if j > 0:
			out.append(_p(1, xf, [Vector3(r1 * 0.98, r1 * 0.88, r1 * 0.95)], 1.0, 0.003))
	var t2: Transform3D = rest[15]
	out.append(_p(1, t2.translated_local(Vector3(0, -THUMB_R[2] * 0.25, -THUMB[2] * 0.66)), [Vector3(THUMB_R[2] * 0.8, THUMB_R[2] * 0.65, THUMB_R[2] * 0.85)], 1.0, 0.003))
	out.append(_p(3, t2.translated_local(Vector3(0, THUMB_R[2] * 0.66 + 0.004, -THUMB[2] * 0.58)), [Vector3(THUMB_R[2] * 0.66, 0.004, THUMB[2] * 0.36), 0.0], 1.0, 0.0012))
	# Veins on the back of the hand (a gentle forked network).
	for v in VEINS:
		out.append(_seg(v[0], v[1], 0.0016, 0.0013, 1.0, 0.003))
	# Carving primitives must be applied after every additive one.
	var add := out.filter(func(q): return q[0] != 3)
	var carve := out.filter(func(q): return q[0] == 3)
	return add + carve


## Packed primitive: [kind, inverse transform, a, b, c, flat, k, center, radius].
## kind 0: a=r1, b=r2, c=h. kind 1: a=radii (Vector3). kind 2/3: a=half extents, b=rounding.
static func _p(kind: int, xf: Transform3D, params: Array, flat: float, k: float) -> Array:
	var c := xf.origin
	var ext := 0.0
	var pa = params[0]
	var pb = params[1] if params.size() > 1 else 0.0
	var pc = params[2] if params.size() > 2 else 0.0
	match kind:
		0:
			c = xf * Vector3(0, 0, -params[2] * 0.5)
			ext = params[2] * 0.5 + maxf(params[0], params[1])
		1:
			ext = maxf(params[0].x, maxf(params[0].y, params[0].z))
		_:
			ext = params[0].length() + (params[1] if params.size() > 1 else 0.0)
	return [kind, xf.affine_inverse(), pa, pb, pc, flat, k, c, ext + k + 0.002]


static func _seg(a: Vector3, b: Vector3, r1: float, r2: float, flat: float, k: float) -> Array:
	var d := b - a
	var z := -d.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return _p(0, Transform3D(Basis(x, y, z), a), [r1, r2, d.length()], flat, k)


static func _smin(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return minf(a, b)
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a, -b, k)


static func _prim_d(pr: Array, p: Vector3) -> float:
	var q: Vector3 = pr[1] * p
	var flat: float = pr[5]
	match pr[0]:
		0:
			q.y /= flat
			var h: float = pr[4]
			var t := clampf(-q.z / h, 0.0, 1.0)
			return (Vector3(q.x, q.y, q.z + t * h).length() - lerpf(pr[2], pr[3], t)) * flat
		1:
			var rr: Vector3 = pr[2]
			return (Vector3(q.x / rr.x, q.y / rr.y, q.z / rr.z).length() - 1.0) * minf(rr.x, minf(rr.y, rr.z))
		_:
			var bb: Vector3 = pr[2]
			var rd: float = pr[3]
			var ax := absf(q.x) - bb.x + rd
			var ay := absf(q.y) - bb.y + rd
			var az := absf(q.z) - bb.z + rd
			var outside := Vector3(maxf(ax, 0.0), maxf(ay, 0.0), maxf(az, 0.0)).length()
			return outside + minf(maxf(ax, maxf(ay, az)), 0.0) - rd


## Field value at p using only the given primitives (pre-culled; carving prims come last).
static func _sdf(p: Vector3, prims: Array) -> float:
	var d := 1.0
	for pr in prims:
		if pr[0] == 3:
			d = _smax(d, -_prim_d(pr, p), pr[6])
		else:
			d = _smin(d, _prim_d(pr, p), pr[6])
	return d


static func _grad(p: Vector3, prims: Array) -> Vector3:
	var e := 0.0004
	var k1 := Vector3(1, -1, -1)
	var k2 := Vector3(-1, -1, 1)
	var k3 := Vector3(-1, 1, -1)
	var k4 := Vector3(1, 1, 1)
	var g := k1 * _sdf(p + k1 * e, prims) + k2 * _sdf(p + k2 * e, prims) + k3 * _sdf(p + k3 * e, prims) + k4 * _sdf(p + k4 * e, prims)
	return g.normalized() if g.length() > 0.0 else Vector3.UP


# --- Meshing -----------------------------------------------------------------------------

## Builds (or returns the cached) right-hand mesh data: arrays for an ArrayMesh plus nail placements.
static func build() -> Dictionary:
	if _cache.has("right"):
		return _cache["right"]
	var prims := _prims()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for pr in prims:
		var c: Vector3 = pr[7]
		var r: float = pr[8]
		lo = lo.min(c - Vector3(r, r, r))
		hi = hi.max(c + Vector3(r, r, r))
	hi.z = minf(hi.z, 0.15)  # the sleeve covers the rest of the forearm
	var n := Vector3i(ceili((hi.x - lo.x) / CELL) + 2, ceili((hi.y - lo.y) / CELL) + 2, ceili((hi.z - lo.z) / CELL) + 2)
	var nc := Vector3i(ceili(float(n.x) / COARSE) + 1, ceili(float(n.y) / COARSE) + 1, ceili(float(n.z) / COARSE) + 1)
	var csize := CELL * COARSE
	var total := n.x * n.y * n.z
	var field := PackedFloat32Array()
	field.resize(total)
	field.fill(1.0)
	# Narrow band: for each coarse cell, cull primitives and only sample fine points near the surface.
	var region_prims := {}
	var band := []
	for cz in nc.z:
		for cy in nc.y:
			for cx in nc.x:
				var cc := lo + Vector3(cx + 0.5, cy + 0.5, cz + 0.5) * csize
				var reach := csize * 0.87 + 0.012
				var near := []
				for pr in prims:
					if (pr[7] as Vector3).distance_to(cc) < float(pr[8]) + reach:
						near.append(pr)
				if near.is_empty():
					continue
				var fx0 := cx * COARSE
				var fy0 := cy * COARSE
				var fz0 := cz * COARSE
				var dc := _sdf(cc, near)
				if absf(dc) > csize * 0.9:
					if dc < 0.0:
						for z in range(fz0, mini(fz0 + COARSE, n.z)):
							for y in range(fy0, mini(fy0 + COARSE, n.y)):
								for x in range(fx0, mini(fx0 + COARSE, n.x)):
									field[x + n.x * (y + n.y * z)] = -1.0
					continue
				var key := Vector3i(cx, cy, cz)
				region_prims[key] = near
				band.append(key)
				for z in range(fz0, mini(fz0 + COARSE, n.z)):
					for y in range(fy0, mini(fy0 + COARSE, n.y)):
						for x in range(fx0, mini(fx0 + COARSE, n.x)):
							field[x + n.x * (y + n.y * z)] = _sdf(lo + Vector3(x, y, z) * CELL, near)
	# Surface nets over the band: one vertex per cell with a sign change...
	var verts := PackedVector3Array()
	var cell_vert := {}
	var sx := 1
	var sy := n.x
	var sz := n.x * n.y
	var offs := [0, sx, sy, sx + sy, sz, sx + sz, sy + sz, sx + sy + sz]
	var cpos := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
	var edges := [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7]
	var vals := PackedFloat32Array()
	vals.resize(8)
	for key in band:
		var k: Vector3i = key
		for z in range(k.z * COARSE, mini(k.z * COARSE + COARSE, n.z - 1)):
			for y in range(k.y * COARSE, mini(k.y * COARSE + COARSE, n.y - 1)):
				for x in range(k.x * COARSE, mini(k.x * COARSE + COARSE, n.x - 1)):
					var base := x + sy * y + sz * z
					var neg := 0
					for c in 8:
						var v: float = field[base + offs[c]]
						vals[c] = v
						if v < 0.0:
							neg += 1
					if neg == 0 or neg == 8:
						continue
					var acc := Vector3.ZERO
					var cnt := 0
					for e in range(0, 24, 2):
						var va := vals[edges[e]]
						var vb := vals[edges[e + 1]]
						if (va < 0.0) != (vb < 0.0):
							acc += (cpos[edges[e]] as Vector3).lerp(cpos[edges[e + 1]], va / (va - vb))
							cnt += 1
					cell_vert[base] = verts.size()
					verts.append(lo + (Vector3(x, y, z) + acc / float(cnt)) * CELL)
	# ...and one quad per crossing grid edge.
	var idx := PackedInt32Array()
	var quads := [[0, -sy - sz, -sz, 0, -sy], [1, -sx - sz, -sx, 0, -sz], [2, -sx - sy, -sy, 0, -sx]]
	for key in band:
		var k: Vector3i = key
		for z in range(maxi(k.z * COARSE, 1), mini(k.z * COARSE + COARSE, n.z - 1)):
			for y in range(maxi(k.y * COARSE, 1), mini(k.y * COARSE + COARSE, n.y - 1)):
				for x in range(maxi(k.x * COARSE, 1), mini(k.x * COARSE + COARSE, n.x - 1)):
					var base := x + sy * y + sz * z
					var v0: float = field[base]
					for qd in quads:
						var step: int = [sx, sy, sz][qd[0]]
						var v1: float = field[base + step]
						if (v0 < 0.0) == (v1 < 0.0):
							continue
						var c0: int = base + qd[1]
						var c1: int = base + qd[2]
						var c3: int = base + qd[4]
						if not (cell_vert.has(c0) and cell_vert.has(c1) and cell_vert.has(base) and cell_vert.has(c3)):
							continue
						var q := [cell_vert[c0], cell_vert[c1], cell_vert[base], cell_vert[c3]]
						if v0 < 0.0:
							q.reverse()
						idx.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	# Project onto the exact surface (one Newton step) and take normals from the field gradient.
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		var p := verts[i]
		var key := Vector3i(floori((p.x - lo.x) / csize), floori((p.y - lo.y) / csize), floori((p.z - lo.z) / csize))
		var near: Array = region_prims.get(key, prims)
		var g := _grad(p, near)
		p -= g * _sdf(p, near)
		verts[i] = p
		normals[i] = g
	var data := {"verts": verts, "normals": normals, "index": idx}
	_skin_and_paint(data)
	data["nails"] = _nail_spots(prims)
	_cache["right"] = data
	return data


# --- Skin weights, color, UVs ---------------------------------------------------------------

static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> Array:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return [p.distance_to(a + ab * t), t]


static func _skin_and_paint(data: Dictionary) -> void:
	var sk := skeleton_rest()
	var sa: Array = sk["seg_a"]
	var sb: Array = sk["seg_b"]
	var verts: PackedVector3Array = data["verts"]
	var normals: PackedVector3Array = data["normals"]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var base := Color(0.72, 0.47, 0.35)
	var palm_tone := Color(0.8, 0.57, 0.45)
	var knuckle_tone := Color(0.62, 0.36, 0.29)
	var tip_tone := Color(0.78, 0.46, 0.38)
	var vein_tone := Color(0.52, 0.44, 0.5)
	var joints := []
	var rest: Array = sk["rest"]
	for i in range(1, BONE_COUNT):
		joints.append((rest[i] as Transform3D).origin)
	for i in verts.size():
		var p := verts[i]
		var nrm := normals[i]
		# Weights: inverse distance^6 to bone segments, top 4.
		var cand := []
		for b in BONE_COUNT:
			var d: float = _seg_dist(p, sa[b], sb[b])[0]
			cand.append([d, b])
		cand.sort_custom(func(u, v): return u[0] < v[0])
		var w := []
		var wsum := 0.0
		for k in 4:
			var ww := 1.0 / pow(maxf(cand[k][0], 0.0015), 6.0)
			w.append(ww)
			wsum += ww
		for k in 4:
			bones.append(cand[k][1])
			weights.append(w[k] / wsum)
		# Color.
		var c := base
		var palmar := clampf(-nrm.y * 1.4, 0.0, 1.0)
		c = c.lerp(palm_tone, palmar * 0.75)
		for j in joints:
			var dj := p.distance_to(j)
			if dj < 0.014 and nrm.y > 0.0:
				c = c.lerp(knuckle_tone, (1.0 - dj / 0.014) * 0.55 * nrm.y)
		# Fingertips: the last third of each distal segment.
		for f in 4:
			var b := 3 + f * 3
			var st: Array = _seg_dist(p, sa[b], sb[b])
			if st[0] < 0.013 and st[1] > 0.55:
				c = c.lerp(tip_tone, (st[1] - 0.55) * 1.6)
		var stt: Array = _seg_dist(p, sa[15], sb[15])
		if stt[0] < 0.015 and stt[1] > 0.55:
			c = c.lerp(tip_tone, (stt[1] - 0.55) * 1.6)
		# Veins: a faint bluish tint right over the raised vein geometry.
		if nrm.y > 0.3:
			for v in VEINS:
				var dv: float = _seg_dist(p, v[0], v[1])[0]
				if dv < 0.0032:
					c = c.lerp(vein_tone, (1.0 - dv / 0.0032) * 0.22)
		# Flexion creases on the palm side of every finger joint.
		if palmar > 0.35:
			for j in range(1, BONE_COUNT):
				if j == 13:
					continue
				var jo: Vector3 = rest[j].origin
				var ax: Vector3 = (rest[j] as Transform3D).basis.z
				var along := (p - jo).dot(ax)
				if absf(along) < 0.0011 and p.distance_to(jo) < 0.016:
					c = c.darkened(0.28)
		# Mottling and fine variation.
		var m := Art._vnoise(p.x * 30.0 + 7.0, p.z * 30.0 + p.y * 20.0, 9, 61) - 0.5
		c = c.lightened(m * 0.08) if m > 0.0 else c.darkened(-m * 0.1)
		colors.append(c)
		uvs.append(Vector2(p.x * 25.0, (p.z + p.y * 0.6) * 25.0))
	data["bones"] = bones
	data["weights"] = weights
	data["colors"] = colors
	data["uvs"] = uvs


## Where each nail sits (bone index, local transform on that bone), measured on the surface.
static func _nail_spots(prims: Array) -> Array:
	var sk := skeleton_rest()
	var rest: Array = sk["rest"]
	var out := []
	for f in 4:
		var b := 3 + f * 3
		var r: float = FINGERS[f][3] * 0.73
		var l: float = FINGERS[f][2][2]
		out.append([b, _surface_y(rest[b], Vector3(0, 0, -l * 0.6), prims), r * 1.25, l * 0.62])
	out.append([15, _surface_y(rest[15], Vector3(0, 0, -THUMB[2] * 0.58), prims), THUMB_R[2] * 0.85 * 1.25, THUMB[2] * 0.6])
	return out


static func _surface_y(xf: Transform3D, local: Vector3, prims: Array) -> Vector3:
	var p := local + Vector3(0, 0.03, 0)
	for it in 60:
		var d := _sdf(xf * p, prims)
		if d < 0.0002:
			break
		p.y -= maxf(d, 0.0003)
	return p


## Mirror the right-hand data for the left hand (x flipped, winding reversed).
static func mirrored(data: Dictionary) -> Dictionary:
	var v: PackedVector3Array = (data["verts"] as PackedVector3Array).duplicate()
	var nm: PackedVector3Array = (data["normals"] as PackedVector3Array).duplicate()
	for i in v.size():
		v[i].x = -v[i].x
		nm[i].x = -nm[i].x
	var idx: PackedInt32Array = (data["index"] as PackedInt32Array).duplicate()
	for t in range(0, idx.size(), 3):
		var tmp := idx[t + 1]
		idx[t + 1] = idx[t + 2]
		idx[t + 2] = tmp
	var uv: PackedVector2Array = (data["uvs"] as PackedVector2Array).duplicate()
	for i in uv.size():
		uv[i].x = -uv[i].x
	var out := data.duplicate()
	out["verts"] = v
	out["normals"] = nm
	out["index"] = idx
	out["uvs"] = uv
	return out


## Tangents along +U (the UVs are a planar projection along X), orthogonalized per vertex.
static func _tangents(data: Dictionary) -> PackedFloat32Array:
	var nm: PackedVector3Array = data["normals"]
	var uvs: PackedVector2Array = data["uvs"]
	var mirrored_u := uvs.size() > 0 and (data["verts"] as PackedVector3Array)[0].x * uvs[0].x < 0.0
	var ux := Vector3(-1, 0, 0) if mirrored_u else Vector3(1, 0, 0)
	var out := PackedFloat32Array()
	out.resize(nm.size() * 4)
	for i in nm.size():
		var n := nm[i]
		var t := ux - n * n.dot(ux)
		if t.length() < 0.05:
			t = Vector3(0, 0, 1) - n * n.z
		t = t.normalized()
		out[i * 4] = t.x
		out[i * 4 + 1] = t.y
		out[i * 4 + 2] = t.z
		out[i * 4 + 3] = 1.0
	return out


static func array_mesh(data: Dictionary) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = data["verts"]
	arr[Mesh.ARRAY_NORMAL] = data["normals"]
	arr[Mesh.ARRAY_COLOR] = data["colors"]
	arr[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arr[Mesh.ARRAY_TANGENT] = _tangents(data)
	arr[Mesh.ARRAY_BONES] = data["bones"]
	arr[Mesh.ARRAY_WEIGHTS] = data["weights"]
	arr[Mesh.ARRAY_INDEX] = data["index"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
