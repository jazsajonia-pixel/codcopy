extends Node
## Pooled visual effects: tracers, impacts, sparks, explosions and smoke.
## All effects are pre-allocated to avoid runtime allocation spikes on mobile.

const TRACERS := 32
const IMPACTS := 48
const SPARKS := 16
const EXPLOSIONS := 4
const SMOKES := 3

var _tracers: Array = []
var _impacts: Array = []
var _sparks: Array = []
var _explosions: Array = []
var _smokes: Array = []
var _ti := 0
var _ii := 0
var _si := 0
var _ei := 0
var _smi := 0

## Active smoke volumes: Array of {pos: Vector3, radius: float, until: float}. Used for bot vision.
var smoke_volumes: Array = []

var _tracer_mat: StandardMaterial3D
var _impact_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _blood_mat: StandardMaterial3D


func _ready() -> void:
	_tracer_mat = _unshaded(Color(1.0, 0.85, 0.45, 0.9))
	_impact_mat = StandardMaterial3D.new()
	_impact_mat.albedo_color = Color(0.08, 0.07, 0.06, 0.85)
	_impact_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_impact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat = _unshaded(Color(1.0, 0.75, 0.3, 1.0))
	_blood_mat = _unshaded(Color(0.75, 0.05, 0.05, 1.0))

	var tmesh := BoxMesh.new()
	tmesh.size = Vector3(0.025, 0.025, 1.0)
	for i in TRACERS:
		var m := MeshInstance3D.new()
		m.mesh = tmesh
		m.material_override = _tracer_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_tracers.append({"node": m, "t": 0.0})

	var imesh := QuadMesh.new()
	imesh.size = Vector2(0.12, 0.12)
	for i in IMPACTS:
		var m2 := MeshInstance3D.new()
		m2.mesh = imesh
		m2.material_override = _impact_mat
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m2.visible = false
		add_child(m2)
		_impacts.append({"node": m2, "t": 0.0})

	var smesh := SphereMesh.new()
	smesh.radius = 0.06
	smesh.height = 0.12
	smesh.radial_segments = 6
	smesh.rings = 3
	for i in SPARKS:
		var m3 := MeshInstance3D.new()
		m3.mesh = smesh
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m3.visible = false
		add_child(m3)
		_sparks.append({"node": m3, "t": 0.0})

	for i in EXPLOSIONS:
		var root := Node3D.new()
		var ball := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 1.0
		bm.height = 2.0
		ball.mesh = bm
		var em := _unshaded(Color(1.0, 0.55, 0.15, 0.85))
		ball.material_override = em
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ball)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.omni_range = 10.0
		light.light_energy = 0.0
		root.add_child(light)
		root.visible = false
		add_child(root)
		_explosions.append({"node": root, "ball": ball, "light": light, "mat": em, "t": 9.0, "r": 5.0})

	for i in SMOKES:
		var sroot := Node3D.new()
		var puffs: Array = []
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.78, 0.78, 0.76, 0.0)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for j in 7:
			var p := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = 1.0
			pm.height = 2.0
			pm.radial_segments = 10
			pm.rings = 6
			p.mesh = pm
			p.material_override = smat
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sroot.add_child(p)
			puffs.append(p)
		sroot.visible = false
		add_child(sroot)
		_smokes.append({"node": sroot, "puffs": puffs, "mat": smat, "t": 99.0, "dur": 12.0, "r": 6.0})


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func clear() -> void:
	for arr in [_tracers, _impacts, _sparks]:
		for e in arr:
			e.node.visible = false
	for e in _explosions:
		e.node.visible = false
		e.t = 9.0
	for e in _smokes:
		e.node.visible = false
		e.t = 99.0
	for e in _rings:
		e.node.visible = false
	for d in _scorches:
		d.visible = false
	for k in _bursts.keys():
		for n in _bursts[k].nodes:
			n.emitting = false
	smoke_volumes.clear()


func _quality() -> int:
	return int(SaveManager.get_setting("graphics", "effects_quality", 1))


func _process(delta: float) -> void:
	for e in _tracers:
		if e.node.visible:
			e.t -= delta
			if e.t <= 0.0:
				e.node.visible = false
	for e in _sparks:
		if e.node.visible:
			e.t -= delta
			e.node.scale = Vector3.ONE * maxf(e.t / 0.08, 0.1)
			if e.t <= 0.0:
				e.node.visible = false
	for e in _impacts:
		if e.node.visible:
			e.t -= delta
			if e.t <= 0.0:
				e.node.visible = false
	for e in _explosions:
		if e.node.visible:
			e.t += delta
			var k: float = e.t / 0.45
			e.ball.scale = Vector3.ONE * lerpf(0.3, e.r, minf(k, 1.0))
			e.mat.albedo_color.a = clampf(1.0 - k, 0.0, 0.85)
			e.light.light_energy = clampf(6.0 * (1.0 - k * 1.5), 0.0, 6.0)
			if k >= 1.0:
				e.node.visible = false
	var now := Time.get_ticks_msec() / 1000.0
	for e in _smokes:
		if e.node.visible:
			e.t += delta
			var grow := clampf(e.t / 1.5, 0.0, 1.0)
			var fade := clampf((e.dur - e.t) / 2.0, 0.0, 1.0)
			e.mat.albedo_color.a = 0.92 * minf(grow * 1.5, 1.0) * fade
			for i in e.puffs.size():
				var p: MeshInstance3D = e.puffs[i]
				p.scale = Vector3.ONE * e.r * 0.55 * (0.4 + 0.6 * grow) * (1.0 + 0.06 * sin(e.t * 0.8 + i))
			if e.t >= e.dur:
				e.node.visible = false
	smoke_volumes = smoke_volumes.filter(func(v): return v.until > now)
	_tick_rings(delta)


func tracer(from: Vector3, to: Vector3) -> void:
	if _quality() == 0 and randf() < 0.5:
		return
	var d := to - from
	var dist := d.length()
	if dist < 0.5:
		return
	var e: Dictionary = _tracers[_ti]
	_ti = (_ti + 1) % TRACERS
	var n: MeshInstance3D = e.node
	var mid := from + d * 0.5
	n.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT), mid)
	n.scale = Vector3(1, 1, minf(dist, 40.0))
	n.visible = true
	e.t = 0.05


func impact(pos: Vector3, normal: Vector3, flesh: bool = false) -> void:
	var s: Dictionary = _sparks[_si]
	_si = (_si + 1) % SPARKS
	s.node.material_override = _blood_mat if flesh else _spark_mat
	s.node.global_position = pos + normal * 0.03
	s.node.visible = true
	s.t = 0.08
	if flesh:
		burst("blood", pos, normal + Vector3.UP * 0.3)
		return
	burst("dust", pos, normal)
	if randf() < 0.35:
		burst("sparks", pos, normal)
	if _quality() == 0:
		return
	var e: Dictionary = _impacts[_ii]
	_ii = (_ii + 1) % IMPACTS
	var n: MeshInstance3D = e.node
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	n.global_transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.01)
	n.visible = true
	e.t = 6.0 if _quality() >= 2 else 3.0


func explosion(pos: Vector3, radius: float) -> void:
	var e: Dictionary = _explosions[_ei]
	_ei = (_ei + 1) % EXPLOSIONS
	e.node.global_position = pos
	e.r = radius * 0.6
	e.t = 0.0
	e.node.visible = true


func smoke(pos: Vector3, radius: float, duration: float) -> void:
	var e: Dictionary = _smokes[_smi]
	_smi = (_smi + 1) % SMOKES
	e.node.global_position = pos
	e.r = radius
	e.dur = duration
	e.t = 0.0
	var rng := RandomNumberGenerator.new()
	for i in e.puffs.size():
		var p: MeshInstance3D = e.puffs[i]
		p.position = Vector3(rng.randf_range(-1, 1) * radius * 0.45, rng.randf_range(0.2, 1.0) * radius * 0.35, rng.randf_range(-1, 1) * radius * 0.45)
	e.node.visible = true
	smoke_volumes.append({"pos": pos + Vector3.UP, "radius": radius * 0.85, "until": Time.get_ticks_msec() / 1000.0 + duration})


## True if the segment a->b passes through an active smoke volume.
func blocked_by_smoke(a: Vector3, b: Vector3) -> bool:
	for v in smoke_volumes:
		var c: Vector3 = v.pos
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < v.radius:
			return true
	return false


## Continuous dark smoke attached to a node (damaged vehicles). Returns the emitter.
func smoke_trail(parent: Node3D, offset: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24 if _quality() > 0 else 10
	p.lifetime = 2.2
	p.position = offset
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 18.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 0.15, 0.15, 0.7))
	grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)
	return p


# ---------------------------------------------------------------------------------------------
# Particle bursts (pooled one-shot GPUParticles3D): blood, impact dust / sparks, debris, fire,
# smoke puffs, shell casings, landing dust, water splashes, shockwave rings and scorch decals.

const BURST_POOL := {"blood": 10, "dust": 12, "sparks": 10, "debris": 4, "fire": 4, "smoke": 6,
	"shell": 10, "land": 4, "splash": 4, "chunks": 4}
var _bursts := {}
var _soft_tex: Texture2D
var _rings: Array = []
var _scorches: Array = []
var _ri := 0
var _sci := 0


func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_soft_tex = gt
	return _soft_tex


func _particle_mat(additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _soft()
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.remove_point(1)
	g.set_color(0, cols[0])
	for i in range(1, cols.size()):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _make_burst(kind: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var mat := _particle_mat()
	match kind:
		"blood":
			p.amount = 14
			p.lifetime = 0.55
			pm.spread = 35.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 4.0
			pm.gravity = Vector3(0, -9.8, 0)
			pm.scale_min = 0.35
			pm.scale_max = 0.9
			pm.color_ramp = _ramp([Color(0.75, 0.02, 0.02, 1), Color(0.45, 0.0, 0.0, 0.0)])
			q.size = Vector2(0.14, 0.14)
		"dust":
			p.amount = 8
			p.lifetime = 0.7
			pm.spread = 30.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 2.0
			pm.gravity = Vector3(0, -1.0, 0)
			pm.damping_min = 2.0
			pm.damping_max = 3.0
			pm.scale_min = 0.6
			pm.scale_max = 1.4
			pm.color_ramp = _ramp([Color(0.75, 0.7, 0.6, 0.6), Color(0.6, 0.57, 0.5, 0.0)])
			q.size = Vector2(0.3, 0.3)
		"sparks":
			p.amount = 10
			p.lifetime = 0.3
			pm.spread = 50.0
			pm.initial_velocity_min = 3.0
			pm.initial_velocity_max = 8.0
			pm.gravity = Vector3(0, -12.0, 0)
			pm.scale_min = 0.15
			pm.scale_max = 0.3
			pm.color_ramp = _ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0)])
			mat = _particle_mat(true)
			q.size = Vector2(0.1, 0.1)
		"debris", "chunks":
			p.amount = 18 if kind == "debris" else 10
			p.lifetime = 1.6
			pm.spread = 70.0
			pm.initial_velocity_min = 5.0
			pm.initial_velocity_max = 13.0
			pm.gravity = Vector3(0, -18.0, 0)
			pm.angular_velocity_min = -500.0
			pm.angular_velocity_max = 500.0
			pm.scale_min = 0.5
			pm.scale_max = 1.3
			pm.color_ramp = _ramp([Color(0.18, 0.16, 0.14, 1), Color(0.18, 0.16, 0.14, 1), Color(0.18, 0.16, 0.14, 0)])
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.08, 0.1)
			var dm := StandardMaterial3D.new()
			dm.vertex_color_use_as_albedo = true
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.material = dm
			p.draw_pass_1 = bm
			p.process_material = pm
			return p
		"fire":
			p.amount = 22
			p.lifetime = 0.75
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.8
			pm.spread = 180.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 6.0
			pm.gravity = Vector3(0, 3.0, 0)
			pm.damping_min = 4.0
			pm.damping_max = 6.0
			pm.scale_min = 2.0
			pm.scale_max = 4.0
			pm.color_ramp = _ramp([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.12, 0.9), Color(0.35, 0.12, 0.05, 0.0)])
			mat = _particle_mat(true)
			q.size = Vector2(0.9, 0.9)
		"smoke":
			p.amount = 16
			p.lifetime = 3.2
			p.explosiveness = 0.75
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 1.0
			pm.spread = 60.0
			pm.initial_velocity_min = 1.0
			pm.initial_velocity_max = 3.0
			pm.gravity = Vector3(0, 1.2, 0)
			pm.damping_min = 1.0
			pm.damping_max = 2.0
			pm.scale_min = 3.0
			pm.scale_max = 5.5
			pm.color_ramp = _ramp([Color(0.25, 0.23, 0.22, 0.0), Color(0.22, 0.21, 0.2, 0.65), Color(0.4, 0.4, 0.4, 0.0)])
			q.size = Vector2(1.0, 1.0)
		"shell":
			p.amount = 1
			p.lifetime = 0.9
			p.explosiveness = 1.0
			pm.direction = Vector3(1, 0.8, 0.2)
			pm.spread = 12.0
			pm.initial_velocity_min = 1.6
			pm.initial_velocity_max = 2.4
			pm.gravity = Vector3(0, -9.8, 0)
			pm.angular_velocity_min = -720.0
			pm.angular_velocity_max = 720.0
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0045
			cm.bottom_radius = 0.0045
			cm.height = 0.022
			cm.radial_segments = 6
			cm.rings = 1
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.85, 0.65, 0.25)
			sm.metallic = 0.8
			sm.roughness = 0.35
			cm.material = sm
			p.draw_pass_1 = cm
			p.process_material = pm
			return p
		"land":
			p.amount = 16
			p.lifetime = 0.8
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = 0.4
			pm.emission_ring_inner_radius = 0.2
			pm.emission_ring_height = 0.05
			pm.direction = Vector3(0, 0.2, 0)
			pm.spread = 90.0
			pm.flatness = 0.9
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 3.5
			pm.damping_min = 4.0
			pm.damping_max = 5.0
			pm.scale_min = 0.8
			pm.scale_max = 1.5
			pm.color_ramp = _ramp([Color(0.75, 0.7, 0.6, 0.55), Color(0.7, 0.66, 0.58, 0.0)])
			q.size = Vector2(0.5, 0.5)
		"splash":
			p.amount = 18
			p.lifetime = 0.8
			pm.spread = 25.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 5.5
			pm.gravity = Vector3(0, -12.0, 0)
			pm.scale_min = 0.4
			pm.scale_max = 1.0
			pm.color_ramp = _ramp([Color(0.85, 0.95, 1.0, 0.9), Color(0.7, 0.85, 1.0, 0.0)])
			q.size = Vector2(0.25, 0.25)
	q.material = mat
	p.draw_pass_1 = q
	p.process_material = pm
	return p


## Fire a pooled burst at pos, spraying along dir. scale grows the emitter (explosions).
func burst(kind: String, pos: Vector3, dir: Vector3 = Vector3.UP, scale: float = 1.0) -> void:
	if not BURST_POOL.has(kind) or not is_inside_tree():
		return
	if _quality() == 0 and kind in ["dust", "shell", "land", "smoke"] and randf() < 0.6:
		return
	if not _bursts.has(kind):
		var arr: Array = []
		for i in BURST_POOL[kind]:
			var e := _make_burst(kind)
			add_child(e)
			arr.append(e)
		_bursts[kind] = {"nodes": arr, "i": 0}
	var pool: Dictionary = _bursts[kind]
	var p: GPUParticles3D = pool.nodes[pool.i]
	pool.i = (int(pool.i) + 1) % pool.nodes.size()
	var d := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var ref := Vector3.FORWARD if absf(d.y) > 0.95 else Vector3.UP
	# Particle "direction" is local +Y; build a basis whose Y axis points along d.
	var x := ref.cross(d).normalized()
	var b := Basis(x, d, x.cross(d).normalized())
	p.global_transform = Transform3D(b.scaled(Vector3.ONE * scale), pos)
	p.restart()


## Brass casing flicked out of the ejection port (basis = weapon orientation, +X = to the right).
func shell_eject(pos: Vector3, basis: Basis) -> void:
	if _quality() == 0:
		return
	if not _bursts.has("shell"):
		burst("shell", Vector3(0, -1000, 0))
	var pool: Dictionary = _bursts["shell"]
	var p: GPUParticles3D = pool.nodes[pool.i]
	pool.i = (int(pool.i) + 1) % pool.nodes.size()
	p.global_transform = Transform3D(basis.orthonormalized(), pos)
	p.restart()


## Expanding ground ring + scorch decal used by big explosions.
func _shockwave(pos: Vector3, radius: float) -> void:
	if _rings.is_empty():
		for i in 3:
			var mi := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.92
			tm.outer_radius = 1.0
			tm.rings = 24
			tm.ring_segments = 4
			mi.mesh = tm
			var m := _unshaded(Color(1.0, 0.85, 0.6, 0.6))
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			add_child(mi)
			_rings.append({"node": mi, "mat": m, "t": 9.0, "r": 5.0})
		for i in 8:
			var dc := Decal.new()
			dc.size = Vector3(4, 2, 4)
			var g := Gradient.new()
			g.set_color(0, Color(0.02, 0.02, 0.02, 0.85))
			g.set_color(1, Color(0.05, 0.05, 0.05, 0.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(1.0, 0.5)
			dc.texture_albedo = gt
			dc.visible = false
			add_child(dc)
			_scorches.append(dc)
	var e: Dictionary = _rings[_ri]
	_ri = (_ri + 1) % _rings.size()
	e.node.global_position = pos + Vector3.UP * 0.15
	e.r = radius
	e.t = 0.0
	e.node.visible = true
	var dcl: Decal = _scorches[_sci]
	_sci = (_sci + 1) % _scorches.size()
	dcl.size = Vector3(radius * 0.9, 2.5, radius * 0.9)
	dcl.global_position = pos
	dcl.rotation.y = randf() * TAU
	dcl.visible = true


func _tick_rings(delta: float) -> void:
	for e in _rings:
		if e.node.visible:
			e.t += delta
			var k: float = e.t / 0.35
			e.node.scale = Vector3(1, 0.4, 1) * lerpf(0.5, e.r * 1.4, minf(k, 1.0))
			e.mat.albedo_color.a = clampf(0.6 * (1.0 - k), 0.0, 0.6)
			if k >= 1.0:
				e.node.visible = false


## Full explosion package: fireball + smoke column + debris + shockwave + scorch.
func big_explosion(pos: Vector3, radius: float) -> void:
	explosion(pos, radius)
	burst("fire", pos + Vector3.UP * 0.4, Vector3.UP, clampf(radius / 6.0, 0.6, 2.0))
	burst("smoke", pos + Vector3.UP * 0.8, Vector3.UP, clampf(radius / 6.0, 0.6, 2.0))
	if _quality() > 0:
		burst("debris", pos + Vector3.UP * 0.2, Vector3.UP, 1.0)
		_shockwave(pos, radius)


func muzzle_smoke(pos: Vector3, dir: Vector3) -> void:
	if _quality() >= 2 or randf() < 0.35:
		burst("dust", pos, dir, 0.5)
