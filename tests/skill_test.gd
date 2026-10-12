extends Node3D
## Headless test of the operator skills (rewind, jetpack, grapple hook, quick slash):
##   godot --headless --fixed-fps 60 res://tests/skill_test.tscn

class TestActor extends Actor:
	var move_dir := Vector3.ZERO
	func _physics_process(delta: float) -> void:
		tick_common(delta)
		if not alive:
			return
		velocity.x = move_dir.x
		velocity.z = move_dir.z
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if skill:
			skill.apply_motion(delta)
		move_and_slide()

var fails := 0
var t := 0.0
var stage := 0
var a: TestActor
var enemy: TestActor
var mark := Vector3.ZERO


func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.global_position = pos


func _ready() -> void:
	MatchConfig.mode = "tdm"
	_box(Vector3(0, -1, 0), Vector3(400, 2, 400))
	_box(Vector3(0, 5, -40), Vector3(30, 10, 1))     # wall for the hook
	a = _spawn(Vector3.ZERO, 0)
	print("== operator skills ==")


func _spawn(p: Vector3, team: int) -> TestActor:
	var x := TestActor.new()
	x.team = team
	add_child(x)
	x.global_position = p
	return x


func check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		fails += 1


func _next(skill_id: String) -> void:
	if a.skill:
		a.skill.queue_free()
		a.skill = null
	a.velocity = Vector3.ZERO
	a.move_dir = Vector3.ZERO
	a.global_position = Vector3.ZERO
	a.setup_skill(skill_id)
	t = 0.0
	stage += 1


func _physics_process(delta: float) -> void:
	t += delta
	match stage:
		0:
			_next("rewind")
			check(a.skill != null and a.skill.charge == 0.0, "skill created with an empty meter")
			check(not a.skill.activate(Vector3.FORWARD), "cannot activate while charging")
			a.move_dir = Vector3(4, 0, 0)
		1:
			if t > 3.2:
				a.health = 20.0
				a.skill.charge = 1.0
				var before := a.global_position
				check(a.skill.activate(Vector3.FORWARD), "rewind activates when charged")
				check(a.global_position.distance_to(before) > 8.0, "rewind moved back %.1f m" % a.global_position.distance_to(before))
				check(a.health >= 99.0, "rewind restored health (%.0f)" % a.health)
				check(a.skill.charge == 0.0, "meter emptied after use")
				_next("jetpack")
				a.skill.charge = 1.0
		2:
			if t > 0.3 and t < 0.4 and not a.skill.active:
				check(a.skill.activate(Vector3.FORWARD), "jetpack activates")
			if t > 1.9 and mark == Vector3.ZERO:
				mark = a.global_position
				check(a.global_position.y > 5.0, "jetpack climbed to %.1f m" % a.global_position.y)
			if t > 3.6:
				check(a.velocity.y > -3.0 and a.global_position.y > 2.0, "jetpack hover sinks slowly (vy %.1f)" % a.velocity.y)
				mark = Vector3.ZERO
				_next("hook")
				a.skill.charge = 1.0
		3:
			if t > 0.3 and not a.skill.active and mark == Vector3.ZERO:
				mark = Vector3.ONE
				check(not a.skill.activate(Vector3(0, 0, 1)), "hook needs a surface to hit (aiming at empty sky behind)")
				check(a.skill.activate(Vector3(0, 0.05, -1).normalized()), "hook latches onto the wall 40 m ahead")
			if t > 2.4:
				check(a.global_position.z < -30.0, "hook pulled the actor to z=%.1f" % a.global_position.z)
				mark = Vector3.ZERO
				_next("quickslash")
				a.skill.charge = 1.0
				enemy = _spawn(Vector3(0, 0, -5), 1)
				enemy.regen_enabled = false
		4:
			if t > 0.3 and mark == Vector3.ZERO:
				mark = Vector3.ONE
				check(a.skill.activate(Vector3(0, 0, -1)), "quick slash activates")
			if t > 1.0:
				check(a.global_position.z < -7.0, "quick slash dashed to z=%.1f" % a.global_position.z)
				check(not enemy.alive, "quick slash cut down the enemy in the path")
				check(a.skill.charge > 0.15, "kill refunded meter charge (%.2f)" % a.skill.charge)
				stage = 99
				print("SKILL TEST: %d failures" % fails)
				get_tree().quit(1 if fails > 0 else 0)
