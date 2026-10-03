extends Node
## Wave Mode toy blasters (specs/004): per-run ammo, firing, aiming and reloading.
## Damage is instant hitscan (fair and testable); what the player sees is a dart, paintball
## or bubble flying to the hit point. Shots only query world + adults (layers 1 and 8), so kids
## can never be hit (Constitution IX / XIII).

const ChickenScript := preload("res://scripts/rocket.gd")
const SHOT_MASK := 1 | 8
const PAINT_COLORS := [Color(1.0, 0.25, 0.55), Color(0.3, 0.9, 0.35), Color(0.25, 0.6, 1.0), Color(1.0, 0.85, 0.15), Color(0.7, 0.35, 1.0)]
const RECOIL := {"dart": 0.012, "soaker": 0.0, "paint": 0.006, "bubble": 0.035, "chicken": 0.045}

var player: CharacterBody3D
var main: Node
var ammo := {}           # blaster id -> {"mag": int, "reserve": int}
var cooldown := 0.0
var reload_t := 0.0      # > 0 while reloading
var reload_len := 1.0
var aim_k := 0.0         # 0 = hip, 1 = fully aimed (smoothed)
var shots_fired := 0
var hits := 0
var stream: CPUParticles3D = null
var _sound_cd := 0.0
var _reloading_id := ""


func reset_ammo() -> void:
	ammo.clear()
	for id in GameState.BLASTERS:
		var b: Dictionary = GameState.BLASTERS[id]
		ammo[id] = {"mag": int(b["mag"]), "reserve": int(b["reserve"])}
	cancel_reload()


func current_id() -> String:
	return GameState.blaster_id


func mag() -> int:
	return ammo[current_id()]["mag"]


func reserve() -> int:
	return ammo[current_id()]["reserve"]


func reloading() -> bool:
	return reload_t > 0.0


func reload_fraction() -> float:
	return 1.0 - reload_t / reload_len if reloading() else 0.0


## Wave clear: refill a share of every blaster's max reserve.
func refill_reserve(frac: float) -> void:
	for id in ammo:
		var max_r: int = GameState.BLASTERS[id]["reserve"]
		if max_r >= 0:
			ammo[id]["reserve"] = mini(max_r, ammo[id]["reserve"] + ceili(max_r * frac))


## Ammo pickup: one magazine's worth of reserve for every blaster.
func add_ammo_pack() -> void:
	for id in ammo:
		var b: Dictionary = GameState.BLASTERS[id]
		if int(b["reserve"]) >= 0:
			ammo[id]["reserve"] = mini(int(b["reserve"]), ammo[id]["reserve"] + int(b["mag"]))


## Called every physics frame by the player in Wave Mode.
func tick(delta: float, fire_held: bool, fire_pressed: bool, aim_held: bool, reload_pressed: bool) -> void:
	cooldown -= delta
	_sound_cd -= delta
	if _reloading_id != "" and _reloading_id != current_id():
		cancel_reload()  # switching blasters cancels a reload (no ammo lost)
	var b := GameState.blaster()
	aim_k = move_toward(aim_k, 1.0 if aim_held and not reloading() else 0.0, delta * 7.0)
	player.viewmodel.set_aim(aim_k)
	if reloading():
		reload_t -= delta
		_set_stream(false)
		if reload_t <= 0.0:
			_finish_reload()
		return
	if reload_pressed:
		start_reload()
		_set_stream(false)
		return
	var want := fire_held if b["auto"] else fire_pressed
	if want and cooldown <= 0.0:
		if mag() <= 0:
			if fire_pressed:
				Sfx.play("empty", 0.02, -4.0)
			start_reload()
		else:
			fire()
	_set_stream(b["kind"] == "stream" and fire_held and mag() > 0)


func _set_stream(on: bool) -> void:
	if stream and is_instance_valid(stream) and stream.emitting != on:
		stream.emitting = on


func start_reload() -> bool:
	if reloading():
		return false
	var b := GameState.blaster()
	var a: Dictionary = ammo[current_id()]
	if a["mag"] >= int(b["mag"]) or a["reserve"] == 0:
		return false
	reload_len = b["reload"]
	reload_t = reload_len
	_reloading_id = current_id()
	player.viewmodel.reload_anim(reload_len)
	Sfx.play("reload", 0.05, -2.0)
	return true


func cancel_reload() -> void:
	reload_t = 0.0
	_reloading_id = ""
	if player and player.viewmodel:
		player.viewmodel.reload_anim(0.0)


func _finish_reload() -> void:
	reload_t = 0.0
	_reloading_id = ""
	var b := GameState.blaster()
	var a: Dictionary = ammo[current_id()]
	var need: int = int(b["mag"]) - a["mag"]
	var take: int = need if a["reserve"] < 0 else mini(need, a["reserve"])
	a["mag"] += take
	if a["reserve"] >= 0:
		a["reserve"] -= take


## Current spread in degrees (aiming tightens it, being airborne loosens it).
func spread_deg() -> float:
	var b := GameState.blaster()
	var s: float = b["spread"] * lerpf(1.0, GameState.AIM_SPREAD_MULT, aim_k)
	if not player.is_on_floor():
		s *= 1.5
	return s


func fire() -> void:
	var id := current_id()
	var b := GameState.blaster()
	cooldown = b["rate"]
	ammo[id]["mag"] -= 1
	shots_fired += 1
	player.last_attack_time = player._time
	var cam: Camera3D = player.camera
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var muzzle: Vector3 = player.viewmodel.muzzle_position()
	var spread := spread_deg()
	if b["kind"] == "projectile":
		var chicken := ChickenScript.new()
		main.level.add_child(chicken)
		chicken.launch(muzzle, _spread_dir(fwd, spread), b, player)
	else:
		for i in int(b["pellets"]):
			_hitscan(origin, _spread_dir(fwd, spread), b, id, muzzle, i)
	player.add_recoil(RECOIL.get(id, 0.01) * lerpf(1.0, 0.6, aim_k))
	player.viewmodel.fire_kick(0.35 if id == "soaker" else 1.0)
	if b["kind"] != "stream" or shots_fired % 4 == 0:
		Art.muzzle_flash(player.viewmodel.muzzle, b["color"], 0.12 if id in ["bubble", "chicken"] else 0.08)
	if b["kind"] != "stream" or _sound_cd <= 0.0:
		_sound_cd = 0.12
		Sfx.play({"dart": "dart", "soaker": "soak", "paint": "paint", "bubble": "bubble", "chicken": "chicken"}[id],
			0.06, -3.0 if id == "paint" else 0.0)


func _spread_dir(fwd: Vector3, deg: float) -> Vector3:
	if deg <= 0.0:
		return fwd
	var r := deg_to_rad(deg) * sqrt(randf())
	var a := randf() * TAU
	var right := fwd.cross(Vector3.UP).normalized()
	if right.length() < 0.1:
		right = Vector3.RIGHT
	var up := right.cross(fwd).normalized()
	return (fwd + (right * cos(a) + up * sin(a)) * tan(r)).normalized()


func _hitscan(origin: Vector3, dir: Vector3, b: Dictionary, id: String, muzzle: Vector3, pellet: int) -> void:
	var to: Vector3 = origin + dir * float(b["range"])
	var q := PhysicsRayQueryParameters3D.create(origin, to, SHOT_MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	var normal := -dir
	var target: Node = null
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		if hit["collider"] is Node and (hit["collider"] as Node).is_in_group("parents"):
			target = hit["collider"]
	if target:
		var h: float = target.data["height"]
		var head: bool = end.y > target.global_position.y + h * GameState.HEADSHOT_HEIGHT
		var dmg: float = b["damage"] * (GameState.HEADSHOT_MULT if head else 1.0)
		target.shot(dmg, Vector3(dir.x, 0, dir.z).normalized(), b["knock"], head, id)
		hits += 1
		main.on_shot_hit(target, end, dmg, head, id)
	var level: Node = main.level
	var world_hit := target == null and not hit.is_empty()
	match id:
		"dart":
			Art.tracer(level, muzzle, end, "dart", b["color"], _arrive_dart.bind(end, dir, world_hit))
		"paint":
			var c: Color = PAINT_COLORS[randi() % PAINT_COLORS.size()]
			Art.tracer(level, muzzle, end, "paint", c, _arrive_paint.bind(end, normal, c, world_hit))
		"bubble":
			if pellet < 4:
				Art.tracer(level, muzzle, end, "bubble", b["color"], _arrive_bubble.bind(end))
		"soaker":
			if world_hit and shots_fired % 3 == 0:
				Art.impact_puff(level, end, Color(0.45, 0.75, 1.0), 4)


func _arrive_dart(at: Vector3, dir: Vector3, world_hit: bool) -> void:
	if main.level == null:
		return
	if world_hit:
		Art.stuck_dart(main.level, at, dir)
	else:
		Art.impact_puff(main.level, at, Color(1.0, 0.6, 0.2), 6)


func _arrive_paint(at: Vector3, normal: Vector3, c: Color, world_hit: bool) -> void:
	if main.level == null:
		return
	if world_hit:
		Art.splat(main.level, at, normal, c)
	Art.impact_puff(main.level, at, c, 8)


func _arrive_bubble(at: Vector3) -> void:
	if main.level == null:
		return
	Art.impact_puff(main.level, at, Color(0.75, 0.95, 1.0), 6)
