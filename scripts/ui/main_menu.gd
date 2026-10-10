extends Control
## Main menu shell: header with profile/level, left navigation rail, and swappable pages.

const PAGES := [
	["home", "HOME"], ["mp", "MULTIPLAYER"], ["br", "BATTLE ROYALE"], ["loadout", "LOADOUT"],
	["operators", "OPERATORS"], ["settings", "SETTINGS"], ["online", "ONLINE (LAN)"], ["profile", "PROFILE"], ["credits", "CREDITS"],
]

var content: Control
var nav_buttons := {}
var header_name: Label
var header_level: Label
var header_xp: ProgressBar
var header_credits: Label
var current := ""


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripes := ColorRect.new()
	stripes.color = Color(0.13, 0.15, 0.11)
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripes.anchor_left = 0.55
	add_child(stripes)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sa := UITheme.safe_rect(get_viewport())
	var vs := get_viewport_rect().size
	margin.add_theme_constant_override("margin_left", int(maxf(sa.position.x, 0) + 18))
	margin.add_theme_constant_override("margin_right", int(maxf(vs.x - sa.end.x, 0) + 18))
	margin.add_theme_constant_override("margin_top", int(maxf(sa.position.y, 0) + 12))
	margin.add_theme_constant_override("margin_bottom", int(maxf(vs.y - sa.end.y, 0) + 12))
	add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	vbox.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 6)
	body.add_child(nav)
	for p in PAGES:
		var b := UITheme.button(p[1], func(): show_page(p[0]), Vector2(230, 52), "select")
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.add_child(b)
		nav_buttons[p[0]] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		nav.add_child(UITheme.button("QUIT", func(): get_tree().quit(), Vector2(230, 52), "back"))
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	SaveManager.profile_changed.connect(_refresh_header)
	_refresh_header()
	show_page("home")
	AudioManager.play_music("res://assets/audio/music/menu_music.ogg", -10.0)


func _header() -> Control:
	var p := UITheme.panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var title := UITheme.label("STRIKE OPS", 30, UITheme.ACCENT)
	h.add_child(title)
	var sub := UITheme.label("FRONTLINE", 18, UITheme.MUTED)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	header_name = UITheme.label("", 20)
	header_level = UITheme.label("", 16, UITheme.MUTED)
	header_xp = ProgressBar.new()
	header_xp.custom_minimum_size = Vector2(220, 8)
	header_xp.show_percentage = false
	lv.add_child(header_name)
	lv.add_child(header_level)
	lv.add_child(header_xp)
	h.add_child(lv)
	header_credits = UITheme.label("", 20, UITheme.ACCENT)
	header_credits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(header_credits)
	return p


func _refresh_header() -> void:
	var pr := SaveManager.profile
	header_name.text = str(pr.name)
	header_level.text = "LEVEL %d   %d / %d XP" % [pr.level, pr.xp, SaveManager.xp_for_next(int(pr.level))]
	header_xp.max_value = SaveManager.xp_for_next(int(pr.level))
	header_xp.value = int(pr.xp)
	header_credits.text = "%d CR" % int(pr.credits)


func show_page(id: String) -> void:
	current = id
	for k in nav_buttons.keys():
		nav_buttons[k].set_pressed_no_signal(k == id)
	for c in content.get_children():
		c.queue_free()
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
