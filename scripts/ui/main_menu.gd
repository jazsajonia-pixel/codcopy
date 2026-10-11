extends Control
## Main menu shell in the CODM style:
##  - top bar: avatar + name/level/XP, MP / BR lobby tabs, currencies, settings
##  - home = lobby (operator on stage, mode card + big START, bottom navigation bar)
##  - other pages open full-width under a "< BACK  TITLE" bar

const PAGES := [
	["home", "LOBBY"], ["mp", "MULTIPLAYER"], ["br", "BATTLE ROYALE"], ["loadout", "LOADOUT"],
	["operators", "OPERATORS"], ["settings", "SETTINGS"], ["online", "ONLINE (LAN)"], ["profile", "PROFILE"], ["credits", "CREDITS"],
]

var content: Control
var nav_buttons := {}          ## bottom-bar buttons (lobby)
var tab_buttons := {}          ## MP / BR lobby tabs
var header_name: Label
var header_level: Label
var header_xp: ProgressBar
var header_credits: Label
var header_avatar: Label
var page_bar: Control
var page_title: Label
var bottom_bar: Control
var current := ""


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	add_child(LobbyBackdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sa := UITheme.safe_rect(get_viewport())
	var vs := get_viewport_rect().size
	margin.add_theme_constant_override("margin_left", int(maxf(sa.position.x, 0) + 16))
	margin.add_theme_constant_override("margin_right", int(maxf(vs.x - sa.end.x, 0) + 16))
	margin.add_theme_constant_override("margin_top", int(maxf(sa.position.y, 0) + 10))
	margin.add_theme_constant_override("margin_bottom", int(maxf(vs.y - sa.end.y, 0) + 10))
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	vbox.add_child(_top_bar())
	page_bar = _page_bar()
	vbox.add_child(page_bar)
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	bottom_bar = _bottom_bar()
	vbox.add_child(bottom_bar)
	SaveManager.profile_changed.connect(_refresh_header)
	_refresh_header()
	show_page("home")
	AudioManager.play_music("res://assets/audio/music/menu_music.ogg", -10.0)


func _top_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	# Avatar (operator initial) + level badge
	var av := PanelContainer.new()
	var avs := UITheme._box(UITheme.PANEL_LIGHT, UITheme.ACCENT, 2, 4)
	av.add_theme_stylebox_override("panel", avs)
	av.custom_minimum_size = Vector2(62, 62)
	header_avatar = UITheme.label("", 30, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	header_avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(header_avatar)
	var avb := Button.new()
	avb.flat = true
	avb.focus_mode = Control.FOCUS_NONE
	avb.set_anchors_preset(Control.PRESET_FULL_RECT)
	avb.pressed.connect(func(): show_page("profile"))
	av.add_child(avb)
	h.add_child(av)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	header_name = UITheme.shadowed(UITheme.label("", 22))
	header_level = UITheme.label("", 15, UITheme.MUTED)
	header_xp = ProgressBar.new()
	header_xp.custom_minimum_size = Vector2(200, 7)
	header_xp.show_percentage = false
	lv.add_child(header_name)
	lv.add_child(header_level)
	lv.add_child(header_xp)
	h.add_child(lv)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	# Lobby tabs
	for t in [["mp", "MULTIPLAYER"], ["br", "BATTLE ROYALE"]]:
		var b := UITheme.button(t[1], func(): _set_lobby(t[0]), Vector2(210, 54), "select")
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 19)
		h.add_child(b)
		tab_buttons[t[0]] = b
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp2)
	# Currencies
	var cur := PanelContainer.new()
	cur.add_theme_stylebox_override("panel", UITheme._box(Color(0, 0, 0, 0.45), UITheme.BORDER, 1, 14))
	var ch := HBoxContainer.new()
	cur.add_child(ch)
	var coin := UITheme.label("CR", 15, Color(0.1, 0.08, 0.02), HORIZONTAL_ALIGNMENT_CENTER)
	coin.add_theme_stylebox_override("normal", UITheme._box(UITheme.ACCENT, UITheme.ACCENT, 0, 10))
	coin.custom_minimum_size = Vector2(36, 0)
	ch.add_child(coin)
	header_credits = UITheme.label("", 20, UITheme.TEXT)
	ch.add_child(header_credits)
	cur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cur)
	var gear := UITheme.button("SETTINGS", func(): show_page("settings"), Vector2(120, 50))
	gear.add_theme_font_size_override("font_size", 16)
	h.add_child(gear)
	return h


func _page_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(UITheme.button("<  BACK", func(): show_page("home"), Vector2(150, 50), "back"))
	page_title = UITheme.shadowed(UITheme.label("", 32, UITheme.ACCENT))
	h.add_child(page_title)
	return h


func _bottom_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme._box(Color(0.02, 0.04, 0.06, 0.82), UITheme.BORDER, 0, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	for it in [["loadout", "LOADOUT"], ["operators", "OPERATORS"], ["online", "ONLINE"], ["profile", "CAREER"], ["hud", "HUD LAYOUT"], ["credits", "CREDITS"]]:
		var id: String = it[0]
		var b := UITheme.button(it[1], func():
			if id == "hud":
				get_tree().change_scene_to_file("res://scenes/menus/hud_editor.tscn")
			else:
				show_page(id), Vector2(150, 52))
		b.add_theme_font_size_override("font_size", 17)
		h.add_child(b)
		nav_buttons[id] = b
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		h.add_child(UITheme.button("QUIT", func(): get_tree().quit(), Vector2(110, 52), "back"))
	return p


func _refresh_header() -> void:
	var pr := SaveManager.profile
	header_name.text = str(pr.name)
	header_level.text = "LV %d   %d / %d XP" % [pr.level, pr.xp, SaveManager.xp_for_next(int(pr.level))]
	header_xp.max_value = SaveManager.xp_for_next(int(pr.level))
	header_xp.value = int(pr.xp)
	header_credits.text = " %d " % int(pr.credits)
	var op := GameDB.get_operator(str(pr.operator))
	header_avatar.text = String(op.name).substr(0, 1)


## MP / BR lobby tab: remembered and shown on the lobby mode card.
func _set_lobby(t: String) -> void:
	SaveManager.set_setting("lobby", "type", t)
	if current != "home":
		show_page("home")
	else:
		show_page("home")


func lobby_type() -> String:
	return str(SaveManager.get_setting("lobby", "type", "mp"))


func show_page(id: String) -> void:
	current = id
	for k in tab_buttons.keys():
		tab_buttons[k].set_pressed_no_signal(id == "home" and k == lobby_type() or id == k)
	for c in content.get_children():
		c.queue_free()
	page_bar.visible = id != "home"
	bottom_bar.visible = id == "home"
	for p in PAGES:
		if p[0] == id:
			page_title.text = p[1]
	var page: Control
	match id:
		"home": page = load("res://scripts/ui/pages/home_page.gd").new()
		"mp": page = load("res://scripts/ui/pages/mp_page.gd").new()
		"br": page = load("res://scripts/ui/pages/br_page.gd").new()
		"loadout": page = load("res://scripts/ui/pages/loadout_page.gd").new()
		"operators": page = load("res://scripts/ui/pages/operators_page.gd").new()
		"settings": page = load("res://scripts/ui/pages/settings_page.gd").new()
		"online": page = load("res://scripts/ui/pages/online_page.gd").new()
		"profile": page = load("res://scripts/ui/pages/profile_page.gd").new()
		"credits": page = load("res://scripts/ui/pages/credits_page.gd").new()
	page.set("menu", self)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(page)
