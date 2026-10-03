extends Node
## Procedurally generated sound effects (no audio assets). Use Sfx.play("punch").

const RATE := 22050

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
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
