extends Node
## "net_host" / "net_client" suites: a real two-process LAN Team Deathmatch over ENet on localhost.
## Run the host and the client as two separate Godot processes (see tests/run_net_test.sh).
## Both players are driven by the autopilot. Each side checks replication from its own point of view
## and prints NET_SCORES so the script can compare the final scores of both processes.

const PORT := 24777

var role := "host"
var passed := 0
var failed := 0
var t := 0.0
var phase := 0
var other_id := 0
var other_start := Vector3.ZERO
var other_max_move := 0.0
var m: Node = null
var saw_net := false
var bot_puppets := 0
var human_tag_ok := false
var last_stats := {}
var my_kills := 0


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  [%s] %s" % [role, name])
	else:
		failed += 1
		print("  FAIL  [%s] %s" % [role, name])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 60          # real time: both processes must run at wall-clock speed
	MatchConfig.fast_test = true
	MatchConfig.autoplay_player = true
	SaveManager.profile.name = "HostHuman" if role == "host" else "ClientHuman"
	if role == "host":
		check(NetworkManager.host(PORT) == OK, "hosting on port %d" % PORT)
	else:
		check(NetworkManager.join("127.0.0.1", PORT) == OK, "joining 127.0.0.1:%d" % PORT)


func _process(delta: float) -> void:
	t += delta
	match phase:
		0:
			if role == "host" and NetworkManager.peers.size() >= 2:
				check(true, "client joined the lobby (%d peers)" % NetworkManager.peers.size())
				check(NetworkManager.start_lan_match("outpost", 12, 75.0), "host started LAN TDM")
				phase = 1
			elif role == "client" and NetworkManager.peers.size() >= 2 and MatchConfig.net.get("active", false):
				check(true, "received match start from host")
				phase = 1
			elif t > 45.0:
				check(false, "lobby connection")
				_done()
		1:
			var cs := get_tree().current_scene
			if cs and cs.get("net") != null and cs.net.started:
				m = cs
				saw_net = true
				check(true, "match scene loaded and started together")
				for id in m.net.by_id.keys():
					if id != m.net.local_id and id > 0:
						other_id = id
				check(other_id != 0, "remote human present as a puppet (peer %d)" % other_id)
				var other: Actor = m.net.by_id.get(other_id)
				if other:
					human_tag_ok = not other.actor_name.contains("[BOT]") and other.actor_name.ends_with("Human")
					other_start = other.global_position
				for a in m.actors:
					if a.actor_name.contains("[BOT]"):
						bot_puppets += 1
				check(human_tag_ok, "remote human labelled by name, not as a bot")
				check(bot_puppets == 8, "8 bots fill the 5v5, all tagged [BOT] (%d)" % bot_puppets)
				check(m.actors.size() == 10, "10 actors on this peer (%d)" % m.actors.size())
				phase = 2
				t = 0.0
			elif t > 60.0:
				check(false, "match started")
				_done()
		2:
			var cs2 := get_tree().current_scene
			if cs2 == m and is_instance_valid(m):
				var other2: Actor = m.net.by_id.get(other_id)
				if other2:
					other_max_move = maxf(other_max_move, other2.global_position.distance_to(other_start))
				last_stats = m.net.stats.duplicate()
				my_kills = m.player.kills
			elif not MatchConfig.last_results.is_empty() and MatchConfig.last_results.get("lan", false):
				_final()
			if t > 150.0:
				check(false, "match finished in time")
				_done()


func _final() -> void:
	var r: Dictionary = MatchConfig.last_results
	check(true, "match ended and results screen reached")
	check(other_max_move > 3.0, "remote player's movement replicated (%.1f m)" % other_max_move)
	check(int(last_stats.get("fx_rx", 0)) > 0, "remote shot effects received (%d)" % int(last_stats.get("fx_rx", 0)))
	if role == "client":
		check(int(last_stats.get("states_rx", 0)) > 100, "state packets received (%d)" % int(last_stats.get("states_rx", 0)))
		check(int(last_stats.get("hits_reported", 0)) > 0, "client hits reported to host (%d)" % int(last_stats.get("hits_reported", 0)))
	else:
		check(int(last_stats.get("hits_accepted", 0)) > 0, "host accepted client hits (%d accepted, %d rejected)" % [int(last_stats.get("hits_accepted", 0)), int(last_stats.get("hits_rejected", 0))])
	var ts: Dictionary = r.get("team_scores", {})
	check(int(ts.get(0, 0)) + int(ts.get(1, 0)) > 0, "kills were scored")
	print("NET_SCORES %s %d-%d" % [role, int(ts.get(0, 0)), int(ts.get(1, 0))])
	print("NET_STATS %s %s kills=%d" % [role, JSON.stringify(last_stats), my_kills])
	_done()


func _done() -> void:
	print("=== RESULT net_%s: %d passed, %d failed ===" % [role, passed, failed])
	NetworkManager.leave()
	get_tree().quit(0 if failed == 0 else 1)
