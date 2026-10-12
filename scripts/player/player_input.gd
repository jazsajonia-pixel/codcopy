class_name PlayerInput
extends RefCounted
## One frame of player intent, filled by keyboard/mouse, the touch HUD, or the test autopilot.
## "pressed" flags are edge-triggered and cleared by the player after each physics tick.

var move := Vector2.ZERO        ## x right, y forward(-)/back(+), length <= 1
var look := Vector2.ZERO        ## accumulated degrees (already sensitivity-scaled)
var fire := false
var ads_held := false
var ads_toggle := false
var jump := false
var crouch := false             ## toggle/slide trigger
var sprint_held := false
var sprint_toggle := false
var reload := false
var switch_weapon := false
var lethal := false
var tactical := false
var melee := false
var interact := false
var interact_held := false      ## held state (revive), not cleared per tick
var heal := false
var plate := false
var touch_sprint := false       ## joystick pushed fully forward (auto sprint)
var select_slot := -1           ## weapon bar / number keys: 0, 1 = weapon slots, 2 = fists/melee
var inspect := false
var toggle_view := false        ## BR: switch first/third person
var skill := false              ## operator skill


func clear_pressed() -> void:
	look = Vector2.ZERO
	ads_toggle = false
	jump = false
	select_slot = -1
	toggle_view = false
	inspect = false
	crouch = false
	sprint_toggle = false
	reload = false
	switch_weapon = false
	lethal = false
	tactical = false
	melee = false
	interact = false
	heal = false
	plate = false
	skill = false
