class_name LobbyBackdrop
extends Control
## Animated lobby background: dark slate gradient, diagonal light streaks, a slow-moving glow
## and a faint hex/grid pattern (drawn procedurally - no texture assets needed).

var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	# Vertical gradient
	var top := Color(0.07, 0.1, 0.14)
	var bot := Color(0.02, 0.03, 0.05)
	var cols := PackedColorArray([top, top, bot, bot])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), cols)
	# Warm glow behind the operator (centre)
	var c := Vector2(s.x * 0.5 + sin(t * 0.3) * 20.0, s.y * 0.55)
	for i in 6:
		draw_circle(c, s.y * (0.55 - i * 0.07), Color(0.98, 0.7, 0.2, 0.025))
	# Diagonal streaks
	for i in 7:
		var x := fmod(i * 260.0 + t * 18.0, s.x + 600.0) - 300.0
		var w := 30.0 + (i % 3) * 40.0
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - s.y * 0.45, s.y), Vector2(x - s.y * 0.45, s.y)]),
			PackedColorArray([Color(1, 1, 1, 0.025)]))
	# Grid
	var g := 48.0
	var gc := Color(0.4, 0.6, 0.8, 0.04)
	var x0 := fmod(t * 6.0, g)
	var gx := x0
	while gx < s.x:
		draw_line(Vector2(gx, s.y * 0.62), Vector2(gx + (gx - s.x * 0.5) * 0.6, s.y), gc, 1.0)
		gx += g
	for j in 6:
		var y := s.y * 0.62 + pow(j / 6.0, 1.6) * s.y * 0.38
		draw_line(Vector2(0, y), Vector2(s.x, y), gc, 1.0)
	# Bottom vignette
	draw_rect(Rect2(0, s.y - 120, s.x, 120), Color(0, 0, 0, 0.25))
