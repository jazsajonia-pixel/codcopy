extends Node
## Automated tests. Run headless from the project folder:
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- unit
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn -- tdm | ffa | br | touch | menus | flow
## Exit code 0 = pass. Match tests drive the player with the bot AI ("autoplay") and short limits.

var mode := "unit"
var passed := 0
var failed := 0
var log_lines: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	var tmp := OS.get_user_data_dir().path_join("test_tmp")
	DirAccess.make_dir_recursive_absolute(tmp)
	for f in ["settings.cfg", "profile.json"]:
		if FileAccess.file_exists(tmp.path_join(f)):
			DirAccess.remove_absolute(tmp.path_join(f))
	SaveManager.save_dir_override = tmp
	SaveManager.load_all()
	Engine.max_fps = 0
	print("=== TEST MODE: %s ===" % mode)
	match mode:
		"unit":
			await _unit()
			_finish()
		"tdm", "ffa", "br", "br_squad", "touch":
			_start_match_test()
		"net_host", "net_client":
			var nt: Node = load("res://tests/net_test.gd").new()
			nt.role = mode.substr(4)
			get_tree().root.add_child.call_deferred(nt)
		"phone":
			get_tree().root.add_child.call_deferred(load("res://tests/phone_test.gd").new())
		"moves":
			get_tree().root.add_child.call_deferred(load("res://tests/moves_test.gd").new())
		"keys":
			get_tree().root.add_child.call_deferred(load("res://tests/keys_test.gd").new())
		"dom":
			get_tree().root.add_child.call_deferred(load("res://tests/dom_test.gd").new())
		"squad":
			get_tree().root.add_child.call_deferred(load("res://tests/squad_test.gd").new())
		"vehicle":
			get_tree().root.add_child.call_deferred(load("res://tests/vehicle_test.gd").new())
		"flow":
			var ft: Node = load("res://tests/flow_test.gd").new()
			get_tree().root.add_child.call_deferred(ft)
		"menus":
			await _menus()
			_finish()
		_:
			print("Unknown mode " + mode)
			get_tree().quit(2)


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _finish() -> void:
	print("=== RESULT %s: %d passed, %d failed ===" % [mode, passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


# ---------------------------------------------------------------- unit

func _unit() -> void:
	# Weapon data
	check(GameDB.weapons.size() >= 10, "weapon database loaded (%d weapons)" % GameDB.weapons.size())
	for id in GameDB.weapons.keys():
		var w := GameDB.get_weapon(id)
		check(ResourceLoader.exists(w.model_path) and ResourceLoader.exists(w.fire_sound), "weapon %s has model and sound" % id)
		for slot in w.allowed_attachments.keys():
			for a in w.allowed_attachments[slot]:
				if not GameDB.ATTACHMENTS.has(a) or GameDB.ATTACHMENTS[a].slot != slot:
					check(false, "weapon %s attachment %s valid for slot %s" % [id, a, slot])
	# Attachments modify stats; disallowed attachments are ignored.
	var base := GameDB.build_stats("ar_m4k")
	var ext := GameDB.build_stats("ar_m4k", {"magazine": "extended_mag"})
	check(ext.mag_size == int(round(base.mag_size * 1.5)), "extended mag x1.5 (%d -> %d)" % [base.mag_size, ext.mag_size])
	var comp := GameDB.build_stats("ar_m4k", {"muzzle": "compensator"})
	check(comp.recoil_vertical < base.recoil_vertical, "compensator reduces vertical recoil")
	var bad := GameDB.build_stats("pistol_p9", {"optic": "scope_8x"})
	check(bad.optic != "8x", "disallowed attachment ignored")
	var sup := GameDB.build_stats("ar_m4k", {"muzzle": "suppressor"})
	check(sup.suppressed == true, "suppressor flag set")
	# Fire rate & magazine
	var wi := WeaponInstance.create("ar_m4k")
	var shots := 0
	var t := 0.0
	while t < 1.0:
		if wi.try_fire(true):
			shots += 1
		wi.tick(1.0 / 120.0)
		t += 1.0 / 120.0
	var expected := int(GameDB.get_weapon("ar_m4k").fire_rate_rpm / 60.0)
	check(absi(shots - expected) <= 2, "auto fire rate ~%d rps (got %d)" % [expected, shots])
	var semi := WeaponInstance.create("pistol_p9")
	var s2 := 0
	for i in 60:
		if semi.try_fire(true):
			s2 += 1
		semi.tick(0.05)
	check(s2 == 1, "semi-auto fires once per trigger pull")
	# Reload from reserve
	var r := WeaponInstance.create("smg_vx")
	var res_before := r.get_reserve()
	r.mag = 3
	r.start_reload()
	for i in 400:
		r.tick(0.01)
	check(r.mag == r.mag_size() and r.get_reserve() == res_before - (r.mag_size() - 3), "reload moves reserve into magazine")
	# Damage falloff
	var st := GameDB.build_stats("smg_vx")
	check(is_equal_approx(Combat._damage_at(st, 1.0), st.damage), "full damage inside effective range")
	check(Combat._damage_at(st, st.max_range + 10) < st.damage, "damage falls off past effective range")
	# Inventory / BR ammo pools
	var inv := Inventory.new()
	inv.use_ammo_pools = true
	check(inv.add_ammo("rifle", 1000) == Inventory.MAX_AMMO.rifle, "ammo pool capped")
	var w1 := WeaponInstance.create("ar_m4k", {}, "default", false)
	var w2 := WeaponInstance.create("smg_vx", {}, "default", false)
	var w3 := WeaponInstance.create("sniper_ls7", {}, "default", false)
	check(inv.pick_up_weapon(w1) == null and inv.pick_up_weapon(w2) == null, "two weapon slots fill")
	var dropped := inv.pick_up_weapon(w3)
	check(dropped == w2 and inv.active() == w3, "third weapon swaps with active one")
	check(w3.get_reserve() == 0 and inv.add_ammo("sniper", 10) == 10 and w3.get_reserve() == 10, "weapon reserve reads shared pool")
	check(inv.add_heal("bandage", 99) == GameDB.BR_ITEMS.bandage.get("max_stack", 5), "heal stack capped")
	# Progression & save
	var prof_before := int(SaveManager.profile.level)
	var lv := SaveManager.add_xp(SaveManager.xp_for_next(prof_before) + 10)
	check(lv.size() == 1 and int(SaveManager.profile.level) == prof_before + 1 and int(SaveManager.profile.xp) == 10, "level up with XP carry-over")
	var rw := SaveManager.record_match({"kills": 5, "deaths": 2, "won": true, "score": 600})
	check(rw.xp > 0 and rw.credits > 0, "match rewards XP and credits")
	SaveManager.profile.name = "TestUser"
	SaveManager.profile.loadouts[1].primary = "lmg_rpv"
	SaveManager.save_profile()
	SaveManager.set_setting("controls", "look_sensitivity", 1.7)
	SaveManager.settings.hud_layout = {"fire": {"x": 0.5, "y": 0.5, "size": 150.0, "opacity": 0.4, "visible": true}}
	SaveManager.save_settings()
	SaveManager.profile = {}
	SaveManager.settings = {}
	SaveManager.load_all()
	check(SaveManager.profile.name == "TestUser" and SaveManager.profile.loadouts[1].primary == "lmg_rpv", "profile & loadout persist")
	check(is_equal_approx(float(SaveManager.get_setting("controls", "look_sensitivity")), 1.7), "settings persist")
	check(float(SaveManager.settings.hud_layout.fire.size) == 150.0, "HUD layout persists")
	# Match rules
	var mr := MatchRules.new()
	mr.setup("tdm", 3, 100.0)
	var fin := [-2]
	mr.finished.connect(func(wt): fin[0] = wt)
	for i in 3:
		mr.register_kill(1, 0, 7)
	check(mr.over and fin[0] == 1, "TDM ends at score limit with correct winner")
	var mf := MatchRules.new()
	mf.setup("ffa", 2, 100.0)
	mf.register_kill(4, 5, 4)
	check(not mf.over, "FFA not over before limit")
	mf.register_kill(4, 6, 4)
	check(mf.over, "FFA ends when one player reaches limit")
	var mt := MatchRules.new()
	mt.setup("tdm", 50, 5.0)
	mt.register_kill(0, 1, 1)
	for i in 10:
		mt.tick(1.0)
	check(mt.over and mt.winner == 0, "TDM time limit picks leader")
	# Safe zone
	var z := SafeZone.new()
	z.setup(Vector2.ZERO, 190.0, 0.1, 1234)
	var radii: Array = []
	for i in 2000:
		z.tick(0.05)
		if i % 100 == 0:
			radii.append(z.radius)
	var mono := true
	for i in range(1, radii.size()):
		if radii[i] > radii[i - 1] + 0.001:
			mono = false
	check(mono, "zone radius never grows")
	check(z.done and z.radius < 1.0, "zone reaches final circle")
	check(z.is_outside(z.center + Vector2(50, 0)), "point outside final zone detected")
	check(z.dps() > 1.0, "late zone damage higher")
	# Actor damage with armor (no tree needed for the math path).
	var a := Actor.new()
	var b := Actor.new()
	a.team = 0
	b.team = 1
	b.max_armor = 100.0
	b.armor = 100.0
	add_child(a)
	add_child(b)
	await get_tree().process_frame
	b.take_damage(40.0, a, "Test")
	check(is_equal_approx(b.health, 90.0) and is_equal_approx(b.armor, 70.0), "armor absorbs 75%% (hp %.0f armor %.0f)" % [b.health, b.armor])
	var c := Actor.new()
	c.team = 1
	add_child(c)
	await get_tree().process_frame
	check(not c.take_damage(30.0, b, "Test") and is_equal_approx(c.health, 100.0), "no friendly fire")
	a.queue_free()
	b.queue_free()
	c.queue_free()
	# Every setting exposed in the settings page exists in defaults.
	var page: Node = load("res://scripts/ui/pages/settings_page.gd").new()
	add_child(page)
	await get_tree().process_frame
	check(page.tabs.get_tab_count() == 5, "settings page builds 5 tabs")
	page.queue_free()


# ---------------------------------------------------------------- menus

func _menus() -> void:
	var menu: Control = load("res://scenes/menus/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	for p in ["home", "mp", "br", "loadout", "operators", "settings", "online", "profile", "credits"]:
		menu.show_page(p)
		await get_tree().process_frame
		await get_tree().process_frame
		check(menu.content.get_child_count() > 0, "menu page '%s' opens" % p)
	# Loadout: change primary + attachment through the page API and confirm persistence.
	menu.show_page("loadout")
	await get_tree().process_frame
	var lp: Node = menu.content.get_child(menu.content.get_child_count() - 1)
	lp._select_slot("primary")
	lp._choose("smg_kr")
	check(SaveManager.current_loadout().primary == "smg_kr", "loadout weapon selection saved")
	# BR page: the squad buttons set the squad size used by the next match.
	menu.show_page("br")
	await get_tree().process_frame
	var bp: Node = menu.content.get_child(menu.content.get_child_count() - 1)
	bp.squad_buttons[4].pressed.emit()
	check(MatchConfig.br_squad_size == 4 and bp.squad_buttons[4].button_pressed, "BR SQUAD button selects squads of 4")
	bp.squad_buttons[1].pressed.emit()
	check(MatchConfig.br_squad_size == 1, "BR SOLO button selects solo")
	# LAN lobby host/leave (real ENet socket on localhost).
	menu.show_page("online")
	await get_tree().process_frame
	var op: Node = menu.content.get_child(menu.content.get_child_count() - 1)
	var err := NetworkManager.host(24999)
	check(err == OK and NetworkManager.is_online(), "LAN host starts")
	await get_tree().process_frame
	check(op.start_btn.visible and op.start_btn.disabled, "LAN START shown to host, disabled until someone joins")
	op.map_btns["crossroads"].pressed.emit()
	check(op.lan_map == "crossroads", "LAN map selection works")
	check(not NetworkManager.start_lan_match(), "LAN match can't start with only the host")
	NetworkManager.leave()
	check(not NetworkManager.is_online(), "LAN leave")
	menu.queue_free()
	var ed: Control = load("res://scenes/menus/hud_editor.tscn").instantiate()
	add_child(ed)
	await get_tree().process_frame
	ed.touch.selected = "fire"
	ed.touch.layout.fire.size = 200.0
	ed.touch.save_layout()
	check(float(SaveManager.settings.hud_layout.fire.size) == 200.0, "HUD editor saves resized button")
	ed.touch.reset_layout()
	check(SaveManager.settings.hud_layout.is_empty(), "HUD editor reset")
	ed.queue_free()


# ---------------------------------------------------------------- matches

func _start_match_test() -> void:
	var watcher: Node = load("res://tests/match_watcher.gd").new()
	watcher.mode = "br" if mode == "br_squad" else mode
	watcher.name = "MatchWatcher"
	get_tree().root.add_child.call_deferred(watcher)
	MatchConfig.fast_test = true
	MatchConfig.autoplay_player = mode != "touch"
	SaveManager.set_setting("bots", "difficulty", "normal")
	if mode == "br" or mode == "br_squad":
		MatchConfig.configure_br()
		MatchConfig.br_players = 12 if mode == "br_squad" else 10
		MatchConfig.br_squad_size = 4 if mode == "br_squad" else 1
	else:
		MatchConfig.configure_mp("ffa" if mode == "ffa" else "tdm", "crossroads" if mode == "ffa" else "outpost")
		MatchConfig.score_limit = 12 if mode == "tdm" else 6
		MatchConfig.time_limit = 150.0
	if mode == "touch":
		SaveManager.set_setting("controls", "scheme", "touch")
	get_tree().change_scene_to_file.call_deferred(MatchConfig.match_scene())
