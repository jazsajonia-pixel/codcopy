extends Node
## "keys" suite: keyboard control in real matches started through the loading screen (no autopilot).
## Presses physical W/A/S/D/Space keys via Input.parse_input_event and checks the player responds.

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


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _hold(k: Key, sec: float) -> void:
	_key(k, true)
	await _wait(sec)
	_key(k, false)
	await _wait(0.1)


func _tap(pos: Vector2) -> void:
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = pos
		t.pressed = down
		Input.parse_input_event(t)
		await get_tree().physics_frame


## Touchscreen laptops / tablets with keyboards: a real key press in touch mode must hand control
## to the keyboard (scheme Auto), but not when the player explicitly picked Touch.
func _touch_switch(p: Player) -> void:
	var hud = get_tree().current_scene.hud
	await _tap(Vector2(640, 200))
	await _wait(0.2)
	check(p.touch_mode and hud.touch.visible, "[auto] a screen touch switches to touch controls")
	var p0 := p.global_position
	await _hold(KEY_W, 0.8)
	var d := Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length()
	check(not p.touch_mode and not hud.touch.visible, "[auto] a keyboard key switches back to keyboard/mouse")
	check(d > 1.0, "[auto] holding W in touch mode still moves the player (%.1f m)" % d)
	SaveManager.set_setting("controls", "scheme", "touch")
	await _tap(Vector2(640, 200))
	await _wait(0.2)
	await _hold(KEY_W, 0.3)
	check(p.touch_mode, "[touch scheme] keyboard does not override an explicit Touch choice")
	SaveManager.set_setting("controls", "scheme", "auto")
	hud.set_keyboard_mode()


func _match_player() -> Player:
	var cs := get_tree().current_scene
	if cs and cs.get("player") and cs.player is Player:
		return cs.player
	return null


func _run() -> void:
	MatchConfig.autoplay_player = false
	for mode in ["tdm", "br"]:
		if mode == "br":
			MatchConfig.configure_br()
			MatchConfig.br_players = 8
			MatchConfig.fast_test = true
		else:
			MatchConfig.configure_mp("tdm", "outpost")
		MatchConfig.start_match()
		var p: Player = null
		var t := 0.0
		while t < 20.0 and p == null:
			await _wait(0.25)
			t += 0.25
			p = _match_player()
		check(p != null, "[%s] match loaded with a player" % mode)
		if p == null:
			continue
		check(not p.touch_mode, "[%s] keyboard scheme active (touch_mode off)" % mode)
		if mode == "br":
			var m = get_tree().current_scene
			t = 0.0
			while t < 30.0 and m.phase < 1:
				await _wait(0.25)
				t += 0.25
			await _wait(1.0)
			_key(KEY_SPACE, true)
			await _wait(0.2)
			_key(KEY_SPACE, false)
			await _wait(1.0)
			check(m.player_dropped, "[br] Space jumps out of the aircraft")
			t = 0.0
			while t < 60.0 and not (p.parachute_state == 0 and p.is_on_floor()):
				p.pitch = -1.3   # dive straight down like a player would
				await _wait(0.25)
				t += 0.25
			check(p.is_on_floor(), "[br] landed (%.0f s)" % t)
		else:
			t = 0.0
			while t < 10.0 and not p.allow_input:
				await _wait(0.25)
				t += 0.25
		check(p.allow_input, "[%s] input enabled after countdown" % mode)
		for pair in [[KEY_W, "W"], [KEY_S, "S"], [KEY_A, "A"], [KEY_D, "D"]]:
			var p0 := p.global_position
			await _hold(pair[0], 0.8)
			var d := Vector2(p.global_position.x - p0.x, p.global_position.z - p0.z).length()
			check(d > 1.0, "[%s] holding %s moves the player (%.1f m)" % [mode, pair[1], d])
		var y0 := p.global_position.y
		var maxy := y0
		_key(KEY_SPACE, true)
		for i in 20:
			await get_tree().physics_frame
			maxy = maxf(maxy, p.global_position.y)
		_key(KEY_SPACE, false)
		check(maxy > y0 + 0.3, "[%s] Space jumps (+%.2f m)" % [mode, maxy - y0])
		await _wait(1.0)
		if DisplayServer.get_name() != "headless":
			check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "[%s] mouse captured at match start" % mode)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			await _wait(0.2)
			var c := InputEventMouseButton.new()
			c.button_index = MOUSE_BUTTON_LEFT
			c.pressed = true
			c.position = Vector2(640, 360)
			c.global_position = c.position
			Input.parse_input_event(c)
			await _wait(0.1)
			c = c.duplicate()
			c.pressed = false
			Input.parse_input_event(c)
			await _wait(0.2)
			check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "[%s] clicking the game window re-captures the mouse" % mode)
			var e := InputEventMouseMotion.new()
			e.relative = Vector2(200, 0)
			e.position = Vector2(640, 360)
			var yaw0: float = p.yaw
			Input.parse_input_event(e)
			await _wait(0.3)
			check(absf(p.yaw - yaw0) > 0.05, "[%s] mouse movement turns the camera (%.2f rad)" % [mode, p.yaw - yaw0])
		if mode == "tdm":
			await _touch_switch(p)
		MatchConfig.to_menu()
		await _wait(1.0)
	print("=== RESULT keys: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
