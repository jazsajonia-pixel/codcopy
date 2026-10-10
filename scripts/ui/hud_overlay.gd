class_name HudOverlay
extends Control
## Immediate-mode HUD drawing: dynamic crosshair, hit markers, damage direction indicators,
## sniper scope, flash and low-health vignette.

var player: Player
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var damage_dirs: Array = []   ## {pos: Vector3, t: float}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func on_hit(headshot: bool, killed: bool) -> void:
	hit_t = 0.22 if not killed else 0.4
	hit_head = headshot
	hit_kill = killed
	AudioManager.play_2d("res://assets/audio/sfx/hitmarker.ogg", -9.0 if not headshot else -5.0, 1.4 if headshot else 1.2)


func on_damaged(from_pos: Vector3) -> void:
	damage_dirs.append({"pos": from_pos, "t": 1.2})
	if damage_dirs.size() > 6:
		damage_dirs.pop_front()


func _process(delta: float) -> void:
	hit_t = maxf(hit_t - delta, 0.0)
	for d in damage_dirs:
		d.t -= delta
	damage_dirs = damage_dirs.filter(func(d): return d.t > 0.0)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var sz := size
	var c := sz * 0.5
	# Low-health vignette
	if player.alive and player.health < 60.0:
		var a := (1.0 - player.health / 60.0) * 0.45
		for i in 6:
			var w := 40.0 + i * 22.0
			draw_rect(Rect2(0, 0, sz.x, w), Color(0.6, 0, 0, a / 6.0))
			draw_rect(Rect2(0, sz.y - w, sz.x, w), Color(0.6, 0, 0, a / 6.0))
			draw_rect(Rect2(0, 0, w, sz.y), Color(0.6, 0, 0, a / 6.0))
			draw_rect(Rect2(sz.x - w, 0, w, sz.y), Color(0.6, 0, 0, a / 6.0))
	var w := player.inv.active()
	var scoped := w != null and bool(w.stats.scope_overlay) and player.ads_blend > 0.85
	player.view_model.visible = player.alive and not scoped
	if scoped:
		var r := minf(sz.x, sz.y) * 0.46
		# Black outside the scope circle
		draw_rect(Rect2(0, 0, c.x - r, sz.y), Color.BLACK)
		draw_rect(Rect2(c.x + r, 0, sz.x - c.x - r, sz.y), Color.BLACK)
		var pts := PackedVector2Array()
		for i in 65:
			var ang := PI + PI * i / 64.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		pts.append(Vector2(c.x + r, 0))
		pts.append(Vector2(c.x - r, 0))
		draw_colored_polygon(pts, Color.BLACK)
		var pts2 := PackedVector2Array()
		for i in 65:
			var ang2 := PI * i / 64.0
			pts2.append(c + Vector2(cos(ang2), sin(ang2)) * r)
		pts2.append(Vector2(c.x - r, sz.y))
		pts2.append(Vector2(c.x + r, sz.y))
		draw_colored_polygon(pts2, Color.BLACK)
		draw_arc(c, r, 0, TAU, 96, Color(0, 0, 0), 6.0)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 1.5)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0, 0, 0, 0.9), 1.5)
		draw_circle(c, 2.0, Color(1, 0.1, 0.1))
	elif player.alive and w and player.parachute_state == 0:
		var spread := w.spread_deg(player.ads_blend > 0.6, Vector2(player.velocity.x, player.velocity.z).length() > 1.0, not player.is_on_floor())
		var px := tan(deg_to_rad(spread)) / tan(deg_to_rad(player.camera.fov * 0.5)) * sz.y * 0.5
		px = clampf(px, 4.0, 140.0) * (1.0 - player.ads_blend * 0.9)
		var col := Bot._enemy_color() if player.on_target else Color(1, 1, 1, 0.9)
		if player.ads_blend < 0.9:
			var L := 9.0
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * px, c + d * (px + L), Color(0, 0, 0, 0.5), 4.0)
				draw_line(c + d * px, c + d * (px + L), col, 2.0)
		if player.ads_blend > 0.5:
			var optic: String = w.stats.optic
			if optic == "red_dot":
				draw_circle(c, 2.5, Color(1, 0.15, 0.15, player.ads_blend))
			elif optic == "holo":
				draw_arc(c, 10, 0, TAU, 32, Color(0.3, 1, 0.45, player.ads_blend), 1.5, true)
				draw_circle(c, 1.5, Color(0.3, 1, 0.45, player.ads_blend))
			elif optic in ["4x", "8x"]:
				draw_line(c - Vector2(30, 0), c + Vector2(30, 0), Color(0, 0, 0, player.ads_blend), 1.5)
				draw_line(c, c + Vector2(0, 30), Color(0, 0, 0, player.ads_blend), 1.5)
				draw_circle(c, 2.0, Color(1, 0.2, 0.1, player.ads_blend))
			else:
				draw_circle(c, 1.5, Color(1, 1, 1, 0.8))
		else:
			draw_circle(c, 1.5, col)
	# Hit marker
	if hit_t > 0.0:
		var s := float(SaveManager.get_setting("accessibility", "hitmarker_scale", 1.0))
		var hc := Color(1, 0.2, 0.15) if hit_kill else (Color(1, 0.85, 0.2) if hit_head else Color(1, 1, 1))
		hc.a = clampf(hit_t / 0.15, 0, 1)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 7 * s, c + d * 16 * s, hc, 3.0)
	# Damage direction indicators
	for d in damage_dirs:
		var to: Vector3 = d.pos - player.global_position
		var dir := Vector2(to.x, to.z).rotated(player.rotation.y)
		dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
		var base := c + dir * 140.0
		var perp := Vector2(-dir.y, dir.x)
		var alpha := clampf(d.t, 0, 1) * 0.85
		draw_colored_polygon(PackedVector2Array([base + dir * 26, base - perp * 22, base + perp * 22]), Color(0.9, 0.1, 0.05, alpha))
	# Flash
	if player.flash_time > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, clampf(player.flash_time / 1.2, 0, 0.95)))
