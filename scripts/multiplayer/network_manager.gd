extends Node
## Networking foundation (autoload "NetworkManager").
##
## What exists: an ENet LAN lobby - host a session, join by IP, see connected peers and their
## profile names, and leave. This is real Godot high-level multiplayer (ENetMultiplayerPeer + RPCs)
## and can be tested with two instances on one machine or a LAN.
##
## What does NOT exist yet: gameplay replication (player/bot state sync, authoritative hit
## validation, match start across peers), internet matchmaking, servers, accounts, or anti-cheat.
## Matches are always played offline against bots. See docs/ARCHITECTURE.md "Online roadmap".

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
	peers = {1: {"name": str(SaveManager.profile.name)}}
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
	_register.rpc_id(1, str(SaveManager.profile.name))


func _on_peer_connected(_id: int) -> void:
	if is_host:
		_sync_peers.rpc(peers)


func _on_peer_disconnected(id: int) -> void:
	peers.erase(id)
	peers_changed.emit()
	if is_host:
		_sync_peers.rpc(peers)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	peers[id] = {"name": player_name.substr(0, 16)}
	peers_changed.emit()
	_sync_peers.rpc(peers)


@rpc("authority", "reliable")
func _sync_peers(p: Dictionary) -> void:
	peers = p
	peers_changed.emit()
