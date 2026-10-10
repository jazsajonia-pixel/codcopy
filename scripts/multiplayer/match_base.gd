class_name MatchBase
extends Node3D
## Shared match plumbing for Multiplayer and Battle Royale:
## spawning, kill feed, hearing propagation, radar pings, pause and results.

signal kill_feed(killer_name: String, victim_name: String, weapon: String, headshot: bool, involves_player: int)
signal announcement(text: String, sub: String)

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BOT_SCENE := preload("res://scenes/enemies/bot.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var map: GameMap
var player: Player
var bots: Array = []
var actors: Array = []
var hud: Node
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var ended := false
var radar_pings := {}   ## Actor -> time left visible on radar (fired unsuppressed)
var used_names := {}


func _ready() -> void:
	rng.randomize()
	Effects.clear()
	process_mode = Node.PROCESS_MODE_PAUSABLE


func load_map(path: String) -> void:
	map = load(path).instantiate()
	add_child(map)


func spawn_player(team: int) -> Player:
	player = PLAYER_SCENE.instantiate()
	player.team = team
	player.actor_name = SaveManager.profile.name
	player.operator_id = SaveManager.profile.operator
	add_child(player)
	_register(player)
	hud = HUD_SCENE.instantiate()
	hud.match_node = self
	hud.player = player
	add_child(hud)
	return player


func spawn_bot(team: int, operator_id := "") -> Bot:
	var bot: Bot = BOT_SCENE.instantiate()
	if operator_id == "":
		operator_id = GameDB.OPERATORS[rng.randi() % GameDB.OPERATORS.size()].id
	bot.setup(_unique_name(), team, operator_id, MatchConfig.difficulty_params())
	bot.match_node = self
	add_child(bot)
	_register(bot)
	bots.append(bot)
	return bot


func _unique_name() -> String:
	for i in 50:
		var n: String = Bot.NAMES[rng.randi() % Bot.NAMES.size()]
		if not used_names.has(n):
			used_names[n] = true
			return n
	return "Bot%d" % rng.randi_range(100, 999)


func _register(a: Actor) -> void:
	actors.append(a)
	a.died.connect(_on_actor_died)
	a.knocked.connect(_on_actor_knocked)
	a.shot_fired.connect(_on_shot_fired)


func _on_shot_fired(a: Actor, suppressed: bool) -> void:
	if suppressed:
		return
	radar_pings[a] = 2.0
	for b in bots:
		if b != a and b.alive and b.global_position.distance_to(a.global_position) < 45.0:
			b.hear(a)


func _on_actor_died(victim: Actor, killer: Actor, weapon_name: String, headshot: bool) -> void:
	var kname := killer.actor_name if killer else ""
	if killer and killer != victim:
		killer.kills += 1
		killer.streak += 1
		killer.score += 100 + (25 if headshot else 0)
		if headshot:
			killer.headshot_kills += 1
	var inv := 0
	if killer == player:
		inv = 1
		player.killed_enemy.emit(victim, headshot)
		AudioManager.play_2d("res://assets/audio/sfx/killconfirm.ogg", -4.0)
	elif victim == player:
		inv = -1
		player.set_death_cam_target(killer)
	kill_feed.emit(kname, victim.actor_name, weapon_name, headshot, inv)
	on_kill(victim, killer)


func _on_actor_knocked(victim: Actor, attacker: Actor, weapon_name: String) -> void:
	var inv := 1 if attacker == player else (-1 if victim == player else 0)
	if attacker:
		attacker.score += 50
	kill_feed.emit(attacker.actor_name if attacker else "", victim.actor_name + " (knocked)", weapon_name, false, inv)
	on_knock(victim, attacker)


## Override in subclasses.
func on_knock(_victim: Actor, _attacker: Actor) -> void:
	pass


## Override in subclasses.
func on_kill(_victim: Actor, _killer: Actor) -> void:
	pass


func _process(delta: float) -> void:
	elapsed += delta
	for a in radar_pings.keys():
		radar_pings[a] -= delta
		if radar_pings[a] <= 0.0 or not is_instance_valid(a):
			radar_pings.erase(a)
	# Name tags: enemies only when the player's crosshair is on them.
	if player:
		for b in bots:
			b.set_tag_style(not player.is_enemy(b), player.aim_assist_target == b)


func random_patrol_point(_bot: Bot) -> Vector3:
	var p := map.random_patrol(rng) + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)


func toggle_pause() -> void:
	if ended:
		return
	get_tree().paused = not get_tree().paused
	if hud:
		hud.show_pause(get_tree().paused)
	if get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func player_stats() -> Dictionary:
	return {"kills": player.kills, "deaths": player.deaths, "assists": player.assists, "score": player.score,
		"headshots": player.headshot_kills, "accuracy": clampf(float(player.shots_hit) / maxf(float(player.shots_fired), 1.0), 0.0, 1.0)}


func scoreboard() -> Array:
	var rows: Array = []
	for a in actors:
		rows.append({"name": a.actor_name, "team": a.team, "kills": a.kills, "deaths": a.deaths, "assists": a.assists, "score": a.score, "is_player": a.is_player, "alive": a.alive})
	rows.sort_custom(func(x, y): return x.score > y.score)
	return rows
