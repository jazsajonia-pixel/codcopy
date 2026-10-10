extends Node
## "phone" suite: touch controls at real phone window sizes (stretch scaling active). Touches are
## injected in WINDOW pixels, the way Android delivers them, then converted by Godot's stretch transform.

var passed := 0
var failed := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += 1.0 / 60.0


## viewport (canvas) coords -> window pixels
func _win(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _touch(idx: int, vp: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _win(vp)
	e.pressed = down
	Input.parse_input_event(e)


func _drag(idx: int, from_vp: Vector2, to_vp: Vector2, steps: int) -> void:
	var last := _win(from_vp)
	for i in range(1, steps + 1):
		var e := InputEventScreenDrag.new()
		e.index = idx
		e.position = _win(from_vp.lerp(to_vp, float(i) / steps))
		e.relative = e.position - last
		last = e.position
		Input.parse_input_event(e)
		await get_tree().physics_frame


func _run() -> void:
	MatchConfig.autoplay_player = false
	SaveManager.set_setting("controls", "scheme", "auto")
	var win := DisplayServer.window_get_size()
	var vp := get_viewport().get_visible_rect().size
	print("    window %s  viewport %s  safe %s" % [win, vp, UITheme.safe_rect(get_viewport())])
	MatchConfig.configure_mp("tdm", "outpost")
	MatchConfig.start_match()
	var p: Player = null
	var t := 0.0
	while t < 20.0 and p == null:
		await _wait(0.25)
		t += 0.25
		var cs := get_tree().current_scene
		if cs and cs.get("player") is Player:
			p = cs.player
	check(p != null, "match loaded")
	if p == null:
		return _done()
	var hud = get_tree().current_scene.hud
	if not p.touch_mode:
		_touch(0, Vector2(vp.x * 0.5, vp.y * 0.2), true)
		await get_tree().physics_frame
		_touch(0, Vector2(vp.x * 0.5, vp.y * 0.2), false)
	await _wait(0.2)
	check(p.touch_mode and hud.touch.visible, "touch controls visible")
	t = 0.0
	while t < 10.0 and not p.allow_input:
		await _wait(0.25)
		t += 0.25
	var s: Rect2 = UITheme.safe_rect(get_viewport())
	# Joystick: touch the lower-left, drag up, hold.
	var a := s.position + Vector2(s.size.x * 0.18, s.size.y * 0.75)
	var p0 := p.global_position
	_touch(1, a, true)
	await get_tree().physics_frame
	await _drag(1, a, a + Vector2(0, -60), 6)
	await _wait(1.0)
	_touch(1, a + Vector2(0, -60), false)
	await _wait(0.2)
	var d := Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length()
	check(d > 1.5, "joystick drag moves the player (%.1f m)" % d)
	# Look: drag on the right half.
	var yaw0: float = p.yaw
	var b := s.position + Vector2(s.size.x * 0.65, s.size.y * 0.35)
	_touch(2, b, true)
	await get_tree().physics_frame
	await _drag(2, b, b + Vector2(120, 0), 8)
	_touch(2, b + Vector2(120, 0), false)
	await _wait(0.2)
	check(absf(p.yaw - yaw0) > 0.05, "right-side drag turns the camera (%.2f rad)" % (p.yaw - yaw0))
	# Jump button.
	var jb: Vector2 = hud.touch._pos("jump")
	var y0 := p.global_position.y
	var maxy := y0
	_touch(3, jb, true)
	for i in 15:
		await get_tree().physics_frame
		maxy = maxf(maxy, p.global_position.y)
	_touch(3, jb, false)
	check(maxy > y0 + 0.3, "JUMP button works (+%.2f m)" % (maxy - y0))
	# Fire button fires.
	var w = p.inv.active()
	var ammo0: int = w.mag if w else 0
	var fb: Vector2 = hud.touch._pos("fire")
	_touch(4, fb, true)
	await _wait(0.5)
	_touch(4, fb, false)
	await _wait(0.1)
	check(w != null and w.mag < ammo0, "FIRE button shoots (%d -> %d)" % [ammo0, w.mag if w else 0])
	# Android system keys must not hide the touch controls.
	for k in [KEY_BACK, KEY_VOLUMEUP, KEY_VOLUMEDOWN]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().physics_frame
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
		await get_tree().physics_frame
	check(p.touch_mode and hud.touch.visible, "Back / volume keys don't switch off touch controls")
	_done()


func _done() -> void:
	print("=== RESULT phone: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
