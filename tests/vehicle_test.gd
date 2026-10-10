extends Node3D
## "vehicle" suite: real physics on a flat test ground. Drives an SUV with a seated actor and checks
## acceleration, steering, braking, exiting, run-over damage, bullet damage pass-through and explosion.

var passed := 0
var failed := 0


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


func _actor(team: int, pos: Vector3) -> Actor:
	var a := Actor.new()
	a.team = team
	a.actor_name = "T%d" % team
	a.position = pos     # set before entering the tree so it never overlaps the car at the origin
	add_child(a)
	return a


func _run() -> void:
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 2, 600)
	cs.shape = box
	ground.add_child(cs)
	ground.position = Vector3(0, -1, 0)
	add_child(ground)
	var v := Vehicle.new()
	v.setup("suv")
	add_child(v)
	v.global_position = Vector3(0, 1.2, 0)
	await _frames(60)
	check(v.global_position.y > 0.2 and v.global_position.y < 1.6, "vehicle rests on its wheels (y=%.2f)" % v.global_position.y)
	check(v.wheels.size() == 4, "4 physics wheels")
	var driver := _actor(0, Vector3(3, 0.2, 0))
	await _frames(5)
	check(v.enter(driver), "actor enters driver seat")
	check(driver.vehicle == v and driver.collision_layer == 0, "driver seated, body out of physics")
	var start := v.global_position
	for i in 240:
		v.drive(Vector2(0, -1), false)
		await get_tree().physics_frame
	var spd := v.forward_speed()
	check(spd > 10.0, "accelerates forward (%.1f m/s after 4 s)" % spd)
	check(v.global_position.distance_to(start) > 25.0, "travels (%.0f m)" % v.global_position.distance_to(start))
	check(spd <= v.max_speed + 2.0, "respects top speed (%.1f <= %.1f)" % [spd, v.max_speed])
	check(driver.global_position.distance_to(v.global_position) < 1.5, "driver carried with vehicle")
	var h0 := v.global_transform.basis.z
	for i in 90:
		v.drive(Vector2(-1, -1), false)
		await get_tree().physics_frame
	var turned := rad_to_deg(h0.signed_angle_to(v.global_transform.basis.z, Vector3.UP))
	check(absf(turned) > 25.0, "steering turns the vehicle (%.0f deg)" % turned)
	check(v.global_transform.basis.y.y > 0.8, "stays upright while turning")
	for i in 150:
		v.drive(Vector2(0, 1), false)
		await get_tree().physics_frame
	check(absf(v.forward_speed()) < 4.0 or v.forward_speed() < 0.0, "brakes / reverses (%.1f m/s)" % v.forward_speed())
	for i in 120:
		v.drive(Vector2.ZERO, true)
		await get_tree().physics_frame
	v.exit(driver)
	await _frames(3)
	check(driver.vehicle == null and driver.collision_layer == 2, "driver exits")
	check(driver.global_position.distance_to(v.global_position) > 1.5, "exit position beside the vehicle (%.1f m)" % driver.global_position.distance_to(v.global_position))
	# Run-over: enemy ahead, drive into them.
	v.enter(driver)
	var heading := v.global_transform.basis.z
	var enemy := _actor(1, v.global_position + heading * 28.0 + Vector3.UP * 0.2)
	enemy.regen_enabled = false
	var hp0 := enemy.health
	for i in 240:
		var to := enemy.global_position - v.global_position
		to.y = 0
		var side := v.global_transform.basis.x.dot(to.normalized())
		v.drive(Vector2(-clampf(side * 3.0, -1, 1), -1), false)
		await get_tree().physics_frame
		if enemy.health < hp0 or not enemy.alive:
			break

	check(enemy.health < hp0 or not enemy.alive, "running over an enemy damages them (%.0f -> %.0f)" % [hp0, enemy.health])
	# Friendly is not run over
	var friend := _actor(0, v.global_position + v.global_transform.basis.z * 20.0 + Vector3.UP * 0.2)
	var fh := friend.health
	for i in 150:
		v.drive(Vector2(0, -1), false)
		await get_tree().physics_frame
	check(friend.health == fh, "teammates are not run over")
	for i in 120:
		v.drive(Vector2.ZERO, true)
		await get_tree().physics_frame
	# Bullet damage from an enemy: vehicle loses health, occupant takes a share.
	var shooter := _actor(1, v.global_position + Vector3(0, 0, 30))
	var dh := driver.health
	v.take_vehicle_damage(200.0, shooter)
	check(v.health < v.max_health, "vehicle takes damage (%.0f/%.0f)" % [v.health, v.max_health])
	check(driver.health < dh, "occupant takes a share of vehicle damage")
	driver.health = driver.max_health
	driver.invulnerable_time = 0.0
	v.take_vehicle_damage(5000.0, shooter)
	await _frames(5)
	check(not v.alive, "vehicle explodes at 0 health")
	check(driver.vehicle == null, "occupants are ejected")
	check(not v.is_in_group("interactable"), "wreck can't be entered")
	print("=== RESULT vehicle: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
