extends Node
## Wave Mode director (specs/004): builds each wave from a budget, feeds adults in through the
## gym doors under a live cap, runs intermissions and clear rewards, and tracks the run.
## Tuning lives in GameState.WAVE_CONFIG / WAVE_ENEMIES (Constitution XI).

enum Phase { WARMUP, SPAWNING, INTERMISSION }

var main: Node
var wave := 0
var phase := Phase.WARMUP
var timer := 0.0
var queue: Array = []          # adult type ids still to spawn this wave
var alive: Array = []          # live adults of this run
var spawn_t := 0.0
var kos := 0
var boss: Node = null
var wave_total := 0
var cash_at_start := 0
var rng := RandomNumberGenerator.new()


func start() -> void:
	rng.randomize()
	wave = 0
	kos = 0
	alive.clear()
	queue.clear()
	boss = null
	cash_at_start = GameState.cash
	phase = Phase.WARMUP
	timer = GameState.WAVE_CONFIG["first_delay"]


static func cfg(key: String):
	return GameState.WAVE_CONFIG[key]


static func is_boss_wave(n: int) -> bool:
	return n > 0 and n % int(cfg("boss_every")) == 0


static func hp_mult(n: int) -> float:
	return 1.0 + float(cfg("hp_growth")) * (n - 1)


## The adult types for wave n: the boss first on boss waves, then budget-priced adds drawn
## from every type unlocked by wave n.
static func compose(n: int, r: RandomNumberGenerator) -> Array:
	var out := []
	var budget := float(GameState.wave_budget(n))
	if is_boss_wave(n):
		out.append(cfg("boss"))
		budget *= float(cfg("boss_add_frac"))
	var pool := []
	for t in GameState.WAVE_ENEMIES:
		if int(GameState.WAVE_ENEMIES[t]["from"]) <= n:
			pool.append(t)
	var left := int(budget)
	for guard in 200:
		var options := []
		for t in pool:
			if int(GameState.WAVE_ENEMIES[t]["cost"]) <= left:
				options.append(t)
		if options.is_empty():
			break
		var pick: String = options[r.randi() % options.size()]
		out.append(pick)
		left -= int(GameState.WAVE_ENEMIES[pick]["cost"])
	return out


func remaining() -> int:
	_prune()
	return queue.size() + alive.size()


func spawning() -> bool:
	return phase == Phase.SPAWNING


func cash_earned() -> int:
	return GameState.cash - cash_at_start


func intermission_left() -> float:
	return maxf(timer, 0.0) if phase != Phase.SPAWNING else 0.0


func _prune() -> void:
	alive = alive.filter(func(a): return is_instance_valid(a) and a.is_in_group("parents"))


func tick(delta: float) -> void:
	match phase:
		Phase.WARMUP, Phase.INTERMISSION:
			timer -= delta
			if timer <= 0.0:
				begin_wave()
		Phase.SPAWNING:
			_prune()
			spawn_t -= delta
			if not queue.is_empty() and spawn_t <= 0.0 and alive.size() < int(cfg("max_alive")):
				spawn_t = cfg("spawn_interval")
				var t: String = queue.pop_front()
				var p: Node = main.spawn_wave_adult(t, hp_mult(wave))
				if p:
					alive.append(p)
					if t == cfg("boss"):
						boss = p
				else:
					queue.push_front(t)
			if queue.is_empty() and alive.is_empty():
				_clear_wave()


func begin_wave() -> void:
	wave += 1
	queue = compose(wave, rng)
	wave_total = queue.size()
	spawn_t = 0.0
	phase = Phase.SPAWNING
	main.on_wave_started(wave, is_boss_wave(wave))


func _clear_wave() -> void:
	phase = Phase.INTERMISSION
	timer = cfg("intermission")
	var bonus := int(cfg("clear_bonus")) * wave
	GameState.cash += bonus
	GameState.health = minf(GameState.max_health(), GameState.health + float(cfg("clear_heal")))
	if main.player and main.player.gunplay:
		main.player.gunplay.refill_reserve(cfg("clear_ammo"))
	GameState.changed.emit()
	main.on_wave_cleared(wave, bonus)


func on_ko(p: Node) -> void:
	kos += 1
	alive.erase(p)
	if p == boss:
		boss = null
	var r := rng.randf()
	if r < float(cfg("drop_health")):
		main.spawn_pickup("health", p.global_position)
	elif r < float(cfg("drop_health")) + float(cfg("drop_ammo")):
		main.spawn_pickup("ammo", p.global_position)
