extends Node
## Visual QA helper (needs a display, e.g. xvfb-run). Captures PNGs to user://shots/.
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 res://tests/screenshot.tscn -- menu|tdm|br|loadout|settings|hud_editor|results

var what := "menu"
var t := 0.0
var shots: Array = []   # [time, name]
var idx := 0
var dir := ""


func _ready() -> void:
	if not has_meta("worker"):
		# The scene root gets freed by scene changes; hand the work to a node that lives under /root.
		var w: Node = (get_script() as Script).new()
		w.set_meta("worker", true)
		get_tree().root.add_child.call_deferred(w)
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		what = a[0]
	dir = OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := OS.get_user_data_dir().path_join("shot_tmp")
	DirAccess.make_dir_recursive_absolute(tmp)
	SaveManager.save_dir_override = tmp
	SaveManager.load_all()
	SaveManager.profile.level = 8
	match what:
		"menu", "loadout", "settings", "operators", "br_page":
			shots = [[1.5, what]]
		"hud_editor":
			shots = [[1.0, what]]
		"tdm", "touch":
			MatchConfig.autoplay_player = what == "tdm"
			MatchConfig.fast_test = true
			if what == "touch":
				SaveManager.set_setting("controls", "scheme", "touch")
			MatchConfig.configure_mp("tdm", "outpost")
			shots = [[9.0, what + "_a"], [16.0, what + "_b"]]
		"crossroads":
			MatchConfig.autoplay_player = true
			MatchConfig.fast_test = true
			MatchConfig.configure_mp("ffa", "crossroads")
			shots = [[10.0, "crossroads_a"], [18.0, "crossroads_b"]]
		"br":
			MatchConfig.autoplay_player = true
			MatchConfig.fast_test = true
			MatchConfig.configure_br()
			MatchConfig.br_players = 10
			shots = [[2.5, "br_plane"], [6.5, "br_chute"], [16.0, "br_ground"], [30.0, "br_ground2"]]
		"drive":
			MatchConfig.autoplay_player = true
			MatchConfig.fast_test = true
			MatchConfig.configure_br()
			MatchConfig.br_players = 8
			shots = [[16.0, "drive_a"], [18.5, "drive_b"]]
		"results":
			MatchConfig.last_results = {"mode": "tdm", "won": true, "kills": 12, "deaths": 4, "assists": 3, "score": 1450, "headshots": 4, "accuracy": 0.31,
				"team_scores": {0: 40, 1: 33}, "duration": 312.0, "rewards": {"xp": 1850, "credits": 270, "levels": [9]},
				"scoreboard": [{"name": "Recruit", "team": 0, "kills": 12, "deaths": 4, "assists": 3, "score": 1450, "is_player": true, "alive": true},
					{"name": "Hawk", "team": 1, "kills": 9, "deaths": 7, "assists": 2, "score": 1000, "is_player": false, "alive": true}]}
			shots = [[1.0, what]]
	_open.call_deferred()


func _open() -> void:
	match what:
		"menu", "loadout", "settings", "operators", "br_page":
			get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
		"hud_editor":
			get_tree().change_scene_to_file("res://scenes/menus/hud_editor.tscn")
		"results":
			get_tree().change_scene_to_file("res://scenes/menus/results.tscn")
		_:
			get_tree().change_scene_to_file(MatchConfig.match_scene())


func _process(delta: float) -> void:
	t += delta
	if what in ["loadout", "settings", "operators", "br_page"] and t > 0.6 and t < 0.7:
		var cs := get_tree().current_scene
		if cs and cs.has_method("show_page"):
			cs.show_page({"br_page": "br"}.get(what, what))
	if what == "drive":
		var m = get_tree().current_scene
		if m and m.get("vehicles") and m.player and m.player.parachute_state == 0 and m.phase >= 2:
			var p: Player = m.player
			if p.vehicle == null and p.alive and p.is_on_floor() and not has_meta("entered"):
				set_meta("entered", true)
				MatchConfig.autoplay_player = false
				var v: Vehicle = m.vehicles[0]
				p.global_position = v.global_position + Vector3(3, 0.5, 0)
				print("  entering ", v.kind, " at ", v.global_position, " hp ", v.health, " alive ", v.alive)
				p.died.connect(func(_a, k, w, _h): print("  PLAYER DIED by ", k, " with ", w, " at ", p.global_position))
				p.invulnerable_time = 999.0
				v.enter(p)
			if p.vehicle:
				p.input.move = Vector2(-0.25, -1.0)
				p.input.look = Vector2.ZERO
	if idx < shots.size() and t >= shots[idx][0]:
		var img := get_viewport().get_texture().get_image()
		var p: String = dir.path_join(shots[idx][1] + ".png")
		img.save_png(p)
		print("SHOT ", p)
		var cs := get_tree().current_scene
		if cs and cs.get("chute_mesh"):
			print("  chute_vis=", cs.chute_mesh.visible, " state=", cs.player.parachute_state, " zone_vis=", cs.zone_wall.visible, " phase=", cs.phase, " r=", cs.zone.radius, " pos=", cs.player.global_position)
		idx += 1
		if idx >= shots.size():
			get_tree().quit()
