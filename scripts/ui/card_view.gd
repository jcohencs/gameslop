extends Control
## Draws a trading card: rarity frame, procedural "art", name, rarity and price.
## Holo and Legendary cards get an animated shimmer.

var card: Dictionary = {}
var show_price := true
var _t := 0.0


func _init(c: Dictionary = {}, min_size := Vector2(150, 210)) -> void:
	card = c
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()


func _process(delta: float) -> void:
	if not card.is_empty() and card["rarity"] >= 3 and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	if card.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var col := GameState.rarity_color(card)
	var s := size.x / 150.0
	var font := ThemeDB.fallback_font
	# Frame.
	draw_style_box(UI.box(col.darkened(0.35), int(10 * s), int(3 * s), col, 0), r)
	var inner := r.grow(-7 * s)
	draw_style_box(UI.box(Color(0.96, 0.93, 0.85), int(6 * s)), inner)
	# Name banner.
	var banner := Rect2(inner.position + Vector2(4, 4) * s, Vector2(inner.size.x - 8 * s, 22 * s))
	draw_style_box(UI.box(col.lightened(0.25), int(4 * s)), banner)
	draw_string(font, banner.position + Vector2(5 * s, 16 * s), card["name"], HORIZONTAL_ALIGNMENT_LEFT,
		banner.size.x - 10 * s, int(12 * s), Color(0.1, 0.08, 0.1))
	# Art window.
	var art := Rect2(banner.position + Vector2(0, 26 * s), Vector2(banner.size.x, inner.size.y * 0.5))
	_draw_art(art, col, s)
	# Rarity + value.
	var y := art.end.y + 18 * s
	draw_string(font, Vector2(art.position.x, y), GameState.rarity_name(card).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
		-1, int(12 * s), col.darkened(0.45))
	if show_price:
		draw_string(font, Vector2(art.position.x, y + 22 * s), "$%d" % GameState.card_sell_value(card), HORIZONTAL_ALIGNMENT_LEFT,
			-1, int(20 * s), Color(0.15, 0.4, 0.15))
	# Rarity gems.
	for i in card["rarity"] + 1:
		var c := Vector2(inner.end.x - (10 + i * 12) * s, inner.end.y - 12 * s)
		draw_colored_polygon(UI.star_points(c, 5 * s, 2.2 * s), col.darkened(0.15))


func _draw_art(art: Rect2, col: Color, s: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(card.get("art", hash(card["name"])))
	var hue := rng.randf()
	var bg_top := Color.from_hsv(hue, 0.5, 0.95)
	var bg_bot := Color.from_hsv(fposmod(hue + 0.15, 1.0), 0.7, 0.55)
	var pts := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
	draw_polygon(pts, PackedColorArray([bg_top, bg_top, bg_bot, bg_bot]))
	# Creature: a blob body, head, eyes and some flair.
	var center := art.get_center() + Vector2(0, art.size.y * 0.1)
	var body_col := Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.65, 0.9)
	var br := art.size.y * rng.randf_range(0.22, 0.3)
	draw_circle(center, br, body_col)
	var head := center + Vector2(rng.randf_range(-0.3, 0.3) * br, -br * 0.95)
	draw_circle(head, br * 0.62, body_col.lightened(0.1))
	for e in [-1, 1]:
		var ep: Vector2 = head + Vector2(e * br * 0.25, -br * 0.05)
		draw_circle(ep, br * 0.14, Color.WHITE)
		draw_circle(ep + Vector2(0, br * 0.03), br * 0.07, Color.BLACK)
	var flair := rng.randi() % 3
	if flair == 0:
		for e in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([head + Vector2(e * br * 0.35, -br * 0.4),
				head + Vector2(e * br * 0.7, -br * 1.1), head + Vector2(e * br * 0.1, -br * 0.55)]), body_col.darkened(0.3))
	elif flair == 1:
		draw_arc(center + Vector2(br * 1.1, 0), br * 0.5, -PI * 0.6, PI * 0.6, 12, body_col.darkened(0.2), 4 * s)
	else:
		draw_colored_polygon(UI.star_points(head + Vector2(0, -br * 0.85), br * 0.3, br * 0.13), Color(1, 0.9, 0.2))
	# Holo shimmer band.
	if card["rarity"] >= 3:
		var x := fposmod(_t * 0.6, 1.6) - 0.3
		var w := art.size.x * 0.25
		var px := art.position.x + x * art.size.x
		var band := PackedVector2Array([Vector2(px, art.position.y), Vector2(px + w, art.position.y),
			Vector2(px + w - art.size.y * 0.4, art.end.y), Vector2(px - art.size.y * 0.4, art.end.y)])
		var clipped := Geometry2D.intersect_polygons(band, pts)
		for poly in clipped:
			draw_colored_polygon(poly, Color(1, 1, 1, 0.35) if card["rarity"] == 3 else Color(1, 0.95, 0.6, 0.45))
	draw_rect(art, col.darkened(0.3), false, 2 * s)
