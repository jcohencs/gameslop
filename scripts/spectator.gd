extends Node3D
## A kid in the bleachers (Wave Mode). Pure decor: no collision, not in the "kids" group, so
## nothing can ever hit them (Constitution IX / XIII). Cheers, chats and bounces.

var shirt := Color.WHITE
var _rig: Rig
var _t := 0.0
var _next := 0.0


func _ready() -> void:
	_rig = Rig.new()
	add_child(_rig)
	var opts := {"kid": true, "brows": Color(0.2, 0.1, 0.05)}
	if randf() < 0.7:
		opts["hair"] = Color.from_hsv(randf_range(0.03, 0.12), 0.6, randf_range(0.15, 0.9))
		opts["hair_style"] = ["bowl", "spiky", "bun", "ponytail"][randi() % 4]
	else:
		opts["cap"] = Color.from_hsv(randf(), 0.7, 0.8)
	_rig.build(randf_range(1.05, 1.3), shirt, Color.from_hsv(randf(), 0.4, 0.5), Color(0.95, 0.78, 0.62).darkened(randf() * 0.45), opts)
	_rig.set_mood("neutral", true)
	_next = randf_range(0.2, 2.0)


func _process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(1.5, 4.0)
		var r := randf()
		if r < 0.55:
			_rig.play("cheer", _next)
		elif r < 0.8:
			_rig.play("talk", _next)
		else:
			_rig.clear_action()
	_rig.tick(delta, 0.0, true)
