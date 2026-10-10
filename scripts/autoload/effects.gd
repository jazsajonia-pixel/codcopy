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
	if flesh or _quality() == 0:
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
