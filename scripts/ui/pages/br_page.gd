extends VBoxContainer
## Battle Royale mode select: squad size (solo), lobby size, difficulty.

var menu: Control
var count_buttons := {}


func _ready() -> void:
	add_child(UITheme.label("BATTLE ROYALE", 34, UITheme.ACCENT))
	var d := UITheme.label("Isla Verde - 400 m island with six points of interest: Harbor Town, Depot, Farmstead, Radar Hill, Crossing and Pine Ridge.\nBoard the aircraft, jump, deploy your parachute, loot weapons, armor and supplies, and stay inside the shrinking safe zone. Solo, last operator standing wins.", 18)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(d)
	add_child(UITheme.label("OPERATORS IN MATCH", 18, UITheme.MUTED))
	var row := HBoxContainer.new()
	add_child(row)
	for n in [8, 12, 16, 20]:
		var b := UITheme.button(str(n), func(): _set_count(n), Vector2(120, 64), "select")
		b.toggle_mode = true
		row.add_child(b)
		count_buttons[n] = b
	add_child(UITheme.label("Larger lobbies need a faster device.", 15, UITheme.MUTED))
	add_child(UITheme.label("BOT DIFFICULTY", 18, UITheme.MUTED))
	add_child(DifficultyRow.make())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sp)
	var launch := UITheme.button("DEPLOY", func():
		MatchConfig.configure_br()
		MatchConfig.start_match(), Vector2(360, 80), "confirm")
	launch.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(launch)
	_set_count(MatchConfig.br_players)


func _set_count(n: int) -> void:
	MatchConfig.br_players = n
	for k in count_buttons.keys():
		count_buttons[k].set_pressed_no_signal(k == n)
