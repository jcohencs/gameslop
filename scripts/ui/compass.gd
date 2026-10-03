extends Control
## Horizontal compass strip. Shows headings plus markers for extracts (green) and
## parents who are hunting you (red).

const FOV_DEG := 110.0

var player: Node3D
var markers: Array = []  # [{pos: Vector3, color: Color, text: String}]


func _init() -> void:
	custom_minimum_size = Vector2(620, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _yaw_to_x(yaw_deg: float, heading: float) -> float:
	var d := wrapf(yaw_deg - heading, -180.0, 180.0)
	return size.x * 0.5 + d / (FOV_DEG * 0.5) * size.x * 0.5


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var font := ThemeDB.fallback_font
	draw_style_box(UI.box(Color(0.05, 0.05, 0.08, 0.55), 8), Rect2(Vector2.ZERO, Vector2(size.x, 30)))
	# Heading in degrees, 0 = -Z ("N"), clockwise.
	var fwd := -player.global_transform.basis.z
	var heading := rad_to_deg(atan2(fwd.x, -fwd.z))
	var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for deg in range(0, 360, 15):
		var x := _yaw_to_x(deg, heading)
		if x < 6 or x > size.x - 6:
			continue
		var fade := 1.0 - absf(x - size.x * 0.5) / (size.x * 0.5)
		if names.has(deg):
			var n: String = names[deg]
			var col := UI.ACCENT if deg == 0 else UI.TEXT
			draw_string(font, Vector2(x - 6 * n.length(), 21), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col, fade))
		else:
			draw_line(Vector2(x, 8), Vector2(x, 20), Color(1, 1, 1, 0.35 * fade), 1.5)
	draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, 30), Color(UI.ACCENT, 0.8), 2)

	for m in markers:
		var to: Vector3 = m["pos"] - player.global_position
		var yaw := rad_to_deg(atan2(to.x, -to.z))
		var x := clampf(_yaw_to_x(yaw, heading), 10, size.x - 10)
		var col: Color = m["color"]
		var diamond := PackedVector2Array([Vector2(x, 24), Vector2(x + 7, 31), Vector2(x, 38), Vector2(x - 7, 31)])
		draw_colored_polygon(diamond, col)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0, 0, 0, 0.6), 1.5)
		var txt: String = m.get("text", "")
		if txt != "":
			draw_string(font, Vector2(x - 20, 46 + 4), txt, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, col)
