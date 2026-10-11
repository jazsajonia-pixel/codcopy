extends VBoxContainer
## Battle Royale mode select: squad size, lobby size, difficulty.

var menu: Control
var count_buttons := {}
var squad_buttons := {}
var squad_hint: Label


func _ready() -> void:
	var d := UITheme.label("Isla Verde - 560 m island, nine points of interest, drivable vehicles and helicopters (Airfield, Military Base). Jump from the aircraft, loot weapons, armor and supplies, and stay inside the shrinking safe zone. Play solo, or as a duo or squad with AI teammates who can revive you.", 17)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(d)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 36)
	add_child(cols)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	cols.add_child(left)
	cols.add_child(right)
	left.add_child(UITheme.label("SQUAD", 18, UITheme.MUTED))
	var srow := HBoxContainer.new()
	left.add_child(srow)
	for opt in [[1, "SOLO"], [2, "DUO"], [4, "SQUAD"]]:
		var size: int = opt[0]
		var sb := UITheme.button(opt[1], func(): _set_squad(size), Vector2(120, 64), "select")
		sb.toggle_mode = true
		srow.add_child(sb)
		squad_buttons[size] = sb
	squad_hint = UITheme.label("", 15, UITheme.MUTED)
	squad_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	squad_hint.custom_minimum_size.x = 380
	left.add_child(squad_hint)
	right.add_child(UITheme.label("OPERATORS IN MATCH", 18, UITheme.MUTED))
	var row := HBoxContainer.new()
	right.add_child(row)
	for n in [8, 12, 16, 20]:
		var b := UITheme.button(str(n), func(): _set_count(n), Vector2(84, 64), "select")
		b.toggle_mode = true
		row.add_child(b)
		count_buttons[n] = b
	right.add_child(UITheme.label("Larger lobbies need a faster device.", 15, UITheme.MUTED))
	add_child(UITheme.label("BOT DIFFICULTY", 18, UITheme.MUTED))
	add_child(DifficultyRow.make())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sp)
	var launch := UITheme.cta("DEPLOY", func():
		MatchConfig.configure_br()
		MatchConfig.start_match(), Vector2(360, 88))
	launch.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(launch)
	_set_count(MatchConfig.br_players)
	_set_squad(MatchConfig.br_squad_size)


func _set_count(n: int) -> void:
	MatchConfig.br_players = n
	for k in count_buttons.keys():
		count_buttons[k].set_pressed_no_signal(k == n)


func _set_squad(n: int) -> void:
	MatchConfig.br_squad_size = n
	for k in squad_buttons.keys():
		squad_buttons[k].set_pressed_no_signal(k == n)
	if n == 1:
		squad_hint.text = "Every operator for themselves. No revives."
	else:
		squad_hint.text = "You + %d AI teammate%s (labelled [BOT]). Hold interact to revive downed teammates." % [n - 1, "" if n == 2 else "s"]
