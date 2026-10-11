class_name MedalFeed
extends Control
## CODM-style kill feedback drawn procedurally above the crosshair:
##  - hex medals that pop in (DOUBLE KILL, HEADSHOT, LONGSHOT ...), up to 3 at once
##  - "+score" popups that stack and fade to the right of the crosshair
##  - an "ELIMINATED <name>" banner under the crosshair

const MEDAL_TIME := 2.0
const POP_TIME := 1.6
var medals: Array = []    ## {title, color, t}
var pops: Array = []      ## {text, t}
var banner := ""
var banner_t := 0.0
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font


func medal(title: String, color := UITheme.ACCENT) -> void:
	medals.append({"title": title, "color": color, "t": 0.0})
	while medals.size() > 3:
		medals.pop_front()


func popup(text: String) -> void:
	pops.append({"text": text, "t": 0.0})
	while pops.size() > 5:
		pops.pop_front()


func eliminated(victim: String) -> void:
	banner = victim
	banner_t = 0.0


func _process(delta: float) -> void:
	for m in medals:
		m.t += delta
	for p in pops:
		p.t += delta
	medals = medals.filter(func(m): return m.t < MEDAL_TIME)
	pops = pops.filter(func(p): return p.t < POP_TIME)
	banner_t += delta
	if not medals.is_empty() or not pops.is_empty() or banner_t < 2.2:
		queue_redraw()
	elif banner != "":
		banner = ""
		queue_redraw()


func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	var s := size
	var cx := s.x * 0.5
	var cy := s.y * 0.5
	# Medals row (above the crosshair)
	var n := medals.size()
	for i in n:
		var m: Dictionary = medals[i]
		var k := clampf(m.t / 0.18, 0.0, 1.0)
		var scale := lerpf(1.7, 1.0, 1.0 - pow(1.0 - k, 3.0))
		var fade := clampf((MEDAL_TIME - m.t) / 0.35, 0.0, 1.0)
		var c := Vector2(cx + (i - (n - 1) * 0.5) * 96.0, cy - 205.0)
		var r := 30.0 * scale
		var col: Color = m.color
		draw_colored_polygon(_hex(c, r + 5), Color(0, 0, 0, 0.55 * fade))
		draw_colored_polygon(_hex(c, r), Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.95 * fade))
		var outline := _hex(c, r)
		outline.append(outline[0])
		draw_polyline(outline, Color(col, fade), 3.0, true)
		draw_colored_polygon(_hex(c, r * 0.55), Color(col, 0.9 * fade))
		# Shine sweep on pop-in
		if m.t < 0.5:
			draw_circle(c, r * (0.6 + m.t), Color(1, 1, 1, 0.25 * (1.0 - m.t / 0.5)))
		var title: String = m.title
		var fs := 15
		var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, Vector2(c.x - w * 0.5, c.y + r + 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * fade))
		draw_string(font, Vector2(c.x - w * 0.5, c.y + r + 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, fade))
	# Score popups (right of the crosshair, newest at the bottom)
	for i in pops.size():
		var p: Dictionary = pops[i]
		var fade := clampf((POP_TIME - p.t) / 0.4, 0.0, 1.0)
		var slide := clampf(p.t / 0.12, 0.0, 1.0)
		var pos := Vector2(cx + 46 + (1.0 - slide) * 30.0, cy - 10 + (i - pops.size() + 1) * 22.0)
		var txt: String = p.text
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, 0.7 * fade))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UITheme.ACCENT, fade) if txt.begins_with("+") else Color(1, 1, 1, fade))
	# Elimination banner (below the crosshair)
	if banner != "" and banner_t < 2.2:
		var fade := clampf((2.2 - banner_t) / 0.4, 0.0, 1.0) * clampf(banner_t / 0.1, 0.0, 1.0)
		var t1 := "ELIMINATED"
		var w1 := font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var w2 := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var bw := maxf(w1, w2) + 60.0
		var by := cy + 90.0
		draw_rect(Rect2(cx - bw * 0.5, by, bw, 50), Color(0.05, 0.05, 0.06, 0.6 * fade))
		draw_rect(Rect2(cx - bw * 0.5, by, 4, 50), Color(UITheme.ENEMY, fade))
		draw_rect(Rect2(cx + bw * 0.5 - 4, by, 4, 50), Color(UITheme.ENEMY, fade))
		draw_string(font, Vector2(cx - w1 * 0.5, by + 17), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UITheme.ENEMY, fade))
		draw_string(font, Vector2(cx - w2 * 0.5, by + 42), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, fade))
