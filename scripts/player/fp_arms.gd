class_name FPArms
extends Node3D
## First-person arms (WRAD Arms, CC0) driven procedurally:
##  - analytic two-bone IK places each hand on a target supplied by the ViewModel every frame
##    (pistol grip, foregrip/pump, magazine during reloads, bolt on bolt-action rifles, chest when healing),
##  - per-finger curl gives a grip / fist / open-hand pose,
##  - the shoulder slides toward the target when it is out of reach, so hands never detach from the gun.
## The asset ships rigged but without animations; every motion here is generated in code.
## Look: blocky, Roblox-style arms - the skinned mesh is hidden and square sleeve blocks plus cube hands
## ride on the same IK-driven bones, so every pose / reload / inspect animation still works.

const MODEL := "res://assets/arms/arms.glb"
const SCALE := 0.1
const FINGERS := ["index", "middle", "ring", "pinky"]

var skel: Skeleton3D
var mesh: MeshInstance3D
var sides := {}            ## "r"/"l" -> {shoulder, bicep, forearm, wrist, l1, l2, fingers: [[b1,b2,b3]], thumb: [..]}
var targets := {}          ## side -> {pos: Vector3 (ArmsRig local space), basis: Basis, curl: float, weight: float}
var _smoothed := {}        ## side -> Transform3D actually used (smooth transitions between targets)
var sleeve_material: StandardMaterial3D
var hand_material: StandardMaterial3D
var cuff_material: StandardMaterial3D


func _ready() -> void:
	var scene: PackedScene = load(MODEL)
	var inst := scene.instantiate()
	add_child(inst)
	scale = Vector3.ONE * SCALE
	skel = inst.find_children("*", "Skeleton3D", true, false)[0]
	mesh = inst.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never cull the arms when bones move them away from the bind-pose bounds.
	mesh.extra_cull_margin = 16.0
	mesh.visible = false   # replaced by block arms (see _build_sleeves)
	for s in ["r", "l"]:
		var d := {
			"shoulder": skel.find_bone("shoulder." + s),
			"bicep": skel.find_bone("bicep." + s),
			"forearm": skel.find_bone("forearm." + s),
			"wrist": skel.find_bone("wrist." + s),
			"fingers": [], "thumb": [],
		}
		var pb := skel.get_bone_global_rest(d.bicep).origin
		var pf := skel.get_bone_global_rest(d.forearm).origin
		var pw := skel.get_bone_global_rest(d.wrist).origin
		var sock := skel.find_bone("socket." + s)
		d.palm = skel.get_bone_global_rest(d.wrist).basis.inverse() * (skel.get_bone_global_rest(sock).origin - pw) if sock >= 0 else Vector3.ZERO
		d.l1 = pb.distance_to(pf)
		d.l2 = pf.distance_to(pw)
		for f in FINGERS:
			d.fingers.append([skel.find_bone("finger_%s1.%s" % [f, s]), skel.find_bone("finger_%s2.%s" % [f, s]), skel.find_bone("finger_%s3.%s" % [f, s])])
		d.thumb = [skel.find_bone("finger_thumb1." + s), skel.find_bone("finger_thumb2." + s), skel.find_bone("finger_thumb3." + s)]
		sides[s] = d
		targets[s] = {"pos": pw * SCALE, "basis": Basis(), "curl": 0.8, "weight": 1.0}
	_build_sleeves()


## Block arms: a square sleeve on the upper and lower arm, a darker cuff and a cube hand per side.
func _build_sleeves() -> void:
	sleeve_material = StandardMaterial3D.new()
	sleeve_material.albedo_color = Color(0.29, 0.33, 0.22)
	sleeve_material.roughness = 0.9
	cuff_material = StandardMaterial3D.new()
	cuff_material.albedo_color = Color(0.16, 0.17, 0.13)
	hand_material = StandardMaterial3D.new()
	hand_material.albedo_color = Color(0.98, 0.8, 0.62)
	hand_material.roughness = 0.75
	for s in ["r", "l"]:
		var d: Dictionary = sides[s]
		_block(skel.get_bone_name(d.bicep), Vector3(0.92, d.l1 * 1.1, 0.92), sleeve_material, -0.12)
		_block(skel.get_bone_name(d.forearm), Vector3(0.86, d.l2 * 0.84, 0.86), sleeve_material, -0.05)
		_block(skel.get_bone_name(d.forearm), Vector3(0.94, d.l2 * 0.12, 0.94), cuff_material, d.l2 * 0.72)
		# Cube hand (slightly flattened so it reads as a palm gripping the gun)
		_block(skel.get_bone_name(d.wrist), Vector3(0.66, 0.68, 0.5), hand_material, -0.06)


func _block(bone: String, size: Vector3, mat: Material, start: float) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = Vector3(0, start + size.y * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	att.add_child(mi)


func set_sleeve_color(c: Color) -> void:
	if sleeve_material:
		sleeve_material.albedo_color = c


## Set where a hand should be, in this node's parent space (the ViewModel / camera space).
## `basis_hint` orients the palm: -Z is the direction the fingers point, +Y the back of the hand.
func set_hand(side: String, pos_parent: Vector3, basis_hint: Basis, curl: float) -> void:
	targets[side] = {"pos": pos_parent, "basis": basis_hint, "curl": curl}


func apply(delta: float, snap := false) -> void:
	if skel == null:
		return
	skel.reset_bone_poses()
	var to_skel := (transform).affine_inverse()   # parent space -> skeleton space (skeleton sits at our origin)
	for s in ["r", "l"]:
		var t: Dictionary = targets[s]
		var want := Transform3D(t.basis.orthonormalized(), to_skel * Vector3(t.pos))
		want.basis = (to_skel.basis * Basis(t.basis)).orthonormalized()
		if snap or not _smoothed.has(s):
			_smoothed[s] = want
		else:
			var k := clampf(delta * 30.0, 0.0, 1.0)
			_smoothed[s] = (_smoothed[s] as Transform3D).interpolate_with(want, k)
		_solve(s, _smoothed[s])
		_curl(s, float(t.curl))


## Two-bone IK. Bones follow Blender's convention: each bone's +Y axis points to its child.
func _solve(s: String, target: Transform3D) -> void:
	var d: Dictionary = sides[s]
	var l1: float = d.l1
	var l2: float = d.l2
	var shoulder_rest := skel.get_bone_global_rest(d.shoulder)
	var bicep_rest := skel.get_bone_global_rest(d.bicep)
	var fore_rest := skel.get_bone_global_rest(d.forearm)
	var wrist_rest := skel.get_bone_global_rest(d.wrist)
	var S := bicep_rest.origin
	# The target is the palm centre ("socket" bone); convert it to a wrist position for the hand orientation.
	var w_basis := (target.basis * _hand_rest_offset(s, wrist_rest.basis)).orthonormalized()
	var T := target.origin - w_basis * (d.palm as Vector3)
	var reach := l1 + l2
	var dist := S.distance_to(T)
	var shift := Vector3.ZERO
	if dist > reach * 0.985:
		# Out of reach: slide the whole shoulder toward the target (keeps the hand on the weapon).
		shift = (T - S).normalized() * (dist - reach * 0.985)
		S += shift
		dist = reach * 0.985
	dist = maxf(dist, absf(l1 - l2) + 0.05)
	if shift != Vector3.ZERO:
		var sh := shoulder_rest
		sh.origin += shift
		skel.set_bone_global_pose(d.shoulder, sh)
	var dir := (T - S).normalized()
	# Elbow hint: down and outward, slightly back.
	var side_sign := 1.0 if s == "r" else -1.0
	var pole := Vector3(side_sign * 0.6, -1.0, 0.35).normalized()
	var pp := (pole - dir * pole.dot(dir))
	if pp.length() < 0.001:
		pp = Vector3(0, -1, 0)
	pp = pp.normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var E := S + dir * a + pp * h
	# Upper arm
	var b_basis := _aim_basis(bicep_rest.basis, E - S, pole)
	skel.set_bone_global_pose(d.bicep, Transform3D(b_basis, S))
	# Forearm
	var f_basis := _aim_basis(fore_rest.basis, T - E, pole)
	skel.set_bone_global_pose(d.forearm, Transform3D(f_basis, E))
	skel.set_bone_global_pose(d.wrist, Transform3D(w_basis, E + (T - E).normalized() * l2))


## Rotate `rest` so its +Y axis points along `along`, choosing the twist so +Z faces away from the pole.
func _aim_basis(rest: Basis, along: Vector3, pole: Vector3) -> Basis:
	var y := along.normalized()
	var q := Quaternion(rest.y.normalized(), y)
	var b := Basis(q) * rest
	return b.orthonormalized()


var _hand_offsets := {}

## Hand frame measured from the rig: fingers = wrist -> middle knuckle, across = pinky -> index knuckle.
func _hand_frame(s: String) -> Dictionary:
	var key := "frame_" + s
	if _hand_offsets.has(key):
		return _hand_offsets[key]
	var d: Dictionary = sides[s]
	var w := skel.get_bone_global_rest(d.wrist).origin
	var mid := skel.get_bone_global_rest(d.fingers[1][0]).origin
	var idx := skel.get_bone_global_rest(d.fingers[0][0]).origin
	var pinky := skel.get_bone_global_rest(d.fingers[3][0]).origin
	var fingers := (mid - w).normalized()
	var across := (idx - pinky).normalized()
	var back := fingers.cross(across) if s == "r" else across.cross(fingers)
	var z := -fingers
	var y := (back - z * back.dot(z)).normalized()
	var fr := {"hint": Basis(y.cross(z), y, z), "flex": across if s == "r" else -across}
	_hand_offsets[key] = fr
	return fr


## Constant rotation mapping a "hint" basis (fingers along -Z, back of hand +Y) onto the rig's wrist bone.
func _hand_rest_offset(s: String, wrist_rest: Basis) -> Basis:
	if _hand_offsets.has(s):
		return _hand_offsets[s]
	var hint: Basis = _hand_frame(s).hint
	var off := (hint.inverse() * wrist_rest).orthonormalized()
	_hand_offsets[s] = off
	return off


## curl: 0 open hand, ~0.8 weapon grip, 1 fist. Fingers flex about the knuckle line (pinky -> index).
func _curl(s: String, curl: float) -> void:
	var d: Dictionary = sides[s]
	var flex: Vector3 = _hand_frame(s).flex
	var ang := [deg_to_rad(75.0), deg_to_rad(90.0), deg_to_rad(65.0)]
	for chain in d.fingers:
		for i in 3:
			_flex_bone(chain[i], flex, ang[i] * curl)
	var tang := [deg_to_rad(10.0), deg_to_rad(30.0), deg_to_rad(35.0)]
	for i in 3:
		_flex_bone(d.thumb[i], flex, tang[i] * curl)


func _flex_bone(b: int, flex_skel: Vector3, angle: float) -> void:
	if b < 0 or absf(angle) < 0.0001:
		return
	var g := skel.get_bone_global_rest(b).basis.orthonormalized()
	var axis := (g.inverse() * flex_skel).normalized()
	var r := skel.get_bone_rest(b).basis.orthonormalized()
	skel.set_bone_pose_rotation(b, (r * Basis(axis, angle)).get_rotation_quaternion())


func set_skin(dark: bool) -> void:
	if hand_material:
		hand_material.albedo_color = Color(0.56, 0.37, 0.25) if dark else Color(0.98, 0.8, 0.62)
