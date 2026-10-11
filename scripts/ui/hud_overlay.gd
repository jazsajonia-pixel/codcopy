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
var _spread_px := 0.0
var dmg_numbers: Array = []   ## {victim, pos: Vector3, amount, head, armor, t}
const DMG_NUMBER_TIME := 0.9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func on_hit(headshot: bool, killed: bool) -> void:
	hit_t = 0.22 if not killed else 0.4
	hit_head = headshot
	hit_kill = killed
	AudioManager.play_2d("res://assets/audio/sfx/hitmarker.ogg", -9.0 if not headshot else -5.0, 1.4 if headshot else 1.2)


## Floating damage numbers (setting). Rapid hits on the same target add up into one number.
func on_damage_dealt(victim: Actor, amount: float, headshot: bool, armor_hit: bool) -> void:
	if not SaveManager.get_setting("controls", "damage_numbers", true) or victim == null:
		return
	for d in dmg_numbers:
		if d.victim == victim and d.t > DMG_NUMBER_TIME - 0.45:
			d.amount += amount
			d.head = d.head or headshot
			d.armor = armor_hit
			d.t = DMG_NUMBER_TIME
			d.pos = victim.global_position + Vector3(0, 2.1, 0)
			return
	dmg_numbers.append({"victim": victim, "pos": victim.global_position + Vector3(0, 2.1, 0), "amount": amount,
		"head": headshot, "armor": armor_hit, "t": DMG_NUMBER_TIME, "x": randf_range(-18, 18)})
	if dmg_numbers.size() > 8:
		dmg_numbers.pop_front()


func on_damaged(from_pos: Vector3) -> void:
	damage_dirs.append({"pos": from_pos, "t": 1.2})
	if damage_dirs.size() > 6:
		damage_dirs.pop_front()


func _process(delta: float) -> void:
	hit_t = maxf(hit_t - delta, 0.0)
	for d in damage_dirs:
		d.t -= delta
	damage_dirs = damage_dirs.filter(func(d): return d.t > 0.0)
	for d in dmg_numbers:
		d.t -= delta
	dmg_numbers = dmg_numbers.filter(func(d): return d.t > 0.0)
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
	_draw_damage_numbers()
	var w := player.inv.active()
	var scoped := w != null and bool(w.stats.scope_overlay) and player.ads_blend > 0.85
	player.scope_hide = scoped
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
	elif player.alive and w and player.parachute_state != 1 and not player.downed:
		# Exact cone of the next shot projected to pixels (vertical FOV), smoothed slightly so it
		# animates; it expands with every shot (bloom) and recovers as the weapon settles.
		var spread := player.current_spread()
		var want_px := tan(deg_to_rad(spread)) / tan(deg_to_rad(player.camera.fov * 0.5)) * sz.y * 0.5
		_spread_px = lerpf(_spread_px, want_px, clampf(get_process_delta_time() * 22.0, 0, 1)) if _spread_px > 0.0 else want_px
		var px := maxf(_spread_px, 3.0)
		var col := Bot._enemy_color() if player.on_target else Color(1, 1, 1, 0.9)
		var hip_a := clampf(1.0 - player.ads_blend * 1.6, 0.0, 1.0)
		if hip_a > 0.02:
			var shadow := Color(0, 0, 0, 0.5 * hip_a)
			var cc := Color(col, col.a * hip_a)
			if int(w.stats.pellets) > 1:
				# Shotguns: a circle showing where the pellets land.
				draw_arc(c, px, 0, TAU, 48, shadow, 3.5, true)
				draw_arc(c, px, 0, TAU, 48, cc, 1.6, true)
				draw_circle(c, 1.8, cc)
			else:
				var L := 9.0
				for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_line(c + d * px, c + d * (px + L), shadow, 4.0)
					draw_line(c + d * px, c + d * (px + L), cc, 2.0)
				draw_circle(c, 1.4, cc)
		if player.ads_blend > 0.5:
			var al := clampf((player.ads_blend - 0.5) * 2.0, 0, 1)
			var optic: String = w.stats.optic
			if optic == "red_dot":
				draw_circle(c, 3.2, Color(0, 0, 0, 0.35 * al))
				draw_circle(c, 2.4, Color(1, 0.12, 0.12, al))
			elif optic == "holo":
				draw_arc(c, 11, 0, TAU, 40, Color(0.3, 1, 0.45, 0.9 * al), 1.6, true)
				draw_circle(c, 1.6, Color(0.3, 1, 0.45, al))
				for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
					draw_line(c + d * 14, c + d * 19, Color(0.3, 1, 0.45, 0.9 * al), 1.6)
			elif optic in ["4x", "8x"]:
				draw_line(c - Vector2(30, 0), c + Vector2(30, 0), Color(0, 0, 0, al), 1.5)
				draw_line(c, c + Vector2(0, 30), Color(0, 0, 0, al), 1.5)
				draw_circle(c, 2.0, Color(1, 0.2, 0.1, al))
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


func _draw_damage_numbers() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for d in dmg_numbers:
		var k: float = 1.0 - d.t / DMG_NUMBER_TIME
		var wp: Vector3 = d.pos + Vector3(0, k * 0.7, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp) + Vector2(d.x, 0)
		var col := Color(1, 0.86, 0.25) if d.head else (Color(0.5, 0.75, 1.0) if d.armor else Color(1, 1, 1))
		col.a = clampf(d.t / 0.3, 0.0, 1.0)
		var fs := 26 if d.head else 22
		var txt := str(roundi(d.amount))
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, sp - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, col.a * 0.8))
		draw_string(_font, sp - Vector2(tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
