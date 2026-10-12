extends Node3D
## "moves" suite: player movement rules on a flat test ground with a real Player node.
## Slide vs crouch (CODM-style), stand-up rules, and crosshair/bullet-cone agreement.

var passed := 0
var failed := 0
var p: Player


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hs() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


## Hold W (+ sprint) for n frames.
func _run_fwd(n: int, sprint: bool) -> void:
	for i in n:
		p.input.move = Vector2(0, -1)
		p.input.sprint_held = sprint
		await get_tree().physics_frame


func _press_crouch() -> void:
	p.input.crouch = true
	await get_tree().physics_frame


func _reset() -> void:
	p.input.move = Vector2.ZERO
	p.input.sprint_held = false
	p.crouching = false
	p.sliding = false
	p.global_position = Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	await _frames(40)


func _run() -> void:
	MatchConfig.autoplay_player = false
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800, 2, 800)
	cs.shape = box
	ground.add_child(cs)
	ground.position = Vector3(0, -1, 0)
	add_child(ground)
	p = Player.new()
	p.position = Vector3(0, 0.1, 0)
	add_child(p)
	p.inv.load_from_loadout({"primary": "ar_m4k", "secondary": "pistol_p9", "melee": "knife", "lethal": "frag", "tactical": "smoke"})
	p.equip_current()
	p.touch_mode = true   # input is driven directly (like the touch HUD); keyboard polling off
	await _frames(30)
	# 1. Walking + crouch = crouch, not a slide.
	await _run_fwd(40, false)
	await _press_crouch()
	check(p.crouching and not p.sliding, "walking + crouch = crouch (no slide)")
	await _run_fwd(30, false)
	check(_hs() < 3.2, "crouch-walk speed (%.1f m/s)" % _hs())
	# 2. Standing still + crouch = crouch.
	await _reset()
	await _press_crouch()
	check(p.crouching and not p.sliding, "standing + crouch = crouch")
	# 3. Crouched -> start sprinting stands up (new sprint request).
	await _run_fwd(20, true)
	check(not p.crouching and p.sprinting, "sprinting from a crouch stands up")
	# 4. Sprint just started from crouch (< 0.2 s) + crouch = crouch, not slide.
	await _reset()
	await _press_crouch()
	await _run_fwd(4, true)
	p.input.move = Vector2(0, -1)
	p.input.sprint_held = true
	await _press_crouch()
	check(p.crouching and not p.sliding, "just came from crouch + crouch = crouch (no slide)")
	await _run_fwd(20, true)
	check(p.crouching, "holding sprint keeps the crouch (no instant stand-up)")
	# 5. Established sprint + crouch = slide with a speed burst that decays.
	await _reset()
	await _run_fwd(60, true)
	check(p.sprinting and _hs() > 6.5, "sprinting (%.1f m/s)" % _hs())
	var x0 := p.global_position
	p.input.move = Vector2(0, -1)
	p.input.sprint_held = false
	await _press_crouch()
	check(p.sliding, "sprint + crouch = slide")
	var peak := 0.0
	for i in 12:
		p.input.move = Vector2(0, -1)
		await get_tree().physics_frame
		peak = maxf(peak, _hs())
	check(peak > 9.5, "slide speed burst (%.1f m/s)" % peak)
	for i in 60:
		p.input.move = Vector2(0, -1)
		await get_tree().physics_frame
	check(not p.sliding, "slide ends after ~1 s")
	check(p.crouching, "slide without sprint held ends in a crouch")
	var dist := Vector2(p.global_position.x - x0.x, p.global_position.z - x0.z).length()
	check(dist > 6.0, "slide covers distance (%.1f m)" % dist)
	# 6. Slide while still holding sprint -> back on your feet sprinting.
	await _reset()
	await _run_fwd(60, true)
	p.input.move = Vector2(0, -1)
	p.input.sprint_held = true
	await _press_crouch()
	check(p.sliding, "slide (sprint held)")
	await _run_fwd(75, true)
	check(not p.crouching and p.sprinting, "slide with sprint held ends standing and sprinting")
	# 7. Slide-cancel jump.
	await _reset()
	await _run_fwd(60, true)
	await _press_crouch()
	await _frames(5)
	p.input.jump = true
	await _frames(6)
	check(not p.sliding and p.velocity.y > 2.0, "jump cancels the slide")
	# 8. Crosshair = bullet cone.
	await _reset()
	var w := p.inv.active()
	for i in 6:
		w.bloom = minf(w.bloom + w.stats.spread_per_shot_deg, w.stats.max_bloom_deg)
	var sp := p.current_spread()
	var worst := 0.0
	var dir := p.look_dir()
	for i in 4000:
		worst = maxf(worst, rad_to_deg(dir.angle_to(Combat.cone(dir, sp))))
	check(worst <= sp + 0.001 and worst > sp * 0.9, "shots stay inside the crosshair cone (max %.2f of %.2f deg)" % [worst, sp])
	var hip := p.current_spread()
	p.crouching = true
	await _frames(2)
	check(p.current_spread() < hip, "crouching tightens the crosshair (%.2f < %.2f)" % [p.current_spread(), hip])
	# Mantle onto a 1.2 m crate in front of the player.
	p.crouching = false
	await _reset()
	var crate := StaticBody3D.new()
	var ccs := CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Vector3(3, 1.2, 3)
	ccs.shape = cb
	crate.add_child(ccs)
	add_child(crate)
	crate.global_position = Vector3(0, 0.6, -2.2)
	p.rotation.y = 0.0
	p.yaw = 0.0
	await _run_fwd(20, false)
	p.input.jump = true
	await _run_fwd(1, false)
	check(p.mantle_t >= 0.0, "jump at a 1.2 m ledge starts a mantle")
	await _run_fwd(40, false)
	check(p.global_position.y > 1.1 and p.mantle_t < 0.0, "mantled on top of the crate (y=%.2f)" % p.global_position.y)
	crate.queue_free()
	await _reset()
	p.input.jump = true
	await _run_fwd(1, false)
	check(p.mantle_t < 0.0 and p.velocity.y > 2.0, "jump with no ledge is a normal jump")
	print("=== RESULT moves: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
