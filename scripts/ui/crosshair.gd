extends Control
## Dynamic crosshair: spreads while attacking/moving, flashes a hit marker, shows the
## heavy-attack charge ring, the extraction ring, and red arcs pointing at attackers.

var player: Node3D
var spread := 0.0
var hit_flash := 0.0
var hit_big := false
var extract := 0.0
var target_kind := ""            # "", "kid", "enemy"
var indicators: Array = []       # [{angle: float, t: float}]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func hit(big: bool) -> void:
	hit_flash = 0.18
	hit_big = big
	spread = maxf(spread, 10.0)


func damage_from(world_pos: Vector3) -> void:
	if player == null:
		return
	var to := world_pos - player.global_position
	var fwd := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var angle := atan2(to.dot(right), to.dot(fwd))  # 0 = ahead, +right
	indicators.append({"angle": angle, "t": 1.0})


func _process(delta: float) -> void:
	hit_flash -= delta
	spread = lerpf(spread, 0.0, minf(delta * 10.0, 1.0))
	for ind in indicators:
		ind["t"] -= delta * 0.8
	indicators = indicators.filter(func(i): return i["t"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.9)
	if target_kind == "kid":
		col = UI.ACCENT
	elif target_kind == "enemy":
		col = UI.BAD
	var gap := 6.0 + spread
	if player:
		gap += Vector3(player.velocity.x, 0, player.velocity.z).length() * 0.6
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * gap, c + d * (gap + 8.0), Color(0, 0, 0, 0.6), 4.0)
		draw_line(c + d * gap, c + d * (gap + 8.0), col, 2.0)
	draw_circle(c, 2.0, col)

	if hit_flash > 0.0:
		var a := hit_flash / 0.18
		var hc := Color(1, 0.85, 0.3, a) if hit_big else Color(1, 1, 1, a)
		var r := 10.0 + (1.0 - a) * 6.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d.normalized() * r, c + d.normalized() * (r + (12.0 if hit_big else 8.0)), hc, 3.0)

	if player and player.charge > 0.0:
		var f: float = player.charge_fraction()
		draw_arc(c, 26, -PI / 2, -PI / 2 + TAU * f, 48, Color(UI.ACCENT, 0.4 + 0.6 * f), 4.0)
		if f >= 1.0:
			draw_arc(c, 31, 0, TAU, 48, Color(1, 1, 1, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)), 2.0)

	if extract > 0.0:
		draw_arc(c, 44, 0, TAU, 64, Color(0, 0, 0, 0.45), 9.0)
		draw_arc(c, 44, -PI / 2, -PI / 2 + TAU * extract, 64, UI.GOOD, 7.0)

	for ind in indicators:
		var ang: float = ind["angle"] - PI / 2
		var a: float = ind["t"]
		draw_arc(c, 120, ang - 0.35, ang + 0.35, 24, Color(1, 0.15, 0.1, a * 0.85), 10.0)
