class_name WeaponBar
extends Control
## CODM-style weapon switcher at the bottom of the HUD.
## Battle Royale: every slot is visible (weapon 1, weapon 2, fists) - tap / press 1, 2, 3 to equip.
## Multiplayer: one gun + melee (tap a card or press Q to swap between them; V is quick melee).

const CARD := Vector2(196, 70)
const SMALL := Vector2(70, 70)
const GAP := 8.0

var player: Player
var br_mode := false
var touch := false
var fade := 1.0
var _font: Font
var _rects: Array = []        ## [{rect, id}] from the last layout


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(_d: float) -> void:
	if player == null:
		return
	var ads := player.ads_blend
	fade = lerpf(fade, 0.35 if ads > 0.5 else 1.0, clampf(_d * 10.0, 0, 1))
	touch = player.touch_mode
	visible = player.alive and player.vehicle == null and player.parachute_state == 0 and player.allow_input
	queue_redraw()


func _layout() -> Array:
	var s := UITheme.safe_rect(get_viewport())
	var sc := float(SaveManager.get_setting("accessibility", "hud_scale", 1.0)) if touch else 0.9
	var card := CARD * sc
	var small := SMALL * sc
	var items: Array = []
	if br_mode:
		items = [["slot0", card], ["slot1", card], ["fists", small]]
	else:
		items = [["weapon", card], ["knife", small]]
	var total := 0.0
	for it in items:
		total += it[1].x
	total += GAP * (items.size() - 1)
	var x := s.position.x + s.size.x * 0.5 - total * 0.5
	var y := s.end.y - card.y - 10.0
	var out: Array = []
	for it in items:
		var sz: Vector2 = it[1]
		out.append({"id": it[0], "rect": Rect2(Vector2(x, y + card.y - sz.y), sz)})
		x += sz.x + GAP
	_rects = out
	return out


## Touch: returns true if the finger landed on a card (and performs its action).
func tap(p: Vector2) -> bool:
	if not visible or player == null:
		return false
	for r in _layout():
		if (r.rect as Rect2).grow(4).has_point(p):
			_activate(r.id)
			return true
	return false


func _activate(id: String) -> void:
	var inp := player.input
	match id:
		"slot0": inp.select_slot = 0
		"slot1": inp.select_slot = 1
		"fists": inp.select_slot = 2
		"weapon":
			if player.inv.holstered:
				inp.select_slot = 0
			else:
				inp.inspect = true   # tap the active gun card to inspect it
		"knife":
			if player.inv.holstered:
				inp.melee = true
			else:
				inp.select_slot = 2


func _draw() -> void:
	if player == null:
		return
	for r in _layout():
		_card(r.rect, r.id)


func _card(rc: Rect2, id: String) -> void:
	var inv := player.inv
	var w: WeaponInstance = null
	var active := false
	var hint := ""
	match id:
		"slot0", "slot1":
			var i := 0 if id == "slot0" else 1
			w = inv.weapons[i]
			active = not inv.holstered and inv.current == i and w != null
			hint = str(i + 1)
		"fists":
			active = inv.holstered or not inv.has_any_weapon()
			hint = "3"
		"weapon":
			w = inv.weapons[inv.current] if inv.weapons[inv.current] != null else inv.weapons[0]
			active = w != null and not inv.holstered
			hint = "1"
		"knife":
			active = inv.holstered
			hint = "Q"
	var a := fade
	var bg := Color(0.05, 0.06, 0.07, 0.62 * a) if not active else Color(0.12, 0.13, 0.1, 0.78 * a)
	draw_rect(rc, bg)
	draw_rect(rc, Color(UITheme.ACCENT, 0.95 * a) if active else Color(1, 1, 1, 0.22 * a), false, 2.0 if active else 1.0)
	if active:
		draw_rect(Rect2(rc.position.x, rc.end.y - 3, rc.size.x, 3), Color(UITheme.ACCENT, a))
	var fs := int(13 * rc.size.y / 70.0)
	if id in ["fists", "knife"]:
		_knife_glyph(rc, a * (1.0 if active or id == "knife" else 0.75))
		var mname: String = "FISTS" if inv.melee == "" else str(GameDB.MELEE.get(inv.melee, GameDB.MELEE.knife).get("short", "KNIFE"))
		_text(Vector2(rc.position.x + rc.size.x * 0.5, rc.end.y - 8), mname, fs - 1, Color(1, 1, 1, 0.8 * a), true)
	elif w == null:
		_text(rc.get_center() + Vector2(0, fs * 0.4), "EMPTY", fs + 2, Color(1, 1, 1, 0.35 * a), true)
	else:
		var tex := WeaponIcons.get_icon(w.id())
		if tex:
			var ir := Rect2(rc.position + Vector2(10, 16), Vector2(rc.size.x - 20, rc.size.y - 34))
			var k := minf(ir.size.x / tex.get_width(), ir.size.y / tex.get_height())
			var isz := Vector2(tex.get_width(), tex.get_height()) * k
			draw_texture_rect(tex, Rect2(ir.get_center() - isz * 0.5, isz), false, Color(1, 1, 1, (0.95 if active else 0.6) * a))
		_text(rc.position + Vector2(8, fs + 3), w.data.display_name.to_upper(), fs, Color(1, 1, 1, (0.95 if active else 0.65) * a), false)
		var ammo := "%d | %d" % [w.mag, w.get_reserve()]
		var col := Color(1, 1, 1, 0.9 * a)
		if w.mag == 0:
			col = Color(1, 0.3, 0.25, a)
		elif w.mag <= w.mag_size() / 4:
			col = Color(1, 0.75, 0.3, a)
		_text_right(Vector2(rc.end.x - 8, rc.end.y - 7), ammo, fs + 2, col)
		if w.reloading:
			draw_rect(Rect2(rc.position.x, rc.end.y - 3, rc.size.x * w.reload_progress(), 3), Color(1, 1, 1, 0.9 * a))
	if not touch and hint != "":
		var hp := rc.position + Vector2(rc.size.x - 14, 15)
		draw_rect(Rect2(hp - Vector2(7, 11), Vector2(16, 15)), Color(0, 0, 0, 0.5 * a))
		_text(hp + Vector2(1, 0), hint, 11, Color(1, 1, 1, 0.8 * a), true)


func _knife_glyph(rc: Rect2, a: float) -> void:
	var c := rc.get_center() + Vector2(0, -6)
	var s := rc.size.y / 70.0
	var blade := PackedVector2Array([c + Vector2(-18, 6) * s, c + Vector2(16, -10) * s, c + Vector2(20, -12) * s, c + Vector2(-12, 10) * s])
	draw_colored_polygon(blade, Color(0.92, 0.94, 0.96, a))
	draw_line(c + Vector2(-18, 6) * s, c + Vector2(-26, 12) * s, Color(0.35, 0.25, 0.18, a), 6.0 * s)


func _text(center: Vector2, t: String, size: int, col: Color, centered: bool) -> void:
	var x := center.x
	if centered:
		x -= _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(_font, Vector2(x, center.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_right(right: Vector2, t: String, size: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(right.x - w, right.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
