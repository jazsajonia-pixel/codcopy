extends HBoxContainer
## Lobby (CODM style): season/mission cards on the left, the operator on stage in the middle,
## and the mode card + big START button on the right.

var menu: Control


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var p := SaveManager.profile
	var lobby: String = menu.lobby_type() if menu and menu.has_method("lobby_type") else "mp"
	# ---- Left column: season banner, missions, career
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	var season := UITheme.card(Vector2(0, 96))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	season.add_child(sv)
	sv.add_child(UITheme.label("SEASON 1", 14, UITheme.ACCENT))
	sv.add_child(UITheme.shadowed(UITheme.label("FRONTLINE", 26)))
	sv.add_child(UITheme.label("New: Dockyard, Suburbia, Firebase", 14, UITheme.MUTED))
	left.add_child(season)
	var miss := UITheme.card(Vector2(0, 0), Color(0.4, 0.75, 1.0))
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	miss.add_child(mv)
	mv.add_child(UITheme.label("DAILY MISSIONS", 15, Color(0.55, 0.8, 1.0)))
	var kills := int(p.kills)
	for m in [["Get 10 kills in any mode", mini(kills % 10, 10), 10], ["Play a Gun Game match", 0, 1], ["Land a helicopter in BR", 0, 1]]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		row.add_child(UITheme.label("%s   %d/%d" % [m[0], m[1], m[2]], 14))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 5)
		pb.show_percentage = false
		pb.max_value = m[2]
		pb.value = m[1]
		row.add_child(pb)
		mv.add_child(row)
	left.add_child(miss)
	var car := UITheme.card(Vector2(0, 0), UITheme.GOOD)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	car.add_child(cv)
	var kd := float(p.kills) / maxf(float(p.deaths), 1.0)
	cv.add_child(UITheme.label("CAREER", 15, UITheme.GOOD))
	cv.add_child(UITheme.label("Matches %d    Wins %d" % [p.matches, p.wins], 15))
	cv.add_child(UITheme.label("Kills %d    K/D %.2f" % [p.kills, kd], 15))
	left.add_child(car)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	left.add_child(UITheme.label("Offline: opponents and teammates are AI bots.\nBuild %s" % ErrorLog.BUILD, 12, UITheme.MUTED))
	# ---- Centre: operator on stage
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(mid)
	var prev := OperatorPreview.new()
	prev.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev.custom_minimum_size = Vector2(300, 300)
	mid.add_child(prev)
	var op := GameDB.get_operator(str(p.operator))
	prev.set_operator.call_deferred(op.id, SaveManager.current_loadout().primary)
	var plate := UITheme.shadowed(UITheme.label("%s   |   %s" % [String(op.name).to_upper(), String(op.faction).to_upper()], 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	mid.add_child(plate)
	# ---- Right column: mode card + START
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp2)
	var mode_btn := Button.new()
	mode_btn.focus_mode = Control.FOCUS_NONE
	mode_btn.custom_minimum_size = Vector2(380, 150)
	mode_btn.pressed.connect(func():
		AudioManager.ui("select")
		menu.show_page(lobby))
	var mv2 := VBoxContainer.new()
	mv2.set_anchors_preset(Control.PRESET_FULL_RECT)
	mv2.offset_left = 22
	mv2.offset_top = 12
	mv2.offset_right = -12
	mv2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv2.add_theme_constant_override("separation", 2)
	mode_btn.add_child(mv2)
	var l1: Label
	var l2: Label
	var l3: Label
	if lobby == "br":
		l1 = UITheme.label("BATTLE ROYALE", 15, UITheme.ACCENT)
		l2 = UITheme.label({1: "SOLO", 2: "DUO", 4: "SQUAD"}.get(MatchConfig.br_squad_size, "SOLO") + "   -   %d PLAYERS" % MatchConfig.br_players, 28)
		l3 = UITheme.label("Isla Verde  |  Helicopters, vehicles, 9 POIs", 15, UITheme.MUTED)
	else:
		var mode := lobby_mp_mode()
		var map := lobby_mp_map()
		l1 = UITheme.label("MULTIPLAYER", 15, UITheme.ACCENT)
		l2 = UITheme.label(String(GameDB.MP_MODES[mode].name).to_upper(), 28)
		l3 = UITheme.label(GameDB.MP_MAPS[map].name + "  |  " + str(GameDB.MP_MODES[mode].desc).get_slice(".", 0), 15, UITheme.MUTED)
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [l1, l2, l3]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mv2.add_child(l)
	var chg := UITheme.label("TAP TO CHANGE MODE  >", 13, UITheme.MUTED)
	chg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv2.add_child(chg)
	right.add_child(mode_btn)
	var start := UITheme.cta("START", func(): _start(lobby), Vector2(380, 92))
	right.add_child(start)


static func lobby_mp_mode() -> String:
	var m := str(SaveManager.get_setting("lobby", "mp_mode", "tdm"))
	return m if GameDB.MP_MODES.has(m) else "tdm"


static func lobby_mp_map() -> String:
	var m := str(SaveManager.get_setting("lobby", "mp_map", "outpost"))
	return m if GameDB.MP_MAPS.has(m) else "outpost"


func _start(lobby: String) -> void:
	if lobby == "br":
		MatchConfig.configure_br()
	else:
		MatchConfig.configure_mp(lobby_mp_mode(), lobby_mp_map())
	MatchConfig.start_match()
