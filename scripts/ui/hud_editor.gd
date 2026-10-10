extends Control
## HUD layout editor: drag buttons, resize, change opacity, hide/show, reset, save.

var touch: TouchControls
var sel_label: Label
var size_slider: HSlider
var op_slider: HSlider
var vis_check: CheckButton
var _updating := false


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.colors = PackedColorArray([Color(0.35, 0.45, 0.55), Color(0.3, 0.32, 0.22)])
	grad.fill_to = Vector2(0, 1)
	bg.texture = grad
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	touch = TouchControls.new()
	touch.edit_mode = true
	touch.br_mode = true
	add_child(touch)
	var panel := UITheme.panel(Vector2(340, 0))
	panel.position = Vector2(get_viewport_rect().size.x * 0.5 - 170, 70)
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.label("HUD EDITOR", 24, UITheme.ACCENT))
	v.add_child(UITheme.label("Drag any button to move it. Select to resize.", 14, UITheme.MUTED))
	sel_label = UITheme.label("Selected: none", 18)
	v.add_child(sel_label)
	size_slider = _slider(v, "Size", 40, 260, 1)
	op_slider = _slider(v, "Opacity", 0.1, 1.0, 0.05)
	vis_check = CheckButton.new()
	vis_check.text = "Visible"
	vis_check.toggled.connect(func(on):
		if not _updating and touch.selected != "":
			touch.layout[touch.selected].visible = on
			touch.queue_redraw())
	v.add_child(vis_check)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(UITheme.button("Reset", func(): touch.reset_layout(); _on_select(touch.selected), Vector2(100, 52), "back"))
	row.add_child(UITheme.button("Save", func():
		touch.save_layout()
		AudioManager.ui("confirm")
		sel_label.text = "Layout saved", Vector2(100, 52), "confirm"))
	row.add_child(UITheme.button("Exit", func(): MatchConfig.to_menu(), Vector2(100, 52)))
	var toggle_btn: Button
	toggle_btn = UITheme.button("HIDE PANEL", func():
		panel.visible = not panel.visible
		toggle_btn.text = "HIDE PANEL" if panel.visible else "SHOW PANEL", Vector2(170, 48))
	toggle_btn.position = Vector2(12, 12)
	add_child(toggle_btn)
	touch.button_selected.connect(_on_select)
	_on_select("")


func _slider(parent: Control, text: String, mn: float, mx: float, step: float) -> HSlider:
	parent.add_child(UITheme.label(text, 16))
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(300, 36)
	s.value_changed.connect(func(val):
		if _updating or touch.selected == "":
			return
		touch.layout[touch.selected]["size" if text == "Size" else "opacity"] = val
		touch.queue_redraw())
	parent.add_child(s)
	return s


func _on_select(id: String) -> void:
	_updating = true
	var has := id != "" and touch.layout.has(id)
	sel_label.text = "Selected: " + (id.capitalize() if has else "none")
	size_slider.editable = has
	op_slider.editable = has
	vis_check.disabled = not has
	if has:
		size_slider.value = touch.layout[id].size
		op_slider.value = touch.layout[id].opacity
		vis_check.button_pressed = touch.layout[id].visible
	_updating = false
