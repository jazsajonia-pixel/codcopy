extends Node
## "flow" suite: drives the real front end (main menu -> mode page -> loading screen -> match) exactly like a
## player would, with the touch scheme, then checks the HUD and on-screen controls exist and actually move the player.
## Regression test for: matches started from the menu had no HUD / no touch controls (HUD script failed to load).

var passed := 0
var failed := 0
var stage := 0
var t := 0.0
var pos0 := Vector3.ZERO
var jc := Vector2.ZERO
var round_mode := "tdm"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.set_setting("controls", "scheme", "touch")
	MatchConfig.fast_test = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/menus/main_menu.tscn")


func _find_btn(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text.strip_edges().to_upper() == txt and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_btn(c, txt)
		if b:
			return b
	return null


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos
	e.pressed = pressed
	get_viewport().push_input(e)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos
	e.relative = rel
	get_viewport().push_input(e)


func _process(delta: float) -> void:
	t += delta
	var cs := get_tree().current_scene
	match stage:
		0:  # main menu -> mode page
			if t > 0.5 and cs:
				var b := _find_btn(cs, "MULTIPLAYER" if round_mode == "tdm" else "BATTLE ROYALE")
				check(b != null, "[%s] main menu button found" % round_mode)
				if b:
					b.pressed.emit()
				stage = 1; t = 0
		1:  # press the launch button
			if t > 0.5:
				var b := _find_btn(cs, "START MATCH" if round_mode == "tdm" else "DEPLOY")
				check(b != null, "[%s] launch button found" % round_mode)
				if b:
					b.pressed.emit()
				stage = 2; t = 0
		2:  # wait for the match through the loading screen
			if cs and cs is MatchBase and cs.player and t > 4.0:
				var m: MatchBase = cs
				check(m.hud != null and m.hud.get_script() != null, "[%s] HUD script loaded after loading screen" % round_mode)
				check(m.hud != null and m.hud.get("touch") != null and m.hud.touch.is_visible_in_tree(), "[%s] on-screen touch controls visible" % round_mode)
				check(m.player.touch_mode, "[%s] player in touch mode" % round_mode)
				if round_mode == "br":
					# Jump out of the aircraft with the touch JUMP button, then wait to land.
					stage = 10; t = 0
				else:
					stage = 3; t = 0
		3:  # touch joystick drag forward
			var m: MatchBase = cs
			var tc: TouchControls = m.hud.touch
			var s: Rect2 = tc._safe()
			jc = s.position + Vector2(s.size.x * 0.16, s.size.y * 0.72)
			pos0 = m.player.global_position
			_touch(1, jc, true)
			_drag(1, jc + Vector2(0, -90), Vector2(0, -90))
			stage = 4; t = 0
		4:
			if t > 1.5:
				var m: MatchBase = cs
				var d := m.player.global_position.distance_to(pos0)
				check(d > 2.0, "[%s] touch joystick moves the player (%.1f m)" % [round_mode, d])
				_touch(1, jc, false)
				if round_mode == "tdm":
					round_mode = "br"
					MatchConfig.br_players = 8
					MatchConfig.to_menu()
					stage = 0; t = 0
				else:
					stage = 20; t = 0
		20:  # BR: get in the nearest vehicle and drive it with the touch joystick
			var m4: MatchBase = cs
			var p: Player = m4.player
			var best: Vehicle = null
			for v in m4.get("vehicles"):
				if best == null or v.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
					best = v
			check(best != null, "[br] vehicles spawned on the island (%d)" % (m4.get("vehicles") as Array).size())
			if best == null:
				_finish(); stage = 99; return
			p.invulnerable_time = 999.0
			best.enter(p)
			var tc4: TouchControls = m4.hud.touch
			check(p.vehicle == best and tc4.driving, "[br] entered vehicle; touch HUD in driving mode")
			check(not tc4._button_active("fire") and tc4._button_active("interact"), "[br] weapon buttons hidden, EXIT shown while driving")
			pos0 = best.global_position
			var s4: Rect2 = tc4._safe()
			jc = s4.position + Vector2(s4.size.x * 0.16, s4.size.y * 0.72)
			_touch(1, jc, true)
			_drag(1, jc + Vector2(0, -90), Vector2(0, -90))
			stage = 21; t = 0
		21:
			if t > 3.0:
				var m5: MatchBase = cs
				var v5: Vehicle = m5.player.vehicle
				var d5 := v5.global_position.distance_to(pos0) if v5 else 0.0
				check(d5 > 4.0, "[br] touch joystick drives the vehicle (%.1f m)" % d5)
				_touch(1, jc, false)
				var tc5: TouchControls = m5.hud.touch
				_touch(3, tc5._pos("interact"), true)
				stage = 22; t = 0
		22:
			if t > 0.2:
				var m6: MatchBase = cs
				_touch(3, m6.hud.touch._pos("interact"), false)
				check(m6.player.vehicle == null and m6.player.camera.current, "[br] EXIT button leaves the vehicle; first-person camera restored")
				_finish()
				stage = 99
		10:  # BR: wait for the aircraft, press JUMP
			var m2: MatchBase = cs
			if m2.get("phase") == 1 and t > 0.5:   # Phase.PLANE
				var tc2: TouchControls = m2.hud.touch
				_touch(2, tc2._pos("jump"), true)
				stage = 11; t = 0
		11:
			if t > 0.2:
				var tc3: TouchControls = (cs as MatchBase).hud.touch
				_touch(2, tc3._pos("jump"), false)
				stage = 12; t = 0
		12:
			var m3: MatchBase = cs
			if m3.player.parachute_state == 0 and m3.player.is_on_floor() and t > 1.0:
				check(true, "[br] player jumped from aircraft and landed")
				stage = 3; t = 0
			elif t > 60.0:
				check(false, "[br] player jumped from aircraft and landed (state=%d)" % m3.player.parachute_state)
				stage = 3; t = 0
	if t > 120.0 and stage < 99:
		check(false, "flow timed out at stage %d" % stage)
		_finish()
		stage = 99


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _finish() -> void:
	print("=== RESULT flow: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
