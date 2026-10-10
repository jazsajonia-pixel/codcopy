extends Node
## Holds the parameters of the next/current match and the results of the last one.
## Menus write here, match scenes read from here.

const LOADING_SCENE := "res://scenes/menus/loading.tscn"
const RESULTS_SCENE := "res://scenes/menus/results.tscn"
const MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const BR_SCENE := "res://scenes/battle_royale/br_match.tscn"
const MP_SCENE := "res://scenes/multiplayer/mp_match.tscn"

var mode := "tdm"            ## tdm | ffa | br
var map_id := "outpost"
var score_limit := 40
var time_limit := 480.0
var team_size := 5
var ffa_players := 8
var br_players := 16
var br_squad_size := 1
## LAN match description from NetworkManager ({} when offline):
## {active, teams: {peer_id: team}, names: {peer_id: name}, ops: {peer_id: operator}, slot: {peer_id: spawn index}}
var net := {}        ## 1 solo, 2 duo, 4 squad (AI teammates)
var bot_difficulty := "normal"
var last_results := {}

## Test/automation hooks (never set by the UI).
var autoplay_player := false   ## player is driven by bot AI (used by headless tests)
var fast_test := false


func configure_mp(p_mode: String, p_map: String) -> void:
	net = {}
	mode = p_mode
	map_id = p_map
	var m: Dictionary = GameDB.MP_MODES[p_mode]
	score_limit = m.score_limit
	time_limit = m.time_limit
	team_size = m.get("team_size", 5)
	ffa_players = m.get("players", 8)
	bot_difficulty = SaveManager.get_setting("bots", "difficulty", "normal")


func configure_br() -> void:
	net = {}
	mode = "br"
	map_id = "isla"
	bot_difficulty = SaveManager.get_setting("bots", "difficulty", "normal")


func match_scene() -> String:
	return BR_SCENE if mode == "br" else MP_SCENE


func start_match() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LOADING_SCENE)


func finish_match(results: Dictionary) -> void:
	last_results = results
	last_results["rewards"] = SaveManager.record_match(results)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(RESULTS_SCENE)


func to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


func difficulty_params() -> Dictionary:
	match bot_difficulty:
		"easy":
			return {"reaction": 0.75, "aim_error_deg": 5.0, "fov_deg": 100.0, "view_dist": 45.0, "aggression": 0.4, "burst": 0.35, "track_speed": 3.0}
		"hard":
			return {"reaction": 0.32, "aim_error_deg": 1.8, "fov_deg": 130.0, "view_dist": 75.0, "aggression": 0.8, "burst": 0.75, "track_speed": 7.0}
		_:
			return {"reaction": 0.5, "aim_error_deg": 3.2, "fov_deg": 115.0, "view_dist": 60.0, "aggression": 0.6, "burst": 0.55, "track_speed": 5.0}
