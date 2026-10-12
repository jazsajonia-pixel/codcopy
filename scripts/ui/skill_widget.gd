class_name SkillWidget
extends Control
## Operator skill HUD: full-screen colour pulse when a skill fires, "SKILL READY" toast and (keyboard /
## gamepad) a round skill icon with its charge ring. On touch the SKILL button draws its own ring.

var player: Player
var show_icon := true
var _font: Font
var _was_ready := false
var _ready_toast := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	if player == null or player.skill == null:
		visible = false
		return
	visible = true
	var r := player.skill.is_ready()
	if r and not _was_ready:
		_ready_toast = 1.8
		AudioManager.play_2d("res://assets/audio/sfx/skill_ready.ogg", -6.0)
	_was_ready = r
	_ready_toast = maxf(_ready_toast - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var sk := player.skill
	var col: Color = sk.data.color
	var vs := get_viewport_rect().size
	# Edge glow while the skill effect is strong (rewind / slash / jet ignition).
	if sk.screen_fx > 0.01:
		var a := sk.screen_fx * 0.5
		var band := vs.y * 0.16
		for i in 6:
			var k := float(i) / 6.0
			var c := Color(col, a * (1.0 - k) * 0.35)
			var o := band * k
			draw_rect(Rect2(0, o, vs.x, band / 6.0), c)
			draw_rect(Rect2(0, vs.y - o - band / 6.0, vs.x, band / 6.0), c)
			draw_rect(Rect2(o, 0, band / 6.0, vs.y), c)
			draw_rect(Rect2(vs.x - o - band / 6.0, 0, band / 6.0, vs.y), c)
		if sk.id == "rewind":
			draw_rect(Rect2(Vector2.ZERO, vs), Color(col, sk.screen_fx * 0.07))
	if sk.active:
		_ready_toast = 0.0
	if _ready_toast > 0.0:
		var t := "%s READY" % String(sk.data.name).to_upper()
		var fs := 22
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(vs.x * 0.5 - w * 0.5, vs.y * 0.4)
		var al := clampf(_ready_toast, 0.0, 1.0)
		draw_rect(Rect2(p - Vector2(14, fs + 6), Vector2(w + 28, fs + 18)), Color(0, 0, 0, 0.45 * al))
		draw_string(_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, al))
	if show_icon:
		var s := UITheme.safe_rect(get_viewport())
		var c := s.position + Vector2(s.size.x - 70, s.size.y - 190)
		draw_icon(self, _font, c, 34.0, sk, "K")


## Shared round skill icon (also used by the touch SKILL button).
static func draw_icon(ci: CanvasItem, font: Font, c: Vector2, r: float, sk: OperatorSkill, key: String, op: float = 1.0) -> void:
	var col: Color = sk.data.color
	var ready := sk.is_ready()
	ci.draw_circle(c, r, Color(col, 0.55 * op) if ready else Color(0, 0, 0, 0.45 * op))
	ci.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.25 * op), 3.0, true)
	if sk.active:
		var left := 1.0 - sk.active_t / maxf(sk.duration(), 0.01)
		ci.draw_arc(c, r + 1, -PI * 0.5, -PI * 0.5 + TAU * left, 40, Color(1, 1, 1, op), 4.0, true)
	else:
		ci.draw_arc(c, r + 1, -PI * 0.5, -PI * 0.5 + TAU * sk.charge, 40, Color(col, op), 4.0, true)
	if ready:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		ci.draw_arc(c, r + 6 + pulse * 3, 0, TAU, 40, Color(col, 0.6 * op * (1.0 - pulse * 0.5)), 2.0, true)
	var label: String = sk.data.short
	var fs := clampi(int(r * 0.42), 11, 22)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, c + Vector2(-w * 0.5, fs * 0.2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, op))
	var sub := key if ready else "%d%%" % int(sk.charge * 100.0)
	if sk.active:
		sub = "ACTIVE"
	var fs2 := clampi(int(r * 0.3), 9, 14)
	var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	ci.draw_string(font, c + Vector2(-w2 * 0.5, fs * 0.2 + fs2 + 2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, 0.8 * op))
