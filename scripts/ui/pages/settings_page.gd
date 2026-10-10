extends VBoxContainer
## Settings with tabs. Every control maps to a setting that is read by gameplay code
## (see README "Settings" for where each one is applied). Changes save immediately.

var menu: Control
var tabs: TabContainer


func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(UITheme.label("SETTINGS", 34, UITheme.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.button("Reset tab", _reset_tab, Vector2(170, 52), "back"))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build()


func _build() -> void:
	var cur := tabs.current_tab
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	_controls_tab()
	_sens_tab()
	_audio_tab()
	_graphics_tab()
	_access_tab()
	if cur >= 0 and cur < tabs.get_tab_count():
		tabs.current_tab = cur


func _reset_tab() -> void:
	var sections := [["controls"], ["controls"], ["audio"], ["graphics"], ["accessibility"]]
	for s in sections[tabs.current_tab]:
		var keep_sens := {}
		if tabs.current_tab == 0:
			# Controls tab resets only its own keys, not sensitivities.
			for k in ["look_sensitivity", "ads_sensitivity", "optic_red_dot", "optic_holo", "optic_4x", "optic_8x", "mouse_sensitivity", "gyro_sensitivity"]:
				keep_sens[k] = SaveManager.get_setting("controls", k)
		elif tabs.current_tab == 1:
			for k in ["scheme", "invert_y", "gyro_enabled", "aim_assist", "sprint_mode", "ads_mode", "auto_fire"]:
				keep_sens[k] = SaveManager.get_setting("controls", k)
		SaveManager.reset_settings_section(s)
		for k in keep_sens.keys():
			SaveManager.set_setting(s, k, keep_sens[k])
	SaveManager.save_settings()
	_build()


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	return v


func _row(parent: Control, text: String, desc: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	lv.custom_minimum_size = Vector2(360, 0)
	lv.add_child(UITheme.label(text, 19))
	if desc != "":
		var d := UITheme.label(desc, 14, UITheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(360, 0)
		lv.add_child(d)
	h.add_child(lv)
	parent.add_child(h)
	return h


func _slider(parent: Control, sec: String, key: String, text: String, mn: float, mx: float, step: float, desc := "", fmt := "%.2f") -> void:
	var h := _row(parent, text, desc)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(300, 40)
	s.value = float(SaveManager.get_setting(sec, key, mn))
	var vl := UITheme.label(fmt % s.value, 18, UITheme.ACCENT)
	vl.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v):
		vl.text = fmt % v
		SaveManager.set_setting(sec, key, int(v) if step >= 1.0 else v)
		if sec == "graphics" and key != "fov":
			SaveManager.set_setting("graphics", "preset", "custom")
		SaveManager.save_settings())
	h.add_child(s)
	h.add_child(vl)


func _check(parent: Control, sec: String, key: String, text: String, desc := "") -> void:
	var h := _row(parent, text, desc)
	var c := CheckButton.new()
	c.button_pressed = bool(SaveManager.get_setting(sec, key, false))
	c.custom_minimum_size = Vector2(80, 44)
	c.toggled.connect(func(on):
		SaveManager.set_setting(sec, key, on)
		if sec == "graphics":
			SaveManager.set_setting("graphics", "preset", "custom")
		SaveManager.save_settings()
		AudioManager.ui("select"))
	h.add_child(c)


func _choice(parent: Control, sec: String, key: String, text: String, options: Array, desc := "", on_change := Callable()) -> void:
	var h := _row(parent, text, desc)
	var cur = SaveManager.get_setting(sec, key)
	var btns := {}
	for o in options:
		var b := UITheme.button(str(o[1]), func():
			SaveManager.set_setting(sec, key, o[0])
			if on_change.is_valid():
				on_change.call(o[0])
			SaveManager.save_settings()
			for k in btns.keys():
				btns[k].set_pressed_no_signal(k == o[0]), Vector2(130, 48), "select")
		b.toggle_mode = true
		b.set_pressed_no_signal(cur == o[0])
		b.add_theme_font_size_override("font_size", 17)
		btns[o[0]] = b
		h.add_child(b)


func _controls_tab() -> void:
	var v := _page("Controls")
	_choice(v, "controls", "scheme", "Control scheme", [["auto", "Auto"], ["touch", "Touch"], ["keyboard", "Keyboard/Mouse"]], "Auto uses touch controls when a touchscreen is detected.")
	_choice(v, "controls", "sprint_mode", "Sprint", [["auto", "Auto"], ["toggle", "Button only"]], "Auto: push the joystick fully forward to sprint. Drag past the top of the stick to lock sprint.")
	_choice(v, "controls", "ads_mode", "Aim down sights", [["toggle", "Tap"], ["hold", "Hold"]])
	_check(v, "controls", "invert_y", "Invert vertical look")
	_check(v, "controls", "aim_assist", "Aim assist", "Slows the crosshair over enemies and gently pulls ADS toward targets in view. Applies to touch controls only.")
	_check(v, "controls", "auto_fire", "Simple mode (auto-fire)", "Fires automatically while the crosshair is on an enemy in range.")
	if OS.has_feature("mobile"):
		_check(v, "controls", "gyro_enabled", "Gyroscope aiming", "Uses the device gyroscope (if present) to aim while using touch controls.")
	v.add_child(UITheme.button("Customize HUD layout", func(): get_tree().change_scene_to_file("res://scenes/menus/hud_editor.tscn"), Vector2(320, 56)))


func _sens_tab() -> void:
	var v := _page("Sensitivity")
	_slider(v, "controls", "look_sensitivity", "Camera (touch/gamepad)", 0.2, 3.0, 0.05)
	_slider(v, "controls", "mouse_sensitivity", "Mouse", 0.2, 3.0, 0.05)
	_slider(v, "controls", "ads_sensitivity", "ADS multiplier", 0.2, 1.5, 0.05, "Applied while aiming with iron sights and any optic.")
	_slider(v, "controls", "optic_red_dot", "Red dot", 0.3, 1.5, 0.05, "Multiplier on top of ADS")
	_slider(v, "controls", "optic_holo", "Holographic", 0.3, 1.5, 0.05)
	_slider(v, "controls", "optic_4x", "4x scope", 0.2, 1.5, 0.05)
	_slider(v, "controls", "optic_8x", "8x scope", 0.1, 1.5, 0.05)
	if OS.has_feature("mobile"):
		_slider(v, "controls", "gyro_sensitivity", "Gyroscope", 0.2, 3.0, 0.05)


func _audio_tab() -> void:
	var v := _page("Audio")
	_slider(v, "audio", "master", "Master volume", 0.0, 1.0, 0.05, "", "%.2f")
	_slider(v, "audio", "music", "Music", 0.0, 1.0, 0.05)
	_slider(v, "audio", "sfx", "Effects", 0.0, 1.0, 0.05)


func _graphics_tab() -> void:
	var v := _page("Graphics")
	_choice(v, "graphics", "preset", "Preset", [["low", "Low"], ["medium", "Medium"], ["high", "High"], ["custom", "Custom"]], "Low is recommended for older phones.",
		func(p):
			if p != "custom":
				GraphicsSettings.apply_preset(p)
				_build.call_deferred())
	_slider(v, "graphics", "render_scale", "Render scale", 0.5, 1.0, 0.05, "3D resolution; the HUD stays sharp.")
	_check(v, "graphics", "shadows", "Shadows")
	_choice(v, "graphics", "effects_quality", "Effects quality", [[0, "Low"], [1, "Medium"], [2, "High"]], "Particle counts, tracers, shadow distance.", func(_p): SaveManager.set_setting("graphics", "preset", "custom"))
	_check(v, "graphics", "msaa", "Anti-aliasing (MSAA 2x)")
	_choice(v, "graphics", "fps_target", "Frame rate limit", [[30, "30"], [60, "60"], [90, "90"], [120, "120"]], "Higher uses more battery.", func(_p): SaveManager.set_setting("graphics", "preset", "custom"))
	_slider(v, "graphics", "fov", "Field of view", 65.0, 100.0, 1.0, "", "%d")
	_check(v, "graphics", "show_fps", "Show FPS counter")


func _access_tab() -> void:
	var v := _page("Accessibility")
	_choice(v, "accessibility", "enemy_color", "Enemy highlight color", [["red", "Red"], ["orange", "Orange"], ["magenta", "Magenta"]], "Name tags, radar dots and crosshair on-target color.")
	_slider(v, "accessibility", "hitmarker_scale", "Hit marker size", 0.6, 2.0, 0.1)
	_slider(v, "accessibility", "camera_shake", "Camera shake / recoil kick", 0.0, 1.0, 0.1)
	_slider(v, "accessibility", "hud_scale", "Touch button size", 0.7, 1.4, 0.05, "Default size for buttons not resized in the HUD editor.")
	_slider(v, "accessibility", "hud_opacity", "Touch button opacity", 0.2, 1.0, 0.05)
