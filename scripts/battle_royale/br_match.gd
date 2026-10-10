extends MatchBase
## Battle Royale: boarding -> plane flight -> freefall/parachute -> loot & fight -> shrinking zone -> last one standing.
## All opponents are AI bots (offline). Uses the same Actor/Inventory/Weapon systems as Multiplayer.

enum Phase { BOARDING, PLANE, ACTIVE, OVER }

const PLANE_HEIGHT := 160.0
const PLANE_SPEED := 16.0
const CHUTE_AUTO_AGL := 70.0

var phase := Phase.BOARDING
var boarding := 6.0
var zone := SafeZone.new()
var zone_wall: MeshInstance3D
var zone_mat: StandardMaterial3D
var plane: Node3D
var plane_from := Vector3.ZERO
var plane_to := Vector3.ZERO
var plane_t := 0.0
var plane_len := 1.0
var bot_drop_t := {}     ## Bot -> plane progress (0..1) at which it jumps
var player_dropped := false
var chute_mesh: Node3D
var placement := 0
var end_timer := -1.0
var zone_tick := 0.0
var time_scale := 1.0
var _isla: GameMap


func _ready() -> void:
	super._ready()
	time_scale = 0.35 if MatchConfig.fast_test else 1.0
	boarding = 6.0 * time_scale
	load_map("res://scenes/maps/isla.tscn")
	_isla = map
	map.bake_navigation(true)
	spawn_player(0)
	player.regen_enabled = false
	player.inv.use_ammo_pools = true
	player.inv.lethal = ""
	player.inv.tactical = ""
	player.inv.melee = SaveManager.current_loadout().get("melee", "knife")
	player.equip_current()
	var n := MatchConfig.br_players
	for i in n - 1:
		var b := spawn_bot(i + 1)
		b.br_mode = true
		b.regen_enabled = false
		b.inv.use_ammo_pools = true
		b.inv.lethal = ""
		b.inv.tactical = ""
		b.set_physics_process(false)
		b.visible = false
	player.team = 0
	_spawn_loot()
	_build_zone()
	_build_plane()
	_build_chute()
	zone.land_check = func(p: Vector2): return _isla.height(p.x, p.y) > 1.0
	zone.setup(Vector2.ZERO, 190.0, time_scale, rng.randi())
	zone.phase_changed.connect(_on_zone_phase)
	player.allow_input = false
	var fdir := plane_to - plane_from
	player.yaw = atan2(-fdir.x, -fdir.z)
	player.pitch = deg_to_rad(-12.0)
	player.global_position = plane_from + Vector3.UP * 6.0
	announcement.emit("BATTLE ROYALE", "%d operators. Last one standing wins." % n)
	AudioManager.play_2d("res://assets/audio/ambience/wind.ogg", -14.0)


# ---------------- Setup ----------------

func _spawn_loot() -> void:
	var weapons := GameDB.weapons.keys()
	var weights := {"weapon": 34, "ammo": 24, "armor": 9, "heal": 17, "plate": 9, "grenade": 7}
	var i := 0
	for p in map.loot_points:
		i += 1
		if rng.randf() > 0.82 and i % 2 == 0:
			continue
		var kind := _weighted(weights)
		if i % 2 == 1:
			kind = "weapon"   # every house pair guarantees at least one weapon
		var l: LootItem
		match kind:
			"weapon":
				l = LootItem.make("weapon", weapons[rng.randi() % weapons.size()])
				if rng.randf() < 0.3:
					l.weapon_attachments = {"optic": "red_dot"}
			"ammo":
				var t: String = ["ammo_rifle", "ammo_smg", "ammo_shotgun", "ammo_sniper", "ammo_pistol"][rng.randi() % 5]
				l = LootItem.make("ammo", t, GameDB.BR_ITEMS[t].amount)
			"armor":
				l = LootItem.make("armor", ["armor_1", "armor_1", "armor_2", "armor_2", "armor_3"][rng.randi() % 5])
			"heal":
				l = LootItem.make("heal", "medkit" if rng.randf() < 0.4 else "bandage", 1 if rng.randf() < 0.6 else 2)
			"plate":
				l = LootItem.make("plate", "plate", 1)
			_:
				l = LootItem.make("grenade", "frag" if rng.randf() < 0.6 else "smoke")
		add_child(l)
		l.global_position = p
		# Pair each weapon with matching ammo next to it.
		if kind == "weapon":
			var w := GameDB.get_weapon(l.item_id)
			var ammo_id := "ammo_" + w.ammo_type
			var la := LootItem.make("ammo", ammo_id, GameDB.BR_ITEMS[ammo_id].amount)
			add_child(la)
			la.global_position = p + Vector3(0.9, 0, 0.4)
	for c in map.crate_points:
		var crate := SupplyCrate.new()
		var best: String = ["ar_k47", "lmg_rpv", "sniper_ls7", "dmr_skr", "sg_tempest", "smg_kr"][rng.randi() % 6]
		crate.contents = [["weapon", best, 1, {"optic": "holo" if best != "sniper_ls7" else "scope_8x", "magazine": "extended_mag"}],
			["armor", "armor_3", 1], ["heal", "medkit", 2], ["plate", "plate", 2], ["ammo", "ammo_" + GameDB.get_weapon(best).ammo_type, 60]]
		add_child(crate)
		crate.global_position = c


func _weighted(w: Dictionary) -> String:
	var total := 0
	for k in w.keys():
		total += w[k]
	var r := rng.randi() % total
	for k in w.keys():
		r -= w[k]
		if r < 0:
			return k
	return w.keys()[0]


func _build_zone() -> void:
	zone_wall = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 64
	cm.rings = 1
	zone_wall.mesh = cm
	zone_mat = StandardMaterial3D.new()
	zone_mat.albedo_color = Color(0.25, 0.55, 1.0, 0.22)
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	zone_wall.material_override = zone_mat
	zone_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(zone_wall)


func _build_plane() -> void:
	plane = Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.5, 0.42)
	for part in [[Vector3(0, 0, 0), Vector3(3.2, 3.2, 22)], [Vector3(0, 0.6, -1), Vector3(30, 0.4, 4)], [Vector3(0, 2.4, 9.5), Vector3(0.4, 4, 3)], [Vector3(0, 1.0, 9.5), Vector3(9, 0.3, 2.4)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		mi.mesh = bm
		mi.material_override = m
		mi.position = part[0]
		plane.add_child(mi)
	add_child(plane)
	var a := rng.randf() * TAU
	plane_from = Vector3(cos(a) * 210.0, PLANE_HEIGHT, sin(a) * 210.0)
	var off := rng.randf_range(-60, 60)
	var perp := Vector3(-sin(a), 0, cos(a)) * off
	plane_to = -plane_from + perp * 2.0
	plane_to.y = PLANE_HEIGHT
	plane_from += perp * 0.0
	plane_len = plane_from.distance_to(plane_to)
	plane.global_position = plane_from
	plane.look_at(plane_to, Vector3.UP)
	# Each bot picks a drop moment; most aim near a POI close to the flight path.
	for b in bots:
		bot_drop_t[b] = clampf(rng.randf_range(0.12, 0.88), 0.0, 1.0)


func _build_chute() -> void:
	chute_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.6
	sm.height = 2.0
	sm.is_hemisphere = true
	(chute_mesh as MeshInstance3D).mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.55, 0.15)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	(chute_mesh as MeshInstance3D).material_override = m
	chute_mesh.position = Vector3(0, 4.2, 0)
	chute_mesh.visible = false
	player.add_child(chute_mesh)


# ---------------- Loop ----------------

func _process(delta: float) -> void:
	super._process(delta)
	_update_zone_visual()
	match phase:
		Phase.BOARDING:
			boarding -= delta
			player.global_position = plane_from - (plane_to - plane_from).normalized() * 18.0 + Vector3.UP * 6.0
			player.velocity = Vector3.ZERO
			if boarding <= 0.0:
				phase = Phase.PLANE
				announcement.emit("JUMP WHEN READY", "Press JUMP to leave the aircraft")
		Phase.PLANE:
			_tick_plane(delta)
		Phase.ACTIVE:
			_tick_active(delta)
		Phase.OVER:
			end_timer -= delta
			if end_timer <= 0.0:
				end_timer = 999.0
				_finish()


func _physics_process(_delta: float) -> void:
	if phase == Phase.PLANE and not player_dropped:
		# Keep the player riding the plane; allow looking around and jump to drop.
		# Ride behind and above the aircraft so it stays in view.
		player.global_position = plane.global_position - plane.global_transform.basis.z * -18.0 + Vector3.UP * 6.0
		player.velocity = Vector3.ZERO
		player.parachute_state = 0


func _tick_plane(delta: float) -> void:
	plane_t += delta * PLANE_SPEED / plane_len / time_scale * (1.0 if not MatchConfig.fast_test else 1.0)
	plane.global_position = plane_from.lerp(plane_to, minf(plane_t, 1.0))
	if not player_dropped:
		player.allow_input = true
		var wants_jump := player.jump_recent() or (MatchConfig.autoplay_player and plane_t > 0.35)
		if wants_jump or plane_t >= 0.97:
			_drop_player()
	for b in bots:
		if not b.visible and plane_t >= bot_drop_t[b]:
			_drop_bot(b)
	if plane_t >= 1.0:
		for b in bots:
			if not b.visible:
				_drop_bot(b)
		if not player_dropped:
			_drop_player()
		plane.visible = false
		phase = Phase.ACTIVE
		announcement.emit("ZONE ACTIVE", zone.status())


func _drop_player() -> void:
	player_dropped = true
	player.consume_jump()
	player.global_position = plane.global_position + Vector3.DOWN * 4.0
	player.parachute_state = 1
	player.velocity = Vector3.ZERO
	player.allow_input = true
	AudioManager.play_2d("res://assets/audio/ambience/wind.ogg", -6.0)


func _drop_bot(b: Bot) -> void:
	b.visible = true
	b.global_position = plane.global_position + Vector3(rng.randf_range(-3, 3), -4, rng.randf_range(-3, 3))
	b.parachute = true
	# Head to the nearest POI (with spread) from the drop point.
	var best: Dictionary = map.pois[0]
	var bd := INF
	for poi in map.pois:
		var d := Vector2(poi.pos.x - b.global_position.x, poi.pos.z - b.global_position.z).length() + rng.randf_range(0, 120)
		if d < bd:
			bd = d
			best = poi
	b.drop_target = best.pos + Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
	b.set_physics_process(true)


func _tick_active(delta: float) -> void:
	zone.tick(delta)
	if not player_dropped:
		_drop_player()
	_update_player_chute()
	zone_tick -= delta
	if zone_tick <= 0.0:
		zone_tick = 1.0
		for a in actors:
			if a.alive and a.visible and not a.parachute_active() and zone.is_outside(Vector2(a.global_position.x, a.global_position.z)):
				a.take_damage(zone.dps(), null, "Zone")
				if a == player:
					AudioManager.play_2d("res://assets/audio/sfx/zone_warning.ogg", -10.0)
	if phase == Phase.ACTIVE:
		var alive := alive_count()
		if not player.alive:
			_game_over(false)
		elif alive <= 1:
			_game_over(true)


func _update_player_chute() -> void:
	if player.parachute_state == 0:
		chute_mesh.visible = false
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3.DOWN * 300.0, 1)
	var hit := space.intersect_ray(q)
	var agl: float = player.global_position.y - (hit.position.y if not hit.is_empty() else 0.0)
	if player.parachute_state == 1:
		if agl < CHUTE_AUTO_AGL or (player.jump_recent() and agl < PLANE_HEIGHT - 20.0):
			player.parachute_state = 2
			AudioManager.play_2d("res://assets/audio/sfx/land.ogg", -2.0, 0.6)
	chute_mesh.visible = player.parachute_state == 2


func _update_zone_visual() -> void:
	zone_wall.visible = phase == Phase.ACTIVE and player.parachute_state != 1
	zone_wall.global_position = Vector3(zone.center.x, 40.0, zone.center.y)
	zone_wall.scale = Vector3(maxf(zone.radius, 0.1), 160.0, maxf(zone.radius, 0.1))
	var outside := zone.is_outside(Vector2(player.global_position.x, player.global_position.z))
	zone_mat.albedo_color = Color(1.0, 0.3, 0.2, 0.3) if outside else Color(0.25, 0.55, 1.0, 0.22)


func _on_zone_phase(index: int, shrinking: bool) -> void:
	if shrinking:
		announcement.emit("ZONE CLOSING", "Move to the safe area")
	elif not zone.done:
		announcement.emit("ZONE %d" % (index + 1), "Next circle marked on the map")
	AudioManager.play_2d("res://assets/audio/sfx/zone_warning.ogg", -6.0)


func on_kill(victim: Actor, _killer: Actor) -> void:
	# Death box: drop the victim's weapons and some supplies.
	var i := 0
	for w in victim.inv.weapons:
		if w:
			var l := LootItem.make("weapon", w.id())
			l.weapon_attachments = w.attachments
			add_child(l)
			l.global_position = victim.global_position + Vector3(cos(i * 2.1), 0.2, sin(i * 2.1)) * 1.0
			i += 1
	for t in victim.inv.ammo.keys():
		if victim.inv.ammo[t] > 0:
			var la := LootItem.make("ammo", "ammo_" + t, victim.inv.ammo[t])
			add_child(la)
			la.global_position = victim.global_position + Vector3(cos(i * 2.1), 0.2, sin(i * 2.1)) * 1.2
			i += 1
	if victim.inv.heals.get("medkit", 0) > 0:
		var lh := LootItem.make("heal", "medkit", victim.inv.heals.medkit)
		add_child(lh)
		lh.global_position = victim.global_position + Vector3(0, 0.2, -1.3)
	if victim == player:
		placement = alive_count() + 1
	# Bodies disappear after a while to keep the scene light.
	if victim is Bot:
		get_tree().create_timer(8.0, false).timeout.connect(func(): if is_instance_valid(victim) and not victim.alive: victim.visible = false)


func _game_over(won: bool) -> void:
	phase = Phase.OVER
	ended = true
	end_timer = 4.0 * (0.5 if MatchConfig.fast_test else 1.0)
	if won:
		placement = 1
		announcement.emit("VICTORY", "Last operator standing")
	else:
		if placement == 0:
			placement = alive_count() + 1
		announcement.emit("ELIMINATED", "You placed #%d of %d" % [placement, actors.size()])
	player.allow_input = false


func _finish() -> void:
	var res := player_stats()
	res.merge({"mode": "br", "map": "isla", "won": placement == 1, "placement": placement, "players": actors.size(),
		"scoreboard": scoreboard(), "duration": elapsed})
	res.score = res.score + maxi(0, (actors.size() - placement) * 40)
	MatchConfig.finish_match(res)


# ---------------- Queries used by bots / HUD ----------------

func alive_count() -> int:
	var n := 0
	for a in actors:
		if a.alive:
			n += 1
	return n


func outside_zone(p: Vector3, margin: float = 1.0) -> bool:
	return zone.is_outside(Vector2(p.x, p.z), margin) or (zone.shrinking and Vector2(p.x, p.z).distance_to(zone.next_center) > zone.next_radius * 1.05 and zone.timer < 10.0)


func zone_target() -> Vector3:
	var c := zone.next_center if zone.shrinking else zone.center
	var r := (zone.next_radius if zone.shrinking else zone.radius) * 0.5
	var p := Vector3(c.x, 0, c.y)
	p.y = _isla.height(p.x, p.z)
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p + Vector3(randf_range(-r, r) * 0.3, 0, randf_range(-r, r) * 0.3))


func random_patrol_point(bot: Bot) -> Vector3:
	# Prefer points inside the current safe zone.
	for i in 8:
		var p := map.random_patrol(rng) + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		if not zone.is_outside(Vector2(p.x, p.z), 0.8):
			return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
	return zone_target()


func zone_info() -> Dictionary:
	var d := {"center": Vector3(zone.center.x, 0, zone.center.y), "radius": zone.radius}
	if not zone.done:
		d.next_center = Vector3(zone.next_center.x, 0, zone.next_center.y)
		d.next_radius = zone.next_radius
	return d


func plane_info() -> Dictionary:
	if phase > Phase.PLANE:
		return {}
	return {"from": plane_from, "to": plane_to, "pos": plane.global_position}


func br_status() -> String:
	var s := "ALIVE %d    KILLS %d" % [alive_count(), player.kills]
	if phase == Phase.BOARDING:
		return s + "    Boarding %ds" % ceili(boarding)
	if phase == Phase.PLANE:
		return s + "    In flight"
	return s + "    " + zone.status()
