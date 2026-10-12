class_name InputSetup
extends RefCounted
## Registers desktop keyboard/mouse/gamepad actions at startup (kept in code so the
## bindings are version-controlled in one readable place).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_C, KEY_CTRL],
	"sprint": [KEY_SHIFT],
	"reload": [KEY_R],
	"switch_weapon": [KEY_Q],
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"toggle_view": [KEY_Z],
	"bag": [KEY_I, KEY_B],
	"lethal": [KEY_G],
	"tactical": [KEY_T],
	"melee": [KEY_V],
	"inspect": [KEY_Y],
	"interact": [KEY_F, KEY_E],
	"heal": [KEY_H],
	"plate": [KEY_X],
	"skill": [KEY_K, KEY_4],
	"pause": [KEY_ESCAPE, KEY_P],
	"scoreboard": [KEY_TAB],
}

const MOUSE := {
	"fire": MOUSE_BUTTON_LEFT,
	"ads": MOUSE_BUTTON_RIGHT,
}

const PAD := {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"reload": JOY_BUTTON_X,
	"switch_weapon": JOY_BUTTON_Y,
	"lethal": JOY_BUTTON_RIGHT_SHOULDER,
	"tactical": JOY_BUTTON_LEFT_SHOULDER,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"melee": JOY_BUTTON_RIGHT_STICK,
	"pause": JOY_BUTTON_START,
	"interact": JOY_BUTTON_DPAD_UP,
	"heal": JOY_BUTTON_DPAD_DOWN,
	"inspect": JOY_BUTTON_DPAD_LEFT,
}


static func register() -> void:
	for action in KEYS.keys():
		_ensure(action)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in MOUSE.keys():
		_ensure(action)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE[action]
		InputMap.action_add_event(action, m)
	for action in PAD.keys():
		_ensure(action)
		var j := InputEventJoypadButton.new()
		j.button_index = PAD[action]
		InputMap.action_add_event(action, j)
	_ensure("fire")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("fire", rt)
	_ensure("ads")
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	InputMap.action_add_event("ads", lt)


static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
