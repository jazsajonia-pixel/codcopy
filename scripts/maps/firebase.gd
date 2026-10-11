extends GameMap
## "Firebase" — military camp in the hills: trench lines, bunkers, a central command post with a
## raised helipad and a parked tank (approx. 80 x 80 m). Mid-range, lots of verticality.

const SURV := "res://assets/maps/survival/"
const TOON := "res://assets/props/toon/"
const VEH := "res://assets/vehicles/"


func build() -> void:
	map_name = "Firebase"
	bounds = Rect2(-40, -40, 80, 80)
	MapBuilder.environment(self, Vector3(-30, -120, 0), 0.0035)
	b.ground(Vector2(170, 170), b.dirt())
	var conc := b.concrete()
	var olive := b.painted(Color(0.38, 0.42, 0.3))
	var steel := b.painted(Color(0.45, 0.47, 0.45))
	# Perimeter: earth berms
	var berm := b.painted(Color(0.5, 0.42, 0.3))
	b.box(Vector3(0, 2.0, -40.5), Vector3(82, 4, 2), berm)
	b.box(Vector3(0, 2.0, 40.5), Vector3(82, 4, 2), berm)
	b.box(Vector3(-40.5, 2.0, 0), Vector3(2, 4, 82), berm)
	b.box(Vector3(40.5, 2.0, 0), Vector3(2, 4, 82), berm)
	# Central command post: two floors, roof helipad reached by ramps
	b.house(Vector3(0, 0, 0), Vector2(14, 12), 3.4, ["n", "s", "e", "w"], conc)
	b.box(Vector3(0, 3.7, 0), Vector3(16, 0.3, 14), b.painted(Color(0.25, 0.27, 0.25)))
	b.box(Vector3(0, 3.88, 0), Vector3(6, 0.04, 0.6), b.flat(Color(0.95, 0.95, 0.9)), 0, null, false)
	b.box(Vector3(-2, 3.88, 0), Vector3(0.6, 0.04, 4), b.flat(Color(0.95, 0.95, 0.9)), 0, null, false)
	b.box(Vector3(2, 3.88, 0), Vector3(0.6, 0.04, 4), b.flat(Color(0.95, 0.95, 0.9)), 0, null, false)
	b.ramp(Vector3(-15, 0, -5), 2.0, 8.0, 3.7, 90.0, steel)
	b.ramp(Vector3(15, 0, 5), 2.0, 8.0, 3.7, -90.0, steel)
	# Rooftop low walls (cover)
	b.box(Vector3(0, 4.3, -6.9), Vector3(16, 0.9, 0.2), conc)
	b.box(Vector3(0, 4.3, 6.9), Vector3(16, 0.9, 0.2), conc)
	# Bunkers (one per side) and barracks
	for side in [-1.0, 1.0]:
		b.house(Vector3(side * 26, 0, side * 24), Vector2(10, 7), 2.6, ["n", "s"], olive)
		b.house(Vector3(side * -24, 0, side * 22), Vector2(12, 6), 3.0, ["e", "w"] if side > 0 else ["w", "e"], b.painted(Color(0.48, 0.5, 0.4)))
		b.tower(Vector3(side * 34, 0, side * -32), 4.0, 90.0 if side > 0 else -90.0)
	# Trench lines (sandbags) crossing the map
	for c in [[Vector3(-14, 0, -16), 0.0], [Vector3(14, 0, 16), 0.0], [Vector3(-20, 0, 4), 90.0], [Vector3(20, 0, -4), 90.0],
			[Vector3(0, 0, -22), 0.0], [Vector3(0, 0, 22), 0.0], [Vector3(-30, 0, -6), 60.0], [Vector3(30, 0, 6), 60.0]]:
		b.prop(TOON + "SackTrench.gltf", c[0], 0.55, c[1])
	for c in [[Vector3(-8, 0, -12), 3.0, 0.0], [Vector3(8, 0, 12), 3.0, 0.0], [Vector3(-26, 0, -14), 4.0, 30.0], [Vector3(26, 0, 14), 4.0, 30.0]]:
		b.cover(c[0], c[1], c[2])
	# Barriers, tank, water tower, broken vehicles
	for i in 4:
		b.prop(TOON + "Barrier_Large.gltf", Vector3(-6 + i * 4, 0, -30), 0.3, 0)
		b.prop(TOON + "Barrier_Large.gltf", Vector3(-6 + i * 4, 0, 30), 0.3, 0)
	b.prop(TOON + "Tank.gltf", Vector3(-12, 0, 12), 2.2, 35)
	b.prop(TOON + "WaterTank_Platform.gltf", Vector3(16, 0, -18), 1.0, 0)
	b.prop(TOON + "Debris_BrokenCar.gltf", Vector3(-30, 0, 18), 1.3, 80)
	b.prop(VEH + "truck.glb", Vector3(12, 0, -10), 1.45, 20)
	b.prop(SURV + "tent.glb", Vector3(30, 0, -18), 6.0, 90)
	b.prop(SURV + "tent.glb", Vector3(-30, 0, 30), 6.0, 0)
	for p in [Vector3(6, 0.1, -16), Vector3(-6, 0.1, 16), Vector3(-22, 0.1, -24), Vector3(22, 0.1, 24), Vector3(-34, 0.1, 0), Vector3(34, 0.1, 0)]:
		PhysicsProp.spawn(self, "barrel", p)
	for p in [Vector3(-10, 0.1, -4), Vector3(10, 0.1, 4), Vector3(-2, 0.1, 30), Vector3(2, 0.1, -30)]:
		PhysicsProp.spawn(self, "crate", p, b.rng.randf() * TAU)
	PhysicsProp.spawn(self, "gas_tank", Vector3(18, 0.1, -14))
	# Hills in the distance
	for i in 10:
		var a := TAU * i / 10.0
		b.prop(SURV + ["rock-a.glb", "rock-b.glb", "rock-c.glb"][i % 3], Vector3(cos(a) * 62, -1, sin(a) * 62), 26.0, i * 37.0, false)
	for i in 16:
		var a2 := TAU * i / 16.0 + 0.2
		b.tree(SURV + "tree-tall.glb", Vector3(cos(a2) * 50, 0, sin(a2) * 50), 7.0)
	# Spawns: A = west corner, B = east corner
	for i in 6:
		var o := -12.0 + i * 5.0
		spawns_a.append(facing(Vector3(-35, 0.2, o), Vector3.ZERO))
		spawns_b.append(facing(Vector3(35, 0.2, -o), Vector3.ZERO))
	for p in [Vector3(-34, 0.2, -34), Vector3(34, 0.2, 34), Vector3(-34, 0.2, 34), Vector3(34, 0.2, -34), Vector3(0, 0.3, 0),
			Vector3(0, 0.2, -34), Vector3(0, 0.2, 34), Vector3(-26, 0.3, -24), Vector3(26, 0.3, 24), Vector3(-24, 0.3, 22), Vector3(24, 0.3, -22)]:
		spawns_ffa.append(facing(p, Vector3.ZERO))
	for x in range(-35, 36, 10):
		for z in range(-35, 36, 10):
			patrol_points.append(Vector3(x, 0, z))
	pois = [{"name": "Command Post", "pos": Vector3.ZERO}, {"name": "West Bunker", "pos": Vector3(-26, 0, -24)}, {"name": "East Bunker", "pos": Vector3(26, 0, 24)}]
	bake_navigation(false)
