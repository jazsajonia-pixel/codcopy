extends Node
## Visual QA director used during development. Renders scripted moments to user://qa/.
##   xvfb-run -s "-screen 0 1280x720x24" godot res://tests/qa_shots.tscn -- <scenario>

var what := "scope"
var t := 0.0
var dir := ""
var step := 0
var st := 0.0


func _ready() -> void:
	if not has_meta("worker"):
		var w: Node = (get_script() as Script).new()
		w.set_meta("worker", true)
		get_tree().root.add_child.call_deferred(w)
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		what = a[0]
	dir = OS.get_user_data_dir().path_join("qa")
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := OS.get_user_data_dir().path_join("qa_tmp")
	DirAccess.make_dir_recursive_absolute(tmp)
	SaveManager.save_dir_override = tmp
	SaveManager.load_all()
	SaveManager.profile.level = 50
	SaveManager.set_setting("controls", "scheme", "touch")
	MatchConfig.fast_test = true
	var parts := what.split(":")
	var kind := parts[0]
	match kind:
		"menu":
			get_tree().change_scene_to_file.call_deferred("res://scenes/menus/main_menu.tscn")
		"mp":
			MatchConfig.configure_mp(parts[1] if parts.size() > 1 else "tdm", parts[2] if parts.size() > 2 else "outpost")
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		"over":
			MatchConfig.configure_mp(parts[2] if parts.size() > 2 else "tdm", parts[1])
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		"sights":
			MatchConfig.configure_mp("tdm", "outpost")
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		"medal":
			MatchConfig.configure_mp("tdm", "dockyard")
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		"scope":
			MatchConfig.configure_mp("tdm", "outpost")
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		"br", "drop", "heli":
			MatchConfig.configure_br()
			MatchConfig.br_players = 8
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
		_:
			MatchConfig.configure_mp("tdm", "outpost")
			get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())


func snap(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var p: String = dir.path_join(n + ".png")
	img.save_png(p)
	print("SHOT ", p)


func _process(delta: float) -> void:
	t += delta
	if int(t*2) != int((t-delta)*2): print("t=", snappedf(t,0.1), " fps=", Engine.get_frames_per_second(), " step=", step)
	var m = get_tree().current_scene
	var kind := what.split(":")[0]
	if kind == "menu":
		if t > 1.5 and step == 0:
			step = 1
			var pages := what.split(":")
			if pages.size() > 1 and m.has_method("show_page"):
				m.show_page(pages[1])
		if t > 3.0:
			snap(what.replace(":", "_"))
			get_tree().quit()
		return
	if m == null or m.get("player") == null or m.player == null:
		return
	var p: Player = m.player
	p.invulnerable_time = 99.0
	if has_method("_s_" + kind):
		call("_s_" + kind, m, p)
	elif t > 8.0:
		snap(what.replace(":", "_"))
		get_tree().quit()
	if t > 120.0:
		get_tree().quit()


## Map overview: elevated orbit camera (over:<map>[:mode]).
func _s_over(m, p: Player) -> void:
	if step == 0 and t > 5.0:
		var cam := Camera3D.new()
		m.add_child(cam)
		var r: Rect2 = m.map.bounds
		var ext := maxf(r.size.x, r.size.y)
		cam.global_position = Vector3(r.get_center().x + ext * 0.35, ext * 0.62, r.get_center().y + ext * 0.75)
		cam.look_at(Vector3(r.get_center().x, 0, r.get_center().y))
		cam.fov = 60
		cam.far = 600
		cam.current = true
		st = t
		step = 1
	elif step == 1 and t - st > 0.8:
		snap(what.replace(":", "_"))
		get_tree().quit()


func _s_medal(m, p: Player) -> void:
	if step == 0 and t > 4.0:
		var mf: MedalFeed = m.hud.medal_feed
		mf.medal("DOUBLE KILL", Color(1.0, 0.45, 0.2))
		mf.medal("HEADSHOT", Color(1.0, 0.3, 0.25))
		mf.medal("LONGSHOT", Color(0.4, 0.8, 1.0))
		mf.popup("+100  ENEMY KILLED")
		mf.popup("+50  DOUBLE KILL")
		mf.popup("+50  HEADSHOT")
		mf.eliminated("Viper [BOT]")
		st = t
		step = 1
	elif step == 1 and t - st > 0.6:
		snap("medal")
		get_tree().quit()


## BR helicopter: skip the drop, board the airfield helicopter, climb and fly forward.
var heli_ref: Helicopter
func _s_heli(m, p: Player) -> void:
	if step == 0 and t > 3.0:
		m._drop_player()
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v is Helicopter:
				heli_ref = v
				break
		p.parachute_state = 0
		p.global_position = heli_ref.global_position + Vector3(4, 1, 0)
		p.velocity = Vector3.ZERO
		step = 1
		st = t
	elif step == 1 and t - st > 1.0:
		heli_ref.enter(p, 0)
		Input.action_press("jump")
		step = 2
		st = t
	elif step == 2:
		p.input.move = Vector2(0, -0.6) if t - st > 5.0 else Vector2.ZERO
		if t - st > 3.0 and t - st < 3.1:
			snap("heli_takeoff")
		if t - st > 8.0:
			Input.action_release("jump")
			print("HELI alt=", heli_ref.altitude(), " speed=", heli_ref.linear_velocity.length(), " hp=", heli_ref.health)
			snap("heli_flying")
			get_tree().quit()


## ADS through every non-magnified sight: sights[:id,id...] (weapon/optic pairs).
var sight_jobs := [["ar_m4k", ""], ["ar_m4k", "red_dot"], ["ar_m4k", "holo"], ["smg_vx", ""], ["pistol_p9", ""], ["sg_breacher", ""], ["ar_k47", "red_dot"], ["dmr_skr", ""], ["lmg_rpv", ""], ["smg_hornet", "holo"]]
var sight_i := 0
func _s_sights(m, p: Player) -> void:
	if step == 0 and OS.get_environment("QA_SIGHTS") != "" and sight_i == 0 and t < 0.1:
		sight_jobs = []
		for j in OS.get_environment("QA_SIGHTS").split(","):
			sight_jobs.append([j.get_slice(":", 0), j.get_slice(":", 1)])
	if step == 0:
		if t > 4.0 and p.is_on_floor():
			step = 1
		return
	if step == 1:
		var j: Array = sight_jobs[sight_i]
		var att := {} if j[1] == "" else {"optic": j[1]}
		p.inv.set_weapon(0, WeaponInstance.create(j[0], att, "default", true))
		p.inv.current = 1
		p.inv.switch_to(0)
		p.ads_on = false
		p.pitch = -0.02
		st = t
		step = 2
	elif step == 2 and t - st > 0.9:
		p.ads_on = true
		st = t
		step = 3
	elif step == 3 and t - st > 1.0:
		var j2: Array = sight_jobs[sight_i]
		snap("sight_%s_%s" % [j2[0], j2[1] if j2[1] != "" else "iron"])
		sight_i += 1
		if sight_i >= sight_jobs.size():
			get_tree().quit()
		step = 1


func _s_scope(m, p: Player) -> void:
	match step:
		0:
			if t > 4.0:
				step = 1
		1:
			if p.is_on_floor():
				p.inv.use_ammo_pools = false
				p.inv.ammo.sniper = 20
				p.inv.ammo.rifle = 120
				p.inv.set_weapon(0, WeaponInstance.create("sniper_ls7", {}, "default", true))
				p.inv.set_weapon(1, WeaponInstance.create("ar_m4k", {"optic": "scope_4x"}, "default", true))
				p.inv.current = 1
				p.inv.switch_to(0)
				p.pitch = -0.05
				st = t
				step = 2
		2:
			if t - st > 1.0:
				snap("scope_hip")
				p.ads_on = true
				st = t
				step = 3
		3:
			if t - st > 1.2:
				snap("scope_sniper_ads")
				p.ads_on = false
				p.select_slot(1)
				st = t
				step = 4
		4:
			if t - st > 1.0:
				p.ads_on = true
				st = t
				step = 5
		5:
			if t - st > 1.2:
				snap("scope_4x_ads")
				get_tree().quit()
