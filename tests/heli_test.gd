extends Node3D
## Headless flight-model test for the Helicopter:
##   godot --headless --fixed-fps 60 res://tests/heli_test.tscn
var heli: Helicopter
var t := 0.0
var stage := 0
var fails := 0
var log_t := 0.0
var alt_hover := 0.0


func _ready() -> void:
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2000, 2, 2000)
	cs.shape = bs
	cs.position.y = -1
	ground.add_child(cs)
	add_child(ground)
	heli = Helicopter.new()
	add_child(heli)
	heli.global_position = Vector3(0, 0.6, 0)
	heli.autopilot_test = true


func check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		fails += 1


func _physics_process(delta: float) -> void:
	t += delta
	log_t += delta
	if log_t > 1.0:
		log_t = 0.0
		print("  [%.0fs] pos=%s vel=%s rpm=%.2f yaw=%.2f" % [t, str(heli.global_position.snapped(Vector3.ONE * 0.1)), str(heli.linear_velocity.snapped(Vector3.ONE * 0.1)), heli.rpm, heli.rotation.y])
	match stage:
		0:  # spool up + climb
			heli.fly(Vector2.ZERO, true, false, 0.0)
			if t > 8.0:
				check(heli.global_position.y > 12.0, "climbs with collective up (alt %.1f)" % heli.global_position.y)
				check(heli.global_transform.basis.y.y > 0.97, "stays level while climbing")
				stage = 1
				t = 0.0
		1:  # hands off: hover
			heli.fly(Vector2.ZERO, false, false, 0.0)
			if t > 1.5 and alt_hover == 0.0:
				alt_hover = heli.global_position.y
			if t > 5.0:
				check(absf(heli.global_position.y - alt_hover) < 2.0 and heli.linear_velocity.length() < 1.5, "hover assist holds altitude (drift %.2f m)" % (heli.global_position.y - alt_hover))
				stage = 2
				t = 0.0
		2:  # forward cyclic
			heli.fly(Vector2(0, -1), false, false, 0.0)
			if t > 6.0:
				var fwd := -heli.global_transform.basis.z
				var v := heli.linear_velocity
				check(Vector2(v.x, v.z).length() > 15.0, "forward stick accelerates (%.1f m/s)" % Vector2(v.x, v.z).length())
				check(v.dot(Vector3(0, 0, -1)) > 10.0, "moves toward the nose")
				check(heli.global_position.y > 6.0, "keeps altitude in forward flight (%.1f)" % heli.global_position.y)
				check(fwd.y < -0.1, "nose pitched down in forward flight")
				stage = 3
				t = 0.0
		3:  # yaw to heading 90 deg left
			heli.fly(Vector2.ZERO, false, false, PI * 0.5)
			if t > 5.0:
				check(absf(wrapf(heli.rotation.y - PI * 0.5, -PI, PI)) < 0.25, "yaws to pilot heading (%.2f)" % heli.rotation.y)
				check(heli.linear_velocity.length() < 8.0, "drag slows the helicopter when stick released")
				stage = 4
				t = 0.0
		4:  # descend and land
			heli.fly(Vector2.ZERO, false, true, PI * 0.5)
			if t > 14.0:
				check(heli.global_position.y < 2.0, "descends to the ground (%.1f)" % heli.global_position.y)
				check(heli.alive and heli.health > heli.max_health * 0.8, "gentle landing does no heavy damage (%d)" % heli.health)
				print("=== RESULT heli: %s ===" % ("all passed" if fails == 0 else "%d failed" % fails))
				get_tree().quit(fails)
