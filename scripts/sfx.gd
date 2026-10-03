extends Node
## Procedurally generated sound effects (no audio assets). Use Sfx.play("punch").

const RATE := 22050

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:  # rapid-fire blasters need more voices
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_streams["whoosh"] = _make(0.2, _whoosh)
	_streams["punch"] = _make(0.16, _punch)
	_streams["slash"] = _make(0.14, _slash)
	_streams["block"] = _make(0.18, _block)
	_streams["hurt"] = _make(0.22, _hurt)
	_streams["click"] = _make(0.035, _click)
	_streams["hover"] = _make(0.02, _hover)
	_streams["cash"] = _make(0.25, _cash)
	_streams["card"] = _make(0.35, _card)
	_streams["extract"] = _make(0.8, _extract)
	_streams["fail"] = _make(0.7, _fail)
	_streams["alert"] = _make(0.3, _alert)
	_streams["ko"] = _make(0.35, _ko)
	_streams["heavy"] = _make(0.25, _heavy)
	# Wave Mode (specs/004).
	_streams["dart"] = _make(0.12, _dart)
	_streams["soak"] = _make(0.14, _soak)
	_streams["paint"] = _make(0.09, _paint)
	_streams["bubble"] = _make(0.3, _bubble)
	_streams["chicken"] = _make(0.32, _chicken)
	_streams["boom"] = _make(0.45, _boom)
	_streams["reload"] = _make(0.3, _reload)
	_streams["empty"] = _make(0.05, _empty)
	_streams["horn"] = _make(0.9, _horn)
	_streams["pickup"] = _make(0.22, _pickup)
	_streams["throw"] = _make(0.18, _throw)
	_streams["splat"] = _make(0.16, _splat)
	_streams["megaphone"] = _make(0.7, _megaphone)
	_streams["bonk"] = _make(0.14, _bonk)


func play(id: String, pitch_jitter := 0.08, volume_db := 0.0) -> void:
	if not _streams.has(id):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Positional one-shot in the 3D world.
func play_at(id: String, pos: Vector3, parent: Node, volume_db := 0.0) -> void:
	if not _streams.has(id) or parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-0.08, 0.08)
	p.unit_size = 6.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _make(length: float, gen: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := {"lp": 0.0, "phase": 0.0, "phase2": 0.0}
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, t / length, state)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


# --- Generators: (t seconds, u 0..1 progress, state) -> sample --------------

func _tone(state: Dictionary, key: String, freq: float) -> float:
	state[key] += freq / RATE
	return sin(state[key] * TAU)

func _noise_lp(state: Dictionary, k: float) -> float:
	state["lp"] = lerpf(state["lp"], randf_range(-1, 1), k)
	return state["lp"]

func _whoosh(_t: float, u: float, s: Dictionary) -> float:
	var env := sin(u * PI)
	return _noise_lp(s, 0.08 + u * 0.25) * env * 1.6

func _punch(_t: float, u: float, s: Dictionary) -> float:
	var env := pow(1.0 - u, 3.0)
	return (_tone(s, "phase", lerpf(140.0, 45.0, u)) * 0.9 + _noise_lp(s, 0.5) * 0.6 * pow(1.0 - u, 8.0)) * env

func _heavy(_t: float, u: float, s: Dictionary) -> float:
	var env := pow(1.0 - u, 2.5)
	return (_tone(s, "phase", lerpf(110.0, 35.0, u)) + _noise_lp(s, 0.3) * 0.7 * pow(1.0 - u, 5.0)) * env

func _slash(_t: float, u: float, s: Dictionary) -> float:
	var env := pow(1.0 - u, 2.0)
	return (_noise_lp(s, 0.9) * 0.7 + _tone(s, "phase", 420.0 - 200.0 * u) * 0.4) * env

func _block(_t: float, u: float, s: Dictionary) -> float:
	var env := pow(1.0 - u, 3.0)
	return (_tone(s, "phase", 820.0) * 0.5 + _tone(s, "phase2", 1230.0) * 0.4 + _noise_lp(s, 0.7) * 0.3 * pow(1.0 - u, 10.0)) * env

func _hurt(_t: float, u: float, s: Dictionary) -> float:
	var env := pow(1.0 - u, 1.5)
	var sq := signf(_tone(s, "phase", lerpf(260.0, 110.0, u)))
	return (sq * 0.35 + _noise_lp(s, 0.4) * 0.3) * env

func _click(_t: float, u: float, s: Dictionary) -> float:
	return _tone(s, "phase", 1400.0) * pow(1.0 - u, 4.0) * 0.6

func _hover(_t: float, u: float, s: Dictionary) -> float:
	return _tone(s, "phase", 2200.0) * pow(1.0 - u, 4.0) * 0.25

func _cash(t: float, u: float, s: Dictionary) -> float:
	var f := 1320.0 if t < 0.09 else 1760.0
	return _tone(s, "phase", f) * pow(1.0 - fmod(u, 0.36) / 0.36, 2.0) * 0.5

func _card(t: float, u: float, s: Dictionary) -> float:
	var notes := [660.0, 880.0, 1320.0]
	var idx := mini(int(t / 0.1), 2)
	return _tone(s, "phase", notes[idx]) * (1.0 - u) * 0.45

func _extract(_t: float, u: float, s: Dictionary) -> float:
	return (_tone(s, "phase", lerpf(300.0, 1000.0, u)) * 0.4 + _tone(s, "phase2", lerpf(450.0, 1500.0, u)) * 0.2) * sin(u * PI)

func _fail(_t: float, u: float, s: Dictionary) -> float:
	return signf(_tone(s, "phase", lerpf(420.0, 120.0, u))) * 0.25 * (1.0 - u)

func _alert(t: float, u: float, s: Dictionary) -> float:
	var f := 880.0 if t < 0.15 else 1175.0
	return _tone(s, "phase", f) * 0.45 * (1.0 - fmod(u, 0.5) * 1.6)

func _ko(_t: float, u: float, s: Dictionary) -> float:
	return (_tone(s, "phase", lerpf(700.0, 160.0, sqrt(u))) * 0.5 + _noise_lp(s, 0.3) * 0.3 * pow(1.0 - u, 6.0)) * (1.0 - u)


# --- Wave Mode blasters ----------------------------------------------------------

func _dart(_t: float, u: float, s: Dictionary) -> float:
	# Spring "thwip" + a soft pop.
	return (_tone(s, "phase", lerpf(900.0, 300.0, u)) * 0.4 + _noise_lp(s, 0.6) * 0.5 * pow(1.0 - u, 10.0)) * pow(1.0 - u, 2.0)

func _soak(_t: float, u: float, s: Dictionary) -> float:
	return _noise_lp(s, 0.35) * 0.5 * sin(u * PI)

func _paint(_t: float, u: float, s: Dictionary) -> float:
	return (_noise_lp(s, 0.8) * 0.6 + _tone(s, "phase", 180.0) * 0.4) * pow(1.0 - u, 4.0)

func _bubble(t: float, u: float, s: Dictionary) -> float:
	# A cluster of rising "blorp"s.
	var k := fmod(t * 14.0, 1.0)
	return _tone(s, "phase", 300.0 + k * 700.0) * 0.4 * (1.0 - k) * (1.0 - u) + _noise_lp(s, 0.5) * 0.3 * pow(1.0 - u, 12.0)

func _chicken(_t: float, u: float, s: Dictionary) -> float:
	# Squeaky rubber chicken: a nasal square-ish wobble.
	var f := 700.0 + sin(u * 30.0) * 180.0 - u * 250.0
	return signf(_tone(s, "phase", f)) * 0.2 * sin(u * PI) + _tone(s, "phase2", f * 2.0) * 0.15 * sin(u * PI)

func _boom(_t: float, u: float, s: Dictionary) -> float:
	return (_noise_lp(s, 0.15 + 0.3 * (1.0 - u)) * 1.2 + _tone(s, "phase", lerpf(90.0, 30.0, u)) * 0.6) * pow(1.0 - u, 1.8)

func _reload(t: float, u: float, s: Dictionary) -> float:
	# Two clacks.
	var k := 1.0 - fmod(t, 0.15) / 0.15
	return (_noise_lp(s, 0.9) * 0.5 + _tone(s, "phase", 1600.0) * 0.2) * pow(k, 8.0) * (1.0 - u * 0.5)

func _empty(_t: float, u: float, s: Dictionary) -> float:
	return _tone(s, "phase", 2000.0) * pow(1.0 - u, 6.0) * 0.4

func _horn(t: float, u: float, s: Dictionary) -> float:
	# Gym buzzer.
	var f := 220.0 if t < 0.45 else 196.0
	return (signf(_tone(s, "phase", f)) * 0.22 + _tone(s, "phase2", f * 1.5) * 0.15) * minf(1.0, (1.0 - u) * 6.0)

func _pickup(t: float, u: float, s: Dictionary) -> float:
	var f := 880.0 if t < 0.08 else 1320.0
	return _tone(s, "phase", f) * 0.4 * (1.0 - u)

func _throw(_t: float, u: float, s: Dictionary) -> float:
	return _noise_lp(s, 0.15 + u * 0.4) * sin(u * PI) * 1.4

func _splat(_t: float, u: float, s: Dictionary) -> float:
	return (_noise_lp(s, 0.25) * 0.9 + _tone(s, "phase", lerpf(260.0, 80.0, u)) * 0.3) * pow(1.0 - u, 2.5)

func _megaphone(t: float, u: float, s: Dictionary) -> float:
	# Feedback screech into a blast.
	var f := 1400.0 + sin(t * 40.0) * 300.0
	return (signf(_tone(s, "phase", f)) * 0.18 + _noise_lp(s, 0.4) * 0.4 * u) * sin(u * PI)

func _bonk(_t: float, u: float, s: Dictionary) -> float:
	return (_tone(s, "phase", lerpf(520.0, 380.0, u)) * 0.6 + _tone(s, "phase2", 1040.0) * 0.2) * pow(1.0 - u, 3.0)
