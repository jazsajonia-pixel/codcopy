extends Node
## Networking foundation (autoload "NetworkManager").
##
## What exists: an ENet LAN lobby - host a session, join by IP, see connected peers and their
## profile names, and leave. This is real Godot high-level multiplayer (ENetMultiplayerPeer + RPCs)
## and can be tested with two instances on one machine or a LAN.
##
## LAN Team Deathmatch: the host presses START and every peer loads the same map; replication is
## done by NetSync (scripts/multiplayer/net_sync.gd) with the host authoritative for damage, deaths,
## scores, respawns, bots and match end.
##
## What does NOT exist: internet matchmaking, dedicated servers, NAT traversal, accounts, lag
## compensation or anti-cheat. LAN play has only been tested with two instances on one machine.

signal peers_changed
signal status_changed(text: String)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 9

var peers := {}          ## peer_id -> {name}
var status := "Offline"
var is_host := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _set_status("Connection failed"); leave())
	multiplayer.server_disconnected.connect(func(): _set_status("Host closed the lobby"); leave())


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func host(port: int = DEFAULT_PORT) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_CLIENTS)
	if err != OK:
		_set_status("Could not host on port %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = p
	is_host = true
	peers = {1: {"name": str(SaveManager.profile.name), "op": str(SaveManager.profile.operator)}}
	_set_status("Hosting LAN lobby on port %d" % port)
	peers_changed.emit()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	leave()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port)
	if err != OK:
		_set_status("Could not connect to %s:%d (error %d)" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = p
	is_host = false
	_set_status("Connecting to %s:%d ..." % [address, port])
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	if not peers.is_empty():
		peers.clear()
		peers_changed.emit()
	if status.begins_with("Hosting") or status.begins_with("Connected"):
		_set_status("Offline")


func local_ips() -> Array:
	var out: Array = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			out.append(ip)
	return out


func _set_status(t: String) -> void:
	status = t
	status_changed.emit(t)


func _on_connected() -> void:
	_set_status("Connected to lobby")
	_register.rpc_id(1, str(SaveManager.profile.name), str(SaveManager.profile.operator))


func _on_peer_connected(_id: int) -> void:
	if is_host:
		_sync_peers.rpc(peers)


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	peers_changed.emit()
	if is_host:
		_sync_peers.rpc(peers)


@rpc("any_peer", "reliable")
func _register(player_name: String, operator_id: String = "") -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	peers[id] = {"name": player_name.substr(0, 16), "op": String(GameDB.get_operator(operator_id).id)}
	peers_changed.emit()
	_sync_peers.rpc(peers)


@rpc("authority", "reliable")
func _sync_peers(p: Dictionary) -> void:
	peers = p
	peers_changed.emit()



## Host: start a LAN Team Deathmatch for everyone in the lobby. Teams alternate by join order and
## empty slots are filled with host-simulated bots (always tagged [BOT]).
func start_lan_match(map_id: String = "outpost", score_limit: int = 50, time_limit: float = 600.0) -> bool:
	if not is_host or peers.size() < 2:
		return false
	var ids := peers.keys()
	ids.sort()
	var teams := {}
	var names := {}
	var ops := {}
	var slot := {}
	var per_team := {0: 0, 1: 0}
	for i in ids.size():
		var id: int = ids[i]
		var t := i % 2
		teams[id] = t
		slot[id] = per_team[t]
		per_team[t] += 1
		names[id] = peers[id].name
		ops[id] = peers[id].get("op", "")
	var cfg := {"active": true, "map": map_id, "teams": teams, "names": names, "ops": ops, "slot": slot,
		"score_limit": score_limit, "time_limit": time_limit, "team_size": maxi(5, maxi(per_team[0], per_team[1]))}
	_begin.rpc(cfg)
	return true


@rpc("authority", "call_local", "reliable")
func _begin(cfg: Dictionary) -> void:
	MatchConfig.configure_mp("tdm", String(cfg.map))
	MatchConfig.score_limit = int(cfg.score_limit)
	MatchConfig.time_limit = float(cfg.time_limit)
	MatchConfig.team_size = int(cfg.team_size)
	MatchConfig.net = cfg
	_set_status("LAN match in progress")
	MatchConfig.start_match()
