class_name ViewModel
extends Node3D
## First-person weapon presentation: gun model, rigged arms (WRAD Arms, CC0) posed with IK, attachments,
## skins, and procedural animation (bob, sway, recoil kick, reload with magazine swap, pump/bolt cycling,
## weapon switch, ADS, melee, grenade throw, healing/plating, unarmed guard).

var weapon: WeaponInstance
var gun: Node3D
var skeleton: Skeleton3D
var muzzle_local := Vector3(0, 0, -0.4)
var scope_local := Vector3(0, 0.04, 0)
var mag_bone := -1
var mag_rest := Vector3.ZERO

var flash: Node3D
var flash_light: OmniLight3D
var flash_t := 0.0

var kick := 0.0
var kick_rot := 0.0
var sway := Vector2.ZERO
var bob_t := 0.0
var switch_t := 0.0     ## > 0 while lowering/raising
var melee_t := 0.0
var ads := 0.0          ## 0..1 blend, set by player
var arms: FPArms
var throw_t := 0.0      ## > 0 while throwing a grenade
var use_item := ""      ## item being used (heal/plate), set by player
var use_progress := 0.0
var sprinting_now := false
## Hand anchor points in gun-local space (filled from the gun's bones).
var grip_local := Vector3(0, -0.05, 0.06)
var fore_local := Vector3(0, -0.03, -0.2)
var pump_bone := -1
var pump_rest := Vector3.ZERO
var bolt_bone := -1
var bolt_rest := Vector3.ZERO
var slide_bone := -1
var slide_rest := Vector3.ZERO
var _punch_side := 0


func _ready() -> void:
	flash = Node3D.new()
	var fm := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	fm.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.35, 0.95)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	fm.material_override = mat
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(fm)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.75, 0.4)
	flash_light.omni_range = 4.0
	flash_light.light_energy = 2.0
	flash.add_child(flash_light)
	flash.visible = false
	arms = FPArms.new()
	arms.position = Vector3(0.0, -0.21, 0.1)
	add_child(arms)
	arms.set_skin(SaveManager.get_setting("graphics", "arm_skin", "pale") == "dark")


func set_weapon(w: WeaponInstance) -> void:
	weapon = w
	if gun:
		gun.queue_free()
		gun = null
	if flash.get_parent():
		flash.get_parent().remove_child(flash)
	if w == null:
		switch_t = 0.25
		return
	gun = load(w.data.model_path).instantiate()
	add_child(gun)
	_cast_off(gun)
	skeleton = gun.find_child("Skeleton3D", true, false)
	muzzle_local = Vector3(0, 0.015, -0.3)
	scope_local = Vector3(0, 0.04, 0.0)
	mag_bone = -1
	if skeleton:
		var rel := _rel_xform(skeleton, gun)
		var mb := skeleton.find_bone("Attach_Muzzle")
		if mb >= 0:
			muzzle_local = rel * skeleton.get_bone_global_rest(mb).origin
		else:
			muzzle_local = Vector3(0, 0.02, -_gun_length() * 0.5)
		var sb := skeleton.find_bone("Attach_Scope")
		if sb >= 0:
			scope_local = rel * skeleton.get_bone_global_rest(sb).origin
		mag_bone = skeleton.find_bone("Magazine")
		if mag_bone >= 0:
			mag_rest = skeleton.get_bone_pose_position(mag_bone)
		pump_bone = skeleton.find_bone("Pump")
		bolt_bone = skeleton.find_bone("Bolt")
		slide_bone = skeleton.find_bone("Slide")
		if pump_bone >= 0: pump_rest = skeleton.get_bone_pose_position(pump_bone)
		if bolt_bone >= 0: bolt_rest = skeleton.get_bone_pose_position(bolt_bone)
		if slide_bone >= 0: slide_rest = skeleton.get_bone_pose_position(slide_bone)
	_find_hand_points()
	gun.add_child(flash)
	flash.position = muzzle_local + Vector3(0, 0, -0.06)
	_build_attachments()
	_apply_skin()
	switch_t = 0.35


static func _rel_xform(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _gun_length() -> float:
	var total := 0.0
	for m in gun.find_children("*", "MeshInstance3D", true, false):
		total = maxf(total, (m as MeshInstance3D).get_aabb().size.z)
	return total if total > 0.0 else 0.6


func _cast_off(n: Node) -> void:
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _box(size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_attachments() -> void:
	var optic: String = weapon.stats.get("optic", "iron")
	if optic in ["red_dot", "holo"]:
		var housing := _box(Vector3(0.035, 0.035, 0.05), Color(0.1, 0.1, 0.1))
		housing.position = scope_local + Vector3(0, 0.02, 0)
		gun.add_child(housing)
		var dot := _box(Vector3(0.004, 0.004, 0.001), Color(1, 0.1, 0.1) if optic == "red_dot" else Color(0.2, 1, 0.4), true)
		dot.position = scope_local + Vector3(0, 0.022, -0.026)
		gun.add_child(dot)
	elif optic in ["4x", "8x"]:
		var tube := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.018
		c.bottom_radius = 0.018
		c.height = 0.2 if optic == "4x" else 0.28
		tube.mesh = c
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.08, 0.08)
		tube.material_override = m
		tube.rotation_degrees.x = 90
		tube.position = scope_local + Vector3(0, 0.03, 0)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gun.add_child(tube)
	if weapon.stats.get("suppressed", false):
		var s := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.016
		cy.bottom_radius = 0.016
		cy.height = 0.16
		s.mesh = cy
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.1, 0.1, 0.1)
		s.material_override = sm
		s.rotation_degrees.x = 90
		s.position = muzzle_local + Vector3(0, 0, -0.08)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gun.add_child(s)
		flash.position = muzzle_local + Vector3(0, 0, -0.17)


func _apply_skin() -> void:
	var sk: Dictionary = GameDB.SKINS.get(weapon.skin, GameDB.SKINS.default)
	if sk.color.a <= 0.0:
		return
	var ov := StandardMaterial3D.new()
	ov.albedo_color = sk.color
	ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ov.metallic = 0.6 if weapon.skin == "gold" else 0.0
	ov.roughness = 0.35 if weapon.skin == "gold" else 0.8
	for m in gun.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = ov


func _bone_local(name: String) -> Variant:
	if skeleton == null:
		return null
	var b := skeleton.find_bone(name)
	if b < 0:
		return null
	return _rel_xform(skeleton, gun) * skeleton.get_bone_global_pose(b).origin


## Grip (right hand) and support (left hand) points from the gun's own bones.
func _find_hand_points() -> void:
	var length := _gun_length()
	var trig = _bone_local("Trigger")
	var pistol: bool = weapon.data.category == "PISTOL"
	grip_local = (trig + Vector3(0, -0.045, 0.04)) if trig != null else Vector3(0, -0.05, length * 0.2)
	if pistol:
		grip_local = (trig + Vector3(0, -0.04, 0.035)) if trig != null else Vector3(0, -0.04, 0.03)
		fore_local = grip_local + Vector3(-0.025, -0.012, -0.01)
		return
	var pump = _bone_local("Pump")
	var rail = _bone_local("Attach_Rail.Bottom")
	if pump != null:
		fore_local = pump + Vector3(0.008, -0.04, 0)
	elif rail != null:
		fore_local = rail + Vector3(0.008, -0.045, 0.02)
	else:
		fore_local = Vector3(0, -0.035, muzzle_local.z * 0.55)


func on_throw() -> void:
	throw_t = 0.55


func on_shot() -> void:
	kick = minf(kick + 0.045, 0.09)
	kick_rot = minf(kick_rot + 4.0 * weapon.stats.recoil_vertical, 10.0)
	flash.visible = true
	flash.rotation.z = randf() * TAU
	flash_light.light_energy = 2.0 if int(SaveManager.get_setting("graphics", "effects_quality", 1)) > 0 else 0.0
	flash_t = 0.045
	if weapon.stats.get("suppressed", false):
		flash.scale = Vector3.ONE * 0.4
	else:
		flash.scale = Vector3.ONE * randf_range(0.8, 1.2)
	if is_inside_tree() and gun != null and weapon.data.category != "LAUNCHER":
		var gb := gun.global_transform.basis.orthonormalized()
		Effects.shell_eject(gun.global_position + gb.x * 0.03 + gb.y * 0.06 - gb.z * 0.1, gb)
		Effects.muzzle_smoke(flash.global_position, -gb.z)


func on_melee() -> void:
	melee_t = 0.3
	_punch_side = 1 - _punch_side


func muzzle_global() -> Vector3:
	if gun:
		return gun.global_transform * muzzle_local
	return global_position


## Called every frame by the player.
func animate(delta: float, look_delta: Vector2, speed01: float, on_floor: bool, sprinting: bool) -> void:
	sprinting_now = sprinting
	throw_t = maxf(throw_t - delta, 0.0)
	if weapon == null or gun == null:
		_animate_unarmed(delta, look_delta, speed01, on_floor, sprinting)
		return
	flash_t -= delta
	if flash_t <= 0.0:
		flash.visible = false
	kick = move_toward(kick, 0.0, delta * 0.45)
	kick_rot = move_toward(kick_rot, 0.0, delta * 45.0)
	switch_t = maxf(switch_t - delta, 0.0)
	melee_t = maxf(melee_t - delta, 0.0)
	sway = sway.lerp(look_delta * 0.0025 * (1.0 - ads * 0.8), clampf(delta * 10.0, 0, 1))
	if on_floor and speed01 > 0.05:
		bob_t += delta * (11.0 if sprinting else 8.0) * maxf(speed01, 0.4)
	var bob_amp := 0.012 * speed01 * (1.0 - ads * 0.85) * (1.6 if sprinting else 1.0)
	var bob := Vector3(sin(bob_t) * bob_amp, -absf(cos(bob_t)) * bob_amp, 0.0)

	var hip: Vector3 = weapon.data.view_offset
	var aim: Vector3 = weapon.data.ads_offset
	aim.y = -scope_local.y - (0.022 if weapon.stats.get("optic", "iron") != "iron" else 0.006)
	var base := hip.lerp(aim, ads)
	var pos := base + bob + Vector3(-sway.x, sway.y, kick)
	var rot := Vector3(deg_to_rad(kick_rot), 0, 0)
	if sprinting and ads < 0.1:
		pos += Vector3(-0.05, -0.04, 0.03)
		rot += Vector3(deg_to_rad(-12), deg_to_rad(28), deg_to_rad(8))
	# Reload: dip and tilt the weapon, drop and re-insert the magazine bone.
	if weapon.reloading:
		var p := weapon.reload_progress()
		var dip := sin(clampf(p, 0, 1) * PI)
		pos += Vector3(0, -0.06 * dip, 0.02 * dip)
		rot += Vector3(deg_to_rad(-18 * dip), deg_to_rad(10 * dip), deg_to_rad(25 * dip))
		if mag_bone >= 0:
			var off := 0.0
			if p < 0.35:
				off = p / 0.35
			elif p < 0.65:
				off = 1.0
			else:
				off = 1.0 - (p - 0.65) / 0.35
			skeleton.set_bone_pose_position(mag_bone, mag_rest + Vector3(0, -0.18 * off, 0.02 * off))
	elif mag_bone >= 0:
		skeleton.set_bone_pose_position(mag_bone, mag_rest)
	if switch_t > 0.0:
		var s := switch_t / 0.35
		pos += Vector3(0, -0.25 * s, 0)
		rot += Vector3(deg_to_rad(-40 * s), 0, 0)
	if melee_t > 0.0:
		var m := sin((1.0 - melee_t / 0.3) * PI)
		pos += Vector3(-0.1 * m, 0.05 * m, -0.15 * m)
		rot += Vector3(0, deg_to_rad(-35 * m), deg_to_rad(-30 * m))
	# Pump / bolt / slide cycling after each shot.
	var cyc := _cycle_phase()
	if pump_bone >= 0:
		skeleton.set_bone_pose_position(pump_bone, pump_rest + Vector3(0, 0, 0.075 * cyc))
	if bolt_bone >= 0 and weapon.data.fire_mode == WeaponData.FireMode.BOLT:
		skeleton.set_bone_pose_position(bolt_bone, bolt_rest + Vector3(0, 0, 0.06 * cyc))
	if slide_bone >= 0:
		skeleton.set_bone_pose_position(slide_bone, slide_rest + Vector3(0, 0, 0.03 * clampf(kick / 0.09, 0, 1)))
	if throw_t > 0.0 or use_item != "":
		var k := sin(clampf((0.55 - throw_t) / 0.55, 0, 1) * PI) if throw_t > 0.0 else 1.0
		pos += Vector3(0.06, -0.09 * k, 0.04 * k)
		rot += Vector3(deg_to_rad(-25 * k), deg_to_rad(-10 * k), 0)
	gun.position = gun.position.lerp(pos, clampf(delta * 22.0, 0, 1))
	gun.rotation = gun.rotation.lerp(rot, clampf(delta * 16.0, 0, 1))
	_pose_arms(delta, bob)


## 0..1..0 over the cycling time after a shot for pump-action and bolt-action weapons.
func _cycle_phase() -> float:
	var fm := weapon.data.fire_mode
	if fm != WeaponData.FireMode.PUMP and fm != WeaponData.FireMode.BOLT:
		return 0.0
	var interval := 60.0 / maxf(float(weapon.stats.fire_rate_rpm), 1.0)
	if weapon.cooldown <= 0.0 or interval <= 0.0:
		return 0.0
	var p := 1.0 - weapon.cooldown / interval
	# wait for the recoil, then rack
	return sin(clampf((p - 0.2) / 0.7, 0, 1) * PI)


func _gun_point(local: Vector3) -> Vector3:
	return gun.transform * local


## Hand orientation hints in camera space. -Z = finger direction, +Y = back of the hand.
func _hand_basis(fingers: Vector3, back: Vector3) -> Basis:
	var z := -fingers.normalized()
	var y := (back - z * back.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


func _pose_arms(delta: float, bob: Vector3) -> void:
	var gb := gun.transform.basis
	var pistol: bool = weapon.data.category == "PISTOL"
	# Right hand: always on the grip, except while racking a bolt.
	var r_pos := _gun_point(grip_local)
	var r_basis := _hand_basis(gb * Vector3(-0.1, -0.25, -1.0), gb * Vector3(1.0, 0.1, 0.0))
	var r_curl := 0.85
	var cyc := _cycle_phase()
	if weapon.data.fire_mode == WeaponData.FireMode.BOLT and bolt_bone >= 0 and cyc > 0.0:
		var bolt_p: Vector3 = _bone_local("Bolt")
		r_pos = r_pos.lerp(_gun_point(bolt_p + Vector3(0.05, 0.0, 0.03)), cyc)
		r_curl = lerpf(0.85, 0.6, cyc)
	# Left hand: foregrip / pump, magazine during reload, throws, items.
	var l_pos := _gun_point(fore_local)
	var l_basis: Basis
	if pistol:
		l_basis = _hand_basis(gb * Vector3(0.6, -0.4, -1.0), gb * Vector3(-1.0, -0.3, 0.0))
	else:
		l_basis = _hand_basis(gb * Vector3(0.75, 0.25, -0.6), gb * Vector3(-0.2, -1.0, 0.1))
	var l_curl := 0.75
	if pump_bone >= 0:
		l_pos = _gun_point(_bone_local("Pump") + Vector3(0.008, -0.04, 0))
	if weapon.reloading:
		var p := weapon.reload_progress()
		var mag_p = _bone_local("Magazine")
		var mag_pos: Vector3 = _gun_point((mag_p + Vector3(-0.01, -0.07, 0.0)) if mag_p != null else (grip_local + Vector3(0, 0, -0.1)))
		var below := mag_pos + Vector3(-0.06, -0.22, 0.05)
		var mag_basis := _hand_basis(gb * Vector3(0.2, 0.9, -0.4), gb * Vector3(-1.0, 0.0, 0.2))
		var tgt: Vector3
		if pistol or mag_p == null:
			# pistols / shotguns: support hand drops to the belt and comes back
			var k := sin(clampf(p, 0, 1) * PI)
			tgt = l_pos.lerp(below, k)
		elif p < 0.15:
			tgt = l_pos.lerp(mag_pos, p / 0.15)
		elif p < 0.65:
			tgt = mag_pos   # hand rides the magazine as it drops and is swapped
		elif p < 0.85:
			tgt = mag_pos
		else:
			tgt = mag_pos.lerp(l_pos, (p - 0.85) / 0.15)
		l_pos = tgt
		if not pistol and mag_p != null and p > 0.12 and p < 0.88:
			l_basis = mag_basis
			l_curl = 0.6
	if throw_t > 0.0:
		var tp := 1.0 - throw_t / 0.55
		var back := Vector3(-0.22, 0.05, 0.05)
		var fwd := Vector3(-0.05, 0.1, -0.5)
		var arc := back.lerp(fwd, smoothstep(0.35, 0.75, tp))
		var start := l_pos
		l_pos = start.lerp(arc, sin(clampf(tp, 0, 1) * PI) * 0.95 + (0.05 if tp > 0.5 else 0.0))
		l_basis = _hand_basis(Vector3(0.1, 0.4, -1.0), Vector3(-0.4, 1.0, 0.0))
		l_curl = 0.9 if tp < 0.6 else 0.2
	elif use_item != "":
		var chest := Vector3(-0.12, -0.21 + 0.025 * sin(use_progress * TAU * 2.0), -0.3)
		l_pos = chest
		l_basis = _hand_basis(Vector3(0.3, 0.5, -1.0), Vector3(-0.5, 0.2, 0.8))
		l_curl = 0.5
	if melee_t > 0.0:
		var m := sin((1.0 - melee_t / 0.3) * PI)
		l_pos = l_pos.lerp(Vector3(-0.06, -0.06, -0.48), m)
		l_basis = _hand_basis(Vector3(0.1, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
		l_curl = 1.0
	arms.set_hand("r", r_pos, r_basis, r_curl)
	arms.set_hand("l", l_pos, l_basis, l_curl)
	arms.apply(delta, switch_t > 0.3)


## No weapon (BR before looting): boxing guard, alternate punches on melee.
func _animate_unarmed(delta: float, look_delta: Vector2, speed01: float, on_floor: bool, sprinting: bool) -> void:
	melee_t = maxf(melee_t - delta, 0.0)
	switch_t = maxf(switch_t - delta, 0.0)
	sway = sway.lerp(look_delta * 0.0025, clampf(delta * 10.0, 0, 1))
	if on_floor and speed01 > 0.05:
		bob_t += delta * (11.0 if sprinting else 8.0) * maxf(speed01, 0.4)
	var amp := 0.015 * speed01 * (1.8 if sprinting else 1.0)
	var bob := Vector3(sin(bob_t) * amp, -absf(cos(bob_t)) * amp, 0.0) + Vector3(-sway.x, sway.y, 0)
	var low := Vector3(0, -0.25 * switch_t / 0.25, 0)
	var r := Vector3(0.13, -0.17, -0.33) + bob + low
	var l := Vector3(-0.13, -0.16, -0.36) + bob * Vector3(-1, 1, 1) + low
	if sprinting:
		r += Vector3(0, -0.05 + sin(bob_t) * 0.04, 0.05)
		l += Vector3(0, -0.05 - sin(bob_t) * 0.04, 0.05)
	if melee_t > 0.0:
		var m := sin((1.0 - melee_t / 0.3) * PI)
		if _punch_side == 0:
			r = r.lerp(Vector3(0.03, -0.08, -0.55), m)
		else:
			l = l.lerp(Vector3(-0.03, -0.08, -0.55), m)
	if throw_t > 0.0:
		var tp := 1.0 - throw_t / 0.55
		l = l.lerp(Vector3(-0.05, 0.1, -0.5), sin(tp * PI))
	var fist := _hand_basis(Vector3(0.0, 0.25, -1.0), Vector3(0.0, 1.0, 0.25))
	arms.set_hand("r", r, fist.rotated(Vector3.FORWARD, deg_to_rad(-20)), 1.0)
	arms.set_hand("l", l, fist.rotated(Vector3.FORWARD, deg_to_rad(20)), 1.0)
	arms.apply(delta)


func is_busy() -> bool:
	return switch_t > 0.05 or melee_t > 0.0
