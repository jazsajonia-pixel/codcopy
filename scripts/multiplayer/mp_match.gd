extends MatchBase
## Multiplayer mode against bots: Team Deathmatch (5v5) and Free-For-All (8 players).
## Offline, all opponents and teammates are AI bots and are never presented as online players.
## In a LAN match (MatchConfig.net.active) other humans appear as puppets driven by NetSync;
## bots are simulated by the host only and always carry the [BOT] tag.

const RESPAWN_TIME := 3.5
const PRE_MATCH := 3.0

var rules := MatchRules.new()
var started := false
var countdown := PRE_MATCH
var respawn_queue := {}   ## Actor -> seconds left
var end_timer := -1.0
var is_ffa := false
var net: NetSync = null
var flags: Array = []        ## Domination capture points (A, B, C)
var _dom_tick := 0.0
var host_lost := false


func _ready() -> void:
	super._ready()
	is_ffa = MatchConfig.mode == "ffa"
	var map_info: Dictionary = GameDB.MP_MAPS.get(MatchConfig.map_id, GameDB.MP_MAPS.outpost)
	load_map(map_info.scene)
	rules.setup(MatchConfig.mode, MatchConfig.score_limit, MatchConfig.time_limit)
	if MatchConfig.net.get("active", false):
		_net_ready()
		return
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
	if MatchConfig.mode == "dom":
		_build_flags()
	for b in bots:
		b.set_physics_process(false)
	player.allow_input = false
	announcement.emit(GameDB.MP_MODES[MatchConfig.mode].name, "Match starting")
	AudioManager.play_2d("res://assets/audio/ambience/wind.ogg", -22.0)


func _add_bot(team: int) -> Bot:
	var bot := spawn_bot(team)
	var prim: Array = GameDB.weapon_ids_for_slot("primary")
	var lo := {"primary": prim[rng.randi() % prim.size()], "melee": "knife", "lethal": "frag", "tactical": "smoke"}
	if rng.randf() < 0.5:
		lo.attachments = {lo.primary: {"optic": "red_dot"}}
	bot.inv.load_from_loadout(lo)
	bot._refresh_gun_model()
	return bot


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
	if net and not started:
		return   # LAN: the host's _go starts everyone together
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
	if net and not net.is_host():
		return   # clients: time, respawns and match end come from the host
	rules.tick(delta)
	_tick_flags(delta)
	for a in respawn_queue.keys():
		if not is_instance_valid(a):
			respawn_queue.erase(a)
			continue
		respawn_queue[a] -= delta
		if respawn_queue[a] <= 0.0:
			respawn_queue.erase(a)
			a.respawn_at(_best_spawn(a))
			if a == player:
				player.yaw = player.rotation.y
			if net:
				net.host_respawned(a)


func on_kill(victim: Actor, killer: Actor) -> void:
	var kt := killer.team if killer and killer != victim else -1
	rules.register_kill(kt, victim.team, kt)
	if net and not net.is_host():
		return
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
	if net and not net.is_host():
		return   # wait for the host's verdict
	if net:
		net.host_ended(winner_team)
	_end_match(winner_team)


func _end_match(winner_team: int) -> void:
	if ended:
		return
	rules.winner = winner_team
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
		"team_scores": rules.team_scores.duplicate(), "scoreboard": scoreboard(), "duration": elapsed,
		"lan": net != null})
	if net:
		res.net_stats = net.stats.duplicate()
		MatchConfig.net = {}
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



# ---------------- LAN (NetSync) ----------------

func _net_ready() -> void:
	var cfg: Dictionary = MatchConfig.net
	net = NetSync.new()
	add_child(net)
	net.setup(self)
	rules.finished.connect(_on_rules_finished)
	var me := multiplayer.get_unique_id()
	var teams: Dictionary = cfg.teams
	spawn_player(int(teams.get(me, 0)))
	player.inv.load_from_loadout(SaveManager.current_loadout())
	player.equip_current()
	net.register(player, me)
	if net.is_host():
		var names: Dictionary = cfg.names
		var ops: Dictionary = cfg.get("ops", {})
		for id in teams.keys():
			if int(id) != me:
				_spawn_puppet(int(id), String(names.get(id, "Player")), int(teams[id]), String(ops.get(id, "")), false)
		# Fill both teams up to team_size with host-simulated bots.
		var counts := {0: 0, 1: 0}
		for a in actors:
			counts[a.team] = counts.get(a.team, 0) + 1
		var i := 0
		for t in [0, 1]:
			while counts[t] < MatchConfig.team_size:
				var b := _add_bot(t)
				b.actor_name += " [BOT]"
				b.name_tag.text = b.actor_name
				net.register(b, NetSync.BOT_ID_BASE - i)
				i += 1
				counts[t] += 1
		_place_all()
		for b in bots:
			b.set_physics_process(false)
		net.host_roster()
	else:
		_place_self()
	player.allow_input = false
	announcement.emit("LAN " + GameDB.MP_MODES[MatchConfig.mode].name, "Waiting for players")
	AudioManager.play_2d("res://assets/audio/ambience/wind.ogg", -22.0)


func _spawn_puppet(id: int, pname: String, team: int, op: String, is_bot: bool) -> Bot:
	var b: Bot = BOT_SCENE.instantiate()
	if op == "":
		op = GameDB.OPERATORS[0].id
	b.setup(pname, team, op, MatchConfig.difficulty_params())
	b.match_node = self
	b.puppet = true
	b.net = net
	b.collision_layer = 2
	add_child(b)
	_register(b)
	net.register(b, id)
	if not is_bot:
		b.name_tag.text = pname
	var prim: Array = GameDB.weapon_ids_for_slot("primary")
	b.inv.load_from_loadout({"primary": prim[0], "melee": "knife", "lethal": "frag", "tactical": "smoke"})
	b._refresh_gun_model()
	return b


## Client: create puppets for everyone in the host's roster except ourselves.
func build_puppets(r: Array) -> void:
	var me := multiplayer.get_unique_id()
	for e in r:
		var id := int(e.id)
		if id == me or net.by_id.has(id):
			continue
		var b := _spawn_puppet(id, String(e.name), int(e.team), String(e.op), bool(e.bot))
		b.global_position = Vector3(0, -50, 0)   # hidden until the first state arrives
	announcement.emit("LAN " + GameDB.MP_MODES[MatchConfig.mode].name, "%d players + bots connected" % NetworkManager.peers.size())


func _place_self() -> void:
	var idx: int = int(MatchConfig.net.get("slot", {}).get(multiplayer.get_unique_id(), 0))
	var pool: Array = map.spawns_a if player.team == 0 else map.spawns_b
	var xf: Transform3D = pool[idx % pool.size()]
	player.global_transform = xf
	player.yaw = xf.basis.get_euler().y


## Everyone (from the host's _go RPC): start the match together.
func net_go() -> void:
	started = true
	player.allow_input = true
	for b in bots:
		b.set_physics_process(true)
	announcement.emit("FIGHT", "")
	AudioManager.play_2d("res://assets/audio/ui/confirmation_001.ogg", -2.0)


func net_end(winner: int) -> void:
	_end_match(winner)


func remove_net_actor(id: int) -> void:
	var a: Actor = net.by_id.get(id)
	if a == null or a == player:
		return
	net.by_id.erase(id)
	actors.erase(a)
	respawn_queue.erase(a)
	kill_feed.emit("", a.actor_name + " left the match", "", false, 0)
	a.queue_free()


func net_host_lost() -> void:
	if ended or host_lost:
		return
	host_lost = true
	announcement.emit("HOST DISCONNECTED", "Returning to menu")
	_end_match(-1)



# ---------------- Domination ----------------

func _build_flags() -> void:
	var ca := Vector3.ZERO
	var cb := Vector3.ZERO
	for xf in map.spawns_a:
		ca += xf.origin
	for xf in map.spawns_b:
		cb += xf.origin
	ca /= maxf(1.0, map.spawns_a.size())
	cb /= maxf(1.0, map.spawns_b.size())
	var nav := get_world_3d().navigation_map
	var letters := ["A", "B", "C"]
	var ts := [0.25, 0.5, 0.75]
	for i in 3:
		var f := DomFlag.new()
		f.letter = letters[i]
		var p: Vector3 = ca.lerp(cb, ts[i])
		var q := NavigationServer3D.map_get_closest_point(nav, p)
		if q != Vector3.ZERO or p.length() < 0.1:
			p = q
		add_child(f)
		f.global_position = p
		f.set_viewer_team(player.team)
		f.captured.connect(_on_flag_captured)
		flags.append(f)


func _tick_flags(delta: float) -> void:
	if flags.is_empty() or ended:
		return
	for f in flags:
		f.tick(delta, actors)
	_dom_tick += delta
	if _dom_tick >= 2.0:
		_dom_tick -= 2.0
		for f in flags:
			if f.owner_team >= 0:
				rules.add_points(f.owner_team, 1)


func _on_flag_captured(f: DomFlag, team: int) -> void:
	for a in actors:
		if a.alive and a.team == team and a.global_position.distance_to(f.global_position) <= DomFlag.RADIUS + 0.5:
			a.score += 150
	var ours := team == player.team
	announcement.emit("FLAG %s %s" % [f.letter, "SECURED" if ours else "LOST"], "")
	AudioManager.play_2d("res://assets/audio/ui/confirmation_001.ogg" if ours else "res://assets/audio/sfx/zone_warning.ogg", -4.0)


## Bots in Domination: attack the nearest flag their team doesn't own, otherwise defend one.
func objective_point(b: Actor) -> Vector3:
	if flags.is_empty():
		return Vector3.ZERO
	var best: DomFlag = null
	var bd := INF
	for f in flags:
		if f.owner_team == b.team:
			continue
		var d: float = b.global_position.distance_to(f.global_position) * (0.7 if f.letter == "B" else 1.0)
		if d < bd:
			bd = d
			best = f
	if best == null:
		best = flags[b.get_instance_id() % flags.size()]
	var off := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	return best.global_position + off


func flag_states() -> Array:
	var out: Array = []
	for f in flags:
		out.append({"letter": f.letter, "owner": f.owner_team, "progress": f.progress, "pos": f.global_position,
			"capturing": f.capturing_team, "contested": f.contested})
	return out
