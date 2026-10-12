class_name OperatorSkill
extends Node3D
## CODM-style operator skill attached to an Actor (player or bot) in multiplayer matches.
## The skill charges over time and faster with kills / damage; when full it can be activated once.
##
##   rewind      - snaps back to where you were ~3 s ago with the health you had then (if higher).
##   jetpack     - burst of vertical thrust, then a slow powered hover; no fall damage while flying.
##   hook        - fires a grappling hook at the surface you aim at and reels you in.
##   quickslash  - lightning dash forward with an energy blade; cuts down enemies in the path.
##
## Movement skills plug into the owner's movement code through apply_motion(), called right before
## move_and_slide(); everything else (charge, visuals, timers) runs in tick().

signal activated(skill_id: String)
signal ended(skill_id: String)

const REWIND_SECONDS := 3.0
const REWIND_SAMPLE := 0.1
const HOOK_RANGE := 45.0
const HOOK_SPEED := 27.0
const HOOK_SHOOT_TIME := 0.14
const SLASH_DIST := 9.0
const SLASH_TIME := 0.24
const SLASH_DAMAGE := 220.0
const SLASH_RADIUS := 1.7
const JET_THRUST_TIME := 1.4
const JET_TOTAL_TIME := 4.5
const KILL_CHARGE := 0.22         ## fraction of the meter per kill
const DAMAGE_CHARGE := 0.0006     ## fraction per point of damage dealt

var actor: Actor
var id := ""
var data: Dictionary = {}
var charge := 0.0                 ## 0..1
var active_t := 0.0               ## seconds the current activation has been running (-1 = idle)
var active := false
var screen_fx := 0.0              ## 0..1 full-screen tint strength for the owner's HUD
var screen_color := Color(0.3, 0.7, 1.0)
var no_fall_damage_t := 0.0

var _hist: Array = []             ## [{p, h, t}] newest last
var _hist_acc := 0.0
var _last_kills := 0
var _hook_point := Vector3.ZERO
var _hook_normal := Vector3.UP
var _slash_dir := Vector3.FORWARD
var _slash_hit := {}
var _ghosts: Array = []           ## [{node, t}]
var _rope: MeshInstance3D
var _hook_head: MeshInstance3D
var _jet: Node3D
var _jet_flames: Array = []
var _blade: MeshInstance3D
var _mat_cache := {}


static func create(p_actor: Actor, skill_id: String) -> OperatorSkill:
	if not GameDB.OPERATOR_SKILLS.has(skill_id):
		return null
	var s := OperatorSkill.new()
	s.actor = p_actor
	s.id = skill_id
	s.data = GameDB.OPERATOR_SKILLS[skill_id]
	s.name = "OperatorSkill"
	s.screen_color = s.data.color
	p_actor.add_child(s)
	return s


func _ready() -> void:
	top_level = true   # visuals live in world space; the node follows the actor manually
	_last_kills = actor.kills
	actor.damage_dealt.connect(_on_damage_dealt)
	actor.hit_confirmed.connect(_on_hit_confirmed)
	_build_visuals()


func is_ready() -> bool:
	return charge >= 1.0 and not active and actor.alive and not actor.downed and actor.vehicle == null


func charge_time() -> float:
	return float(data.get("charge", 40.0))


## Meter fill per second of play (CODM: skills also charge by themselves over time).
func tick(delta: float) -> void:
	global_position = actor.global_position
	if not active and actor.alive:
		charge = minf(charge + delta / charge_time(), 1.0)
	no_fall_damage_t = maxf(no_fall_damage_t - delta, 0.0)
	screen_fx = move_toward(screen_fx, 0.0, delta * 1.6)
	# Rewind history (also kept while other skills are idle so it is ready instantly)
	_hist_acc += delta
	if _hist_acc >= REWIND_SAMPLE and actor.alive:
		_hist_acc = 0.0
		_hist.append({"p": actor.global_position, "h": actor.health, "a": actor.armor})
		while _hist.size() > int(REWIND_SECONDS / REWIND_SAMPLE) + 1:
			_hist.pop_front()
	if active:
		active_t += delta
		_tick_active(delta)
	_tick_ghosts(delta)
	if not actor.alive and active:
		_end()


func _on_damage_dealt(_victim: Actor, amount: float, _hs: bool, _armor: bool) -> void:
	if not active:
		charge = minf(charge + amount * DAMAGE_CHARGE, 1.0)


func _on_hit_confirmed(_hs: bool, killed: bool) -> void:
	if killed:
		charge = minf(charge + KILL_CHARGE, 1.0)


func on_respawn() -> void:
	_hist.clear()
	if active:
		_end()
	_last_kills = actor.kills


## Try to fire the skill along `dir` (the owner's aim). Returns true if it started.
func activate(dir: Vector3) -> bool:
	if not is_ready():
		return false
	match id:
		"rewind":
			if _hist.size() < 4:
				return false
			_do_rewind()
		"jetpack":
			_jet.visible = true
			for f in _jet_flames:
				f.emitting = true
			actor.velocity.y = maxf(actor.velocity.y, 4.0)
			AudioManager.play_3d("res://assets/audio/sfx/jet_burst.ogg", actor.global_position, -2.0)
		"hook":
			var from := actor.eye_position()
			var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * HOOK_RANGE, 1)
			q.exclude = [actor.get_rid()]
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				return false
			_hook_point = hit.position
			_hook_normal = hit.normal
			_rope.visible = true
			_hook_head.visible = true
			AudioManager.play_3d("res://assets/audio/sfx/hook_fire.ogg", from, -3.0)
		"quickslash":
			_slash_dir = Vector3(dir.x, 0, dir.z)
			if _slash_dir.length() < 0.1:
				_slash_dir = -actor.global_transform.basis.z
			_slash_dir = _slash_dir.normalized()
			_slash_hit.clear()
			_blade.visible = true
			AudioManager.play_3d("res://assets/audio/sfx/slash.ogg", actor.global_position, -1.0)
	var body = actor.get("body") if actor.get("body") != null else actor.get("model")
	if body is ActorModel and id in ["quickslash", "hook"]:
		(body as ActorModel).play_melee()
	charge = 0.0
	active = true
	active_t = 0.0
	screen_fx = 1.0
	no_fall_damage_t = 2.0
	activated.emit(id)
	return true


func duration() -> float:
	match id:
		"rewind": return 0.45
		"jetpack": return JET_TOTAL_TIME
		"hook": return 1.6
		"quickslash": return SLASH_TIME + 0.15
	return 0.5


## Called by the owner right before move_and_slide(). May override the velocity it computed.
func apply_motion(delta: float) -> void:
	if not active:
		return
	match id:
		"jetpack":
			var hv := Vector3(actor.velocity.x, 0, actor.velocity.z) * 1.012
			if active_t < JET_THRUST_TIME:
				actor.velocity.y = move_toward(actor.velocity.y, 7.5, delta * 32.0)
			else:
				# Powered hover: slow sink, a little extra air control.
				actor.velocity.y = move_toward(actor.velocity.y, -1.4, delta * 26.0)
			actor.velocity.x = hv.x
			actor.velocity.z = hv.z
			no_fall_damage_t = 1.5
		"hook":
			if active_t < HOOK_SHOOT_TIME:
				return
			var to := _hook_point + _hook_normal * 0.6 - actor.global_position - Vector3.UP * 0.9
			if to.length() < 1.4 or active_t > duration() - 0.05:
				actor.velocity = actor.velocity.limit_length(6.0) + Vector3.UP * 3.0
				_end()
				return
			var ramp := clampf((active_t - HOOK_SHOOT_TIME) / 0.12, 0.25, 1.0)
			actor.velocity = to.normalized() * HOOK_SPEED * ramp
			no_fall_damage_t = 1.5
		"quickslash":
			if active_t < SLASH_TIME:
				actor.velocity = _slash_dir * (SLASH_DIST / SLASH_TIME)
				actor.velocity.y = 0.0
				_slash_damage()
			elif active_t < SLASH_TIME + delta * 1.5:
				actor.velocity = _slash_dir * 3.0


func _tick_active(delta: float) -> void:
	match id:
		"rewind":
			screen_fx = maxf(screen_fx, 1.0 - active_t / duration())
		"jetpack":
			_jet.global_position = actor.global_position + Vector3.UP * 1.15 + actor.global_transform.basis.z * 0.32
			_jet.global_rotation.y = actor.global_rotation.y
			var thrusting := active_t < JET_THRUST_TIME
			for f in _jet_flames:
				(f as CPUParticles3D).initial_velocity_max = 7.0 if thrusting else 3.5
			if Engine.get_physics_frames() % 6 == 0:
				Effects.burst("smoke", _jet.global_position - Vector3.UP * 0.5, Vector3.DOWN, 0.4)
		"hook":
			var hand := actor.global_position + Vector3.UP * 1.25 - actor.global_transform.basis.z * 0.3
			var k := clampf(active_t / HOOK_SHOOT_TIME, 0.0, 1.0)
			var tip := hand.lerp(_hook_point, k)
			_place_rope(hand, tip)
			_hook_head.global_position = tip
		"quickslash":
			var f := clampf(active_t / SLASH_TIME, 0.0, 1.0)
			_blade.global_position = actor.global_position + Vector3.UP * 1.35
			# Diagonal sweep: the arc rolls 35 degrees and swings across the front during the dash.
			_blade.global_basis = Basis.looking_at(_slash_dir, Vector3.UP) * Basis(Vector3.FORWARD, deg_to_rad(-35.0)) \
					* Basis(Vector3.UP, lerpf(0.9, -0.9, f))
			(_blade.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - f * 0.6)
			if Engine.get_physics_frames() % 2 == 0 and active_t < SLASH_TIME:
				_spawn_ghost(actor.global_position, 0.25)
	if active and active_t >= duration():
		_end()


func _end() -> void:
	if not active:
		return
	active = false
	if _jet:
		_jet.visible = false
		for f in _jet_flames:
			f.emitting = false
	if _rope:
		_rope.visible = false
		_hook_head.visible = false
	if _blade:
		_blade.visible = false
	ended.emit(id)


func _do_rewind() -> void:
	var snap: Dictionary = _hist[0]
	var from := actor.global_position
	# Ghost trail along the recorded path, newest to oldest.
	var step := maxi(1, _hist.size() / 6)
	for i in range(_hist.size() - 1, -1, -step):
		_spawn_ghost(_hist[i].p, 0.7)
	Effects.burst("sparks", from + Vector3.UP, Vector3.UP, 1.4)
	actor.global_position = snap.p
	actor.velocity = Vector3.ZERO
	actor.health = maxf(actor.health, float(snap.h))
	actor.armor = maxf(actor.armor, float(snap.a))
	actor.invulnerable_time = maxf(actor.invulnerable_time, 0.35)
	Effects.burst("sparks", actor.global_position + Vector3.UP, Vector3.UP, 1.4)
	AudioManager.play_3d("res://assets/audio/sfx/rewind.ogg", actor.global_position, -2.0)
	_hist.clear()


func _slash_damage() -> void:
	for a in get_tree().get_nodes_in_group("actors"):
		var o := a as Actor
		if o == null or not o.alive or _slash_hit.has(o) or not actor.is_enemy(o):
			continue
		var d := o.global_position - actor.global_position
		d.y = 0.0
		if d.length() < SLASH_RADIUS and absf(o.global_position.y - actor.global_position.y) < 2.0:
			_slash_hit[o] = true
			o.take_damage(SLASH_DAMAGE, actor, "Quick Slash", false, actor.global_position)
			Effects.burst("blood", o.aim_point(), _slash_dir, 1.5)
			Effects.burst("sparks", o.aim_point(), -_slash_dir, 1.0)


# ---------------- visuals ----------------

func _unlit(c: Color, additive := false) -> StandardMaterial3D:
	var key := str(c) + str(additive)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_cache[key] = m
	return m


func _build_visuals() -> void:
	match id:
		"jetpack":
			_jet = Node3D.new()
			_jet.visible = false
			add_child(_jet)
			var pack := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.42, 0.5, 0.2)
			pack.mesh = bm
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.22, 0.24, 0.27)
			pm.metallic = 0.6
			pack.material_override = pm
			_jet.add_child(pack)
			for side in [-0.13, 0.13]:
				var noz := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.06
				cm.bottom_radius = 0.08
				cm.height = 0.18
				noz.mesh = cm
				noz.material_override = pm
				noz.position = Vector3(side, -0.32, 0.02)
				_jet.add_child(noz)
				var fl := CPUParticles3D.new()
				fl.emitting = false
				fl.amount = 22
				fl.lifetime = 0.28
				fl.local_coords = false
				fl.position = Vector3(side, -0.42, 0.02)
				fl.direction = Vector3.DOWN
				fl.spread = 9.0
				fl.gravity = Vector3.ZERO
				fl.initial_velocity_min = 3.0
				fl.initial_velocity_max = 7.0
				fl.scale_amount_min = 0.6
				fl.scale_amount_max = 1.0
				var qm := QuadMesh.new()
				qm.size = Vector2(0.16, 0.16)
				var fm := _unlit(Color(1.0, 0.6, 0.2, 0.9), true)
				fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				qm.material = fm
				fl.mesh = qm
				var g := Gradient.new()
				g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
				g.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
				fl.color_ramp = g
				_jet.add_child(fl)
				_jet_flames.append(fl)
		"hook":
			_rope = MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.018
			rm.bottom_radius = 0.018
			rm.height = 1.0
			rm.radial_segments = 5
			rm.rings = 1
			_rope.mesh = rm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.15, 0.15, 0.16)
			rmat.emission_enabled = true
			rmat.emission = Color(0.2, 0.9, 0.5) * 0.4
			_rope.material_override = rmat
			_rope.visible = false
			add_child(_rope)
			_hook_head = MeshInstance3D.new()
			var hm := PrismMesh.new()
			hm.size = Vector3(0.22, 0.26, 0.08)
			_hook_head.mesh = hm
			var hmat := StandardMaterial3D.new()
			hmat.albedo_color = Color(0.7, 0.72, 0.75)
			hmat.metallic = 0.9
			_hook_head.material_override = hmat
			_hook_head.visible = false
			add_child(_hook_head)
		"quickslash":
			_blade = MeshInstance3D.new()
			# Glowing crescent (flat arc in front of the actor, thick in the middle, pointed at the tips).
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			var n := 24
			for i in n + 1:
				var u := float(i) / n
				var ang := lerpf(-1.25, 1.25, u)
				var w := sin(u * PI) * 0.32
				var dir := Vector3(sin(ang), 0, -cos(ang))
				st.add_vertex(dir * 1.25)
				st.add_vertex(dir * (1.25 - w))
			_blade.mesh = st.commit()
			_blade.material_override = _unlit(Color(0.55, 0.95, 1.0, 0.85), true).duplicate()
			_blade.visible = false
			add_child(_blade)


func _place_rope(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.01:
		return
	_rope.global_position = (a + b) * 0.5
	_rope.global_basis = Basis(Quaternion(Vector3.UP, (b - a).normalized())) * Basis.from_scale(Vector3(1, len, 1))


## Translucent after-image capsule that fades out (rewind path, slash trail).
func _spawn_ghost(pos: Vector3, life: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.32
	cm.height = 1.7
	cm.radial_segments = 10
	cm.rings = 3
	m.mesh = cm
	var mat := _unlit(Color(screen_color, 0.45), true).duplicate() as StandardMaterial3D
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3.UP * 0.9
	_ghosts.append({"node": m, "t": life, "life": life})


func _tick_ghosts(delta: float) -> void:
	for i in range(_ghosts.size() - 1, -1, -1):
		var g: Dictionary = _ghosts[i]
		g.t -= delta
		var n: MeshInstance3D = g.node
		if g.t <= 0.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			_ghosts.remove_at(i)
			continue
		var k: float = g.t / g.life
		(n.material_override as StandardMaterial3D).albedo_color.a = 0.45 * k
		n.scale = Vector3.ONE * (1.0 + (1.0 - k) * 0.25)
