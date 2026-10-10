extends Control
## Post-match results: outcome, K/D/A, score, XP/credits earned, level-ups, full scoreboard.


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var r: Dictionary = MatchConfig.last_results
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	m.add_child(h)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(440, 0)
	h.add_child(left)
	var won: bool = r.get("won", false)
	var title := "VICTORY" if won else "DEFEAT"
	if r.get("mode", "") == "br":
		title = "WINNER" if won else "#%d of %d" % [r.get("placement", 0), r.get("players", 0)]
	elif r.get("draw", false):
		title = "DRAW"
	left.add_child(UITheme.label(title, 60, UITheme.ACCENT if won else UITheme.ENEMY))
	var mode_name: String = "Battle Royale" if r.get("mode", "") == "br" else GameDB.MP_MODES.get(r.get("mode", "tdm"), {"name": "Match"}).name
	left.add_child(UITheme.label(mode_name, 22, UITheme.MUTED))
	if r.has("team_scores"):
		left.add_child(UITheme.label("Final score  %d - %d" % [r.team_scores[0], r.team_scores[1]], 24))
	var kd := float(r.get("kills", 0)) / maxf(float(r.get("deaths", 0)), 1.0)
	left.add_child(UITheme.label("Kills %d   Deaths %d   Assists %d" % [r.get("kills", 0), r.get("deaths", 0), r.get("assists", 0)], 24))
	left.add_child(UITheme.label("K/D %.2f    Score %d    Headshots %d" % [kd, r.get("score", 0), r.get("headshots", 0)], 22))
	left.add_child(UITheme.label("Accuracy %d%%    Time %d:%02d" % [int(r.get("accuracy", 0.0) * 100), int(r.get("duration", 0)) / 60, int(r.get("duration", 0)) % 60], 20, UITheme.MUTED))
	var rw: Dictionary = r.get("rewards", {})
	left.add_child(UITheme.label("REWARDS", 18, UITheme.MUTED))
	left.add_child(UITheme.label("+%d XP    +%d Credits" % [rw.get("xp", 0), rw.get("credits", 0)], 28, UITheme.GOOD))
	for lv in rw.get("levels", []):
		left.add_child(UITheme.label("LEVEL UP!  Level %d" % lv, 26, UITheme.ACCENT))
	var p := SaveManager.profile
	var pb := ProgressBar.new()
	pb.max_value = SaveManager.xp_for_next(int(p.level))
	pb.value = int(p.xp)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(400, 12)
	left.add_child(UITheme.label("Level %d  (%d / %d)" % [p.level, p.xp, pb.max_value], 18))
	left.add_child(pb)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	var br := HBoxContainer.new()
	left.add_child(br)
	br.add_child(UITheme.button("PLAY AGAIN", func(): MatchConfig.start_match(), Vector2(210, 70), "confirm"))
	br.add_child(UITheme.button("MAIN MENU", func(): MatchConfig.to_menu(), Vector2(210, 70), "back"))
	var right := UITheme.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	scroll.add_child(grid)
	for hdr in ["OPERATOR", "K", "D", "A", "SCORE"]:
		grid.add_child(UITheme.label(hdr, 18, UITheme.ACCENT))
	for row in r.get("scoreboard", []):
		var col := UITheme.ACCENT if row.is_player else (UITheme.FRIENDLY if r.get("mode", "") == "tdm" and row.team == 0 else UITheme.TEXT)
		grid.add_child(UITheme.label(str(row.name) + ("" if row.is_player else "  [BOT]"), 17, col))
		for k in ["kills", "deaths", "assists", "score"]:
			grid.add_child(UITheme.label(str(row[k]), 17, col))
	AudioManager.ui("confirm" if won else "back")
