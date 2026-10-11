class_name Combat
extends RefCounted
## Stateless combat helpers: hitscan firing, melee and explosion damage.

const MASK_WORLD := 1
const MASK_ACTORS := 2
const MASK_SHOT := MASK_WORLD | MASK_ACTORS


## Random direction inside a cone around `dir` with half-angle `deg` (uniform-ish, center weighted).
static func cone(dir: Vector3, deg: float, rng: RandomNumberGenerator = null) -> Vector3:
	if deg <= 0.001:
		return dir
	var r1 := randf() if rng == null else rng.randf()
	var r2 := randf() if rng == null else rng.randf()
	var ang := deg_to_rad(deg) * sqrt(r1)
	var phi := TAU * r2
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	var up2 := right.cross(dir).normalized()
	return (dir * cos(ang) + (right * cos(phi) + up2 * sin(phi)) * sin(ang)).normalized()


## LAN hooks (set by NetSync): replay shots / explosions as effects on the other peers.
static var net_shot_hook := Callable()
static var net_explode_hook := Callable()


## Fires one trigger pull (all pellets). Returns {hits, kills, headshot, positions}.
static func fire_hitscan(shooter: Actor, origin: Vector3, dir: Vector3, w: WeaponInstance, spread: float, muzzle: Vector3, show_tracer: bool) -> Dictionary:
	var space := shooter.get_world_3d().direct_space_state
	var res := {"hits": 0, "kills": 0, "headshot": false, "damage": 0.0}
	var pellets := int(w.stats.pellets)
	var max_range: float = w.stats.max_range
	for i in pellets:
		var d := cone(dir, spread)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * max_range, MASK_SHOT, [shooter.get_rid()])
		var hit := space.intersect_ray(q)
		var end := origin + d * max_range
		if not hit.is_empty():
			end = hit.position
			var col = hit.collider
			if col is Actor and col.alive:
				var a: Actor = col
				var head := a.is_headshot(hit.position)
				var dist := origin.distance_to(hit.position)
				var dmg := _damage_at(w.stats, dist) * (float(w.stats.headshot_multiplier) if head else 1.0)
				var killed := a.take_damage(dmg, shooter, w.data.display_name, head, origin)
				res.hits += 1
				res.damage += dmg
				res.headshot = res.headshot or head
				if killed:
					res.kills += 1
				Effects.impact(hit.position, hit.normal, true)
			else:
				var pdmg := _damage_at(w.stats, origin.distance_to(hit.position))
				if col != null and col.has_method("take_vehicle_damage"):
					col.take_vehicle_damage(pdmg * 0.6, shooter)
					res.hits += 1
				# Physics props: bullets push loose objects; barrels / crates take damage.
				if col is RigidBody3D:
					var rb: RigidBody3D = col
					rb.apply_impulse(d * pdmg * 0.035, hit.position - rb.global_position)
				if col != null and col.has_method("take_prop_damage"):
					col.take_prop_damage(pdmg, shooter)
				Effects.impact(hit.position, hit.normal, false)
				if i == 0:
					AudioManager.play_3d("res://assets/audio/sfx/bullet_impact.ogg", hit.position, -14.0, randf_range(0.9, 1.15), 25.0)
		if show_tracer and (i == 0 or pellets > 1 and i % 3 == 0):
			Effects.tracer(muzzle, end)
		if i == 0 and net_shot_hook.is_valid():
			net_shot_hook.call(shooter, muzzle, end, w.data.fire_sound)
	return res


static func _damage_at(s: Dictionary, dist: float) -> float:
	var eff: float = s.effective_range
	var mx: float = s.max_range
	if dist <= eff:
		return s.damage
	if dist >= mx:
		return s.damage * s.falloff_multiplier
	return s.damage * lerpf(1.0, s.falloff_multiplier, (dist - eff) / maxf(mx - eff, 0.01))


## Melee: short ray, then a small sphere sweep fallback for forgiving mobile aim.
static func melee(attacker: Actor, origin: Vector3, dir: Vector3, reach: float, damage: float, weapon_name: String) -> bool:
	var space := attacker.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, MASK_SHOT, [attacker.get_rid()])
	var hit := space.intersect_ray(q)
	var target: Actor = null
	if not hit.is_empty() and hit.collider is Actor:
		target = hit.collider
	if target == null:
		var best := reach + 0.6
		for n in attacker.get_tree().get_nodes_in_group("actors"):
			var a: Actor = n
			if a == attacker or not a.alive or not attacker.is_enemy(a):
				continue
			var to := a.global_position + Vector3.UP * 1.0 - origin
			var dist := to.length()
			if dist < best and to.normalized().dot(dir) > 0.75:
				best = dist
				target = a
	if target and attacker.is_enemy(target):
		target.take_damage(damage, attacker, weapon_name, false, origin)
		Effects.impact(target.global_position + Vector3.UP * 1.1, -dir, true)
		return true
	return false


## Radial damage with line-of-sight check. Returns number of actors damaged.
static func explode(source: Actor, pos: Vector3, radius: float, damage: float, weapon_name: String, world: World3D, tree: SceneTree) -> int:
	var space := world.direct_space_state
	var n := 0
	if net_explode_hook.is_valid():
		net_explode_hook.call(source, pos, radius)
	for node in tree.get_nodes_in_group("actors"):
		var a: Actor = node
		if not a.alive:
			continue
		var center := a.global_position + Vector3.UP * 0.9
		var dist := pos.distance_to(center)
		if dist > radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.2, center, MASK_WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var falloff := clampf(1.0 - dist / radius, 0.0, 1.0)
		var dmg := damage * (0.25 + 0.75 * falloff)
		# Your own grenade still hurts you (at half strength); teammates are protected.
		if a == source:
			dmg *= 0.5
		elif source and not source.is_enemy(a):
			continue
		a.take_damage(dmg, source, weapon_name, false, pos)
		a.add_shake(0.6 * falloff + 0.2)
		# Blast pushes survivors away (and pops them off the ground a little).
		var away := center - pos
		away.y = 0.0
		a.apply_knockback(away.normalized() * 8.0 * falloff + Vector3.UP * 3.5 * falloff)
		n += 1
	# Loose physics props get thrown; explosive props chain-react.
	for node in tree.get_nodes_in_group("physics_props"):
		var rb := node as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var pd := pos.distance_to(rb.global_position)
		if pd > radius * 1.4:
			continue
		var pf := clampf(1.0 - pd / (radius * 1.4), 0.0, 1.0)
		var dirp := (rb.global_position - pos + Vector3.UP * 0.6).normalized()
		rb.apply_impulse(dirp * rb.mass * 11.0 * pf, Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2)))
		if rb.has_method("take_prop_damage"):
			rb.take_prop_damage(damage * pf, source)
	for node in tree.get_nodes_in_group("vehicles"):
		var v: Node3D = node
		var vd := pos.distance_to(v.global_position + Vector3.UP * 0.8)
		if vd < radius + 1.5 and v.has_method("take_vehicle_damage"):
			v.take_vehicle_damage(damage * 2.5 * clampf(1.0 - vd / (radius + 1.5), 0.15, 1.0), source)
	return n
