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
	var optic_kind: String = str(w.stats.optic) if w != null else ""
	var magnified := w != null and (bool(w.stats.scope_overlay) or optic_kind in ["3x", "4x", "8x"])
	# Scope-in: the screen darkens as the eye reaches the eyepiece, then the lens opens. The 3D
	# scope model is hidden once the overlay is up so it can never block the view.
	var scope_k := clampf((player.ads_blend - 0.55) / 0.3, 0.0, 1.0) if magnified and player.alive else 0.0
	var scoped := scope_k >= 1.0
	player.scope_hide = scope_k > 0.6
	if scope_k > 0.0 and not scoped:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, sin(scope_k * PI) * 0.85))
	if scoped:
		_draw_scope(c, sz, optic_kind if optic_kind in ["3x", "4x"] else "8x", w)
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


## Magnified optic picture. The world is rendered through a clear lens (the camera FOV does the
## zoom); everything outside is the scope housing. 3x/4x use a wide eyepiece with a soft edge
## and an ACOG-style chevron, 8x/sniper scopes get the classic black ring with a mil-dot cross.
func _draw_scope(c: Vector2, sz: Vector2, kind: String, w) -> void:
	var big := kind == "8x"
	var r := minf(sz.x, sz.y) * (0.47 if big else 0.5)
	# Lens bob: the eyepiece trails the camera a few pixels when moving/turning.
	c += player.scope_bob
	var housing := Color(0.02, 0.02, 0.02, 1.0 if big else 0.96)
	_ring_fill(c, r, sz, housing)
	# Soft inner vignette (glass edge darkening) and a faint lens tint.
	for i in 10:
		var k := float(i) / 10.0
		draw_arc(c, r - k * r * 0.16, 0, TAU, 96, Color(0, 0, 0, 0.16 * (1.0 - k)), r * 0.018 + 2.0, true)
	draw_circle(c, r, Color(0.35, 0.55, 0.65, 0.05))
	draw_arc(c, r, 0, TAU, 128, Color(0.12, 0.12, 0.12), 7.0, true)
	draw_arc(c, r - 4.0, 0, TAU, 128, Color(0.4, 0.42, 0.45, 0.35), 1.5, true)
	var ink := Color(0.03, 0.03, 0.03, 0.95)
	if big:
		# Thick outer posts + thin center cross + mil dots.
		var gap := r * 0.12
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]:
			draw_line(c + d * r * 0.55, c + d * r, ink, 7.0)
		draw_line(c + Vector2(0, -1) * r * 0.55, c + Vector2(0, -1) * r, ink, 3.0)
		draw_line(c - Vector2(r * 0.55, 0), c + Vector2(r * 0.55, 0), ink, 1.4)
		draw_line(c - Vector2(0, r * 0.55), c + Vector2(0, r * 0.55), ink, 1.4)
		for i in range(1, 5):
			var o := gap * i
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_circle(c + d * o, 2.4, ink)
		draw_circle(c, 2.2, Color(1, 0.12, 0.08))
	else:
		# ACOG chevron + bullet-drop ticks, red illuminated tip.
		var s := r * 0.05
		draw_line(c + Vector2(-s, s * 1.3), c, ink, 2.4)
		draw_line(c + Vector2(s, s * 1.3), c, ink, 2.4)
		draw_line(c + Vector2(-s * 0.8, s * 1.1), c + Vector2(0, -1), Color(1, 0.2, 0.1, 0.95), 1.6)
		draw_line(c + Vector2(s * 0.8, s * 1.1), c + Vector2(0, -1), Color(1, 0.2, 0.1, 0.95), 1.6)
		draw_line(c + Vector2(0, s * 1.4), c + Vector2(0, r * 0.5), ink, 1.4)
		for i in range(1, 5):
			var y := c.y + s * 1.4 + r * 0.09 * i
			var hw := r * (0.05 - i * 0.008)
			draw_line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), ink, 1.4)
		draw_line(c + Vector2(-r, 0), c + Vector2(-r * 0.62, 0), ink, 2.0)
		draw_line(c + Vector2(r * 0.62, 0), c + Vector2(r, 0), ink, 2.0)


## Fills everything outside a circle of radius r (centered at c) with col.
func _ring_fill(c: Vector2, r: float, sz: Vector2, col: Color) -> void:
	draw_rect(Rect2(0, 0, maxf(c.x - r, 0), sz.y), col)
	draw_rect(Rect2(c.x + r, 0, maxf(sz.x - c.x - r, 0), sz.y), col)
	draw_rect(Rect2(c.x - r, 0, r * 2, maxf(c.y - r, 0)), col)
	draw_rect(Rect2(c.x - r, c.y + r, r * 2, maxf(sz.y - c.y - r, 0)), col)
	# Four corner pieces between the square and the circle, as triangle fans (always convex).
	var n := 24
	for q in 4:
		var a0 := q * PI * 0.5
		var corner := c + Vector2(signf(cos(a0 + PI * 0.25)), signf(sin(a0 + PI * 0.25))) * r
		for i in n:
			var a := a0 + PI * 0.5 * i / n
			var b := a0 + PI * 0.5 * (i + 1) / n
			draw_colored_polygon(PackedVector2Array([corner, c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(b), sin(b)) * r]), col)


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
