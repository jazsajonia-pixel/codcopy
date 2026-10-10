class_name MapBuilder
extends RefCounted
## Helper for building optimized blockout + prop maps in code.
## All collidable geometry is parented under a NavigationRegion3D so navmesh baking
## (static colliders, works on mobile and headless) sees it.

var root: Node3D
var nav: NavigationRegion3D
var props: Node3D
var _mats := {}
var _scene_cache := {}
var rng := RandomNumberGenerator.new()


func _init(p_root: Node3D, seed_value: int = 1) -> void:
	root = p_root
	rng.seed = seed_value
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = 0.5
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 42.0
	nm.region_min_size = 4.0
	nav.navigation_mesh = nm
	root.add_child(nav)
	props = Node3D.new()
	props.name = "Decor"
	root.add_child(props)


# ---------------- Materials ----------------

func mat(key: String, color: Color, tex: String = "", uv_scale: float = 0.25, rough: float = 0.9) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if tex != "":
		m.albedo_texture = load(tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


func concrete() -> StandardMaterial3D:
	return mat("concrete", Color(0.82, 0.8, 0.76), "res://assets/textures/concrete_floor_worn_001_diff_1k.jpg", 0.3)


func dirt() -> StandardMaterial3D:
	return mat("dirt", Color(1, 1, 1), "res://assets/textures/dry_ground_01_diff_1k.jpg", 0.08)


func grass() -> StandardMaterial3D:
	return mat("grass", Color(0.95, 1.0, 0.9), "res://assets/textures/aerial_grass_rock_diff_1k.jpg", 0.04)


func painted(c: Color) -> StandardMaterial3D:
	return mat("paint_%s" % c.to_html(), c, "res://assets/textures/concrete_floor_worn_001_diff_1k.jpg", 0.3)


func flat(c: Color) -> StandardMaterial3D:
	return mat("flat_%s" % c.to_html(), c)


# ---------------- Primitives ----------------

## Static box with collision + mesh. `pos` is the box center.
func box(pos: Vector3, size: Vector3, m: Material, rot_y_deg: float = 0.0, parent: Node3D = null, cast_shadow := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	(parent if parent else nav).add_child(body)
	body.position = pos
	body.rotation_degrees.y = rot_y_deg
	return body


## Invisible collision only.
func blocker(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)   # not under nav: map borders shouldn't create navmesh tops
	body.position = pos
	return body


func ground(size: Vector2, m: Material, y: float = 0.0) -> void:
	box(Vector3(0, y - 0.5, 0), Vector3(size.x, 1.0, size.y), m, 0.0, null, false)


## Ramp from `a` (low end, on ground) rising `height` over `length` along rot_y direction (-Z local).
func ramp(base: Vector3, width: float, length: float, height: float, rot_y_deg: float, m: Material) -> void:
	var ang := atan2(height, length)
	var hyp := sqrt(length * length + height * height)
	var body := box(Vector3.ZERO, Vector3(width, 0.3, hyp), m)
	var b := Basis(Vector3.UP, deg_to_rad(rot_y_deg)) * Basis(Vector3.RIGHT, ang)
	var center := base + Basis(Vector3.UP, deg_to_rad(rot_y_deg)) * Vector3(0, height * 0.5, -length * 0.5)
	body.transform = Transform3D(b, center)


# ---------------- Props ----------------

func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


## Places a GLB prop. If `collide`, adds a box collider fitted to the prop's AABB (cheap on mobile).
func prop(path: String, pos: Vector3, scale: float, rot_y_deg: float = 0.0, collide := true, collider_shrink := 0.9) -> Node3D:
	var inst: Node3D = _scene(path).instantiate()
	inst.scale = Vector3.ONE * scale
	var aabb := _local_aabb(inst)
	if collide:
		var body := StaticBody3D.new()
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var s := aabb.size * scale
		shape.size = Vector3(s.x * collider_shrink, s.y, s.z * collider_shrink)
		cs.shape = shape
		cs.position = (aabb.position + aabb.size * 0.5) * scale
		body.add_child(cs)
		body.add_child(inst)
		inst.position = Vector3.ZERO
		nav.add_child(body)
		body.position = pos
		body.rotation_degrees.y = rot_y_deg
		return body
	props.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = rot_y_deg
	return inst


## Tree with a thin trunk collider (so it gives cover without blocking like a cube).
func tree(path: String, pos: Vector3, scale: float) -> void:
	var inst: Node3D = _scene(path).instantiate()
	inst.scale = Vector3.ONE * scale
	inst.rotation_degrees.y = rng.randf_range(0, 360)
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 260.0
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.06 * scale
	cyl.height = 0.6 * scale
	cs.shape = cyl
	cs.position.y = cyl.height * 0.5
	body.add_child(cs)
	body.add_child(inst)
	nav.add_child(body)
	body.position = pos


static func _local_aabb(n: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var a := t * mi.get_aabb()
		if first:
			acc = a
			first = false
		else:
			acc = acc.merge(a)
	return acc


# ---------------- Structures ----------------

## Enterable building: 4 walls with door gaps (sides: "n","s","e","w"), optional windows and roof.
## Returns interior loot points.
func house(center: Vector3, size: Vector2, height: float, doors: Array, wall_mat: Material, roof := true, windows := true, rot := 0.0) -> Array:
	var holder := Node3D.new()
	nav.add_child(holder)
	holder.position = center
	holder.rotation_degrees.y = rot
	var t := 0.3
	var door_w := 2.0
	var door_h := 2.5
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	# floor slab
	box(Vector3(0, 0.05, 0), Vector3(size.x, 0.1, size.y), concrete(), 0, holder, false)
	var sides := {
		"n": {"len": size.x, "pos": Vector3(0, 0, -hz), "rot": 0.0},
		"s": {"len": size.x, "pos": Vector3(0, 0, hz), "rot": 0.0},
		"w": {"len": size.y, "pos": Vector3(-hx, 0, 0), "rot": 90.0},
		"e": {"len": size.y, "pos": Vector3(hx, 0, 0), "rot": 90.0},
	}
	for k in sides.keys():
		var sd: Dictionary = sides[k]
		var L: float = sd.len
		var dir := Vector3.RIGHT if sd.rot == 0.0 else Vector3.BACK
		var base: Vector3 = sd.pos
		if k in doors:
			var seg := (L - door_w) * 0.5
			for sgn in [-1.0, 1.0]:
				var c: Vector3 = base + dir * sgn * (door_w * 0.5 + seg * 0.5)
				_wall_segment(holder, c, seg, height, t, sd.rot, wall_mat, windows and seg > 3.0)
			# lintel
			box(base + Vector3(0, door_h + (height - door_h) * 0.5, 0), _wall_size(door_w, height - door_h, t, sd.rot), wall_mat, 0, holder)
		else:
			_wall_segment(holder, base, L + (t if sd.rot == 90.0 else 0.0), height, t, sd.rot, wall_mat, windows and L > 5.0)
	if roof:
		box(Vector3(0, height + 0.15, 0), Vector3(size.x + 0.6, 0.3, size.y + 0.6), painted(Color(0.35, 0.32, 0.3)), 0, holder)
	var pts: Array = []
	for i in 2:
		var local := Vector3(rng.randf_range(-hx + 1.2, hx - 1.2), 0.4, rng.randf_range(-hz + 1.2, hz - 1.2))
		pts.append(center + local.rotated(Vector3.UP, deg_to_rad(rot)))
	return pts


func _wall_size(length: float, h: float, t: float, rot: float) -> Vector3:
	return Vector3(length, h, t) if rot == 0.0 else Vector3(t, h, length)


func _wall_segment(holder: Node3D, c: Vector3, length: float, h: float, t: float, rot: float, m: Material, window: bool) -> void:
	if not window or length < 3.0:
		box(c + Vector3(0, h * 0.5, 0), _wall_size(length, h, t, rot), m, 0, holder)
		return
	# Window: lower wall, upper wall, two pillars around a 1.4 x 1.1 opening.
	var ww := 1.4
	var sill := 1.1
	var top := 2.2
	var dir := Vector3.RIGHT if rot == 0.0 else Vector3.BACK
	box(c + Vector3(0, sill * 0.5, 0), _wall_size(length, sill, t, rot), m, 0, holder)
	box(c + Vector3(0, top + (h - top) * 0.5, 0), _wall_size(length, h - top, t, rot), m, 0, holder)
	var side := (length - ww) * 0.5
	for sgn in [-1.0, 1.0]:
		box(c + dir * sgn * (ww * 0.5 + side * 0.5) + Vector3(0, sill + (top - sill) * 0.5, 0), _wall_size(side, top - sill, t, rot), m, 0, holder)


## Low cover wall (sandbag style).
func cover(pos: Vector3, length: float, rot := 0.0, h := 1.05) -> void:
	box(pos + Vector3(0, h * 0.5, 0), Vector3(length, h, 0.7), mat("sandbag", Color(0.62, 0.55, 0.4), "res://assets/textures/dry_ground_01_diff_1k.jpg", 0.5), rot)


## Shipping container (solid), colored.
func container(pos: Vector3, rot: float, c: Color, stacked := false) -> void:
	var m := mat("container_%s" % c.to_html(), c, "res://assets/textures/concrete_floor_worn_001_diff_1k.jpg", 0.6, 0.6)
	box(pos + Vector3(0, 1.3, 0), Vector3(6.0, 2.6, 2.5), m, rot)
	if stacked:
		box(pos + Vector3(0, 3.9, 0), Vector3(6.0, 2.6, 2.5), m, rot + 4.0)


## Elevated platform with a ramp (watchtower / catwalk).
func tower(pos: Vector3, h: float, ramp_rot: float) -> void:
	var wood := mat("wood", Color(0.55, 0.42, 0.3), "res://assets/textures/dry_ground_01_diff_1k.jpg", 0.4)
	box(pos + Vector3(0, h, 0), Vector3(4.0, 0.3, 4.0), wood)
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			box(pos + Vector3(x, h * 0.5, z), Vector3(0.3, h, 0.3), wood)
	# railings (low cover)
	box(pos + Vector3(0, h + 0.6, -1.95), Vector3(4.0, 0.9, 0.12), wood)
	box(pos + Vector3(-1.95, h + 0.6, 0), Vector3(0.12, 0.9, 4.0), wood)
	var dir := Basis(Vector3.UP, deg_to_rad(ramp_rot)) * Vector3(0, 0, 1)
	ramp(pos + dir * (2.0 + h * 2.2), 1.6, h * 2.2, h + 0.15, ramp_rot, wood)


# ---------------- Environment ----------------

static func environment(parent: Node3D, sun_rot := Vector3(-48, -35, 0), fog_density := 0.0015) -> DirectionalLight3D:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/textures/sky_kloofendal_1k.hdr")
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = fog_density > 0.0
	env.fog_density = fog_density
	env.fog_light_color = Color(0.72, 0.78, 0.85)
	env.fog_sky_affect = 0.25
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = SaveManager.get_setting("graphics", "shadows", true)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.add_to_group("sun")
	parent.add_child(sun)
	return sun
