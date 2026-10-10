class_name TouchControls
extends Control
## Multi-touch mobile FPS controls: floating left joystick, right-side look area and action buttons.
## Each finger is owned by exactly one thing (joystick, look, or a button), so pressing a button
## never rotates the camera or moves the player. Dragging on the fire button also aims (common mobile FPS pattern).
## In edit_mode (HUD editor), buttons can be dragged and resized instead.

signal button_selected(id: String)
signal layout_edited

## id -> default {x, y (0..1 of safe area), size (px @720p), label, br_only}
const DEFAULTS := {
	"joystick": {"x": 0.15, "y": 0.72, "size": 190.0, "label": ""},
	"fire": {"x": 0.86, "y": 0.62, "size": 112.0, "label": "FIRE"},
	"fire_left": {"x": 0.08, "y": 0.38, "size": 84.0, "label": "FIRE"},
	"ads": {"x": 0.93, "y": 0.42, "size": 80.0, "label": "ADS"},
	"jump": {"x": 0.93, "y": 0.84, "size": 80.0, "label": "JUMP"},
	"crouch": {"x": 0.80, "y": 0.88, "size": 76.0, "label": "CROUCH"},
	"reload": {"x": 0.74, "y": 0.70, "size": 66.0, "label": "RELOAD"},
	"switch": {"x": 0.68, "y": 0.86, "size": 70.0, "label": "SWAP"},
	"lethal": {"x": 0.71, "y": 0.50, "size": 62.0, "label": "FRAG"},
	"tactical": {"x": 0.78, "y": 0.38, "size": 62.0, "label": "TACT"},
	"melee": {"x": 0.66, "y": 0.62, "size": 58.0, "label": "KNIFE"},
	"interact": {"x": 0.57, "y": 0.66, "size": 76.0, "label": "PICK"},
	"heal": {"x": 0.30, "y": 0.08, "size": 64.0, "label": "HEAL", "br_only": true},
	"plate": {"x": 0.36, "y": 0.08, "size": 60.0, "label": "PLATE", "br_only": true},
	"sprint": {"x": 0.15, "y": 0.40, "size": 64.0, "label": "SPRINT"},
	"score": {"x": 0.62, "y": 0.06, "size": 52.0, "label": "TAB"},
	"pause": {"x": 0.68, "y": 0.06, "size": 52.0, "label": "II"},
}

const MOUSE_FINGER := 99

var player: Player
var edit_mode := false
var br_mode := false
var driving := false         ## in a vehicle: only movement, look, EXIT, BRAKE, pause, scoreboard
var layout := {}
var selected := ""
var _fingers := {}           ## index -> {kind: "joy"/"look"/"btn", id, start, last}
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _pressed := {}           ## button id -> true while held
var _interact_available := false
var _font: Font
var on_pause: Callable
var on_score: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	load_layout()
	SaveManager.settings_changed.connect(load_layout)


func load_layout() -> void:
	layout = {}
	var saved: Dictionary = SaveManager.settings.get("hud_layout", {})
	var g_size := float(SaveManager.get_setting("accessibility", "hud_scale", 1.0))
	var g_op := float(SaveManager.get_setting("accessibility", "hud_opacity", 0.75))
	for id in DEFAULTS.keys():
		var d: Dictionary = DEFAULTS[id].duplicate()
		d.opacity = g_op
		d.visible = true
		d.size = d.size * g_size
		if saved.has(id):
			for k in ["x", "y", "size", "opacity", "visible"]:
				if saved[id].has(k):
					d[k] = saved[id][k]
		layout[id] = d
	_joy_center = _pos("joystick")
	queue_redraw()


func save_layout() -> void:
	var out := {}
	for id in layout.keys():
		out[id] = {"x": layout[id].x, "y": layout[id].y, "size": layout[id].size, "opacity": layout[id].opacity, "visible": layout[id].visible}
	SaveManager.settings.hud_layout = out
	SaveManager.save_settings()


func reset_layout() -> void:
	SaveManager.settings.hud_layout = {}
	load_layout()
	layout_edited.emit()


func _safe() -> Rect2:
	return UITheme.safe_rect(get_viewport())


func _pos(id: String) -> Vector2:
	var s := _safe()
	var d: Dictionary = layout[id]
	return s.position + Vector2(d.x * s.size.x, d.y * s.size.y)


func _radius(id: String) -> float:
	return float(layout[id].size) * 0.5


func _button_active(id: String) -> bool:
	if id == "joystick" or not layout[id].visible:
		return false
	if DEFAULTS[id].get("br_only", false) and not br_mode and not edit_mode:
		return false
	if driving and not edit_mode:
		return id in ["interact", "jump", "pause", "score"]
	if id == "interact" and not _interact_available and not edit_mode and not driving:
		return false
	return true


func set_driving(v: bool) -> void:
	driving = v
	layout.interact.label = "EXIT" if v else "PICK"
	layout.jump.label = "BRAKE" if v else "JUMP"
	release_all()
	queue_redraw()


func is_held(id: String) -> bool:
	return _pressed.has(id)


func set_interact_available(v: bool, text: String = "PICK") -> void:
	if driving:
		return
	_interact_available = v
	layout.interact.label = text
	queue_redraw()


func _hit_button(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in layout.keys():
		if not _button_active(id) and not (edit_mode and id == "joystick"):
			continue
		var d := p.distance_to(_pos(id))
		var r := _radius(id) * (1.15 if not edit_mode else 1.0)
		if d < r and d < best_d:
			best_d = d
			best = id
	return best


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touch_down(e.index, e.position)
		else:
			_touch_up(e.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_drag(d.index, d.position, d.relative)
		get_viewport().set_input_as_handled()
	elif not DisplayServer.is_touchscreen_available():
		# Desktop: let the mouse act as a single finger so the touch layout and HUD editor can be used/tested.
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				_touch_down(MOUSE_FINGER, mb.position)
			else:
				_touch_up(MOUSE_FINGER)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _fingers.has(MOUSE_FINGER):
			var mm := event as InputEventMouseMotion
			_touch_drag(MOUSE_FINGER, mm.position, mm.relative)
			get_viewport().set_input_as_handled()


func _touch_down(idx: int, p: Vector2) -> void:
	if edit_mode:
		var hid := _hit_button(p)
		if hid != "":
			selected = hid
			_fingers[idx] = {"kind": "edit", "id": hid, "offset": _pos(hid) - p}
			button_selected.emit(hid)
			queue_redraw()
		return
	var id := _hit_button(p)
	if id != "":
		_fingers[idx] = {"kind": "btn", "id": id}
		_press(id)
		return
	var s := _safe()
	if p.x < s.position.x + s.size.x * 0.42 and p.y > s.position.y + s.size.y * 0.3:
		_fingers[idx] = {"kind": "joy"}
		_joy_center = p   # floating joystick
		_joy_vec = Vector2.ZERO
	else:
		_fingers[idx] = {"kind": "look"}
	queue_redraw()


func _touch_drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	match f.kind:
		"edit":
			var s := _safe()
			var np: Vector2 = p + f.offset
			layout[f.id].x = clampf((np.x - s.position.x) / s.size.x, 0.02, 0.98)
			layout[f.id].y = clampf((np.y - s.position.y) / s.size.y, 0.03, 0.97)
			layout_edited.emit()
			queue_redraw()
		"joy":
			var r := _radius("joystick")
			var v := (p - _joy_center) / r
			# Dragging well above the stick engages sprint lock.
			if player:
				player.input.touch_sprint = v.y < -1.35 or (SaveManager.get_setting("controls", "sprint_mode", "auto") == "auto" and v.y < -0.92 and absf(v.x) < 0.5)
			_joy_vec = v.limit_length(1.0)
			if player:
				player.input.move = _joy_vec
			queue_redraw()
		"look":
			if player:
				player.touch_look(rel)
		"btn":
			if f.id in ["fire", "ads", "fire_left"] and player:
				player.touch_look(rel)


func _touch_up(idx: int) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	_fingers.erase(idx)
	match f.kind:
		"edit":
			pass
		"joy":
			_joy_vec = Vector2.ZERO
			_joy_center = _pos("joystick")
			if player:
				player.input.move = Vector2.ZERO
				player.input.touch_sprint = false
		"btn":
			_release(f.id)
	queue_redraw()


func _press(id: String) -> void:
	_pressed[id] = true
	queue_redraw()
	if player == null:
		return
	var inp := player.input
	match id:
		"fire", "fire_left": inp.fire = true
		"ads":
			if SaveManager.get_setting("controls", "ads_mode", "toggle") == "hold":
				player.ads_on = true
			else:
				inp.ads_toggle = true
		"jump": inp.jump = true
		"crouch": inp.crouch = true
		"reload": inp.reload = true
		"switch": inp.switch_weapon = true
		"lethal": inp.lethal = true
		"tactical": inp.tactical = true
		"melee": inp.melee = true
		"interact":
			inp.interact = true
			inp.interact_held = true
		"heal": inp.heal = true
		"plate": inp.plate = true
		"sprint": inp.sprint_toggle = true
		"pause":
			if on_pause.is_valid(): on_pause.call()
		"score":
			if on_score.is_valid(): on_score.call(true)


func _release(id: String) -> void:
	_pressed.erase(id)
	if player == null:
		return
	match id:
		"fire", "fire_left":
			var still := false
			for f in _fingers.values():
				if f.kind == "btn" and f.id in ["fire", "fire_left"]:
					still = true
			player.input.fire = still
		"interact":
			player.input.interact_held = false
		"ads":
			if SaveManager.get_setting("controls", "ads_mode", "toggle") == "hold":
				player.ads_on = false
		"score":
			if on_score.is_valid(): on_score.call(false)


func release_all() -> void:
	for idx in _fingers.keys():
		_touch_up(idx)
	_fingers.clear()


func _process(_d: float) -> void:
	if player and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	for id in layout.keys():
		var d: Dictionary = layout[id]
		if not d.visible and not edit_mode:
			continue
		if not _button_active(id) and id != "joystick":
			if not edit_mode:
				continue
		var op: float = d.opacity * (0.35 if edit_mode and not d.visible else 1.0)
		var c := _pos(id)
		var r := _radius(id)
		if id == "joystick":
			var jc := _joy_center if not edit_mode else c
			draw_circle(jc, r, Color(0, 0, 0, 0.28 * op))
			draw_arc(jc, r, 0, TAU, 48, Color(1, 1, 1, 0.45 * op), 3.0, true)
			var knob := jc + _joy_vec * r * 0.6
			draw_circle(knob, r * 0.36, Color(1, 1, 1, 0.5 * op))
			if player and player.input.touch_sprint:
				_text(jc + Vector2(0, -r - 18), "SPRINT", 18, Color(UITheme.ACCENT, op))
		else:
			var held := _pressed.has(id)
			var fill := Color(UITheme.ACCENT, 0.55 * op) if held else Color(0, 0, 0, 0.38 * op)
			if id in ["fire", "fire_left"] and not held:
				fill = Color(0.6, 0.12, 0.08, 0.42 * op)
			draw_circle(c, r, fill)
			draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.6 * op), 2.5, true)
			var label: String = d.label
			if player:
				if id == "lethal":
					label = "%s %d" % ["NADE", player.inv.lethal_count]
				elif id == "tactical":
					label = "%s %d" % ["TACT", player.inv.tactical_count]
				elif id == "heal":
					label = "HEAL %d" % (player.inv.heals.get("medkit", 0) + player.inv.heals.get("bandage", 0))
				elif id == "plate":
					label = "PLATE %d" % player.inv.plates
				elif id == "ads" and player.ads_on:
					label = "ADS*"
			_text(c, label, clampi(int(r * 0.34), 11, 24), Color(1, 1, 1, minf(op + 0.2, 1.0)))
		if edit_mode and id == selected:
			draw_arc(c, r + 6, 0, TAU, 48, UITheme.ACCENT, 3.0, true)


func _text(center: Vector2, t: String, size: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(_font, center + Vector2(-w * 0.5, size * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
