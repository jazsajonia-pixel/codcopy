extends CanvasLayer
## In-game HUD for both modes. Built in code so layout adapts to any aspect ratio and safe area.

var match_node: MatchBase
var player: Player

var root: Control
var overlay: HudOverlay
var touch: TouchControls
var minimap: Minimap
var weapon_bar: WeaponBar
var drop_label: Label         ## BR drop: altitude / speed / chute hint
var bag: BagPanel
var bigmap: Minimap
var score_box: HBoxContainer
var score_a: Label
var score_b: Label
var timer_label: Label
var br_label: Label
var killfeed: VBoxContainer
var health_bar: ProgressBar
var armor_bar: ProgressBar
var health_label: Label
var weapon_label: Label
var ammo_label: Label
var equip_label: Label
var reload_bar: ProgressBar
var use_bar: ProgressBar
var interact_label: Label
var announce: Label
var announce_sub: Label
var announce_t := 0.0
var death_panel: Control
var death_label: Label
var pause_panel: Control
var scoreboard_panel: PanelContainer
var scoreboard_list: VBoxContainer
var fps_label: Label
var hint_label: Label
var streak_label: Label
var medal_feed: MedalFeed
var _kills_this_match := 0
var squad_label: Label
var flags_label: RichTextLabel
var status_label: Label
var _last_revive: Actor = null
var streak_t := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	overlay = HudOverlay.new()
	overlay.player = player
	root.add_child(overlay)
	_build_top()
	_build_bottom()
	_build_center()
	_build_touch()
	_build_pause()
	_build_scoreboard()
	_build_bigmap()
	player.hit_confirmed.connect(overlay.on_hit)
	player.damage_dealt.connect(overlay.on_damage_dealt)
	player.damaged.connect(func(_a, from, _att): overlay.on_damaged(from))
	player.interact_target_changed.connect(_on_interact_target)
	player.vehicle_changed.connect(_on_vehicle_changed)
	player.set_meta("touch_controls", touch)
	player.killed_enemy.connect(_on_player_kill)
	match_node.kill_feed.connect(_on_kill_feed)
	match_node.announcement.connect(show_announcement)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _safe() -> Rect2:
	return UITheme.safe_rect(get_viewport())


func _build_top() -> void:
	minimap = Minimap.new()
	minimap.match_node = match_node
	minimap.player = player
	minimap.radius_m = 160.0 if MatchConfig.mode == "br" else 45.0
	root.add_child(minimap)
	score_box = HBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_theme_constant_override("separation", 6)
	root.add_child(score_box)
	score_a = _score_chip(UITheme.FRIENDLY)
	timer_label = UITheme.shadowed(UITheme.label("0:00", 24, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	timer_label.custom_minimum_size = Vector2(90, 0)
	score_b = _score_chip(UITheme.ENEMY)
	score_box.add_child(score_a.get_parent())
	score_box.add_child(timer_label)
	score_box.add_child(score_b.get_parent())
	br_label = UITheme.shadowed(UITheme.label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(br_label)
	killfeed = VBoxContainer.new()
	killfeed.alignment = BoxContainer.ALIGNMENT_BEGIN
	killfeed.add_theme_constant_override("separation", 2)
	root.add_child(killfeed)
	fps_label = UITheme.label("", 14, UITheme.MUTED)
	root.add_child(fps_label)


func _score_chip(c: Color) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c, 0.75)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	var l := UITheme.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(56, 0)
	p.add_child(l)
	return l


func _build_bottom() -> void:
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.max_value = 100
	var hf := StyleBoxFlat.new()
	hf.bg_color = Color(0.92, 0.92, 0.88)
	hf.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("fill", hf)
	root.add_child(health_bar)
	armor_bar = ProgressBar.new()
	armor_bar.show_percentage = false
	var af := StyleBoxFlat.new()
	af.bg_color = Color(0.35, 0.62, 1.0)
	af.set_corner_radius_all(3)
	armor_bar.add_theme_stylebox_override("fill", af)
	root.add_child(armor_bar)
	health_label = UITheme.shadowed(UITheme.label("100", 18))
	root.add_child(health_label)
	# Weapon name and ammo are shown on the weapon bar; these labels stay as hidden fallbacks.
	weapon_label = UITheme.shadowed(UITheme.label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	weapon_label.visible = false
	root.add_child(weapon_label)
	ammo_label = UITheme.shadowed(UITheme.label("", 34, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	ammo_label.visible = false
	root.add_child(ammo_label)
	equip_label = UITheme.shadowed(UITheme.label("", 16, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	root.add_child(equip_label)
	drop_label = UITheme.shadowed(UITheme.label("", 20, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	drop_label.visible = false
	root.add_child(drop_label)
	hint_label = UITheme.shadowed(UITheme.label("", 15, UITheme.MUTED))
	root.add_child(hint_label)
	flags_label = RichTextLabel.new()
	flags_label.bbcode_enabled = true
	flags_label.fit_content = true
	flags_label.scroll_active = false
	flags_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flags_label.add_theme_font_size_override("normal_font_size", 22)
	flags_label.add_theme_constant_override("outline_size", 6)
	flags_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	flags_label.visible = false
	root.add_child(flags_label)
	squad_label = UITheme.shadowed(UITheme.label("", 14, UITheme.FRIENDLY))
	squad_label.visible = false
	root.add_child(squad_label)


func _build_center() -> void:
	reload_bar = ProgressBar.new()
	reload_bar.show_percentage = false
	reload_bar.visible = false
	root.add_child(reload_bar)
	use_bar = ProgressBar.new()
	use_bar.show_percentage = false
	use_bar.visible = false
	root.add_child(use_bar)
	interact_label = UITheme.shadowed(UITheme.label("", 20, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(interact_label)
	announce = UITheme.shadowed(UITheme.label("", 54, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(announce)
	announce_sub = UITheme.shadowed(UITheme.label("", 22, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(announce_sub)
	streak_label = UITheme.shadowed(UITheme.label("", 26, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(streak_label)
	streak_label.visible = false
	medal_feed = MedalFeed.new()
	root.add_child(medal_feed)
	status_label = UITheme.shadowed(UITheme.label("", 24, UITheme.ENEMY, HORIZONTAL_ALIGNMENT_CENTER))
	status_label.visible = false
	root.add_child(status_label)
	death_panel = Control.new()
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	root.add_child(death_panel)
	death_label = UITheme.shadowed(UITheme.label("", 30, UITheme.ENEMY, HORIZONTAL_ALIGNMENT_CENTER))
	death_panel.add_child(death_label)


func _build_touch() -> void:
	touch = TouchControls.new()
	touch.player = player
	touch.br_mode = MatchConfig.mode == "br"
	touch.on_pause = func(): match_node.toggle_pause()
	touch.on_score = func(show: bool): scoreboard_panel.visible = show
	touch.on_bag = toggle_bag
	weapon_bar = WeaponBar.new()
	weapon_bar.player = player
	weapon_bar.br_mode = MatchConfig.mode == "br"
	root.add_child(weapon_bar)
	touch.weapon_bar = weapon_bar
	bag = BagPanel.new()
	bag.player = player
	bag.visible = false
	bag.closed.connect(_on_bag_closed)
	root.add_child(touch)
	root.add_child(bag)
	var scheme: String = SaveManager.get_setting("controls", "scheme", "auto")
	var use_touch := scheme == "touch" or (scheme != "keyboard" and (DisplayServer.is_touchscreen_available() or is_mobile()))
	touch.visible = use_touch
	player.touch_mode = use_touch
	weapon_bar.touch = use_touch
	if not use_touch and not MatchConfig.autoplay_player and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_pause() -> void:
	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var p := UITheme.panel(Vector2(420, 0))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UITheme.label("PAUSED", 34, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label("Build %s" % ErrorLog.BUILD, 13, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.button("Resume", func(): match_node.toggle_pause(), Vector2(380, 64)))
	v.add_child(UITheme.button("Restart Match", func(): MatchConfig.start_match(), Vector2(380, 64)))
	# Quick sensitivity tweak without leaving the match.
	var sl := HSlider.new()
	sl.min_value = 0.2
	sl.max_value = 3.0
	sl.step = 0.05
	sl.value = SaveManager.get_setting("controls", "look_sensitivity", 1.0)
	var sl_label := UITheme.label("Look sensitivity: %.2f" % sl.value, 18)
	sl.value_changed.connect(func(val):
		sl_label.text = "Look sensitivity: %.2f" % val
		SaveManager.set_setting("controls", "look_sensitivity", val)
		SaveManager.set_setting("controls", "mouse_sensitivity", val)
		SaveManager.save_settings())
	v.add_child(sl_label)
	v.add_child(sl)
	v.add_child(UITheme.button("Quit to Menu", func(): MatchConfig.to_menu(), Vector2(380, 64), "back"))


func _build_scoreboard() -> void:
	scoreboard_panel = UITheme.panel(Vector2(640, 0))
	scoreboard_panel.visible = false
	root.add_child(scoreboard_panel)
	scoreboard_list = VBoxContainer.new()
	scoreboard_list.add_theme_constant_override("separation", 2)
	scoreboard_panel.add_child(scoreboard_list)


func _build_bigmap() -> void:
	bigmap = Minimap.new()
	bigmap.match_node = match_node
	bigmap.player = player
	bigmap.full_map = true
	bigmap.visible = false
	root.add_child(bigmap)


func toggle_big_map() -> void:
	bigmap.visible = not bigmap.visible


func _layout() -> void:
	var s := _safe()
	var vs := root.get_viewport_rect().size
	root.position = Vector2.ZERO
	root.size = vs
	for full in [overlay, touch]:
		full.set_anchors_preset(Control.PRESET_TOP_LEFT)
		full.position = Vector2.ZERO
		full.size = vs
	var mm := clampf(s.size.y * 0.27, 150, 220)
	minimap.position = s.position + Vector2(16, 16)
	minimap.size = Vector2(mm, mm)
	score_box.position = Vector2(s.position.x + s.size.x * 0.5 - 140, s.position.y + 10)
	score_box.size = Vector2(280, 40)
	br_label.position = Vector2(s.position.x + s.size.x * 0.5 - 250, s.position.y + 54)
	br_label.size = Vector2(500, 30)
	flags_label.position = Vector2(s.position.x + s.size.x * 0.5 - 250, s.position.y + 54)
	flags_label.size = Vector2(500, 34)
	killfeed.position = Vector2(s.end.x - 430, s.position.y + 70)
	killfeed.size = Vector2(414, 200)
	fps_label.position = s.position + Vector2(20, mm + 22)
	squad_label.position = s.position + Vector2(18, mm + 42)
	squad_label.size = Vector2(150, 80)
	var bw := clampf(s.size.x * 0.24, 220, 360)
	# Health / armor sit just above the weapon bar (bottom centre), like CODM.
	var bar_top := s.end.y - 10.0 - WeaponBar.CARD.y * (float(SaveManager.get_setting("accessibility", "hud_scale", 1.0)) if player.touch_mode else 0.9)
	health_bar.position = Vector2(s.position.x + s.size.x * 0.5 - bw * 0.5, bar_top - 22)
	health_bar.size = Vector2(bw, 14)
	armor_bar.position = health_bar.position + Vector2(0, -12)
	armor_bar.size = Vector2(bw, 8)
	health_label.position = health_bar.position + Vector2(-60, -8)
	health_label.size = Vector2(54, 26)
	weapon_label.position = Vector2(s.end.x - 420, s.end.y - 150)
	weapon_label.size = Vector2(400, 28)
	ammo_label.position = Vector2(s.end.x - 420, s.end.y - 120)
	ammo_label.size = Vector2(400, 44)
	equip_label.position = Vector2(s.end.x - 420, s.end.y - 76)
	equip_label.size = Vector2(400, 24)
	if player.touch_mode:
		# Keep weapon info clear of the right-thumb button cluster.
		for l in [weapon_label, ammo_label, equip_label]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.position.x = s.position.x + s.size.x * 0.5 - 200
		weapon_label.position.y = bar_top - 120
		ammo_label.position.y = bar_top - 96
		equip_label.position.y = bar_top - 64
	# Keyboard hint: bottom-left, wrapped so it stays clear of the weapon bar.
	var hint_w := maxf(s.size.x * 0.5 - 270.0 - 30.0, 200.0)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.position = Vector2(s.position.x + 20, s.end.y - 74)
	hint_label.size = Vector2(hint_w, 66)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var c := s.get_center()
	reload_bar.position = c + Vector2(-80, 60)
	reload_bar.size = Vector2(160, 8)
	drop_label.position = Vector2(s.position.x, s.position.y + 64)
	drop_label.size = Vector2(s.size.x, 60)
	use_bar.position = c + Vector2(-110, 90)
	use_bar.size = Vector2(220, 12)
	interact_label.position = c + Vector2(-300, 110)
	interact_label.size = Vector2(600, 30)
	announce.position = Vector2(s.position.x, s.position.y + s.size.y * 0.22)
	announce.size = Vector2(s.size.x, 70)
	announce_sub.position = announce.position + Vector2(0, 68)
	announce_sub.size = Vector2(s.size.x, 30)
	streak_label.position = Vector2(s.position.x, c.y - 120)
	streak_label.size = Vector2(s.size.x, 34)
	status_label.position = Vector2(s.position.x, c.y + 130)
	status_label.size = Vector2(s.size.x, 64)
	death_panel.position = Vector2.ZERO
	death_panel.size = vs
	death_label.position = Vector2(0, vs.y * 0.3)
	death_label.size = Vector2(vs.x, 80)
	scoreboard_panel.position = c - Vector2(320, 200)
	var bm := minf(s.size.x, s.size.y) * 0.85
	bigmap.position = c - Vector2(bm, bm) * 0.5
	bigmap.size = Vector2(bm, bm)


func show_announcement(text: String, sub: String) -> void:
	announce.text = text
	announce_sub.text = sub
	announce_t = 2.6


func show_pause(p: bool) -> void:
	pause_panel.visible = p
	touch.release_all()
	touch.visible = not p and player.touch_mode
	if not p and not player.touch_mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Safety net: a real finger touch while in keyboard mode switches to on-screen controls (unless the
	# player explicitly chose Keyboard/Mouse). Covers devices that don't report a touchscreen up front.
	# On phones/tablets a real touch always brings the on-screen controls back, even if Keyboard/Mouse was chosen.
	if event is InputEventScreenTouch and event.pressed and player and not player.touch_mode \
			and (is_mobile() or SaveManager.get_setting("controls", "scheme", "auto") != "keyboard"):
		player.touch_mode = true
		touch.visible = not get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_layout()
	# And the reverse: a physical keyboard key or gamepad button while in touch mode switches to
	# keyboard/mouse controls (touchscreen laptops, tablets or phones with a keyboard or controller),
	# unless the player explicitly chose Touch. Emulated mouse events from touches never switch modes.
	elif player and player.touch_mode and not MatchConfig.autoplay_player \
			and SaveManager.get_setting("controls", "scheme", "auto") != "touch" \
			and ((event is InputEventKey and event.pressed and not event.echo and _is_game_key(event)) \
				or (event is InputEventJoypadButton and event.pressed)):
		set_keyboard_mode()


## Android / iOS (native, or the Godot Android editor running the game, or a mobile browser).
static func is_mobile() -> bool:
	for f in ["android", "ios", "mobile", "web_android", "web_ios"]:
		if OS.has_feature(f):
			return true
	return OS.get_name() in ["Android", "iOS"]


## True only for keys bound to gameplay actions (WASD, Space, R, ...). Android system keys such as
## Back, volume or media keys must never hide the on-screen controls.
func _is_game_key(e: InputEventKey) -> bool:
	for action in InputSetup.KEYS.keys():
		if action != "pause" and InputMap.has_action(action) and e.is_action(action, true):
			return true
	return false


## Switch the HUD and player to keyboard/mouse (or gamepad) controls.
func set_keyboard_mode() -> void:
	player.touch_mode = false
	touch.release_all()
	touch.visible = false
	for l in [weapon_label, ammo_label, equip_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not get_tree().paused and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("pause"):
		match_node.toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("scoreboard"):
		scoreboard_panel.visible = true
	elif event.is_action_released("scoreboard"):
		scoreboard_panel.visible = false
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
		toggle_big_map()
	if event.is_action_pressed("bag") and not get_tree().paused:
		toggle_bag()


## Battle Royale backpack. Touch controls are hidden while it is open so the buttons get the taps.
func toggle_bag() -> void:
	if bag == null or MatchConfig.mode != "br":
		return
	if bag.visible:
		bag.close()
		return
	if not player.alive or player.downed or player.vehicle != null or player.parachute_state > 0:
		return
	touch.release_all()
	touch.visible = false
	if not player.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.allow_input = false
	bag.open()


func _on_bag_closed() -> void:
	player.allow_input = true
	touch.visible = player.touch_mode and not get_tree().paused
	if not player.touch_mode and not MatchConfig.autoplay_player and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_vehicle_changed(v: Vehicle) -> void:
	touch.set_driving(v != null, v is Helicopter and player.vehicle_seat == 0)
	overlay.visible = v == null
	if v:
		interact_label.text = (("Piloting " if v is Helicopter else "Driving ") if player.vehicle_seat == 0 else "Riding ") + v.display_name() + ("" if player.touch_mode else ("   [F] exit   [Space] climb   [C] descend" if v is Helicopter else "   [F] exit   [Space] handbrake"))
	else:
		interact_label.text = ""


func _on_interact_target(t: Node) -> void:
	if t and is_instance_valid(t) and t.has_method("prompt"):
		var txt: String = t.prompt()
		interact_label.text = txt + ("" if player.touch_mode else "  [F]")
		touch.set_interact_available(true, "OPEN" if t.get("kind") == "crate" else "PICK")
	else:
		interact_label.text = ""
		touch.set_interact_available(false)


func _on_kill_feed(killer: String, victim: String, weapon: String, headshot: bool, involves: int) -> void:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45) if involves == 0 else (Color(0.5, 0.35, 0.05, 0.6) if involves > 0 else Color(0.45, 0.05, 0.05, 0.6))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	row.add_theme_stylebox_override("panel", sb)
	var txt := "%s  [%s%s]  %s" % [killer if killer != "" else "", weapon, " HS" if headshot else "", victim]
	if killer == "":
		txt = "%s  [%s]" % [victim, weapon if weapon != "" else "Eliminated"]
	var l := UITheme.label(txt, 16, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(l)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	killfeed.add_child(row)
	while killfeed.get_child_count() > 5:
		killfeed.get_child(0).queue_free()
		killfeed.remove_child(killfeed.get_child(0))
	var rid := row.get_instance_id()
	get_tree().create_timer(5.0, false).timeout.connect(func():
		var o := instance_from_id(rid)
		if o:
			o.queue_free())


func _on_player_kill(victim: Actor, headshot: bool) -> void:
	var s := player.streak
	_kills_this_match += 1
	var names := {2: "DOUBLE KILL", 3: "TRIPLE KILL", 4: "FURY KILL", 5: "FRENZY KILL", 6: "SUPER KILL", 7: "MEGA KILL", 8: "ULTRA KILL"}
	medal_feed.popup("+100  ENEMY KILLED")
	if names.has(s):
		medal_feed.medal(names[s], Color(1.0, 0.45, 0.2))
		medal_feed.popup("+%d  %s" % [50 * (s - 1), names[s]])
	if headshot:
		medal_feed.medal("HEADSHOT", Color(1.0, 0.3, 0.25))
		medal_feed.popup("+50  HEADSHOT")
	if _kills_this_match == 1 and MatchConfig.mode != "br":
		medal_feed.medal("FIRST BLOOD", Color(0.9, 0.15, 0.15))
	if victim and is_instance_valid(victim):
		var d := victim.global_position.distance_to(player.global_position)
		if d > 40.0:
			medal_feed.medal("LONGSHOT", Color(0.4, 0.8, 1.0))
			medal_feed.popup("+50  LONGSHOT")
		elif d < 2.5:
			medal_feed.medal("POINT BLANK", Color(0.6, 0.9, 0.4))
		if victim.streak >= 3:
			medal_feed.medal("BUZZKILL", Color(0.75, 0.5, 1.0))
			medal_feed.popup("+50  BUZZKILL")
		medal_feed.eliminated(victim.actor_name)
	if s in [3, 5, 7]:
		medal_feed.medal("%d KILL STREAK" % s, UITheme.ACCENT)


func _process(delta: float) -> void:
	if player == null:
		return
	announce_t -= delta
	announce.visible = announce_t > 0.0
	announce_sub.visible = announce_t > 0.0
	streak_t -= delta
	streak_label.visible = streak_t > 0.0
	health_bar.value = player.health
	health_label.text = str(ceili(player.health))
	armor_bar.visible = player.max_armor > 0.0
	armor_bar.max_value = maxf(player.max_armor, 1.0)
	armor_bar.value = player.armor
	var w := player.inv.active()
	if w:
		weapon_label.text = w.data.display_name
		ammo_label.text = "%d / %d" % [w.mag, w.get_reserve()]
		ammo_label.add_theme_color_override("font_color", UITheme.ENEMY if w.mag <= w.mag_size() * 0.2 else UITheme.TEXT)
		reload_bar.visible = w.reloading
		reload_bar.value = w.reload_progress() * 100.0
	else:
		weapon_label.text = "Unarmed"
		ammo_label.text = "-"
		reload_bar.visible = false
	var parts: Array = []
	if player.inv.lethal != "" and (player.inv.lethal_count > 0 or MatchConfig.mode != "br"):
		parts.append("%s x%d" % [GameDB.EQUIPMENT[player.inv.lethal].name, player.inv.lethal_count])
	if player.inv.tactical != "" and (player.inv.tactical_count > 0 or MatchConfig.mode != "br"):
		parts.append("%s x%d" % [GameDB.EQUIPMENT[player.inv.tactical].name, player.inv.tactical_count])
	if MatchConfig.mode == "br":
		parts.append("Med %d  Band %d  Plate %d" % [player.inv.heals.get("medkit", 0), player.inv.heals.get("bandage", 0), player.inv.plates])
	var eq := "   ".join(parts)
	equip_label.text = eq
	if player.vehicle and is_instance_valid(player.vehicle):
		var v := player.vehicle
		equip_label.text = "%s  %d%%   %d km/h" % [v.display_name(), roundi(100.0 * v.health / v.max_health), roundi(v.speed() * 3.6)]
		if v is Helicopter:
			equip_label.text += "   ALT %d m   ROTOR %d%%" % [roundi((v as Helicopter).altitude()), roundi((v as Helicopter).rpm * 100.0)]
	drop_label.visible = player.parachute_state > 0
	if drop_label.visible:
		var spd := roundi(player.velocity.length() * 3.6)
		var hint := ""
		if player.parachute_state == 1:
			hint = "Look down to dive faster  |  %s opens the parachute (auto at %d m)" % ["CHUTE" if player.touch_mode else "Space", int(Player.CHUTE_AUTO_AGL)]
		elif player.agl > Player.CHUTE_MIN_CUT_AGL:
			hint = "%s closes the parachute  |  you can fire from the hip" % ("CUT" if player.touch_mode else "Space")
		drop_label.text = "ALT %d m    %d km/h\n%s" % [roundi(player.agl), spd, hint]
	use_bar.visible = player.using_item != ""
	if use_bar.visible:
		use_bar.value = (1.0 - player.use_left / maxf(player.use_total, 0.01)) * 100.0
	_update_squad()
	# Score / timer
	if match_node.has_method("score_text"):
		var st: Array = match_node.score_text()
		score_a.text = str(st[0])
		score_b.text = str(st[1])
		var tl: float = match_node.time_left()
		timer_label.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
		br_label.text = ""
		_update_flags()
	else:
		score_box.visible = false
		if match_node.has_method("br_status"):
			br_label.text = match_node.br_status()
	# Death
	death_panel.visible = not player.alive and not match_node.ended
	if death_panel.visible and player.spectate_target and is_instance_valid(player.spectate_target) and player.spectate_target.alive:
		death_label.text = "SQUAD STILL IN THE FIGHT\nSpectating %s" % player.spectate_target.actor_name
	elif death_panel.visible:
		var killer := player.death_cam_target
		var who := killer.actor_name if killer and is_instance_valid(killer) and killer != player else "the zone"
		death_label.text = "ELIMINATED BY %s" % who.to_upper()
		if match_node.has_method("respawn_eta"):
			death_label.text += "\nRespawning in %.1f" % match_node.respawn_eta(player)
	hint_label.visible = not player.touch_mode and (match_node.elapsed < 25.0 or get_tree().paused)
	hint_label.text = "WASD move  Mouse aim  LMB fire  RMB ADS  R reload  Q swap  1/2/3 weapons  Shift sprint  C crouch (slide while sprinting)  G/T grenades  V melee  F interact  H heal  X plate  M map  Tab scores  Esc pause"
	if MatchConfig.mode == "br":
		hint_label.text += "  I/B backpack  Z first/third person  Space parachute"
	fps_label.visible = SaveManager.get_setting("graphics", "show_fps", false)
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	if scoreboard_panel.visible:
		_refresh_scoreboard()


## Domination: colored flag letters (friendly / enemy / neutral) and the capture state under you.
func _update_flags() -> void:
	if not match_node.has_method("flag_states"):
		return
	var fs: Array = match_node.flag_states()
	flags_label.visible = not fs.is_empty()
	if fs.is_empty():
		return
	var parts: Array = []
	var here := ""
	for f in fs:
		var c := Color(0.85, 0.85, 0.85)
		if f.owner >= 0:
			c = UITheme.FRIENDLY if f.owner == player.team else Bot._enemy_color()
		parts.append("[color=#%s]%s[/color]" % [c.to_html(false), "[ %s ]" % f.letter if f.contested else f.letter])
		var d := Vector2(player.global_position.x - f.pos.x, player.global_position.z - f.pos.z).length()
		if player.alive and d <= DomFlag.RADIUS:
			if f.contested:
				here = "%s CONTESTED" % f.letter
			elif f.owner == player.team and absf(f.progress) >= 1.0:
				here = "%s SECURED" % f.letter
			elif f.capturing == player.team:
				var p: float = f.progress if player.team == 0 else -f.progress
				if p < 0.0:
					here = "NEUTRALIZING %s" % f.letter
				else:
					here = "CAPTURING %s  %d%%" % [f.letter, roundi(clampf(p, 0.0, 1.0) * 100.0)]
	flags_label.text = "[center]" + "     ".join(parts) + ("     [color=#f0c040]%s[/color]" % here if here != "" else "") + "[/center]"


## Squad panel, downed status and revive prompts (Battle Royale duos/squads).
func _update_squad() -> void:
	var mates: Array = []
	if int(match_node.get("squad_size") if match_node.get("squad_size") != null else 1) > 1:
		for a in match_node.actors:
			if a != player and is_instance_valid(a) and a.team == player.team:
				mates.append(a)
	squad_label.visible = not mates.is_empty()
	if squad_label.visible:
		var lines: Array = []
		for a in mates:
			var st := "%d HP" % ceili(a.health)
			if not a.alive:
				st = "OUT"
			elif a.downed:
				st = "DOWNED"
			lines.append("%s  %s" % [a.actor_name, st])
		squad_label.text = "SQUAD\n" + "\n".join(lines)
	# Downed / revive status
	status_label.visible = false
	if player.alive and player.downed:
		status_label.visible = true
		if player.reviver and player.revive_progress > 0.0:
			status_label.text = "BEING REVIVED BY %s" % player.reviver.actor_name.to_upper()
			use_bar.visible = true
			use_bar.value = player.revive_progress * 100.0
		else:
			status_label.text = "YOU ARE DOWN  -  bleeding out (%d)\nCrawl to cover and wait for a teammate" % ceili(player.health / Actor.DOWN_HEALTH * Actor.BLEED_TIME)
	var rt := player.revive_target
	if rt and is_instance_valid(rt) and rt.downed and player.vehicle == null:
		if rt.revive_progress > 0.0 and rt.reviver == player:
			interact_label.text = "Reviving %s" % rt.actor_name
			use_bar.visible = true
			use_bar.value = rt.revive_progress * 100.0
		else:
			interact_label.text = "Hold to revive %s" % rt.actor_name + ("" if player.touch_mode else "  [F]")
		if _last_revive != rt:
			touch.set_interact_available(true, "REVIVE")
	elif _last_revive != null:
		var it: Variant = player.interact_target
		_on_interact_target(it if is_instance_valid(it) else null)
	_last_revive = rt if rt and is_instance_valid(rt) and rt.downed and player.vehicle == null else null


func _refresh_scoreboard() -> void:
	for c in scoreboard_list.get_children():
		c.queue_free()
	scoreboard_list.add_child(UITheme.label("%-18s %6s %6s %6s %7s" % ["OPERATOR", "K", "D", "A", "SCORE"], 18, UITheme.ACCENT))
	for r in match_node.scoreboard():
		var col := UITheme.ACCENT if r.is_player else (UITheme.FRIENDLY if r.team == player.team else UITheme.ENEMY)
		if MatchConfig.mode != "tdm" and not r.is_player:
			col = UITheme.TEXT
		var l := UITheme.label("%-18s %6d %6d %6d %7d" % [r.name, r.kills, r.deaths, r.assists, r.score], 17, col if r.alive or MatchConfig.mode != "br" else UITheme.MUTED)
		scoreboard_list.add_child(l)
