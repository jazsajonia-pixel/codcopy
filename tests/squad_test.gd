extends Node
## "squad" suite: a real Battle Royale match in SQUAD mode (4 per team, AI teammates).
## Checks team setup, teammates dropping with the player, knock-down instead of death, bleed-out,
## revive by the player (hold interact) and by an AI teammate, squad wipe, spectating and placement.

var passed := 0
var failed := 0
var m: Node = null


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


func _team(t: int) -> Array:
	var r: Array = []
	for a in m.actors:
		if a.team == t:
			r.append(a)
	return r


func _run() -> void:
	MatchConfig.fast_test = true
	MatchConfig.autoplay_player = true
	MatchConfig.configure_br()
	MatchConfig.br_players = 12
	MatchConfig.br_squad_size = 4
	get_tree().change_scene_to_file(MatchConfig.BR_SCENE)
	await _wait(0.5)
	m = get_tree().current_scene
	var p: Player = m.player
	var mates := _team(p.team).filter(func(a): return a != p)
	check(mates.size() == 3 and mates.all(func(b): return b is Bot and b.leader == p), "player has 3 AI teammates following them")
	check(m.team_count() == 3, "12 operators form 3 squads (%d)" % m.team_count())
	check(m.actors.all(func(a): return a.can_be_downed), "knock-downs enabled in squads")
	# Wait for the drop and landing (squad 0 protected so random fights can't end the test early).
	var t := 0.0
	while t < 60.0 and not (p.parachute_state == 0 and p.is_on_floor() and m.phase == 2 and mates.all(func(b): return not b.parachute)):
		for a in _team(p.team):
			a.invulnerable_time = 5.0
		await _wait(0.5)
		t += 0.5
	var far := 0.0
	for b in mates:
		far = maxf(far, b.global_position.distance_to(p.global_position))
	check(far < 70.0, "teammates landed near the player (max %.0f m)" % far)
	MatchConfig.autoplay_player = false
	for a in m.actors:
		a.invulnerable_time = 0.0
	# Keep the test squads out of other fights: enemies of squad 2 are frozen far away.
	var enemy_team := 1
	var enemies := _team(enemy_team)
	var shooter: Actor = _team(2)[0]
	# Freeze the other squads far away so the revive checks are deterministic.
	for a in m.actors:
		if a.team != p.team and a is Bot:
			a.set_physics_process(false)
			a.global_position = Vector3(a.global_position.x, 200.0 + randf() * 20.0, a.global_position.z) + Vector3(0, 0, 0)

	# --- Knock-down instead of death ---
	var e0: Actor = enemies[0]
	var knocked := [0]
	m.kill_feed.connect(func(_k, v, _w, _h, _i): if v.ends_with("(knocked)"): knocked[0] += 1)
	e0.take_damage(500.0, shooter, "Test")
	check(e0.alive and e0.downed, "lethal damage knocks a squad member down")
	check(knocked[0] >= 1, "kill feed reports the knock")
	check(e0.process_trigger(true, e0.eye_position(), Vector3.FORWARD, e0.eye_position(), false, false).is_empty(), "downed operators cannot shoot")
	var h0 := e0.health
	e0.set_physics_process(true)
	await _wait(1.0)
	e0.set_physics_process(false)
	check(e0.health < h0, "downed operator bleeds out over time (%.0f -> %.0f)" % [h0, e0.health])

	# --- Player revives a downed teammate ---
	var tm: Actor = mates[0]
	tm.set_physics_process(false)    # hold the teammate still for a deterministic revive
	tm.take_damage(500.0, shooter, "Test")
	check(tm.downed, "teammate knocked down")
	var nav: RID = p.get_world_3d().navigation_map
	var spot: Vector3 = NavigationServer3D.map_get_closest_point(nav, m.zone_target())   # safely inside the zone
	tm.global_position = spot + Vector3(0, 0.1, 0)
	for b in mates:
		if b != tm:
			b.global_position = spot + Vector3(-3, 0.3, 2)
	p.global_position = NavigationServer3D.map_get_closest_point(nav, spot + Vector3(1.2, 0, 0)) + Vector3(0, 0.2, 0)
	for b in mates:
		if b != tm:
			b.global_position = p.global_position + Vector3(60, 5, 60)   # keep the AI from reviving first
			b.set_physics_process(false)
	await _wait(0.4)
	check(p.revive_target == tm, "revive prompt targets the downed teammate")
	Input.action_press("interact")      # real input path (keyboard poll)
	await _wait(Actor.REVIVE_TIME + 0.6)
	Input.action_release("interact")
	check(not tm.downed and tm.alive and is_equal_approx(tm.health, Actor.REVIVE_HEALTH), "holding interact revives the teammate (%.0f HP)" % tm.health)
	tm.set_physics_process(true)

	# --- AI teammate revives the downed player ---
	var helper: Bot = mates[1]
	helper.set_physics_process(true)
	helper.global_position = NavigationServer3D.map_get_closest_point(nav, p.global_position + Vector3(4, 0, 0)) + Vector3(0, 0.3, 0)
	p.take_damage(500.0, shooter, "Test")
	check(p.downed and p.alive, "player can be knocked down")
	t = 0.0
	while t < 14.0 and p.downed:
		await _wait(0.25)
		t += 0.25
	check(p.alive and not p.downed, "AI teammate came over and revived the player (%.1f s)" % t)
	check(t >= Actor.REVIVE_TIME - 0.3, "revives take the full revive time (no stacking)")
	for b in mates:
		b.set_physics_process(true)

	# --- Squad wipe: knocking the last standing member eliminates the downed ones ---
	for a in enemies:
		if a.alive and not a.downed:
			a.take_damage(500.0, shooter, "Test")
	await _wait(0.2)
	check(enemies.all(func(a): return not a.alive), "squad wiped once nobody is left standing")
	check(m.alive_teams() == 2, "two squads remain (%d)" % m.alive_teams())

	# --- Player dies with teammates alive: match continues, spectating a teammate ---
	p.health = 1.0
	p.take_damage(500.0, shooter, "Test")   # knocked
	p.finish_off()
	await _wait(0.5)
	check(not p.alive and not m.ended, "match continues while teammates are alive")
	check(p.spectate_target != null and p.spectate_target.alive and p.spectate_target.team == p.team, "camera spectates a living teammate")

	# --- Last teammates fall: squad eliminated, placement by squad ---
	for b in mates:
		if b.alive:
			b.take_damage(500.0, shooter, "Test")
			if b.alive:
				b.take_damage(500.0, shooter, "Test")
	await _wait(0.5)
	check(m.ended and m.placement == 2, "squad eliminated: placed #%d of %d squads" % [m.placement, m.team_count()])
	print("=== RESULT squad: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
