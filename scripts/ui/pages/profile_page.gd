extends VBoxContainer
## Profile: name, level/XP, lifetime stats, unlock roadmap, reset.

var menu: Control
var confirm_reset := false


func _ready() -> void:
	var p := SaveManager.profile
	add_child(UITheme.label("PROFILE", 34, UITheme.ACCENT))
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(UITheme.label("Name", 20))
	var le := LineEdit.new()
	le.text = str(p.name)
	le.max_length = 16
	le.custom_minimum_size = Vector2(300, 52)
	le.text_changed.connect(func(t):
		if t.strip_edges() != "":
			p.name = t.strip_edges()
			SaveManager.save_profile())
	row.add_child(le)
	var lvl := int(p.level)
	add_child(UITheme.label("Level %d   (%d / %d XP to next)" % [lvl, p.xp, SaveManager.xp_for_next(lvl)], 22))
	var pb := ProgressBar.new()
	pb.max_value = SaveManager.xp_for_next(lvl)
	pb.value = int(p.xp)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(500, 14)
	add_child(pb)
	add_child(UITheme.label("Credits %d (earned by playing matches - there are no purchases)" % p.credits, 17, UITheme.MUTED))
	add_child(UITheme.label("Matches %d   Wins %d   Kills %d   Deaths %d   K/D %.2f" % [p.matches, p.wins, p.kills, p.deaths, float(p.kills) / maxf(float(p.deaths), 1.0)], 20))
	add_child(UITheme.label("UPCOMING UNLOCKS", 18, UITheme.MUTED))
	var up := []
	for id in GameDB.weapons.keys():
		var w := GameDB.get_weapon(id)
		if w.unlock_level > lvl:
			up.append([w.unlock_level, "Weapon: " + w.display_name])
	for a_id in GameDB.ATTACHMENTS.keys():
		if int(GameDB.ATTACHMENTS[a_id].unlock) > lvl:
			up.append([int(GameDB.ATTACHMENTS[a_id].unlock), "Attachment: " + GameDB.ATTACHMENTS[a_id].name])
	for o in GameDB.OPERATORS:
		if int(o.unlock) > lvl:
			up.append([int(o.unlock), "Operator: " + o.name])
	for sk in GameDB.SKINS.keys():
		if int(GameDB.SKINS[sk].unlock) > lvl:
			up.append([int(GameDB.SKINS[sk].unlock), "Skin: " + GameDB.SKINS[sk].name])
	up.sort_custom(func(a, b): return a[0] < b[0])
	var txt := ""
	for i in mini(up.size(), 8):
		txt += "LVL %d  %s\n" % up[i]
	add_child(UITheme.label(txt if txt != "" else "Everything unlocked.", 17))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sp)
	var reset_btn: Button
	reset_btn = UITheme.button("RESET PROGRESS", func():
		if not confirm_reset:
			confirm_reset = true
			reset_btn.text = "TAP AGAIN TO CONFIRM"
			return
		SaveManager.profile = SaveManager.DEFAULT_PROFILE.duplicate(true)
		SaveManager.save_profile()
		menu.show_page("profile"), Vector2(320, 60), "back")
	add_child(reset_btn)
