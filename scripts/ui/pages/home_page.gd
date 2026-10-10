extends HBoxContainer
## Home: operator on display, quick-play cards, lifetime stats.

var menu: Control


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	left.add_child(UITheme.label("READY UP", 34, UITheme.ACCENT))
	left.add_child(_card("MULTIPLAYER", "Team Deathmatch and Free-For-All against AI opponents.", func(): menu.show_page("mp")))
	left.add_child(_card("BATTLE ROYALE", "Drop onto Isla Verde, loot, and outlast the zone.", func(): menu.show_page("br")))
	var row := HBoxContainer.new()
	row.add_child(UITheme.button("LOADOUT", func(): menu.show_page("loadout"), Vector2(200, 60)))
	row.add_child(UITheme.button("HUD LAYOUT", func(): get_tree().change_scene_to_file("res://scenes/menus/hud_editor.tscn"), Vector2(200, 60)))
	row.add_child(UITheme.button("SETTINGS", func(): menu.show_page("settings"), Vector2(200, 60)))
	left.add_child(row)
	var p := SaveManager.profile
	var kd := float(p.kills) / maxf(float(p.deaths), 1.0)
	left.add_child(UITheme.label("Matches %d   Wins %d   Kills %d   K/D %.2f" % [p.matches, p.wins, p.kills, kd], 18, UITheme.MUTED))
	left.add_child(UITheme.label("Offline mode: every opponent and teammate is an AI bot.", 16, UITheme.MUTED))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	add_child(right)
	var prev := OperatorPreview.new()
	prev.custom_minimum_size = Vector2(340, 420)
	prev.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(prev)
	var op := GameDB.get_operator(str(p.operator))
	prev.set_operator.call_deferred(op.id, SaveManager.current_loadout().primary)
	right.add_child(UITheme.label("%s  -  %s" % [op.name, op.faction], 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	right.add_child(UITheme.label("Loadout: %s" % SaveManager.current_loadout().name, 16, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _card(title: String, desc: String, cb: Callable) -> Control:
	var b := UITheme.button("", cb, Vector2(0, 120), "confirm")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_top = 14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UITheme.label(title, 32, UITheme.ACCENT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UITheme.label(desc, 18, UITheme.MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	v.add_child(d)
	b.add_child(v)
	return b
