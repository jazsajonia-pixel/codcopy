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
