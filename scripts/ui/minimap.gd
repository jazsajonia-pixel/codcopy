class_name Minimap
extends Control
## Player-centred rotating radar. Shows teammates, enemies that fired unsuppressed, POIs, loot crates
## and (in Battle Royale) the current and next safe zone. `full_map` draws the whole map north-up.

var match_node: MatchBase
var player: Player
var radius_m := 45.0
var full_map := false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = ThemeDB.fallback_font


func _process(_d: float) -> void:
	queue_redraw()


func _w2m(p: Vector3) -> Vector2:
	var c := size * 0.5
	var R := minf(size.x, size.y) * 0.5
	if full_map:
		var bnd: Rect2 = match_node.map.bounds
		var k := (R * 2.0) / maxf(bnd.size.x, bnd.size.y)
		return c + Vector2(p.x - bnd.get_center().x, p.z - bnd.get_center().y) * k
	var rel := Vector2(p.x - player.global_position.x, p.z - player.global_position.z)
	rel = rel.rotated(player.rotation.y)
	return c + rel * (R / radius_m)


func _scale() -> float:
	var R := minf(size.x, size.y) * 0.5
	if full_map:
		var bnd: Rect2 = match_node.map.bounds
		return (R * 2.0) / maxf(bnd.size.x, bnd.size.y)
	return R / radius_m


func _draw() -> void:
	if player == null or match_node == null or match_node.map == null:
		return
	var c := size * 0.5
	var R := minf(size.x, size.y) * 0.5
	if full_map:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.16, 0.2, 0.92))
		draw_circle(c, R * 0.84, Color(0.32, 0.42, 0.25, 0.95))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.05, 0.62))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 2.0)
	var k := _scale()
	# Map bounds outline
	var bnd: Rect2 = match_node.map.bounds
	var corners := [Vector3(bnd.position.x, 0, bnd.position.y), Vector3(bnd.end.x, 0, bnd.position.y), Vector3(bnd.end.x, 0, bnd.end.y), Vector3(bnd.position.x, 0, bnd.end.y)]
	for i in 4:
		var a := _w2m(corners[i])
		var b2 := _w2m(corners[(i + 1) % 4])
		draw_line(a, b2, Color(1, 1, 1, 0.25), 2.0)
	# POIs
	for poi in match_node.map.pois:
		var mp := _w2m(poi.pos)
		if full_map or (absf(mp.x - c.x) < R - 8 and absf(mp.y - c.y) < R - 8):
			draw_circle(mp, 3.0, Color(1, 1, 1, 0.6))
			if full_map:
				_text(mp + Vector2(0, -8), poi.name, 14, Color(1, 1, 1, 0.9))
	# Zone (BR)
	if match_node.has_method("zone_info"):
		var z: Dictionary = match_node.zone_info()
		if not z.is_empty():
			draw_arc(_w2m(z.center), z.radius * k, 0, TAU, 96, Color(1, 1, 1, 0.85), 2.0, true)
			if z.has("next_center"):
				draw_arc(_w2m(z.next_center), z.next_radius * k, 0, TAU, 96, Color(0.4, 0.75, 1.0, 0.85), 1.5, true)
		if match_node.has_method("plane_info"):
			var pl: Dictionary = match_node.plane_info()
			if not pl.is_empty():
				draw_line(_w2m(pl.from), _w2m(pl.to), Color(1, 0.85, 0.3, 0.7), 2.0)
				draw_circle(_w2m(pl.pos), 5.0, UITheme.ACCENT)
	# Actors
	for a in match_node.actors:
		if a == player or not is_instance_valid(a) or not a.alive:
			continue
		var mp := _w2m(a.global_position)
		if not full_map and (absf(mp.x - c.x) > R - 4 or absf(mp.y - c.y) > R - 4):
			continue
		if not player.is_enemy(a):
			_arrow(mp, a.rotation.y - (player.rotation.y if not full_map else 0.0), UITheme.FRIENDLY)
		elif match_node.radar_pings.has(a):
			draw_circle(mp, 5.0, Bot._enemy_color())
	# Player
	var pp := _w2m(player.global_position)
	_arrow(pp if full_map else c, player.rotation.y if full_map else 0.0, UITheme.ACCENT, 9.0)
	if not full_map:
		_north(c, R)


func _north(c: Vector2, R: float) -> void:
	var dir := Vector2(0, -1).rotated(player.rotation.y)
	_text(c + dir * (R - 12), "N", 14, Color(1, 1, 1, 0.75))


func _arrow(p: Vector2, yaw: float, col: Color, s := 6.0) -> void:
	var f := Vector2(0, -1).rotated(-yaw)
	var r := Vector2(f.y, -f.x)
	draw_colored_polygon(PackedVector2Array([p + f * s * 1.4, p - f * s * 0.7 + r * s * 0.8, p - f * s * 0.3, p - f * s * 0.7 - r * s * 0.8]), col)


func _text(center: Vector2, t: String, sz: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, sz).x
	draw_string(_font, center + Vector2(-w * 0.5, sz * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
