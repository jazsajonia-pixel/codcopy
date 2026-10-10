class_name ViewModel
extends Node3D
## First-person weapon presentation: gun model, procedural arms, attachments, skins,
## and procedural animation (bob, sway, recoil kick, reload, weapon switch, ADS).

const ARM_COLOR := Color(0.27, 0.31, 0.2)
const GLOVE_COLOR := Color(0.12, 0.12, 0.11)

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
var arms: Node3D


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


func set_weapon(w: WeaponInstance) -> void:
	weapon = w
	if gun:
		gun.queue_free()
		gun = null
	if flash.get_parent():
		flash.get_parent().remove_child(flash)
	if arms:
		arms.queue_free()
		arms = null
	if w == null:
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
	gun.add_child(flash)
	flash.position = muzzle_local + Vector3(0, 0, -0.06)
	_build_attachments()
	_apply_skin()
	_build_arms()
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


## Simple original placeholder arms (no licensed FP arms asset was available as CC0).
func _build_arms() -> void:
	arms = Node3D.new()
	gun.add_child(arms)
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = ARM_COLOR
	var glove := StandardMaterial3D.new()
	glove.albedo_color = GLOVE_COLOR
	var grip := Vector3(0, -0.06, 0.06)
	var fore := Vector3(0, -0.03, muzzle_local.z * 0.55)
	_arm(grip, Vector3(0.09, -0.16, 0.42), sleeve, glove)
	_arm(fore, Vector3(-0.16, -0.2, 0.25), sleeve, glove)


func _arm(hand: Vector3, elbow: Vector3, sleeve: Material, glove: Material) -> void:
	var fore := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.032
	cm.height = hand.distance_to(elbow) + 0.06
	cm.radial_segments = 8
	cm.rings = 2
	fore.mesh = cm
	fore.material_override = sleeve
	fore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms.add_child(fore)
	var mid := (hand + elbow) * 0.5
	var dir := (hand - elbow).normalized()
	var b := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	fore.transform = Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), mid)
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.06, 0.07)
	g.mesh = bm
	g.material_override = glove
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.position = hand
	arms.add_child(g)


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


func on_melee() -> void:
	melee_t = 0.3


func muzzle_global() -> Vector3:
	if gun:
		return gun.global_transform * muzzle_local
	return global_position


## Called every frame by the player.
func animate(delta: float, look_delta: Vector2, speed01: float, on_floor: bool, sprinting: bool) -> void:
	if weapon == null or gun == null:
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
	gun.position = gun.position.lerp(pos, clampf(delta * 22.0, 0, 1))
	gun.rotation = gun.rotation.lerp(rot, clampf(delta * 16.0, 0, 1))


func is_busy() -> bool:
	return switch_t > 0.05 or melee_t > 0.0
