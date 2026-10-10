extends GameMap
## "Outpost" — 3-lane desert compound for Team Deathmatch / FFA (approx. 92 x 72 m playable).

const CITY := "res://assets/maps/city/"
const SURV := "res://assets/maps/survival/"
const VEH := "res://assets/vehicles/"


func build() -> void:
	map_name = "Outpost"
	bounds = Rect2(-46, -36, 92, 72)
	MapBuilder.environment(self, Vector3(-52, -30, 0), 0.0035)
	b.ground(Vector2(160, 140), b.dirt())
	var wall := b.painted(Color(0.78, 0.72, 0.6))
	var dark := b.painted(Color(0.55, 0.5, 0.42))
	# Perimeter walls
	b.box(Vector3(0, 2.5, -36.5), Vector3(94, 5, 1), wall)
	b.box(Vector3(0, 2.5, 36.5), Vector3(94, 5, 1), wall)
	b.box(Vector3(-46.5, 2.5, 0), Vector3(1, 5, 74), wall)
	b.box(Vector3(46.5, 2.5, 0), Vector3(1, 5, 74), wall)

	# Center compound with 4 entrances
	b.house(Vector3(0, 0, 0), Vector2(14, 10), 3.4, ["n", "s", "e", "w"], wall)
	b.cover(Vector3(0, 0, 0), 3.0, 90.0)
	b.prop(SURV + "box-large.glb", Vector3(-4.5, 0.1, -2.5), 4.0, 0)
	b.prop(SURV + "barrel.glb", Vector3(4.6, 0.1, 3.0), 3.2, 0)
	# North / south buildings
	b.house(Vector3(0, 0, -25), Vector2(12, 7), 3.2, ["s", "e", "w"], dark)
	b.house(Vector3(0, 0, 25), Vector2(12, 7), 3.2, ["n", "e", "w"], dark)
	# Mid-lane containers and cover
	b.container(Vector3(-17, 0, -12), 0, Color(0.2, 0.35, 0.55))
	b.container(Vector3(17, 0, 12), 0, Color(0.6, 0.2, 0.15))
	b.container(Vector3(-17, 0, 14), 90, Color(0.25, 0.45, 0.25), true)
	b.container(Vector3(17, 0, -14), 90, Color(0.75, 0.45, 0.12), true)
	for c in [[Vector3(-28, 0, 0), 4.0, 90.0], [Vector3(28, 0, 0), 4.0, 90.0], [Vector3(-10, 0, -14), 3.0, 0.0],
			[Vector3(10, 0, 14), 3.0, 0.0], [Vector3(-10, 0, 15), 3.0, 0.0], [Vector3(10, 0, -15), 3.0, 0.0],
			[Vector3(-30, 0, -20), 3.5, 30.0], [Vector3(30, 0, 20), 3.5, 30.0], [Vector3(-30, 0, 22), 3.5, -30.0], [Vector3(30, 0, -22), 3.5, -30.0]]:
		b.cover(c[0], c[1], c[2])
	b.tower(Vector3(-36, 0, -27), 3.4, 90)
	b.tower(Vector3(36, 0, 27), 3.4, -90)
	# Vehicles & props as cover
	b.prop(VEH + "suv.glb", Vector3(-24, 0, 26), 1.45, 35)
	b.prop(VEH + "truck.glb", Vector3(24, 0, -26), 1.45, -20)
	b.prop(VEH + "van.glb", Vector3(-6, 0, -31), 1.45, 90)
	b.prop(VEH + "sedan.glb", Vector3(7, 0, 31), 1.45, 80)
	for p in [Vector3(-22, 0, -4), Vector3(22, 0, 4), Vector3(-12, 0, 26), Vector3(12, 0, -26), Vector3(-38, 0, 10), Vector3(38, 0, -10)]:
		b.prop(SURV + "box-large.glb", p, 4.0, b.rng.randf_range(0, 90))
	for p in [Vector3(-21, 0, -2.5), Vector3(21, 0, 2.5), Vector3(-7, 0, 20), Vector3(7, 0, -20), Vector3(-40, 0, -14), Vector3(40, 0, 14)]:
		b.prop(SURV + "barrel.glb", p, 3.2, 0)
	# Backdrop city outside the walls (no collision needed, culled at range)
	var names := ["building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g", "building-h"]
	for i in 9:
		b.prop(CITY + names[i % names.size()] + ".glb", Vector3(-48 + i * 12, 0, -45), 9.0, 180, false)
		b.prop(CITY + names[(i + 3) % names.size()] + ".glb", Vector3(-48 + i * 12, 0, 45), 9.0, 0, false)
	for z in [-24, 0, 24]:
		b.prop(CITY + "building-skyscraper-a.glb", Vector3(-58, 0, z), 9.0, 90, false)
		b.prop(CITY + "building-skyscraper-b.glb", Vector3(58, 0, z), 9.0, -90, false)

	# Spawns
	for i in 6:
		var za := -12.0 + i * 4.8
		spawns_a.append(facing(Vector3(-41, 0.2, za), Vector3(0, 0, za * 0.3)))
		spawns_b.append(facing(Vector3(41, 0.2, -za), Vector3(0, 0, -za * 0.3)))
	for p in [Vector3(-38, 0.2, -30), Vector3(38, 0.2, 30), Vector3(-38, 0.2, 30), Vector3(38, 0.2, -30), Vector3(0, 0.2, -31),
			Vector3(0, 0.2, 31), Vector3(-25, 0.2, 0), Vector3(25, 0.2, 0), Vector3(0, 0.3, 0), Vector3(-12, 0.2, -24), Vector3(12, 0.2, 24), Vector3(-42, 0.2, 0), Vector3(42, 0.2, 0)]:
		spawns_ffa.append(facing(p, Vector3.ZERO))
	for x in range(-40, 41, 10):
		for z in range(-30, 31, 10):
			patrol_points.append(Vector3(x, 0, z))
	pois = [{"name": "Compound", "pos": Vector3.ZERO}, {"name": "North Hall", "pos": Vector3(0, 0, -25)}, {"name": "South Hall", "pos": Vector3(0, 0, 25)}]
	bake_navigation(false)
