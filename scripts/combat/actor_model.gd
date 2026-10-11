class_name ActorModel
extends Node3D
## Animated third-person body shared by bots, LAN puppets and the player's own body (third-person
## view / first-person shadow). Kenney Mini Characters (CC0) driven by an AnimationTree:
## lower body = locomotion (idle / walk / sprint / crouch / fall / die), upper body (arms) = weapon
## hold or shoot pose blended on top, and AimPose tilts the arms with the aim pitch. Also owns the
## wingsuit and parachute visuals used during the Battle Royale drop.

const SCALE := 2.65
const LOOPED := ["idle", "walk", "sprint", "holding-both", "holding-both-shoot", "holding-right",
	"holding-right-shoot", "crouch", "fall", "sit", "drive"]
const LOCO := ["idle", "walk", "sprint", "crouch", "fall", "die", "sit", "drive"]
const ARMS := ["holding-both", "holding-both-shoot", "holding-right", "holding-right-shoot"]

var pose_root: Node3D      ## pivot at the hips; tilted for wingsuit / downed poses
var model: Node3D
var anim: AnimationPlayer
var tree: AnimationTree
var skel: Skeleton3D
var aim: AimPose
var gun_holder: Node3D
var gun_model: Node3D
var wings: Node3D
var chute: Node3D
var mode := "ground"       ## ground | freefall | chute | downed | dead
var _loco := ""
var _arms := ""
var _shadow_only := false
var _tilt := 0.0


func setup(model_path: String) -> void:
	pose_root = Node3D.new()
	pose_root.position.y = 0.9
	add_child(pose_root)
	model = load(model_path).instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI
	model.position.y = -0.9
	pose_root.add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	skel = sks[0] if sks.size() > 0 else null
	gun_holder = Node3D.new()
	gun_holder.position = Vector3(0.2, 1.08, -0.12)
	add_child(gun_holder)
	if anim and skel:
		_build_tree()
	_build_wings()
	_build_chute()
	set_mode("ground")


func _build_tree() -> void:
	for a in LOOPED:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.stop()
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.18
	for a in LOCO:
		loco.add_input(a)
		var n := AnimationNodeAnimation.new()
		n.animation = a
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
		n.animation = a
		bt.add_node("u_" + a, n)
	bt.add_node("arms", arms)
	for i in ARMS.size():
		bt.connect_node("arms", i, "u_" + ARMS[i])
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	var base := String(model.get_path_to(skel)) if anim.root_node == NodePath("..") else String(anim.get_node(anim.root_node).get_path_to(skel))
	for b in ["arm-left", "arm-right"]:
		upper.set_filter_path(NodePath(base + ":" + b), true)
	bt.add_node("upper", upper)
	bt.connect_node("upper", 0, "speed")
	bt.connect_node("upper", 1, "arms")
	bt.connect_node("output", 0, "upper")
	tree = AnimationTree.new()
	tree.tree_root = bt
	anim.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_node = tree.get_path_to(anim.get_node(anim.root_node))
	tree.active = true
	aim = AimPose.new()
	for b in ["arm-left", "arm-right"]:
		var i := skel.find_bone(b)
		if i >= 0:
			aim.arm_bones.append(i)
	aim.head_bone = skel.find_bone("head")
	skel.add_child(aim)


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


func _build_chute() -> void:
	chute = Node3D.new()
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.6
	sm.height = 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 8
	canopy.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.55, 0.15)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = m
	canopy.position = Vector3(0, 4.4, 0)
	chute.add_child(canopy)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.1, 0.1, 0.1)
	for i in 6:
		var ang := TAU * i / 6.0
		var top := Vector3(cos(ang) * 2.4, 4.4, sin(ang) * 2.4)
		var bottom := Vector3(0, 1.5, 0)
		var line := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = top.distance_to(bottom)
		cm.radial_segments = 4
		line.mesh = cm
		line.material_override = lm
		line.position = (top + bottom) * 0.5
		line.basis = Basis(Quaternion(Vector3.UP, (top - bottom).normalized()))
		chute.add_child(line)
	add_child(chute)


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
	mode = m
	wings.visible = m == "freefall"
	chute.visible = m == "chute"
	if gun_model:
		gun_model.visible = m in ["ground", "chute"]


## st: speed (m/s, horizontal), on_floor, crouch, armed, pistol, firing, pitch (rad, + up)
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
		_:
			if not st.get("on_floor", true):
				loco = "fall"
			elif st.get("crouch", false):
				loco = "crouch"
			elif spd > 5.4:
				loco = "sprint"
			elif spd > 0.6:
				loco = "walk"
	_tilt = lerpf(_tilt, want_tilt, clampf(delta * 6.0, 0, 1))
	pose_root.rotation.x = _tilt
	pose_root.position.y = 0.9 - (0.55 if mode == "downed" else 0.0)
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
	var armed: bool = st.get("armed", false) and mode in ["ground", "chute"] and loco != "sprint"
	var arms := ("holding-right" if st.get("pistol", false) else "holding-both") + ("-shoot" if st.get("firing", false) else "")
	if arms != _arms:
		_arms = arms
		tree.set("parameters/arms/transition_request", arms)
	tree.set("parameters/upper/blend_amount", 1.0 if armed else 0.0)
	var p: float = st.get("pitch", 0.0) if armed else 0.0
	aim.pitch = lerpf(aim.pitch, p, clampf(delta * 14.0, 0, 1))
	gun_holder.rotation.x = st.get("pitch", 0.0)
	gun_holder.visible = mode in ["ground", "chute"] and loco != "die"
