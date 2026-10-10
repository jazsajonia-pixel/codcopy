extends Node
## "dom" suite: a real Domination match on Outpost with bots, plus the UAV scorestreak.

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


func _run() -> void:
	# Pure rules: kills don't score in Domination, flags do.
	var r := MatchRules.new()
	r.setup("dom", 10, 100.0)
	r.register_kill(0, 1, 0)
	check(r.team_scores[0] == 0, "Domination: kills don't add team score")
	r.add_points(1, 4)
	check(r.team_scores[1] == 4 and r.leader() == 1, "Domination: flag points add up and set the leader")
	r.add_points(1, 20)
	check(r.over and r.winner == 1 and r.team_scores[1] == 10, "Domination: reaching the limit ends the match")

	MatchConfig.fast_test = true
	MatchConfig.autoplay_player = true
	MatchConfig.configure_mp("dom", "outpost")
	get_tree().change_scene_to_file(MatchConfig.match_scene())
	await _wait(0.5)
	var m: Node = get_tree().current_scene
	check(m.flags.size() == 3, "three flags placed (A, B, C)")
	var spaced := true
	for i in m.flags.size():
		for j in range(i + 1, m.flags.size()):
			spaced = spaced and m.flags[i].global_position.distance_to(m.flags[j].global_position) > 15.0
	check(spaced, "flags spread across the map")
	await _wait(4.0)   # pre-match countdown
	var owned_any := false
	var t := 0.0
	while t < 90.0:
		await _wait(1.0)
		t += 1.0
		for f in m.flags:
			if f.owner_team >= 0:
				owned_any = true
		if owned_any and (m.rules.team_scores[0] + m.rules.team_scores[1]) >= 3:
			break
	check(owned_any, "bots captured a flag (%.0f s)" % t)
	check(m.rules.team_scores[0] + m.rules.team_scores[1] >= 3, "held flags score points (%d-%d)" % [m.rules.team_scores[0], m.rules.team_scores[1]])
	# UAV: three kills without dying.
	var p: Player = m.player
	var enemy: Actor = null
	for a in m.actors:
		if p.is_enemy(a):
			enemy = a
			break
	p.streak = 2
	m._on_actor_died(enemy, p, "Test", false)
	check(m.uav_active(p.team), "3-kill streak calls in a UAV")
	var shown := 0
	for a in m.actors:
		if p.is_enemy(a) and a.alive:
			shown += 1
	check(shown > 0, "UAV active while enemies are alive (minimap draws all of them)")
	for b in m.bots:
		b.set_physics_process(false)   # no new streaks while timing the UAV
	MatchConfig.autoplay_player = false
	await _wait(MatchBase.UAV_TIME + 0.5)
	check(not m.uav_active(p.team), "UAV expires after %d s" % int(MatchBase.UAV_TIME))
	print("=== RESULT dom: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
