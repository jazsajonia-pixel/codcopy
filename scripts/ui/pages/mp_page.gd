extends HBoxContainer
## Multiplayer mode + map select (CODM style cards). The selection is remembered for the lobby START.

var menu: Control
var mode := "tdm"
var map_id := "outpost"
var mode_buttons := {}
var map_buttons := {}
var info: Label


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	mode = preload("res://scripts/ui/pages/home_page.gd").lobby_mp_mode()
	map_id = preload("res://scripts/ui/pages/home_page.gd").lobby_mp_map()
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(left)
	left.add_child(UITheme.label("MODE", 16, UITheme.MUTED))
	var mgrid := GridContainer.new()
	mgrid.columns = 4
	mgrid.add_theme_constant_override("h_separation", 10)
	mgrid.add_theme_constant_override("v_separation", 10)
	left.add_child(mgrid)
	for id in GameDB.MP_MODES.keys():
		var b := _card_button(String(GameDB.MP_MODES[id].name).to_upper(), _mode_tag(id), func(): _set_mode(id), Vector2(210, 76))
		mgrid.add_child(b)
		mode_buttons[id] = b
	left.add_child(UITheme.label("MAP", 16, UITheme.MUTED))
	var mapgrid := GridContainer.new()
	mapgrid.columns = 4
	mapgrid.add_theme_constant_override("h_separation", 10)
	mapgrid.add_theme_constant_override("v_separation", 10)
	left.add_child(mapgrid)
	for id in GameDB.MP_MAPS.keys():
		var b := _card_button(String(GameDB.MP_MAPS[id].name).to_upper(), "", func(): _set_map(id), Vector2(210, 60))
		mapgrid.add_child(b)
		map_buttons[id] = b
	left.add_child(UITheme.label("BOT DIFFICULTY", 16, UITheme.MUTED))
	left.add_child(DifficultyRow.make())
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	add_child(right)
	var card := UITheme.card(Vector2(360, 0))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info = UITheme.label("", 17, UITheme.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(info)
	right.add_child(card)
	var launch := UITheme.cta("START", _start, Vector2(360, 88))
	right.add_child(launch)
	_set_mode(mode)
	_set_map(map_id)


func _mode_tag(id: String) -> String:
	var m: Dictionary = GameDB.MP_MODES[id]
	return "%d PLAYERS FFA" % m.players if m.has("players") else "%dv%d" % [m.get("team_size", 5), m.get("team_size", 5)]


func _card_button(title: String, sub: String, cb: Callable, sz: Vector2) -> Button:
	var b := UITheme.button("", cb, sz, "select")
	b.toggle_mode = true
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var t := UITheme.label(title, 18)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if sub != "":
		var s := UITheme.label(sub, 13, UITheme.MUTED)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	b.add_child(v)
	b.toggled.connect(func(on: bool):
		t.add_theme_color_override("font_color", Color(0.08, 0.08, 0.06) if on else UITheme.TEXT))
	return b


func _set_mode(id: String) -> void:
	mode = id
	SaveManager.set_setting("lobby", "mp_mode", id)
	for k in mode_buttons.keys():
		mode_buttons[k].button_pressed = k == id
	_update()


func _set_map(id: String) -> void:
	map_id = id
	SaveManager.set_setting("lobby", "mp_map", id)
	for k in map_buttons.keys():
		map_buttons[k].button_pressed = k == id
	_update()


func _update() -> void:
	if info == null:
		return
	var m: Dictionary = GameDB.MP_MODES[mode]
	info.text = "%s\n%s\n\nScore limit %d  |  %d min\n\n%s\n%s\n\nLoadout: primary weapon + melee + lethal + tactical. Teammates and opponents are AI bots." % [
		String(m.name).to_upper(), m.desc, m.score_limit, int(m.time_limit / 60), String(GameDB.MP_MAPS[map_id].name).to_upper(), GameDB.MP_MAPS[map_id].desc]


func _start() -> void:
	MatchConfig.configure_mp(mode, map_id)
	MatchConfig.start_match()
