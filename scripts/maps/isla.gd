extends GameMap
## "Isla Verde" — Battle Royale island (~340 m across) with generated terrain and six points of interest.
## Kept intentionally compact for mobile: 2 m terrain grid, box colliders, distance-culled props.

const CITY := "res://assets/maps/city/"
const SURV := "res://assets/maps/survival/"
const VEH := "res://assets/vehicles/"
const HALF := 200.0
const GRID := 2.0
const ISLAND_R := 165.0

var noise := FastNoiseLite.new()
var poi_defs := [
	{"name": "Harbor Town", "pos": Vector2(-95, 70), "r": 38.0},
	{"name": "Depot", "pos": Vector2(85, 80), "r": 36.0},
	{"name": "Farmstead", "pos": Vector2(-85, -80), "r": 32.0},
	{"name": "Radar Hill", "pos": Vector2(70, -75), "r": 26.0},
	{"name": "Crossing", "pos": Vector2(0, 5), "r": 30.0},
	{"name": "Pine Ridge", "pos": Vector2(-10, -105), "r": 24.0},
]


func build() -> void:
	map_name = "Isla Verde"
	bounds = Rect2(-HALF, -HALF, HALF * 2, HALF * 2)
	noise.seed = 4242
	noise.frequency = 0.0085
	noise.fractal_octaves = 3
	for p in poi_defs:
		p.base = _raw_height(p.pos.x, p.pos.y)
	MapBuilder.environment(self, Vector3(-38, -50, 0), 0.0016)
	_terrain()
	_water()
	_harbor_town(poi_defs[0])
	_depot(poi_defs[1])
	_farmstead(poi_defs[2])
	_radar(poi_defs[3])
	_crossing(poi_defs[4])
	_pine_ridge(poi_defs[5])
	_scatter()
	for p in poi_defs:
		pois.append({"name": p.name, "pos": Vector3(p.pos.x, height(p.pos.x, p.pos.y), p.pos.y)})
		patrol_points.append(Vector3(p.pos.x, height(p.pos.x, p.pos.y), p.pos.y))
	for i in 40:
		var a := b.rng.randf() * TAU
		var r := sqrt(b.rng.randf()) * (ISLAND_R - 25.0)
		var x := cos(a) * r
		var z := sin(a) * r
		patrol_points.append(Vector3(x, height(x, z), z))
	# Invisible border
	b.blocker(Vector3(0, 40, -HALF), Vector3(HALF * 2, 100, 2))
	b.blocker(Vector3(0, 40, HALF), Vector3(HALF * 2, 100, 2))
	b.blocker(Vector3(-HALF, 40, 0), Vector3(2, 100, HALF * 2))
	b.blocker(Vector3(HALF, 40, 0), Vector3(2, 100, HALF * 2))


# ---------------- Terrain ----------------

func _raw_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var h := 2.5 + noise.get_noise_2d(x, z) * 7.0
	# Radar hill
	h += 13.0 * exp(-Vector2(x - 70, z + 75).length_squared() / (2.0 * 32.0 * 32.0))
	h += 6.0 * exp(-Vector2(x + 10, z + 105).length_squared() / (2.0 * 30.0 * 30.0))
	# Coastline
	var coast := smoothstep(ISLAND_R - 30.0, ISLAND_R + 12.0, r)
	return lerpf(h, -4.0, coast)


func height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	for p in poi_defs:
		if not p.has("base"):
			continue
		var d := Vector2(x, z).distance_to(p.pos)
		var k := smoothstep(p.r, p.r * 0.6, d)
		h = lerpf(h, p.base, k)
	return h


func _terrain() -> void:
	var n := int(HALF * 2 / GRID) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height(-HALF + i * GRID, -HALF + j * GRID)
	# Mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			var hx := heights[j * n + mini(i + 1, n - 1)] - heights[j * n + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, n - 1) * n + i] - heights[maxi(j - 1, 0) * n + i]
			var normal := Vector3(-hx, 2.0 * GRID, -hz).normalized()
			var col := Color(0.55, 0.72, 0.38)
			if h < 0.8:
				col = Color(1.0, 0.93, 0.72)
			elif h < 1.6:
				col = Color(1.0, 0.93, 0.72).lerp(col, (h - 0.8) / 0.8)
			if normal.y < 0.82:
				col = col.lerp(Color(0.62, 0.6, 0.56), clampf((0.82 - normal.y) * 5.0, 0, 1))
			st.set_color(col)
			st.set_normal(normal)
			st.set_uv(Vector2(i, j) * 0.25)
			st.add_vertex(Vector3(-HALF + i * GRID, h, -HALF + j * GRID))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/textures/dry_ground_01_diff_1k.jpg")
	m.uv1_scale = Vector3(1, 1, 1)
	m.roughness = 0.95
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Collision
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = heights
	cs.shape = hm
	cs.scale = Vector3(GRID, 1, GRID)
	body.add_child(cs)
	body.add_child(mi)
	b.nav.add_child(body)


func _water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	w.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.38, 0.52, 0.86)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.metallic = 0.2
	w.material_override = m
	w.position.y = -0.4
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)


func _g(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


# ---------------- POIs ----------------

func _add_house(c: Vector3, size: Vector2, doors: Array, color: Color, rot := 0.0, h := 3.4) -> void:
	var pts := b.house(c, size, h, doors, b.painted(color), true, true, rot)
	loot_points.append_array(pts)


func _harbor_town(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	var cols := [Color(0.85, 0.78, 0.62), Color(0.7, 0.75, 0.8), Color(0.8, 0.65, 0.55), Color(0.75, 0.8, 0.65)]
	var k := 0
	for ix in [-1, 0, 1]:
		for iz in [-1, 1]:
			_add_house(o + Vector3(ix * 18, 0, iz * 12), Vector2(10, 8), ["n" if iz > 0 else "s", "e"], cols[k % 4])
			k += 1
	var names := ["building-a", "building-c", "building-e", "building-g"]
	for i in 4:
		b.prop(CITY + names[i] + ".glb", o + Vector3(-30 + i * 20, 0, -28), 9.0, 180, true, 0.95)
	b.prop(VEH + "truck.glb", o + Vector3(-6, 0, 0), 1.45, 90)
	b.prop(VEH + "sedan.glb", o + Vector3(12, 0, 2), 1.45, 80)
	b.prop(VEH + "van.glb", o + Vector3(28, 0, -3), 1.45, 100)
	crate_points.append(o + Vector3(0, 0.1, 0))
	for i in 6:
		loot_points.append(o + Vector3(b.rng.randf_range(-28, 28), 0.3, b.rng.randf_range(-6, 6)))


func _depot(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	_add_house(o + Vector3(-12, 0, -10), Vector2(18, 12), ["s", "e", "w"], Color(0.55, 0.58, 0.6), 0.0, 5.0)
	_add_house(o + Vector3(14, 0, 12), Vector2(16, 10), ["n", "w"], Color(0.6, 0.55, 0.5), 0.0, 5.0)
	var cc := [Color(0.2, 0.35, 0.55), Color(0.6, 0.2, 0.15), Color(0.25, 0.45, 0.25), Color(0.75, 0.45, 0.12)]
	for i in 8:
		var pos := o + Vector3(-26 + (i % 4) * 9.0, 0, 8 + (i / 4) * 7.0)
		b.container(pos, 90.0 if i % 3 == 0 else 0.0, cc[i % 4], i % 2 == 0)
		loot_points.append(pos + Vector3(0, 0.3, 2.2))
	b.tower(o + Vector3(24, 0, -18), 4.0, 180)
	loot_points.append(o + Vector3(24, 4.5, -18))
	crate_points.append(o + Vector3(2, 0.1, -2))


func _farmstead(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	_add_house(o + Vector3(0, 0, 0), Vector2(11, 9), ["s", "e"], Color(0.72, 0.5, 0.38))
	_add_house(o + Vector3(-18, 0, 10), Vector2(9, 7), ["n"], Color(0.8, 0.75, 0.6), 30.0)
	_add_house(o + Vector3(16, 0, 14), Vector2(12, 8), ["w", "n"], Color(0.6, 0.45, 0.35), 0.0, 4.2)
	for i in 4:
		b.prop(SURV + "tent.glb", o + Vector3(-20 + i * 6, 0, -18), 6.0, b.rng.randf_range(0, 360))
		loot_points.append(o + Vector3(-20 + i * 6, 0.3, -15))
	for i in 10:
		b.prop(SURV + "fence-fortified.glb", o + Vector3(-25 + i * 5, 0, 26), 10.0, 0)
	b.prop(VEH + "suv.glb", o + Vector3(6, 0, -10), 1.45, 20)
	crate_points.append(o + Vector3(0, 0.1, -10))


func _radar(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	var metal := b.painted(Color(0.5, 0.55, 0.5))
	b.box(o + Vector3(0, 4, 0), Vector3(3, 8, 3), metal)
	b.box(o + Vector3(0, 8.6, 0), Vector3(8, 0.4, 2), b.flat(Color(0.85, 0.85, 0.85)))
	_add_house(o + Vector3(-12, 0, 6), Vector2(10, 7), ["e", "s"], Color(0.62, 0.65, 0.6))
	_add_house(o + Vector3(12, 0, -6), Vector2(8, 6), ["w"], Color(0.62, 0.65, 0.6))
	for i in 5:
		b.prop(SURV + "structure-metal-wall.glb", o + Vector3(-16 + i * 7, 0, 16), 7.0, 0)
	b.tower(o + Vector3(0, 0, -16), 4.5, 90)
	loot_points.append(o + Vector3(0, 5.0, -16))
	crate_points.append(o + Vector3(5, 0.1, 5))


func _crossing(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	var road := b.flat(Color(0.25, 0.24, 0.24))
	b.box(o + Vector3(0, 0.05, 0), Vector3(60, 0.1, 8), road, 0, null, false)
	b.box(o + Vector3(0, 0.05, 0), Vector3(8, 0.1, 60), road, 0, null, false)
	var cols := [Color(0.82, 0.74, 0.6), Color(0.66, 0.7, 0.76), Color(0.76, 0.62, 0.58), Color(0.7, 0.75, 0.62)]
	var k := 0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_add_house(o + Vector3(sx * 13, 0, sz * 13), Vector2(10, 9), ["n" if sz > 0 else "s", "w" if sx > 0 else "e"], cols[k])
			k += 1
	b.prop(VEH + "police.glb", o + Vector3(2, 0, 2), 1.45, 45)
	b.prop(VEH + "delivery.glb", o + Vector3(-20, 0, 1.5), 1.45, 90)
	b.cover(o + Vector3(0, 0, 12), 4.0)
	b.cover(o + Vector3(0, 0, -12), 4.0)
	crate_points.append(o + Vector3(-3, 0.15, -3))


func _pine_ridge(p: Dictionary) -> void:
	var o := Vector3(p.pos.x, p.base, p.pos.y)
	_add_house(o, Vector2(9, 7), ["s"], Color(0.5, 0.38, 0.28), 15.0)
	for i in 30:
		var a := b.rng.randf() * TAU
		var r := b.rng.randf_range(9.0, 34.0)
		var x := o.x + cos(a) * r
		var z := o.z + sin(a) * r
		b.tree(SURV + ("tree-tall.glb" if i % 3 else "tree.glb"), _g(x, z), b.rng.randf_range(5.5, 7.5))
	for i in 4:
		loot_points.append(_g(o.x + b.rng.randf_range(-20, 20), o.z + b.rng.randf_range(-20, 20)) + Vector3(0, 0.3, 0))
	crate_points.append(o + Vector3(0, 0.1, 6))


func _scatter() -> void:
	# Trees, rocks and lone shacks between POIs.
	for i in 140:
		var a := b.rng.randf() * TAU
		var r := sqrt(b.rng.randf()) * (ISLAND_R - 20.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if _near_poi(x, z, 6.0):
			continue
		var h := height(x, z)
		if h < 1.2:
			continue
		if i % 4 == 0:
			b.prop(SURV + ["rock-a.glb", "rock-b.glb", "rock-c.glb"][i % 3], Vector3(x, h - 0.3, z), b.rng.randf_range(5.0, 9.0), b.rng.randf_range(0, 360))
		else:
			b.tree(SURV + ["tree.glb", "tree-tall.glb", "tree-autumn.glb"][i % 3], Vector3(x, h, z), b.rng.randf_range(5.0, 7.0))
	for i in 9:
		var a2 := TAU * i / 9.0 + 0.3
		var r2 := 115.0 + b.rng.randf_range(-15, 15)
		var x2 := cos(a2) * r2
		var z2 := sin(a2) * r2
		if _near_poi(x2, z2, 12.0) or height(x2, z2) < 1.5:
			continue
		var c := Vector3(x2, height(x2, z2), z2)
		_add_house(c, Vector2(7, 6), ["s"], Color(0.7, 0.62, 0.5), b.rng.randf_range(0, 90), 3.0)
	for i in 30:
		var a3 := b.rng.randf() * TAU
		var r3 := sqrt(b.rng.randf()) * (ISLAND_R - 30.0)
		var x3 := cos(a3) * r3
		var z3 := sin(a3) * r3
		if height(x3, z3) > 1.0:
			loot_points.append(Vector3(x3, height(x3, z3) + 0.3, z3))


func _near_poi(x: float, z: float, pad: float) -> bool:
	for p in poi_defs:
		if Vector2(x, z).distance_to(p.pos) < p.r + pad:
			return true
	return false
