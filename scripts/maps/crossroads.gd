extends GameMap
## "Crossroads" — urban intersection with enterable shops, parked cars and side alleys (approx. 84 x 84 m).

const CITY := "res://assets/maps/city/"
const SURV := "res://assets/maps/survival/"
const VEH := "res://assets/vehicles/"


func build() -> void:
	map_name = "Crossroads"
	bounds = Rect2(-42, -42, 84, 84)
	MapBuilder.environment(self, Vector3(-40, 60, 0), 0.004)
	b.ground(Vector2(150, 150), b.concrete())
	var asphalt := b.flat(Color(0.18, 0.18, 0.2))
	var line := b.flat(Color(0.9, 0.85, 0.5))
	# Roads (thin slabs slightly above ground)
	b.box(Vector3(0, 0.02, 0), Vector3(84, 0.04, 12), asphalt, 0, null, false)
	b.box(Vector3(0, 0.02, 0), Vector3(12, 0.04, 84), asphalt, 0, null, false)
	for i in range(-38, 39, 6):
		if absi(i) > 7:
			b.box(Vector3(i, 0.045, 0), Vector3(2.5, 0.01, 0.2), line, 0, null, false)
			b.box(Vector3(0, 0.045, i), Vector3(0.2, 0.01, 2.5), line, 0, null, false)
	# Map border
	var wall := b.painted(Color(0.5, 0.48, 0.46))
	b.box(Vector3(0, 3, -42.5), Vector3(86, 6, 1), wall)
	b.box(Vector3(0, 3, 42.5), Vector3(86, 6, 1), wall)
	b.box(Vector3(-42.5, 3, 0), Vector3(1, 6, 86), wall)
	b.box(Vector3(42.5, 3, 0), Vector3(1, 6, 86), wall)
	# Four corner blocks, each with one enterable shop and solid buildings behind it
	var colors := [Color(0.75, 0.62, 0.5), Color(0.6, 0.66, 0.72), Color(0.72, 0.7, 0.55), Color(0.65, 0.55, 0.6)]
	var names := ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-e"]
	var q := 0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := Vector3(sx * 20, 0, sz * 20)
			var doors := ["n" if sz > 0 else "s", "e" if sx < 0 else "w"]
			b.house(c, Vector2(12, 10), 3.6, doors, b.painted(colors[q]))
			b.prop(CITY + "detail-awning.glb", c + Vector3(-sx * 3.0, 2.2, sz * 5.3), 7.0, 0 if sz > 0 else 180, false)
			b.prop(CITY + names[q] + ".glb", Vector3(sx * 35, 0, sz * 12), 9.0, 90 * -sx, true, 0.95)
			b.prop(CITY + names[q + 4] + ".glb", Vector3(sx * 12, 0, sz * 35), 9.0, 0 if sz > 0 else 180, true, 0.95)
			b.prop(SURV + "box-large.glb", c + Vector3(-sx * 9, 0, -sz * 2), 4.0, 15)
			b.cover(c + Vector3(-sx * 10, 0, -sz * 10), 3.0, 45.0 * sx * sz)
			q += 1
	# Corner skyscrapers (solid)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.prop(CITY + "building-skyscraper-a.glb", Vector3(sx * 36, 0, sz * 36), 7.0, 0, true, 0.95)
	# Cars on the roads = mid-map cover
	b.prop(VEH + "sedan.glb", Vector3(-14, 0, 2.5), 1.45, 90)
	b.prop(VEH + "suv.glb", Vector3(15, 0, -3), 1.45, -90)
	b.prop(VEH + "police.glb", Vector3(3, 0, 4), 1.45, 30)
	b.prop(VEH + "van.glb", Vector3(-3, 0, -15), 1.45, 0)
	b.prop(VEH + "truck.glb", Vector3(2.5, 0, 17), 1.45, 180)
	b.prop(VEH + "delivery.glb", Vector3(-26, 0, -3), 1.45, 90)
	b.prop(VEH + "sedan.glb", Vector3(28, 0, 3), 1.45, -90)
	for p in [Vector3(-6, 0, 6.5), Vector3(6, 0, -6.5), Vector3(-6.5, 0, -6), Vector3(6.5, 0, 6)]:
		b.prop(VEH + "cone.glb", p, 1.6, 0, false)
	for p in [Vector3(-8, 0, -30), Vector3(8, 0, 30), Vector3(-30, 0, 8), Vector3(30, 0, -8)]:
		b.cover(p, 4.0, 0.0 if absf(p.x) < 10 else 90.0)
		b.prop(SURV + "barrel.glb", p + Vector3(1.5, 0, 1.5), 3.2, 0)

	for i in 6:
		var x := -10.0 + i * 4.0
		spawns_a.append(facing(Vector3(x, 0.2, -38), Vector3(x * 0.2, 0, 0)))
		spawns_b.append(facing(Vector3(-x, 0.2, 38), Vector3(-x * 0.2, 0, 0)))
	for p in [Vector3(-38, 0.2, -38 + 10), Vector3(38, 0.2, 28), Vector3(-38, 0.2, 28), Vector3(38, 0.2, -28), Vector3(-20, 0.3, -20),
			Vector3(20, 0.3, 20), Vector3(-20, 0.3, 20), Vector3(20, 0.3, -20), Vector3(0, 0.2, -38), Vector3(0, 0.2, 38), Vector3(-38, 0.2, 0), Vector3(38, 0.2, 0)]:
		spawns_ffa.append(facing(p, Vector3.ZERO))
	for x in range(-36, 37, 9):
		for z in range(-36, 37, 9):
			patrol_points.append(Vector3(x, 0, z))
	pois = [{"name": "Intersection", "pos": Vector3.ZERO}]
	bake_navigation(false)
