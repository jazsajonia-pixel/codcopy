class_name NetSync
extends Node
## LAN Team Deathmatch replication (child of the MP match, path /root/MPMatch/NetSync on every peer).
##
## Model (host-authoritative, small and honest):
## - Every peer simulates ONLY its own Player and streams its state (~20 Hz, unreliable).
## - The host also simulates every AI bot and streams their state in one batch.
## - Everyone else is a "puppet" (a Bot node with AI switched off) that interpolates to that state.
## - Health, deaths, kills, scores, respawns and match end are decided by the host and broadcast.
##   A client that hits a puppet sends a hit report; the host validates and applies it.
## - Shots and explosions are replayed as effects only (no damage) on the other peers.
## Not provided: lag compensation, client prediction of damage, anti-cheat, internet play.

const SEND_RATE := 1.0 / 20.0
const BOT_ID_BASE := -1000   ## bots use negative ids (peer ids are positive and can be large)

var match_node: Node
var by_id := {}            ## net_id -> Actor (local player, puppets and, on host, bots)
var local_id := 1
var ready_peers := {}      ## host: peer ids whose match scene is loaded
var started := false
var send_t := 0.0
var wait_t := 0.0
var roster: Array = []     ## [{id, name, team, op, bot, spawn}]
var stats := {"hits_reported": 0, "hits_accepted": 0, "hits_rejected": 0, "states_rx": 0, "fx_rx": 0}
var _applying := false     ## true while applying host-authoritative damage locally
var _last_hit_t := {}      ## host: peer -> msec of last accepted hit (rate limit)


func is_host() -> bool:
	return multiplayer.is_server()


## Host: send an RPC only to clients whose match scene is loaded (others would log "node not found").
func _to_ready(method: StringName, args: Array, except_id := 0) -> void:
	for id in ready_peers.keys():
		if id != except_id:
			Callable(self, "rpc_id").callv([id, method] + args)


func setup(m: Node) -> void:
	match_node = m
	name = "NetSync"
	local_id = multiplayer.get_unique_id()
	Combat.net_shot_hook = _on_local_shot
	Combat.net_explode_hook = _on_local_explosion
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.server_disconnected.connect(_on_host_left)


func _exit_tree() -> void:
	Combat.net_shot_hook = Callable()
	Combat.net_explode_hook = Callable()


func register(a: Actor, id: int) -> void:
	a.net_id = id
	by_id[id] = a
	if is_host():
		a.died.connect(_on_actor_died_host)


## Host: build the roster after the match spawned the local player, remote puppets and bots.
func host_roster() -> void:
	roster.clear()
	for id in by_id.keys():
		var a: Actor = by_id[id]
		roster.append({"id": id, "name": a.actor_name, "team": a.team, "op": a.operator_id, "bot": id < 0})


func _process(delta: float) -> void:
	if match_node == null:
		return
	if not is_host() and roster.is_empty():
		wait_t -= delta
		if wait_t <= 0.0:
			wait_t = 1.0
			client_ready()   # retried until the host's match scene answers with the roster
	if is_host() and not started:
		wait_t += delta
		var need := NetworkManager.peers.size() - 1
		if ready_peers.size() >= need or wait_t > 20.0:
			_to_ready(&"_go", [match_node.rules.time_left])
			_go(match_node.rules.time_left)
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = SEND_RATE
	var me: Actor = match_node.player
	if not is_host():
		if me and started:
			_state.rpc_id(1, _pack(me))
		return
	# Host: one batch with the host player, every bot and the latest state of every remote player.
	var batch: Array = []
	var hp := {}
	for id in by_id.keys():
		var a: Actor = by_id[id]
		if not is_instance_valid(a):
			continue
		if a is Bot and a.puppet:
			if a._net_has:
				batch.append([id, a._net_pos, a._net_yaw, a._net_pitch, a._net_vel, a.alive, a._net_weapon, a.current_height, a._net_floor])
			hp[id] = [a.health, a.armor]
		else:
			batch.append(_pack(a))
	_to_ready(&"_bots", [batch, hp, match_node.rules.time_left])


func _pack(a: Actor) -> Array:
	var w := a.inv.active()
	var pitch := 0.0
	if a is Player:
		pitch = (a as Player).pitch
	elif a is Bot:
		pitch = asin(clampf((a as Bot).aim_dir.y, -1, 1))
	var yaw := a.rotation.y
	return [a.net_id, a.global_position, yaw, pitch, a.velocity, a.alive, w.id() if w else "", a.current_height, a.is_on_floor()]


func _apply_state(s: Array) -> void:
	var a: Actor = by_id.get(int(s[0]))
	if a == null or not (a is Bot) or not a.puppet:
		return
	stats.states_rx += 1
	a.net_apply(s[1], s[2], s[3], s[4], s[6], s[7], s[8])


# ---------------- RPCs: state ----------------

## Client -> host: our own player's state. The host relays it to everyone else in its batch.
@rpc("any_peer", "unreliable_ordered")
func _state(s: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host() or int(s[0]) != sender:
		return   # a peer may only move its own player
	_apply_state(s)


@rpc("authority", "unreliable_ordered")
func _bots(batch: Array, hp: Dictionary, time_left: float) -> void:
	for s in batch:
		if int(s[0]) != local_id:
			_apply_state(s)
	if hp.has(local_id) and match_node.player and match_node.player.alive:
		match_node.player.health = float(hp[local_id][0])
		match_node.player.armor = float(hp[local_id][1])
	match_node.rules.time_left = time_left


# ---------------- RPCs: match flow ----------------

## Client: our scene is loaded; ask the host for the roster.
func client_ready() -> void:
	if roster.is_empty():
		_ready_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _ready_rpc() -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	ready_peers[id] = true
	_roster.rpc_id(id, roster)


@rpc("authority", "reliable")
func _roster(r: Array) -> void:
	roster = r
	match_node.build_puppets(r)


@rpc("authority", "reliable")
func _go(time_left: float) -> void:
	started = true
	match_node.rules.time_left = time_left
	match_node.net_go()


@rpc("authority", "reliable")
func _died(victim_id: int, killer_id: int, weapon: String, headshot: bool) -> void:
	var v: Actor = by_id.get(victim_id)
	if v == null or not v.alive:
		return
	var k: Actor = by_id.get(killer_id)
	v.health = 0.0
	v.downed = false
	v._die(k, weapon, headshot)


@rpc("authority", "reliable")
func _respawn(id: int, xf: Transform3D) -> void:
	var a: Actor = by_id.get(id)
	if a == null:
		return
	a.respawn_at(xf)
	if a == match_node.player:
		match_node.player.yaw = xf.basis.get_euler().y


@rpc("authority", "reliable")
func _end(winner: int) -> void:
	match_node.net_end(winner)


@rpc("authority", "reliable")
func _remove(id: int) -> void:
	match_node.remove_net_actor(id)


## Host: broadcast deaths of anyone (bots, host player, remote puppets).
func _on_actor_died_host(victim: Actor, killer: Actor, weapon: String, headshot: bool) -> void:
	_to_ready(&"_died", [victim.net_id, killer.net_id if killer else 0, weapon, headshot])


func host_respawned(a: Actor) -> void:
	_to_ready(&"_respawn", [a.net_id, a.global_transform])


func host_ended(winner: int) -> void:
	_to_ready(&"_end", [winner])


# ---------------- Damage ----------------

## Client: a puppet (or our own player from a local source) was hit; let the host decide.
func report_hit(victim: Actor, amount: float, attacker: Actor, weapon: String, headshot: bool, from_pos: Vector3) -> void:
	stats.hits_reported += 1
	_hit.rpc_id(1, victim.net_id, amount, attacker.net_id if attacker else 0, weapon, headshot, from_pos)


@rpc("any_peer", "reliable")
func _hit(victim_id: int, amount: float, attacker_id: int, weapon: String, headshot: bool, from_pos: Vector3) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var v: Actor = by_id.get(victim_id)
	var att: Actor = by_id.get(attacker_id)
	# Validation: the sender may only report damage dealt by its own player (or self-damage),
	# from a living attacker, with a plausible amount and distance, at a bounded rate.
	var ok := v != null and v.alive and (attacker_id == sender or attacker_id == 0) and amount > 0.0 and amount <= 400.0
	if ok and att:
		ok = att.alive and att.global_position.distance_to(v.global_position) < 260.0
	if ok and attacker_id != 0:
		var now := Time.get_ticks_msec()
		ok = now - int(_last_hit_t.get(sender, 0)) >= 15 or weapon.contains("Frag") or weapon.contains("explosion")
		_last_hit_t[sender] = now
	if not ok:
		stats.hits_rejected += 1
		return
	stats.hits_accepted += 1
	if v == match_node.player or (v is Bot and not v.puppet):
		v.take_damage(amount, att, weapon, headshot, from_pos)
	else:
		v.host_apply_damage(amount, att, weapon, headshot, from_pos)


## Host: tell the owning client its player was hurt (for the damage indicator + health).
func host_notify_damage(v: Actor, from_pos: Vector3, attacker: Actor) -> void:
	if v.net_id > 0 and v.net_id != local_id:
		_hurt.rpc_id(v.net_id, v.health, v.armor, from_pos, attacker.net_id if attacker else 0)


@rpc("authority", "reliable")
func _hurt(health: float, armor: float, from_pos: Vector3, attacker_id: int) -> void:
	var p: Player = match_node.player
	if p == null or not p.alive:
		return
	p.health = health
	p.armor = armor
	p.net_hurt(from_pos, by_id.get(attacker_id))


# ---------------- Effects ----------------

func _on_local_shot(shooter: Actor, muzzle: Vector3, end: Vector3, sound: String) -> void:
	if shooter == null or shooter.net_id == 0:
		return
	if shooter == match_node.player or (is_host() and shooter is Bot and not shooter.puppet):
		if is_host():
			_to_ready(&"_shot_fx", [shooter.net_id, muzzle, end, sound])
		else:
			_shot_fx.rpc_id(1, shooter.net_id, muzzle, end, sound)


func _on_local_explosion(source: Actor, pos: Vector3, radius: float) -> void:
	if source == match_node.player or (is_host() and source is Bot and not source.puppet):
		if is_host():
			_to_ready(&"_explosion_fx", [pos, radius])
		else:
			_explosion_fx.rpc_id(1, pos, radius)


@rpc("any_peer", "unreliable")
func _shot_fx(shooter_id: int, muzzle: Vector3, end: Vector3, sound: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host():
		if shooter_id != sender:
			return
		_to_ready(&"_shot_fx", [shooter_id, muzzle, end, sound], sender)   # relay
	stats.fx_rx += 1
	Effects.tracer(muzzle, end)
	if sound != "":
		AudioManager.play_3d(sound, muzzle, -4.0, randf_range(0.95, 1.05), 140.0)
	var a: Actor = by_id.get(shooter_id)
	if a and a.alive:
		a.shot_fired.emit(a, false)   # lets host bots hear remote players


@rpc("any_peer", "unreliable")
func _explosion_fx(pos: Vector3, radius: float) -> void:
	if is_host():
		_to_ready(&"_explosion_fx", [pos, radius], multiplayer.get_remote_sender_id())
	Effects.explosion(pos, radius)
	AudioManager.play_3d("res://assets/audio/sfx/explosion.ogg", pos, 0.0, 1.0, 200.0)


# ---------------- Disconnects ----------------

func _on_peer_left(id: int) -> void:
	ready_peers.erase(id)
	if is_host() and by_id.has(id):
		match_node.remove_net_actor(id)
		_to_ready(&"_remove", [id])


func _on_host_left() -> void:
	match_node.net_host_lost()
