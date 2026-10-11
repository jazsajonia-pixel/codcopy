class_name ActorModel
extends Node3D
## Animated third-person body shared by bots, LAN puppets, the lobby preview and the player's own body
## (third-person view / first-person shadow). Supports three CC0 character rigs:
##   mini   - Kenney Mini Characters (skinned, bone names arm-left / arm-right / head)
##   blocky - Kenney Blocky Characters (node-animated parts, same clip names as mini)
##   toon   - Quaternius Toon Shooter soldiers (skinned, Blender-style bone names, own clip names)
## An AnimationTree blends locomotion (lower body) with a weapon hold/shoot pose on the arms, plus
## one-shot melee / hit-react / emote clips. AimPose tilts the arms by aim pitch. Death uses a light
## physics simulation (knock-back slide, topple, bounce) driven by the killing blow. Also owns the
## wingsuit and parachute visuals used during the Battle Royale drop.

const TARGET_HEIGHT := 1.78       ## every rig is normalised to this standing height (m)
const LOCO := ["idle", "walk", "sprint", "crouch", "fall", "die", "sit", "drive", "emote"]
const ARMS := ["holding-both", "holding-both-shoot", "holding-right", "holding-right-shoot"]
const LOOPED := ["idle", "walk", "sprint", "holding-both", "holding-both-shoot", "holding-right",
	"holding-right-shoot", "crouch", "fall", "sit", "drive", "emote"]
## logical clip -> clip name per rig (missing keys = same name)
const RIG_CLIPS := {
	"mini": {"melee": "attack-melee-right", "emote": "emote-yes", "hit": "interact-right"},
	"blocky": {"crouch": "idle", "fall": "idle", "melee": "attack-melee-right", "emote": "emote-yes", "hit": "interact-right"},
	"toon": {"idle": "Idle", "walk": "Walk", "sprint": "Run", "crouch": "Duck", "fall": "Jump_Idle", "die": "Death",
		"sit": "Idle", "drive": "Idle", "emote": "Wave", "melee": "Punch", "hit": "HitReact",
		"holding-both": "Run_Gun", "holding-both-shoot": "Run_Shoot", "holding-right": "Idle_Shoot", "holding-right-shoot": "Idle_Shoot"},
}
const RIG_ARMS := {
	"mini": ["arm-left", "arm-right"],
	"blocky": ["arm-left", "arm-right"],
	"toon": ["Shoulder.L", "UpperArm.L", "LowerArm.L", "Shoulder.R", "UpperArm.R", "LowerArm.R",
		"Pinky1.L", "Pinky2.L", "Pinky3.L", "Middle1.L", "Middle2.L", "Middle3.L", "Index1.L", "Index2.L", "Index3.L", "Thumb1.L", "Thumb2.L",
		"Pinky1.R", "Pinky2.R", "Pinky3.R", "Middle1.R", "Middle2.R", "Middle3.R", "Index1.R", "Index2.R", "Index3.R", "Thumb1.R", "Thumb2.R"],
}
const RIG_AIM := {"mini": ["arm-left", "arm-right"], "blocky": [], "toon": ["Shoulder.L", "Shoulder.R"]}
const RIG_HEAD := {"mini": "head", "blocky": "", "toon": "Neck"}

var pose_root: Node3D      ## pivot at the hips; tilted for wingsuit / downed / death poses
var model: Node3D
var anim: AnimationPlayer
var tree: AnimationTree
var skel: Skeleton3D
var aim: AimPose
var gun_holder: Node3D
var gun_model: Node3D
var wings: Node3D
var chute: Node3D
var rig := "mini"
var mode := "ground"       ## ground | freefall | chute | downed | dead
var _loco := ""
var _arms := ""
var _shadow_only := false
var _tilt := 0.0
var _clips := {}
var _blocky_arms: Array[Node3D] = []
var _blocky_legs: Array[Node3D] = []
var _crouching := false
var _walk_phase := 0.0
var _gun_y := 1.08
var _aim_pitch := 0.0
var _crouch_drop := 0.0
## hit flinch spring (radians) and death physics
var _flinch := Vector2.ZERO
var _flinch_v := Vector2.ZERO
var _death_vel := Vector3.ZERO     ## local-space slide velocity of the corpse
var _death_off := Vector3.ZERO
var _death_ang := 0.0              ## topple angle about _death_axis
var _death_ang_v := 0.0
var _death_axis := Vector3.RIGHT
var _death_spin := 0.0
var _death_yaw := 0.0


## Build the rig for an operator entry from GameDB.OPERATORS (model + optional colour variant).
func setup_operator(op: Dictionary) -> void:
	setup(op.model)
	apply_tint(op.get("tint", {}))


## Recolour named materials (Toon Shooter variants): {"Character_Main": Color, ...}. Materials are duplicated
## per actor so variants never leak into each other.
func apply_tint(tint: Dictionary) -> void:
	if tint.is_empty() or model == null:
		return
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D and tint.has(String(mat.resource_name)):
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = tint[String(mat.resource_name)]
				mi.set_surface_override_material(i, dup)


func setup(model_path: String) -> void:
	pose_root = Node3D.new()
	pose_root.position.y = 0.9
	add_child(pose_root)
	model = load(model_path).instantiate()
	model.rotation.y = PI
	pose_root.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	skel = sks[0] if sks.size() > 0 else null
	if skel == null:
		rig = "blocky"
	elif skel.find_bone("UpperArm.L") >= 0:
		rig = "toon"
	else:
		rig = "mini"
	if rig == "toon":
		# Toon Shooter soldiers come with every gun of the kit parented to the hand; ours replaces them.
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if String(m.get_parent().name).begins_with("Index1"):
				m.visible = false
	_clips = RIG_CLIPS[rig]
	_gun_y = 0.98 if rig == "toon" else 1.08
	_normalise_scale()
	gun_holder = Node3D.new()
	gun_holder.position = Vector3(0.2, _gun_y, -0.12)
	add_child(gun_holder)
	if anim:
		_build_tree()
	_build_wings()
	_build_chute()
	set_mode("ground")


## Scale the rig so it stands TARGET_HEIGHT tall with its feet on y = 0 (relative to the actor).
func _normalise_scale() -> void:
	var acc: Array = [null]
	_visible_aabb(model, Transform3D.IDENTITY, acc)
	var box: AABB = acc[0] if acc[0] != null else AABB(Vector3.ZERO, Vector3(1, TARGET_HEIGHT, 1))
	var k := TARGET_HEIGHT / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * k
	model.position.y = -0.9 - box.position.y * k


static func _visible_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).visible:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_visible_aabb(c, t, acc)


func clip(logical: String) -> String:
	var c: String = _clips.get(logical, logical)
	if anim and anim.has_animation(c):
		return c
	return _clips.get("idle", "idle")


func _build_tree() -> void:
	for a in LOOPED:
		var c := clip(a)
		if anim.has_animation(c):
			anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	anim.stop()
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.18
	for a in LOCO:
		loco.add_input(a)
		var n := AnimationNodeAnimation.new()
		n.animation = clip(a)
		bt.add_node("a_" + a, n)
	bt.add_node("loco", loco)
	for i in LOCO.size():
		bt.connect_node("loco", i, "a_" + LOCO[i])
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("speed", ts)
	bt.connect_node("speed", 0, "loco")
	var arms := AnimationNodeTransition.new()
	arms.xfade_time = 0.1
	for a in ARMS:
		arms.add_input(a)
		var n := AnimationNodeAnimation.new()
		n.animation = clip(a)
		bt.add_node("u_" + a, n)
	bt.add_node("arms", arms)
	for i in ARMS.size():
		bt.connect_node("arms", i, "u_" + ARMS[i])
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	var anim_root := anim.get_node(anim.root_node)
	var arm_paths: Array[NodePath] = []
	if rig == "blocky":
		for nm in RIG_ARMS[rig]:
			var node := model.find_child(nm, true, false) as Node3D
			if node:
				arm_paths.append(anim_root.get_path_to(node))
				_blocky_arms.append(node)
		for nm in ["leg-left", "leg-right"]:
			var lg := model.find_child(nm, true, false) as Node3D
			if lg:
				_blocky_legs.append(lg)
	else:
		var base := String(anim_root.get_path_to(skel))
		for b in RIG_ARMS[rig]:
			if skel.find_bone(b) >= 0:
				arm_paths.append(NodePath(base + ":" + b))
	for ap in arm_paths:
		upper.set_filter_path(ap, true)
	bt.add_node("upper", upper)
	bt.connect_node("upper", 0, "speed")
	bt.connect_node("upper", 1, "arms")
	# One-shot overlays on the arms: melee swing and hit-react.
	var shot := AnimationNodeOneShot.new()
	shot.filter_enabled = true
	for ap in arm_paths:
		shot.set_filter_path(ap, true)
	shot.fadein_time = 0.05
	shot.fadeout_time = 0.12
	bt.add_node("melee", shot)
	var mn := AnimationNodeAnimation.new()
	mn.animation = clip("melee")
	bt.add_node("a_melee", mn)
	bt.connect_node("melee", 0, "upper")
	bt.connect_node("melee", 1, "a_melee")
	bt.connect_node("output", 0, "melee")
	tree = AnimationTree.new()
	tree.tree_root = bt
	anim.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_node = tree.get_path_to(anim_root)
	tree.active = true
	if rig == "blocky":
		tree.mixer_applied.connect(_post_blocky)
	elif skel:
		aim = AimPose.new()
		for b in RIG_AIM[rig]:
			var i := skel.find_bone(b)
			if i >= 0:
				aim.arm_bones.append(i)
		aim.head_bone = skel.find_bone(RIG_HEAD[rig]) if RIG_HEAD[rig] != "" else -1
		skel.add_child(aim)


## Blocky characters have no skeleton: tilt the arm nodes by the aim pitch after the mixer runs.
func _post_blocky() -> void:
	if absf(_aim_pitch) > 0.001:
		for a in _blocky_arms:
			a.rotate_object_local(Vector3.RIGHT, _aim_pitch)
	# No crouch clip and single-block legs: squat by splaying the legs (one forward, one back).
	if _crouch_drop > 0.01 and _blocky_legs.size() == 2:
		var k := _crouch_drop / 0.19
		var sw := sin(_walk_phase) * 0.35
		_blocky_legs[0].rotation = Vector3(deg_to_rad(-48.0) * k + sw, 0, 0)
		_blocky_legs[1].rotation = Vector3(deg_to_rad(42.0) * k - sw, 0, 0)


func _wing_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.2, 0.24)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_wings() -> void:
	wings = Node3D.new()
	var m := _wing_mat()
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.95, 0.6, 0.12)
	stripe.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Arm-to-leg membranes on each side (with an accent stripe) and one between the legs.
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.95, 1.15, 0.04)
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(side * 0.62, 0.05, 0.0)
		wings.add_child(mi)
		var st := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.16, 1.15, 0.05)
		st.mesh = sb
		st.material_override = stripe
		st.position = Vector3(side * 0.98, 0.05, 0.0)
		wings.add_child(st)
	var mid := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.42, 0.6, 0.04)
	mid.mesh = bm2
	mid.material_override = m
	mid.position = Vector3(0, -0.5, 0)
	wings.add_child(mid)
	pose_root.add_child(wings)


const CHUTE_A := 3.3      ## oval canopy half-span (m)
const CHUTE_B := 1.45     ## oval canopy half-chord (m)
const CHUTE_ARCH := 0.9   ## how far the wing tips droop below the centre
const CHUTE_H := 4.3      ## canopy height above the feet
var chute_canopy: Node3D
var _chute_t := 9.0


## Oval ram-air canopy: elliptical planform, arched span, upper + lower skin with alternating cell colours,
## open leading edge, risers from the canopy edge down to the shoulders.
func _build_chute() -> void:
	chute = Node3D.new()
	chute_canopy = Node3D.new()
	chute_canopy.position = Vector3(0, CHUTE_H, 0)
	chute.add_child(chute_canopy)
	var cols := [Color(0.95, 0.55, 0.12), Color(0.96, 0.93, 0.85)]
	var mats := []
	for c in cols:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		mats.append(m)
	var cells := 9
	var seg := 4
	for cell in cells:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in seg:
			var u0 := lerpf(-1.0, 1.0, float(cell * seg + k) / (cells * seg))
			var u1 := lerpf(-1.0, 1.0, float(cell * seg + k + 1) / (cells * seg))
			for j in 6:
				var v0 := lerpf(-1.0, 1.0, j / 6.0)
				var v1 := lerpf(-1.0, 1.0, (j + 1) / 6.0)
				for top in [true, false]:
					var q := [_chute_pt(u0, v0, top), _chute_pt(u1, v0, top), _chute_pt(u1, v1, top), _chute_pt(u0, v1, top)]
					st.add_vertex(q[0]); st.add_vertex(q[1]); st.add_vertex(q[2])
					st.add_vertex(q[0]); st.add_vertex(q[2]); st.add_vertex(q[3])
			# trailing edge closes the airfoil; the leading edge (front, -Z) stays open like real cells
			var t0a := _chute_pt(u0, 1.0, true)
			var t0b := _chute_pt(u0, 1.0, false)
			var t1a := _chute_pt(u1, 1.0, true)
			var t1b := _chute_pt(u1, 1.0, false)
			st.add_vertex(t0a); st.add_vertex(t1a); st.add_vertex(t1b)
			st.add_vertex(t0a); st.add_vertex(t1b); st.add_vertex(t0b)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[cell % 2]
		chute_canopy.add_child(mi)
	# Risers: from points along the canopy underside to the shoulders (left / right groups)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.12, 0.12, 0.12)
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.22, 1.45, 0.0)
		for u in [0.25, 0.6, 0.92]:
			for v in [-0.6, 0.6]:
				var top := _chute_pt(side * u, v, false) + Vector3(0, CHUTE_H, 0)
				var line := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.012
				cm.bottom_radius = 0.012
				cm.height = top.distance_to(shoulder)
				cm.radial_segments = 4
				cm.rings = 1
				line.mesh = cm
				line.material_override = lm
				line.position = (top + shoulder) * 0.5
				line.basis = Basis(Quaternion(Vector3.UP, (top - shoulder).normalized()))
				chute.add_child(line)
	add_child(chute)


## Canopy deploy + flight animation: the oval unfurls from a narrow bundle (span first, then chord), overshoots
## slightly as it pressurises, then breathes and banks with the turn rate / swings with speed.
func _animate_chute(delta: float, st: Dictionary) -> void:
	if chute_canopy == null:
		return
	_chute_t += delta
	var k := clampf(_chute_t / 1.1, 0.0, 1.0)
	var span := 0.15 + 0.85 * ease(k, 0.4) + sin(k * PI) * 0.08
	var chord := 0.2 + 0.8 * ease(clampf(k * 1.3 - 0.2, 0.0, 1.0), 0.5)
	var breathe := 1.0 + sin(_chute_t * 2.3) * 0.015
	chute_canopy.scale = Vector3(span * breathe, lerpf(0.4, 1.0, k), chord * breathe)
	chute_canopy.position.y = lerpf(2.4, CHUTE_H, ease(k, 0.6))
	var turn: float = st.get("turn_rate", 0.0)
	var spd: float = st.get("speed", 0.0)
	var bank := clampf(-turn * 0.18, -0.35, 0.35) + sin(_chute_t * 1.4) * 0.03
	var pitch := clampf(spd * 0.012, 0.0, 0.14)
	chute.rotation.z = lerp_angle(chute.rotation.z, bank, minf(delta * 3.0, 1.0))
	chute.rotation.x = lerp_angle(chute.rotation.x, -pitch, minf(delta * 3.0, 1.0))


## Point on the oval canopy. u = -1..1 across the span, v = -1 (leading edge, front) .. 1 (trailing edge).
func _chute_pt(u: float, v: float, top: bool) -> Vector3:
	var half_chord := CHUTE_B * sqrt(maxf(1.0 - u * u, 0.0)) + 0.05
	var x := u * CHUTE_A
	var z := v * half_chord
	var arch := -CHUTE_ARCH * u * u
	# Airfoil thickness: thickest a third back from the leading edge, zero at the trailing edge.
	var tv := (v + 1.0) * 0.5
	var thick := 0.32 * sqrt(maxf(1.0 - u * u, 0.05)) * (1.0 - tv) * clampf(tv * 4.0 + 0.35, 0.0, 1.0)
	var y := arch + (thick if top else 0.0) + 0.08 * (1.0 - v * v)
	return Vector3(x, y, z)


func set_cast_shadows(on: bool) -> void:
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## First-person: the body is invisible but still casts the player's shadow.
func set_shadow_only(v: bool) -> void:
	_shadow_only = v
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if v else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func set_visibility_range(end: float) -> void:
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = end


func set_weapon(w: WeaponInstance) -> void:
	if gun_model:
		gun_model.queue_free()
		gun_model = null
	if w == null:
		return
	gun_model = load(w.data.model_path).instantiate()
	# The chunky operator models need a bigger gun to read at a distance.
	gun_model.scale = Vector3.ONE * 1.8
	gun_model.position = Vector3(0, 0, -0.5)
	gun_holder.add_child(gun_model)
	if _shadow_only:
		set_shadow_only(true)


func set_mode(m: String) -> void:
	var was := mode
	mode = m
	wings.visible = m == "freefall"
	chute.visible = m == "chute"
	if m == "chute" and was != "chute":
		_chute_t = 0.0
	if gun_model:
		gun_model.visible = m in ["ground", "chute"]
	if m == "dead" and was != "dead":
		_start_death()
	elif m != "dead":
		_death_vel = Vector3.ZERO
		_death_off = Vector3.ZERO
		_death_ang = 0.0
		_death_ang_v = 0.0
		_death_spin = 0.0
		_death_yaw = 0.0


## Knock-back from the killing blow: the owner Actor records where the hit came from and how hard.
func _start_death() -> void:
	var actor := get_parent() as Actor
	var push := Vector3(0, 0, 1)
	var force := 1.0
	if actor:
		var from: Vector3 = actor.last_hit_from
		if from != Vector3.ZERO:
			var d := actor.global_position - from
			d.y = 0.0
			if d.length() > 0.01:
				push = (global_transform.basis.inverse() * d.normalized())
		force = actor.last_hit_force
	push.y = 0.0
	push = push.normalized()
	_death_vel = push * (1.6 + force * 1.4) + Vector3.UP * maxf(force - 1.5, 0.0) * 2.2
	_death_axis = Vector3.UP.cross(push).normalized() if push.length() > 0.01 else Vector3.RIGHT
	_death_ang_v = 1.5 + force * 1.2
	_death_spin = randf_range(-1.0, 1.0) * force * 0.8


func _tick_death(delta: float) -> void:
	# Corpse slides along the floor (friction) and hops for explosive kills.
	_death_vel.y -= 18.0 * delta
	_death_off += _death_vel * delta
	if _death_off.y <= 0.0:
		_death_off.y = 0.0
		if _death_vel.y < -2.0:
			_death_vel.y *= -0.3
		else:
			_death_vel.y = 0.0
		var hv := Vector3(_death_vel.x, 0, _death_vel.z)
		hv = hv.move_toward(Vector3.ZERO, delta * 7.0)
		_death_vel = Vector3(hv.x, _death_vel.y, hv.z)
	_death_off = _death_off.limit_length(3.5)
	# Extra topple on top of the death clip, with a damped bounce when it hits the ground.
	_death_ang_v -= 4.0 * delta
	_death_ang += _death_ang_v * delta
	if _death_ang > 0.35:
		_death_ang = 0.35
		_death_ang_v = -absf(_death_ang_v) * 0.25
	if _death_ang < 0.0:
		_death_ang = 0.0
		_death_ang_v = 0.0
	_death_spin = move_toward(_death_spin, 0.0, delta * 2.0)
	_death_yaw += _death_spin * delta


## Small physical flinch toward the hit (spring back).
func flinch(from_world: Vector3, strength: float = 1.0) -> void:
	var d := global_transform.basis.inverse() * (global_position - from_world)
	_flinch_v += Vector2(clampf(d.z, -1, 1), clampf(-d.x, -1, 1)).normalized() * 2.6 * clampf(strength, 0.3, 2.0)


func play_melee() -> void:
	if tree:
		tree.set("parameters/melee/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## st: speed (m/s, horizontal), on_floor, crouch, armed, pistol, firing, pitch (rad, + up), emote
func update(delta: float, st: Dictionary) -> void:
	var want_tilt := 0.0
	var loco := "idle"
	var spd: float = st.get("speed", 0.0)
	match mode:
		"dead":
			loco = "die"
		"downed":
			loco = "crouch"
			want_tilt = deg_to_rad(-62.0)
		"freefall":
			loco = "fall"
			want_tilt = deg_to_rad(-78.0)
		"chute":
			loco = "fall"
			_animate_chute(delta, st)
		_:
			if st.get("emote", false):
				loco = "emote"
			elif not st.get("on_floor", true):
				loco = "fall"
			elif st.get("crouch", false):
				loco = "crouch"
				# Rigs without a crouch-walk clip walk low instead of sliding in a sit pose.
				if rig == "blocky" and spd > 0.6:
					loco = "walk"
			elif spd > 5.4:
				loco = "sprint"
			elif spd > 0.6:
				loco = "walk"
	_tilt = lerpf(_tilt, want_tilt, clampf(delta * 6.0, 0, 1))
	# Hit flinch spring
	_flinch_v += (-_flinch * 90.0 - _flinch_v * 12.0) * delta
	_flinch += _flinch_v * delta
	var crouch_low := 0.19 if rig == "blocky" and (st.get("crouch", false) or mode == "downed") and mode != "dead" else 0.0
	if crouch_low > 0.0 and spd > 0.6:
		_walk_phase += delta * spd * 2.2
	_crouch_drop = lerpf(_crouch_drop, crouch_low, clampf(delta * 10.0, 0, 1))
	if mode == "dead":
		_tick_death(delta)
		pose_root.position = Vector3(0, 0.9, 0) + _death_off
		pose_root.transform.basis = Basis(_death_axis, _death_ang) * Basis(Vector3.UP, _death_yaw)
	else:
		pose_root.rotation = Vector3(_tilt + _flinch.x * 0.25, 0.0, _flinch.y * 0.25)
		pose_root.position = Vector3(0, 0.9 - (0.55 if mode == "downed" else 0.0) - _crouch_drop, 0)
	if tree == null:
		return
	if loco != _loco:
		_loco = loco
		tree.set("parameters/loco/transition_request", loco)
	var ts := 1.0
	if loco == "walk":
		ts = clampf(spd / 3.2, 0.6, 1.8)
	elif loco == "sprint":
		ts = clampf(spd / 7.0, 0.8, 1.4)
	elif loco == "crouch" and spd > 0.6:
		ts = 1.0
	tree.set("parameters/speed/scale", ts)
	var armed: bool = st.get("armed", false) and mode in ["ground", "chute"] and loco != "sprint" and loco != "emote"
	var arms := ("holding-right" if st.get("pistol", false) else "holding-both") + ("-shoot" if st.get("firing", false) else "")
	if arms != _arms:
		_arms = arms
		tree.set("parameters/arms/transition_request", arms)
	tree.set("parameters/upper/blend_amount", 1.0 if armed else 0.0)
	var p: float = st.get("pitch", 0.0) if armed else 0.0
	_aim_pitch = lerpf(_aim_pitch, p, clampf(delta * 14.0, 0, 1))
	if aim:
		aim.pitch = _aim_pitch
	gun_holder.rotation.x = st.get("pitch", 0.0)
	gun_holder.position.y = _gun_y - _crouch_drop - (0.3 if rig != "blocky" and st.get("crouch", false) else 0.0)
	gun_holder.visible = mode in ["ground", "chute"] and loco != "die" and loco != "emote"
