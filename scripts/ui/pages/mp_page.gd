extends VBoxContainer
## Multiplayer mode + map select, bot difficulty, and launch.

var menu: Control
var mode := "tdm"
var map_id := "outpost"
var mode_buttons := {}
var map_buttons := {}
var info: Label


func _ready() -> void:
	add_child(UITheme.label("MULTIPLAYER", 34, UITheme.ACCENT))
	add_child(UITheme.label("MODE", 18, UITheme.MUTED))
	var mrow := HBoxContainer.new()
	add_child(mrow)
	for id in GameDB.MP_MODES.keys():
		var b := UITheme.button(GameDB.MP_MODES[id].name, func(): _set_mode(id), Vector2(280, 70), "select")
		b.toggle_mode = true
		mrow.add_child(b)
		mode_buttons[id] = b
	add_child(UITheme.label("MAP", 18, UITheme.MUTED))
	var maprow := HBoxContainer.new()
	add_child(maprow)
	for id in GameDB.MP_MAPS.keys():
		var b := UITheme.button(GameDB.MP_MAPS[id].name, func(): _set_map(id), Vector2(280, 70), "select")
		b.toggle_mode = true
		maprow.add_child(b)
		map_buttons[id] = b
	add_child(UITheme.label("BOT DIFFICULTY", 18, UITheme.MUTED))
	add_child(DifficultyRow.make())
	info = UITheme.label("", 18, UITheme.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sp)
	var launch := UITheme.button("START MATCH", _start, Vector2(360, 80), "confirm")
	launch.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(launch)
	_set_mode(mode)
	_set_map(map_id)


func _set_mode(id: String) -> void:
	mode = id
	for k in mode_buttons.keys():
		mode_buttons[k].set_pressed_no_signal(k == id)
	_update()


func _set_map(id: String) -> void:
	map_id = id
	for k in map_buttons.keys():
		map_buttons[k].set_pressed_no_signal(k == id)
	_update()


func _update() -> void:
	if info == null:
		return
	var m: Dictionary = GameDB.MP_MODES[mode]
	info.text = "%s - %s\nScore limit %d, time limit %d min.\n%s - %s\nTeammates and opponents are AI bots (offline)." % [
		m.name, m.desc, m.score_limit, int(m.time_limit / 60), GameDB.MP_MAPS[map_id].name, GameDB.MP_MAPS[map_id].desc]


func _start() -> void:
	MatchConfig.configure_mp(mode, map_id)
	MatchConfig.start_match()
