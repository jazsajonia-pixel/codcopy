extends GameMap
## "Dockyard" — shipping-container port for TDM / Domination / Hardpoint (approx. 96 x 70 m).
## Three lanes: the quay (west, long sightlines), the container maze (centre) and the warehouse (east).

const CITY := "res://assets/maps/city/"
const SURV := "res://assets/maps/survival/"
const TOON := "res://assets/props/toon/"
const VEH := "res://assets/vehicles/"


func build() -> void:
	map_name = "Dockyard"
	bounds = Rect2(-48, -35, 96, 70)
	MapBuilder.environment(self, Vector3(-38, 140, 0), 0.0045)
	b.ground(Vector2(170, 150), b.concrete())
	var wall := b.painted(Color(0.42, 0.45, 0.48))
	var yellow := b.flat(Color(0.95, 0.78, 0.15))
	# Perimeter: fence walls north/south/east, sea wall west (water beyond)
	b.box(Vector3(0, 2.5, -35.5), Vector3(98, 5, 1), wall)
	b.box(Vector3(0, 2.5, 35.5), Vector3(98, 5, 1), wall)
	b.box(Vector3(48.5, 2.5, 0), Vector3(1, 5, 72), wall)
	b.box(Vector3(-48.5, 0.6, 0), Vector3(1, 1.2, 72), b.painted(Color(0.6, 0.6, 0.58)))
	b.blocker(Vector3(-49, 10, 0), Vector3(1, 20, 72))
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 160)
	sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.1, 0.3, 0.42)
	sm.roughness = 0.1
	sea.material_override = sm
	sea.position = Vector3(-90, -0.8, 0)
	add_child(sea)
	# Quay edge markings + bollards
	b.box(Vector3(-46, 0.03, 0), Vector3(0.4, 0.02, 70), yellow, 0, null, false)
	for z in range(-30, 31, 10):
		b.box(Vector3(-47, 0.4, z), Vector3(0.6, 0.8, 0.6), b.painted(Color(0.2, 0.2, 0.22)))
	# Gantry crane over the quay (walkable deck = power position)
	var crane := b.painted(Color(0.85, 0.35, 0.12))
	for z in [-10.0, 10.0]:
		for x in [-44.0, -34.0]:
			b.box(Vector3(x, 4.5, z), Vector3(0.8, 9, 0.8), crane)
	b.box(Vector3(-39, 9.2, 0), Vector3(12, 0.5, 22), crane)
	b.box(Vector3(-39, 9.9, -10.8), Vector3(12, 0.9, 0.2), crane)
	b.box(Vector3(-39, 9.9, 10.8), Vector3(12, 0.9, 0.2), crane)
	b.ramp(Vector3(-28, 0, 4), 2.0, 18.0, 9.2, -90.0, crane)
	# Container maze (centre): rows with gaps for flanks
	var cc := [Color(0.2, 0.35, 0.55), Color(0.6, 0.2, 0.15), Color(0.25, 0.45, 0.25), Color(0.75, 0.45, 0.12), Color(0.5, 0.5, 0.52)]
	var k := 0
	for row in [-22.0, -11.0, 0.0, 11.0, 22.0]:
		for col in [-16.0, -4.0, 8.0]:
			if (int(row) + int(col)) % 3 == 0:
				continue   # gaps
			b.container(Vector3(col + (2.0 if int(row) % 2 == 0 else -2.0), 0, row), 0.0, cc[k % cc.size()], k % 3 == 0)
			k += 1
	b.container(Vector3(-22, 0, -5), 90.0, cc[1])
	b.container(Vector3(14, 0, 5), 90.0, cc[3])
	# Toon containers and props for extra variety
	b.prop(TOON + "Container_Long.gltf", Vector3(-24, 0, 26), 0.85, 0)
	b.prop(TOON + "Container_Small.gltf", Vector3(-26, 0, -27), 0.85, 0)
	b.prop(TOON + "Container_Small.gltf", Vector3(20, 0, -28), 0.85, 90)
	# Warehouse (east) with two entrances and a loading bay
	b.house(Vector3(34, 0, 0), Vector2(18, 26), 6.0, ["w", "n", "s"], b.painted(Color(0.58, 0.55, 0.5)))
	b.tower(Vector3(38, 0, -8), 3.2, 180)
	b.cover(Vector3(30, 0, 6), 3.0, 0)
	b.cover(Vector3(30, 0, -4), 3.0, 90)
	for i in 3:
		b.prop(TOON + "Pallet.gltf", Vector3(28 + i * 3.0, 0, 10), 0.14, 90)
	# Cover on the quay
	for c in [[Vector3(-36, 0, -24), 4.0, 0.0], [Vector3(-36, 0, 24), 4.0, 0.0], [Vector3(-30, 0, -14), 3.0, 90.0], [Vector3(-30, 0, 14), 3.0, 90.0]]:
		b.cover(c[0], c[1], c[2])
	b.prop(VEH + "truck.glb", Vector3(22, 0, 26), 1.45, 90)
	b.prop(VEH + "van.glb", Vector3(22, 0, -24), 1.45, -90)
	for i in 6:
		b.prop(TOON + "StreetLight.gltf", Vector3(-20 + i * 12, 0, 33), 0.5, 180, false)
	# Physics props (dynamic cover / explosive barrels)
	for p in [Vector3(-28, 0.1, -20), Vector3(-10, 0.1, 6), Vector3(4, 0.1, -6), Vector3(26, 0.1, 14), Vector3(-34, 0.1, 30)]:
		PhysicsProp.spawn(self, "barrel", p)
	for p in [Vector3(-12, 0.1, -16), Vector3(16, 0.1, 18), Vector3(36, 0.1, 8), Vector3(-26, 0.1, 6)]:
		PhysicsProp.spawn(self, "crate", p, b.rng.randf() * TAU)
	PhysicsProp.spawn(self, "boxes", Vector3(40, 0.1, -2))
	# Backdrop
	for i in 7:
		b.prop(CITY + ["building-a", "building-c", "building-e", "building-g"][i % 4] + ".glb", Vector3(-36 + i * 13, 0, -46), 9.0, 180, false)
		b.prop(CITY + ["building-b", "building-d", "building-f", "building-h"][i % 4] + ".glb", Vector3(-36 + i * 13, 0, 46), 9.0, 0, false)
	# Spawns: A = quay (west), B = warehouse yard (east)
	for i in 6:
		var z := -15.0 + i * 6.0
		spawns_a.append(facing(Vector3(-42, 0.2, z), Vector3(0, 0, z * 0.4)))
		spawns_b.append(facing(Vector3(44, 0.2, -z), Vector3(0, 0, -z * 0.4)))
	for p in [Vector3(-40, 0.2, -30), Vector3(-40, 0.2, 30), Vector3(44, 0.2, -30), Vector3(44, 0.2, 30), Vector3(0, 0.2, -31),
			Vector3(0, 0.2, 31), Vector3(-22, 0.2, 16), Vector3(20, 0.2, -16), Vector3(34, 0.3, 0), Vector3(-10, 0.2, -28), Vector3(10, 0.2, 28)]:
		spawns_ffa.append(facing(p, Vector3.ZERO))
	for x in range(-42, 43, 10):
		for z in range(-30, 31, 10):
			patrol_points.append(Vector3(x, 0, z))
	pois = [{"name": "Quay", "pos": Vector3(-38, 0, 0)}, {"name": "Containers", "pos": Vector3(-2, 0, 0)}, {"name": "Warehouse", "pos": Vector3(34, 0, 0)}]
	bake_navigation(false)
