extends MatchBase
## Multiplayer mode against bots: Team Deathmatch (5v5) and Free-For-All (8 players).
## NOTE: all opponents and teammates here are AI bots; they are never presented as online players.

const RESPAWN_TIME := 3.5
const PRE_MATCH := 3.0

var rules := MatchRules.new()
var started := false
var countdown := PRE_MATCH
var respawn_queue := {}   ## Actor -> seconds left
var end_timer := -1.0
var is_ffa := false


func _ready() -> void:
	super._ready()
	is_ffa = MatchConfig.mode == "ffa"
	var map_info: Dictionary = GameDB.MP_MAPS.get(MatchConfig.map_id, GameDB.MP_MAPS.outpost)
	load_map(map_info.scene)
	rules.setup(MatchConfig.mode, MatchConfig.score_limit, MatchConfig.time_limit)
	rules.finished.connect(_on_rules_finished)
	spawn_player(0)
	player.inv.load_from_loadout(SaveManager.current_loadout())
	player.equip_current()
	if is_ffa:
		for i in MatchConfig.ffa_players - 1:
			_add_bot(i + 1)
	else:
		for i in MatchConfig.team_size - 1:
			_add_bot(0)
		for i in MatchConfig.team_size:
			_add_bot(1)
	_place_all()
	for b in bots:
		b.set_physics_process(false)
	player.allow_input = false
	announcement.emit(GameDB.MP_MODES[MatchConfig.mode].name, "Match starting")
	AudioManager.play_2d("res://assets/audio/ambience/wind.ogg", -22.0)


func _add_bot(team: int) -> void:
	var bot := spawn_bot(team)
	var prim: Array = GameDB.weapon_ids_for_slot("primary")
	var lo := {"primary": prim[rng.randi() % prim.size()], "secondary": "pistol_p9", "melee": "knife", "lethal": "frag", "tactical": "smoke"}
	if rng.randf() < 0.5:
		lo.attachments = {lo.primary: {"optic": "red_dot"}}
	bot.inv.load_from_loadout(lo)
	bot._refresh_gun_model()


func _place_all() -> void:
	var ia := 0
	var ib := 0
	var iff := 0
	for a in actors:
		var xf: Transform3D
		if is_ffa:
			xf = map.spawns_ffa[iff % map.spawns_ffa.size()]
			iff += 1
		elif a.team == 0:
			xf = map.spawns_a[ia % map.spawns_a.size()]
			ia += 1
		else:
			xf = map.spawns_b[ib % map.spawns_b.size()]
			ib += 1
		a.global_transform = xf
		if a == player:
			player.yaw = xf.basis.get_euler().y


func _process(delta: float) -> void:
	super._process(delta)
	if not started:
		countdown -= delta
		if countdown <= 0.0:
			started = true
			player.allow_input = true
			for b in bots:
				b.set_physics_process(true)
			announcement.emit("FIGHT", "")
			AudioManager.play_2d("res://assets/audio/ui/confirmation_001.ogg", -2.0)
		return
	if end_timer >= 0.0:
		end_timer -= delta
		if end_timer <= 0.0:
			_finish()
		return
	rules.tick(delta)
	for a in respawn_queue.keys():
		respawn_queue[a] -= delta
		if respawn_queue[a] <= 0.0:
			respawn_queue.erase(a)
			a.respawn_at(_best_spawn(a))
			if a == player:
				player.yaw = player.rotation.y


func on_kill(victim: Actor, killer: Actor) -> void:
	var kt := killer.team if killer and killer != victim else -1
	rules.register_kill(kt, victim.team, kt)
	respawn_queue[victim] = RESPAWN_TIME + (0.5 if victim == player else 0.0)


func _best_spawn(a: Actor) -> Transform3D:
	var pool: Array = map.spawns_ffa if is_ffa else (map.spawns_a if a.team == 0 else map.spawns_b)
	# In TDM, also allow any FFA spawn far from enemies so spawns don't get camped.
	if not is_ffa:
		pool = pool + map.spawns_ffa
	var best: Transform3D = pool[0]
	var best_score := -INF
	for xf in pool:
		var min_enemy := 999.0
		var near_friend := 999.0
		for o in actors:
			if o == a or not o.alive:
				continue
			var d: float = o.global_position.distance_to(xf.origin)
			if a.is_enemy(o):
				min_enemy = minf(min_enemy, d)
			else:
				near_friend = minf(near_friend, d)
		var s := minf(min_enemy, 40.0) - (near_friend * 0.1 if not is_ffa else 0.0) + rng.randf() * 4.0
		if s > best_score:
			best_score = s
			best = xf
	return best


func _on_rules_finished(winner_team: int) -> void:
	ended = true
	end_timer = 3.0
	var won := winner_team == player.team
	player.allow_input = false
	for b in bots:
		b.set_physics_process(false)
	if winner_team == -1:
		announcement.emit("DRAW", "Match over")
	else:
		announcement.emit("VICTORY" if won else "DEFEAT", "Match over")


func _finish() -> void:
	var won := rules.winner == player.team
	var res := player_stats()
	res.merge({"mode": MatchConfig.mode, "map": MatchConfig.map_id, "won": won, "draw": rules.winner == -1,
		"team_scores": rules.team_scores.duplicate(), "scoreboard": scoreboard(), "duration": elapsed})
	MatchConfig.finish_match(res)


func time_left() -> float:
	return rules.time_left


func score_text() -> Array:
	if is_ffa:
		var mine: int = rules.individual.get(player.team, 0)
		var best := 0
		for id in rules.individual.keys():
			if id != player.team:
				best = maxi(best, rules.individual[id])
		return [mine, best]
	return [rules.team_scores[0], rules.team_scores[1]]


func respawn_eta(a: Actor) -> float:
	return maxf(respawn_queue.get(a, 0.0), 0.0)
