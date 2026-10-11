extends GameMap
## "Suburbia" — small, fast cul-de-sac map: two houses facing each other across a street,
## fenced back yards, a bus and cars for mid cover (approx. 64 x 52 m). Built for close fights.

const CITY := "res://assets/maps/city/"
const SURV := "res://assets/maps/survival/"
const TOON := "res://assets/props/toon/"
const VEH := "res://assets/vehicles/"


func build() -> void:
	map_name = "Suburbia"
	bounds = Rect2(-32, -26, 64, 52)
	MapBuilder.environment(self, Vector3(-55, 20, 0), 0.003)
	b.ground(Vector2(140, 130), b.grass())
	var asphalt := b.flat(Color(0.2, 0.2, 0.22))
	var curb := b.flat(Color(0.75, 0.74, 0.7))
	var fence := b.painted(Color(0.92, 0.9, 0.85))
	# Street (east-west) with a turning circle in the middle
	b.box(Vector3(0, 0.02, 0), Vector3(64, 0.04, 10), asphalt, 0, null, false)
	var circle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.05
	circle.mesh = cm
	circle.material_override = asphalt
	circle.position.y = 0.03
	add_child(circle)
	b.box(Vector3(0, 0.08, 5.3), Vector3(64, 0.16, 0.6), curb, 0, null, false)
	b.box(Vector3(0, 0.08, -5.3), Vector3(64, 0.16, 0.6), curb, 0, null, false)
	# Map border (tall hedges / walls)
	var hedge := b.painted(Color(0.22, 0.42, 0.2))
	b.box(Vector3(0, 2.5, -26.5), Vector3(66, 5, 1), hedge)
	b.box(Vector3(0, 2.5, 26.5), Vector3(66, 5, 1), hedge)
	b.box(Vector3(-32.5, 2.5, 0), Vector3(1, 5, 54), hedge)
	b.box(Vector3(32.5, 2.5, 0), Vector3(1, 5, 54), hedge)
	# The two houses (blue team north, red team south), both enterable front and back, with a roof deck
	var blue := b.painted(Color(0.55, 0.68, 0.82))
	var yellow := b.painted(Color(0.9, 0.8, 0.5))
	b.house(Vector3(-6, 0, -15), Vector2(14, 9), 3.2, ["s", "n", "e"], blue)
	b.house(Vector3(6, 0, 15), Vector2(14, 9), 3.2, ["n", "s", "w"], yellow)
	b.ramp(Vector3(-17, 0, -12), 1.6, 7.0, 3.35, 90.0, b.painted(Color(0.5, 0.4, 0.3)))
	b.ramp(Vector3(17, 0, 12), 1.6, 7.0, 3.35, -90.0, b.painted(Color(0.5, 0.4, 0.3)))
	# Garages
	b.house(Vector3(10, 0, -16), Vector2(7, 7), 2.8, ["s", "w"], b.painted(Color(0.7, 0.72, 0.75)))
	b.house(Vector3(-10, 0, 16), Vector2(7, 7), 2.8, ["n", "e"], b.painted(Color(0.78, 0.7, 0.6)))
	# Front yard fences (low cover) with gaps
	for side in [-1.0, 1.0]:
		for x in [-24.0, -16.0, 16.0, 24.0]:
			b.box(Vector3(x, 0.5, side * 7.2), Vector3(5, 1.0, 0.15), fence)
		# back yard fences
		for x in [-22.0, -8.0, 8.0, 22.0]:
			b.box(Vector3(x, 0.9, side * 22), Vector3(9, 1.8, 0.15), fence)
	# Street cover: bus, cars, debris
	b.prop(VEH + "delivery.glb", Vector3(-2, 0, 1.5), 1.45, 90)
	b.prop(VEH + "suv.glb", Vector3(14, 0, -2.5), 1.45, 100)
	b.prop(VEH + "sedan.glb", Vector3(-15, 0, 2.6), 1.45, -80)
	b.prop(TOON + "Debris_BrokenCar.gltf", Vector3(24, 0, 2), 1.2, 15)
	b.prop(TOON + "Debris_BrokenCar.gltf", Vector3(-25, 0, -2), 1.2, 195)
	b.cover(Vector3(4, 0, -4), 2.5, 0)
	b.cover(Vector3(-5, 0, 4.2), 2.5, 0)
	# Back yards: trees, sheds, trampolines (boxes)
	for p in [Vector3(-24, 0, -18), Vector3(24, 0, 18), Vector3(22, 0, -19), Vector3(-22, 0, 19)]:
		b.tree(SURV + "tree.glb", p, 5.5)
	b.prop(TOON + "Structure_1.gltf", Vector3(22, 0, -12), 0.5, 0)
	b.prop(TOON + "Structure_1.gltf", Vector3(-22, 0, 12), 0.5, 180)
	for p in [Vector3(-27, 0.1, -10), Vector3(27, 0.1, 10), Vector3(0, 0.1, -8), Vector3(0, 0.1, 8)]:
		PhysicsProp.spawn(self, "barrel", p)
	for p in [Vector3(-12, 0.1, -9), Vector3(12, 0.1, 9), Vector3(20, 0.1, -9)]:
		PhysicsProp.spawn(self, "boxes", p, b.rng.randf() * TAU)
	PhysicsProp.spawn(self, "gas_tank", Vector3(-20, 0.1, 9))
	# Backdrop houses beyond the hedges
	for i in 6:
		b.prop(CITY + ["building-a", "building-b", "building-c"][i % 3] + ".glb", Vector3(-30 + i * 12, 0, -38), 8.0, 180, false)
		b.prop(CITY + ["building-d", "building-e", "building-f"][i % 3] + ".glb", Vector3(-30 + i * 12, 0, 38), 8.0, 0, false)
	# Spawns: A behind the north house, B behind the south house
	for i in 6:
		var x := -15.0 + i * 6.0
		spawns_a.append(facing(Vector3(x, 0.2, -24), Vector3(x * 0.3, 0, 0)))
		spawns_b.append(facing(Vector3(-x, 0.2, 24), Vector3(-x * 0.3, 0, 0)))
	for p in [Vector3(-28, 0.2, -22), Vector3(28, 0.2, 22), Vector3(-28, 0.2, 22), Vector3(28, 0.2, -22), Vector3(-28, 0.2, 0),
			Vector3(28, 0.2, 0), Vector3(-6, 0.3, -15), Vector3(6, 0.3, 15), Vector3(10, 0.3, -16), Vector3(-10, 0.3, 16)]:
		spawns_ffa.append(facing(p, Vector3.ZERO))
	for x in range(-28, 29, 7):
		for z in range(-22, 23, 7):
			patrol_points.append(Vector3(x, 0, z))
	pois = [{"name": "Blue House", "pos": Vector3(-6, 0, -15)}, {"name": "Street", "pos": Vector3.ZERO}, {"name": "Yellow House", "pos": Vector3(6, 0, 15)}]
	bake_navigation(false)
