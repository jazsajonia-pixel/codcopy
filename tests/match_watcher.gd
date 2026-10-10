extends Node
## Lives under the root during match tests; observes the running match and checks outcomes.

var mode := "tdm"
var sim_time := 0.0
var next_report := 0.0
var limit := 300.0
var feed := 0
var hooked := false
var m: Node
var max_bot_travel := 0.0
var bot_start := {}
var player_had_weapon := false
var player_shots := 0
var player_landed := false
var zone_phases := 0
var min_alive := 999
var touch_stage := 0
var touch_t := 0.0
var touch_results := {}
var passed := 0
var failed := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	limit = {"tdm": 330.0, "ffa": 330.0, "br": 600.0, "touch": 40.0}.get(mode, 300.0)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _process(delta: float) -> void:
	Engine.max_fps = 0
	sim_time += delta
	var cs := get_tree().current_scene
	if cs and cs.has_signal("kill_feed") and not hooked:
		hooked = true
		m = cs
		m.kill_feed.connect(func(_a, _b, _c, _d, _e): feed += 1)
		if m.has_signal("announcement"):
			m.announcement.connect(func(t, s): print("  [announce %.0fs] %s - %s" % [sim_time, t, s]))
	if m and is_instance_valid(m):
		_observe()
	if sim_time >= next_report:
		next_report += 10.0
		_report()
	if cs and cs.scene_file_path == MatchConfig.RESULTS_SCENE:
		_on_results()
		return
	if mode == "touch" and m and is_instance_valid(m):
		_touch_test(delta)
	if sim_time > limit:
		print("  TIMEOUT after %.0f simulated seconds" % sim_time)
		failed += 1
		_done()


func _observe() -> void:
	if m.player == null:
		return
	for b in m.bots:
		if not is_instance_valid(b) or not b.visible:
			continue
		if not bot_start.has(b):
			bot_start[b] = b.global_position
		max_bot_travel = maxf(max_bot_travel, b.global_position.distance_to(bot_start[b]))
	if m.player.inv.has_any_weapon():
		player_had_weapon = true
	player_shots = maxi(player_shots, m.player.shots_fired)
	if mode == "br":
		if m.player_dropped and m.player.parachute_state == 0 and m.player.is_on_floor():
			player_landed = true
		zone_phases = maxi(zone_phases, m.zone.phase + (1 if m.zone.shrinking else 0))
		min_alive = mini(min_alive, m.alive_count())


func _report() -> void:
	if m == null or not is_instance_valid(m) or m.player == null:
		print("  [%.0fs] waiting for match" % sim_time)
		return
	var p: Player = m.player
	var extra := ""
	if mode == "br":
		extra = " goal=%s path=%d loot=%s nav_ready=%s" % [str(p._auto_goal.snapped(Vector3.ONE)), p._auto_path.size(), str(p._auto_loot), str(m.map.nav_ready)] + " alive=%d zone_phase=%d r=%.0f landed=%s chute=%d weapon=%s" % [m.alive_count(), m.zone.phase, m.zone.radius, player_landed, p.parachute_state, p.inv.active().id() if p.inv.active() else "-"]
	elif m.has_method("score_text"):
		extra = " score=%s time_left=%.0f" % [str(m.score_text()), m.time_left()]
	print("  [%.0fs] fps=%d player K/D=%d/%d hp=%.0f pos=%s feed=%d bot_travel=%.0f%s" % [sim_time, Engine.get_frames_per_second(), p.kills, p.deaths, p.health, str(p.global_position.snapped(Vector3.ONE)), feed, max_bot_travel, extra])


func _on_results() -> void:
	var r: Dictionary = MatchConfig.last_results
	print("  RESULTS: ", JSON.stringify({"mode": r.get("mode"), "won": r.get("won"), "kills": r.get("kills"), "deaths": r.get("deaths"), "assists": r.get("assists"),
		"score": r.get("score"), "placement": r.get("placement", 0), "team_scores": r.get("team_scores", {}), "rewards": r.get("rewards", {}), "duration": r.get("duration")}))
	check(r.has("rewards") and int(r.rewards.xp) > 0, "results screen reached with XP reward")
	check(feed > 0, "kill feed produced events (%d)" % feed)
	check(max_bot_travel > 10.0, "bots navigated (max travel %.0f m)" % max_bot_travel)
	if mode in ["tdm", "ffa"]:
		var ts: Dictionary = r.get("team_scores", {})
		var top := 0
		if mode == "tdm":
			for k in ts.keys():
				top = maxi(top, int(ts[k]))
		else:
			for row in r.get("scoreboard", []):
				top = maxi(top, int(row.kills))
		check(top >= MatchConfig.score_limit or float(r.get("duration", 0)) >= MatchConfig.time_limit - 1.0, "match ended by score or time limit")
		check(player_shots > 0 and int(r.get("kills", 0)) + int(r.get("deaths", 0)) + int(r.get("assists", 0)) > 0, "player fought (%d shots, K/D/A %d/%d/%d)" % [player_shots, r.get("kills", 0), r.get("deaths", 0), r.get("assists", 0)])
	if mode == "br":
		check(player_landed, "player deployed and landed")
		check(player_had_weapon, "player looted a weapon")
		check(zone_phases >= 1, "safe zone advanced (phase %d)" % zone_phases)
		check(min_alive < MatchConfig.br_players, "operators were eliminated (min alive %d)" % min_alive)
		check(int(r.get("placement", 0)) >= 1, "placement recorded (#%d)" % int(r.get("placement", 0)))
	_done()


func _done() -> void:
	print("=== RESULT %s: %d passed, %d failed (%.0f simulated s) ===" % [mode, passed, failed, sim_time])
	get_tree().quit(0 if failed == 0 else 1)


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos   # viewport -> window coordinates
	e.pressed = pressed
	get_viewport().push_input(e)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = get_viewport().get_final_transform() * pos
	e.relative = get_viewport().get_final_transform().basis_xform(rel)
	get_viewport().push_input(e)


func _touch_test(delta: float) -> void:
	var p: Player = m.player
	if p == null or not m.get("started"):
		return
	var tc: TouchControls = m.hud.touch
	touch_t += delta
	match touch_stage:
		0:
			check(p.touch_mode and tc.visible, "touch controls active when scheme=touch")
			touch_results.yaw0 = p.yaw
			touch_results.pitch0 = p.pitch
			_touch(4, tc._pos("reload"), true)
			touch_stage = 10
			touch_t = 0
		10:
			if touch_t > 0.3:
				check(is_equal_approx(p.yaw, touch_results.yaw0) and is_equal_approx(p.pitch, touch_results.pitch0), "holding a HUD button does not rotate the camera")
				_touch(4, tc._pos("reload"), false)
				_touch(0, tc._pos("fire"), true)
				touch_stage = 1
				touch_t = 0
		1:
			if touch_t > 0.3:
				check(p.input.fire, "fire button holds trigger")
				# Second finger: joystick (simultaneous with fire).
				var jc := tc._pos("joystick")
				touch_results.jc = jc
				touch_results.pos0 = p.global_position
				_touch(1, jc, true)
				_drag(1, jc + Vector2(0, -60), Vector2(0, -60))
				touch_stage = 2
				touch_t = 0
		2:
			if touch_t > 1.0:
				check(p.input.move.y < -0.2, "joystick drives movement while firing (move=%s)" % str(p.input.move))
				check(p.global_position.distance_to(touch_results.pos0) > 1.0, "player moved with joystick")
				# Third finger: free look area.
				var s := tc._safe()
				var lp := s.position + Vector2(s.size.x * 0.5, s.size.y * 0.3)
				touch_results.yaw1 = p.yaw
				_touch(2, lp, true)
				for i in 5:
					_drag(2, lp + Vector2(20 * (i + 1), 0), Vector2(20, 0))
				touch_stage = 3
				touch_t = 0
		3:
			if touch_t > 0.3:
				check(absf(p.yaw - touch_results.yaw1) > 0.05, "look area rotates camera (dyaw=%.3f)" % (p.yaw - touch_results.yaw1))
				for i in 3:
					_touch(i, Vector2.ZERO, false)
				touch_stage = 4
				touch_t = 0
		4:
			if touch_t > 0.2:
				check(not p.input.fire and p.input.move == Vector2.ZERO, "releasing fingers clears fire and movement")
				# Pause button opens pause menu
				_touch(5, tc._pos("pause"), true)
				_touch(5, tc._pos("pause"), false)
				touch_stage = 5
				touch_t = 0
		5:
			if touch_t > 0.2:
				check(get_tree().paused and m.hud.pause_panel.visible, "pause button opens pause menu")
				m.toggle_pause()
				check(not get_tree().paused, "resume closes pause menu")
				_done()
