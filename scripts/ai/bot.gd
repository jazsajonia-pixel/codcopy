class_name Bot
extends Actor
## Reusable AI soldier for Multiplayer and Battle Royale.
## Perception: distance + field of view + line of sight (+ smoke) + hearing unsuppressed shots.
## Behaviour: patrol -> investigate -> engage (strafe/advance) -> retreat to cover at low HP.
## BR extras: parachute descent, loot seeking, healing, safe-zone awareness.

enum State { PATROL, INVESTIGATE, ENGAGE, RETREAT, LOOT, ZONE, PARACHUTE, HEAL, DOWNED, REVIVE, FOLLOW, MOUNT }

const NAMES := ["Hawk", "Bravo", "Kodiak", "Sable", "Rook", "Mako", "Jinx", "Talon", "Brick", "Dusk",
	"Fang", "Grit", "Havoc", "Ivory", "Jolt", "Karma", "Lotus", "Maverick", "Nomad", "Onyx", "Pike",
	"Quill", "Ronin", "Spectre", "Tusk", "Umbra", "Vandal", "Wraith", "Yeti", "Zulu", "Cinder", "Banshee"]

var state := State.PATROL
var diff := {}
var agent: NavigationAgent3D
var model: ActorModel        ## animated body (also owns gun, wingsuit and parachute visuals)
var gun_holder: Node3D
var chute_inflate := 1.0
var chute_open := false      ## BR drop: false = wingsuit freefall, true = parachute
var name_tag: Label3D
var aim_dir := Vector3.FORWARD
var target: Actor = null
var last_known := Vector3.ZERO
var last_seen_t := 99.0
var reaction_left := 0.0
var aim_error := Vector3.ZERO
var aim_error_t := 0.0
var tracking_t := 0.0
var burst_left := 0.0
var burst_pause := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var think_t := 0.0
var repath_t := 0.0
var move_goal := Vector3.ZERO
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var retreat_t := 0.0
var grenade_t := 6.0
var crouch_t := 0.0
var cur_anim := ""
var match_node: Node = null   ## MP/BR match manager (provides patrol points / zone info)
var br_mode := false
var parachute := false
var drop_target := Vector3.ZERO
var loot_target: Node3D = null
var step_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _ignored_loot := {}
var leader: Actor = null
## Network puppet (LAN matches): AI is off; position/aim come from the network.
var puppet := false
var net: NetSync = null
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_floor := true
var _net_weapon := ""
var _net_has := false          ## squad leader to stay near (the player's AI teammates)
var revive_mate: Actor = null
var _revive_near_t := 0.0     ## time spent close to the downed mate (widens reach if navigation can't get closer)
var mount_vehicle: Vehicle = null


var _last_body_yaw := 0.0

func parachute_active() -> bool:
	return parachute


func setup(p_name: String, p_team: int, p_operator: String, p_diff: Dictionary) -> void:
	actor_name = p_name
	team = p_team
	operator_id = p_operator
	diff = p_diff


func _ready() -> void:
	super._ready()
	_rng.randomize()
	think_t = _rng.randf() * 0.25
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.2
	agent.radius = RADIUS
	agent.height = HEIGHT
	agent.avoidance_enabled = false
	agent.path_max_distance = 4.0
	add_child(agent)
	var op := GameDB.get_operator(operator_id)
	model = ActorModel.new()
	model.name = "Body"
	add_child(model)
	model.setup_operator(op)
	gun_holder = model.gun_holder
	name_tag = Label3D.new()
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = false
	name_tag.font_size = 40
	name_tag.pixel_size = 0.006
	name_tag.outline_size = 8
	name_tag.position.y = 2.15
	name_tag.text = actor_name
	add_child(name_tag)
	_refresh_gun_model()
	inv.changed.connect(_refresh_gun_model)
	_apply_body_quality()
	last_pos = global_position
	if not puppet:
		var ks := GameDB.OPERATOR_SKILLS.keys()
		setup_skill(ks[_rng.randi() % ks.size()])


func _refresh_gun_model() -> void:
	model.set_weapon(inv.active())
	_apply_body_quality()


func _apply_body_quality() -> void:
	model.set_cast_shadows(SaveManager.get_setting("graphics", "effects_quality", 1) >= 1)
	# Distance culling keeps far bots cheap on mobile (the parachute stays visible further).
	model.set_visibility_range(220.0)
	for g in model.chute.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 400.0


func set_tag_style(friendly: bool, visible_to_player: bool) -> void:
	if friendly:
		name_tag.modulate = Color(0.45, 0.75, 1.0)
		name_tag.visible = alive
	else:
		name_tag.modulate = _enemy_color()
		name_tag.visible = alive and visible_to_player


static func _enemy_color() -> Color:
	match SaveManager.get_setting("accessibility", "enemy_color", "red"):
		"orange": return Color(1.0, 0.55, 0.1)
		"magenta": return Color(1.0, 0.2, 0.85)
	return Color(1.0, 0.25, 0.2)


func look_dir() -> Vector3:
	return aim_dir


func muzzle_pos() -> Vector3:
	return gun_holder.global_position + aim_dir * 0.6


# ---------------- Loop ----------------

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_update(delta)
		return
	tick_common(delta)
	if not alive:
		return
	if parachute:
		_parachute(delta)
		return
	if vehicle:
		# Passenger: ride along; leave when the squad leader gets out.
		velocity = Vector3.ZERO
		if leader == null or not is_instance_valid(leader) or leader.vehicle != vehicle:
			vehicle.exit(self)
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.2 + _rng.randf() * 0.08
		_think()
	_update_aim(delta)
	_act(delta)
	_move(delta)
	_animate()


func _think() -> void:
	if downed:
		target = null
		state = State.DOWNED
		return
	_perceive()
	_maybe_skill()
	var w := inv.active()
	# Reviving a downed teammate beats finishing off a downed enemy, trading shots at range,
	# or running from the zone edge (a revive takes only a few seconds).
	var mate := _downed_teammate(40.0)
	if mate:
		revive_mate = mate
		state = State.REVIVE
		return
	if br_mode and match_node and match_node.has_method("outside_zone") and match_node.outside_zone(global_position, 0.85):
		if target == null or health < 50.0:
			state = State.ZONE
			return
	if target:
		if health < max_health * 0.35 and retreat_t <= 0.0 and _rng.randf() < 0.5 + (1.0 - diff.get("aggression", 0.6)) * 0.4:
			state = State.RETREAT
			retreat_t = 3.5
			move_goal = _find_cover(target.global_position)
			return
		if state != State.RETREAT or retreat_t <= 0.0:
			state = State.ENGAGE
		return
	if br_mode and health < 70.0 and inv.best_heal() != "" and using_item == "":
		state = State.HEAL
		start_use(inv.best_heal())
		return
	if br_mode and armor < max_armor and inv.plates > 0 and using_item == "":
		start_use("plate")
	# Squad duties: ride with the leader and stay close to them.
	if leader and is_instance_valid(leader) and leader.alive:
		var lv: Vehicle = leader.vehicle
		if lv and lv.alive and lv.free_passenger_seat() > 0 and global_position.distance_to(lv.global_position) < 30.0:
			mount_vehicle = lv
			state = State.MOUNT
			return
		var ld := global_position.distance_to(leader.global_position)
		if ld > 16.0:
			state = State.FOLLOW
			var off := Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
			move_goal = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, leader.global_position + off)
			return
	if w and w.mag < w.mag_size() * 0.5 and not w.reloading:
		request_reload()
	if br_mode and not (leader and is_instance_valid(leader) and leader.alive and global_position.distance_to(leader.global_position) > 28.0):
		var lt := _find_loot()
		if lt:
			loot_target = lt
			state = State.LOOT
			return
	if last_seen_t < 8.0:
		state = State.INVESTIGATE
		return
	var op: Vector3 = match_node.objective_point(self) if match_node and match_node.has_method("objective_point") else Vector3.ZERO
	if op != Vector3.ZERO:
		if state != State.PATROL or global_position.distance_to(move_goal) < 2.0 or move_goal == Vector3.ZERO \
				or op.distance_to(move_goal) > 8.0:
			state = State.PATROL
			move_goal = op
		return
	if state != State.PATROL or global_position.distance_to(move_goal) < 2.0 or move_goal == Vector3.ZERO:
		state = State.PATROL
		move_goal = _patrol_point()


## Bots use their operator skill when the situation suits it (CODM bots do the same).
func _maybe_skill() -> void:
	if skill == null or not skill.is_ready() or using_item != "":
		return
	var td := global_position.distance_to(target.global_position) if target and is_instance_valid(target) else 999.0
	var go := false
	match skill.id:
		"rewind":
			go = health < max_health * 0.35 and _since_damage < 1.0
		"jetpack":
			go = target != null and td > 10.0 and td < 40.0 and _rng.randf() < 0.12
		"hook":
			go = target != null and td > 16.0 and td < 40.0 and _rng.randf() < 0.15
		"quickslash":
			go = target != null and td < 7.0 and look_dir().dot((target.global_position - global_position).normalized()) > 0.8
	if go:
		var dir := look_dir()
		if skill.id == "hook" and target:
			dir = (target.global_position + Vector3.UP * 0.3 - eye_position()).normalized()
		skill.activate(dir)


func _perceive() -> void:
	var best: Actor = null
	var best_score := INF
	var eye := eye_position()
	var fwd := aim_dir
	var fov_cos := cos(deg_to_rad(diff.get("fov_deg", 115.0) * 0.5))
	var view: float = diff.get("view_dist", 60.0)
	var space := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("actors"):
		var a: Actor = n
		if not a.alive or not a.visible or not is_enemy(a) or a.parachute_active():
			continue
		var to := a.aim_point() - eye
		var dist := to.length()
		if dist > view:
			continue
		var in_fov := fwd.dot(to / dist) > fov_cos or dist < 4.0 or (a == target and last_seen_t < 1.0)
		if not in_fov:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, a.aim_point(), 1)
		var h1 := space.intersect_ray(q)
		if not h1.is_empty() and not (a.vehicle != null and h1.collider == a.vehicle):
			var q2 := PhysicsRayQueryParameters3D.create(eye, a.head_point(), 1)
			if not space.intersect_ray(q2).is_empty():
				continue
		if Effects.blocked_by_smoke(eye, a.aim_point()):
			continue
		var s := dist * (0.5 if a == target else 1.0) * (1.8 if a.downed else 1.0)
		if s < best_score:
			best_score = s
			best = a
	if best:
		if best != target:
			reaction_left = diff.get("reaction", 0.5) * _rng.randf_range(0.8, 1.25) * (1.0 + flash_time)
			tracking_t = 0.0
		target = best
		last_known = best.global_position
		last_seen_t = 0.0
	else:
		if target:
			last_known = target.global_position if target.alive else last_known
		target = null
		last_seen_t += 0.2


## Called by the match when an unsuppressed shot or explosion is heard nearby.
func hear(source: Actor) -> void:
	if target == null and is_enemy(source) and source.alive:
		last_known = source.global_position
		last_seen_t = 0.5
		var to := (source.global_position - global_position)
		to.y = 0
		if to.length() > 0.1:
			aim_dir = aim_dir.slerp(to.normalized(), 0.6).normalized()


func _on_damaged_by(attacker: Actor) -> void:
	if attacker and attacker.alive and target == null:
		last_known = attacker.global_position
		last_seen_t = 0.2
		var to := attacker.global_position - global_position
		to.y = 0
		if to.length() > 0.1:
			aim_dir = to.normalized()


func take_damage(amount: float, attacker: Actor, weapon_name: String = "", headshot: bool = false, from_pos: Vector3 = Vector3.ZERO) -> bool:
	if puppet and net:
		if not alive or invulnerable_time > 0.0 or (attacker and attacker != self and not attacker.is_enemy(self)):
			return false
		if net.is_host():
			return host_apply_damage(amount, attacker, weapon_name, headshot, from_pos)
		# Client: the host owns this actor's health. Report the hit and show local feedback only.
		net.report_hit(self, amount, attacker, weapon_name, headshot, from_pos)
		if attacker and attacker != self:
			attacker.hit_confirmed.emit(headshot, false)
		return false
	var killed := super.take_damage(amount, attacker, weapon_name, headshot, from_pos)
	if not killed:
		_on_damaged_by(attacker)
	return killed


## Host only: apply authoritative damage to a remote player's puppet and tell its owner.
func host_apply_damage(amount: float, attacker: Actor, weapon_name: String, headshot: bool, from_pos: Vector3) -> bool:
	var killed := super.take_damage(amount, attacker, weapon_name, headshot, from_pos)
	if net and not killed:
		net.host_notify_damage(self, from_pos, attacker)
	return killed


func net_apply(pos: Vector3, yaw: float, pitch: float, vel: Vector3, weapon_id: String, height: float, on_floor: bool) -> void:
	_net_pos = pos
	_net_yaw = yaw
	_net_pitch = pitch
	_net_vel = vel
	_net_floor = on_floor
	if not _net_has or global_position.distance_to(pos) > 8.0:
		global_position = pos
	_net_has = true
	if absf(height - current_height) > 0.05:
		set_height(height)
	if weapon_id != _net_weapon and weapon_id != "":
		_net_weapon = weapon_id
		inv.load_from_loadout({"primary": weapon_id, "melee": "knife", "lethal": "frag", "tactical": "smoke"})
		_refresh_gun_model()


func _puppet_update(delta: float) -> void:
	if invulnerable_time > 0.0:
		invulnerable_time -= delta
	if not alive or not _net_has:
		return
	# Host-side health regen for remote players (the host owns their health).
	if net and net.is_host() and regen_enabled:
		_since_damage += delta
		if _since_damage > regen_delay and health < max_health:
			health = minf(max_health, health + regen_rate * delta)
	var target_pos := _net_pos + _net_vel * 0.05
	global_position = global_position.lerp(target_pos, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * 16.0, 0.0, 1.0))
	aim_dir = Vector3(-sin(rotation.y) * cos(_net_pitch), sin(_net_pitch), -cos(rotation.y) * cos(_net_pitch))
	velocity = _net_vel
	_animate()


func _update_aim(delta: float) -> void:
	var desired := aim_dir
	if target and target.alive:
		tracking_t += delta
		aim_error_t -= delta
		if aim_error_t <= 0.0:
			aim_error_t = 0.35
			var err: float = diff.get("aim_error_deg", 3.0) * (1.0 + flash_time * 3.0) / (1.0 + tracking_t * 0.6)
			var dist := global_position.distance_to(target.global_position)
			# Angular error shrinks slightly with distance so bots stay beatable at range and up close.
			aim_error = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-1, 1)) * tan(deg_to_rad(err)) * dist
		var pt := target.aim_point() + aim_error
		if target.velocity.length() > 0.5:
			pt += target.velocity * 0.05
		desired = (pt - eye_position()).normalized()
	elif velocity.length() > 0.5:
		desired = Vector3(velocity.x, 0, velocity.z).normalized()
	var speed: float = diff.get("track_speed", 5.0) if target else 4.0
	aim_dir = aim_dir.slerp(desired, clampf(delta * speed, 0, 1)).normalized()
	var flat := Vector3(aim_dir.x, 0, aim_dir.z)
	if flat.length() > 0.05:
		rotation.y = atan2(-flat.x, -flat.z)


func _act(delta: float) -> void:
	reaction_left -= delta
	grenade_t -= delta
	retreat_t -= delta
	crouch_t -= delta
	var w := inv.active()
	var fire := false
	# Knife anyone who gets right on top of us (CODM bots love a melee trade).
	if target and target.alive and reaction_left <= 0.0 and using_item == "" and not downed:
		var md := global_position.distance_to(target.global_position)
		if md < 2.1 and (w == null or w.mag == 0 or _rng.randf() < 0.04):
			if do_melee(eye_position(), (target.aim_point() - eye_position()).normalized()):
				model.play_melee()
	if target and target.alive and w and reaction_left <= 0.0 and flash_time < 0.4 and using_item == "":
		var to := (target.aim_point() - eye_position())
		var dist := to.length()
		var aligned := aim_dir.dot(to.normalized()) > cos(deg_to_rad(6.0 + 60.0 / maxf(dist, 1.0)))
		if dist <= float(w.stats.max_range) * 0.9 and aligned:
			if burst_left > 0.0:
				burst_left -= delta
				fire = true
			else:
				burst_pause -= delta
				if burst_pause <= 0.0:
					var b: float = diff.get("burst", 0.55)
					burst_left = _rng.randf_range(0.25, 0.7) * (0.5 + b) * (1.6 if dist < 15.0 else 1.0)
					burst_pause = _rng.randf_range(0.2, 0.55) * (1.5 - b) * (1.0 + dist / 60.0)
		# Occasional grenade at mid range.
		if grenade_t <= 0.0 and dist > 9.0 and dist < 24.0 and inv.lethal_count > 0:
			grenade_t = _rng.randf_range(10.0, 20.0)
			if _rng.randf() < 0.35:
				var arc := (target.global_position - global_position)
				var throw_dir := (arc.normalized() + Vector3.UP * clampf(dist / 40.0, 0.1, 0.6)).normalized()
				throw_dir = throw_dir * clampf(dist / 20.0, 0.5, 1.2)
				throw_equipment("lethal", eye_position(), throw_dir.normalized())
		# Mid-fight crouch for variety.
		if crouch_t <= 0.0:
			crouch_t = _rng.randf_range(2.0, 5.0)
			set_height(CROUCH_HEIGHT if _rng.randf() < 0.25 and dist > 12.0 else HEIGHT)
	elif current_height < HEIGHT and crouch_t <= 0.0 and not downed:
		set_height(HEIGHT)
	if w and w.mag == 0 and not w.reloading:
		request_reload()
	var wdir := aim_dir
	if fire:
		# Pistol/semi weapons: pulse the trigger.
		if w.data.fire_mode != WeaponData.FireMode.AUTO and Engine.get_physics_frames() % 2 == 0:
			fire = false
	process_trigger(fire, eye_position(), wdir, muzzle_pos(), true, velocity.length() > 1.0)
	# In BR, swap to the other weapon if the active one is dry.
	if w and w.mag == 0 and w.get_reserve() == 0:
		inv.cycle()


func _move(delta: float) -> void:
	var speed := 4.6
	var goal := Vector3.ZERO
	var has_goal := true
	match state:
		State.ENGAGE:
			if target:
				var dist := global_position.distance_to(target.global_position)
				strafe_t -= delta
				if strafe_t <= 0.0:
					strafe_t = _rng.randf_range(0.6, 1.6)
					strafe_dir = -strafe_dir if _rng.randf() < 0.7 else strafe_dir
				var side := aim_dir.cross(Vector3.UP).normalized() * strafe_dir
				var w := inv.active()
				var ideal: float = clampf(float(w.stats.effective_range) * 0.6, 6.0, 30.0) if w else 10.0
				var push := 0.0
				if dist > ideal * (1.4 - diff.get("aggression", 0.6) * 0.5):
					push = 1.0
				elif dist < ideal * 0.4:
					push = -0.6
				goal = global_position + side * 2.5 + Vector3(aim_dir.x, 0, aim_dir.z).normalized() * push * 3.0
				speed = 3.6
			else:
				has_goal = false
		State.RETREAT:
			goal = move_goal
			speed = 6.2
			if global_position.distance_to(move_goal) < 1.5:
				retreat_t = 0.0
		State.INVESTIGATE:
			goal = last_known
			speed = 4.8
			if global_position.distance_to(last_known) < 2.0:
				last_seen_t = 99.0
		State.PATROL:
			goal = move_goal
			speed = 4.0
		State.LOOT:
			if loot_target and is_instance_valid(loot_target) and loot_target.is_inside_tree():
				goal = loot_target.global_position
				speed = 5.6
				if global_position.distance_to(goal) < 1.6:
					loot_target.interact(self)
					if is_instance_valid(loot_target):
						_ignored_loot[loot_target] = true
					loot_target = null
					state = State.PATROL
			else:
				loot_target = null
				state = State.PATROL
				has_goal = false
		State.ZONE:
			goal = match_node.zone_target() if match_node and match_node.has_method("zone_target") else move_goal
			speed = 6.6
		State.HEAL:
			has_goal = false
			if using_item == "":
				state = State.PATROL
		State.DOWNED:
			# Crawl toward the nearest standing teammate (or just stay put).
			var helper := _standing_teammate()
			if helper and global_position.distance_to(helper.global_position) > 2.0:
				goal = helper.global_position
				speed = 2.0
			else:
				has_goal = false
		State.REVIVE:
			if revive_mate and is_instance_valid(revive_mate) and revive_mate.alive and revive_mate.downed:
				goal = revive_mate.global_position
				speed = 6.0
				var rd := global_position.distance_to(goal)
				_revive_near_t = _revive_near_t + delta if rd < 4.5 else 0.0
				if rd < 1.7 or (_revive_near_t > 1.5 and rd < 4.5):
					has_goal = false
					var to_m := goal - global_position
					to_m.y = 0
					if to_m.length() > 0.1:
						aim_dir = aim_dir.slerp(to_m.normalized(), 0.2).normalized()
					if revive_mate.revive_tick(self, delta):
						revive_mate = null
						state = State.PATROL
			else:
				revive_mate = null
				state = State.PATROL
				has_goal = false
		State.FOLLOW:
			goal = move_goal
			speed = 6.0
			if global_position.distance_to(move_goal) < 3.0:
				state = State.PATROL
		State.MOUNT:
			if mount_vehicle and is_instance_valid(mount_vehicle) and mount_vehicle.alive and leader and leader.vehicle == mount_vehicle:
				goal = mount_vehicle.global_position
				speed = 6.4
				if global_position.distance_to(goal) < 4.5:
					mount_vehicle.enter(self, mount_vehicle.free_passenger_seat())
					mount_vehicle = null
					state = State.PATROL
					return
			else:
				mount_vehicle = null
				state = State.PATROL
				has_goal = false
	var dir := Vector3.ZERO
	if has_goal:
		repath_t -= delta
		if repath_t <= 0.0 or agent.target_position.distance_to(goal) > 2.0:
			repath_t = 0.5
			agent.target_position = goal
		var next := agent.get_next_path_position()
		dir = next - global_position
		dir.y = 0
		if dir.length() < 0.2 or agent.is_navigation_finished():
			dir = goal - global_position
			dir.y = 0
		if dir.length() > 0.15:
			dir = dir.normalized()
		else:
			dir = Vector3.ZERO
	if using_item != "":
		speed *= 0.5
	var w2 := inv.active()
	if w2:
		speed *= float(w2.stats.move_speed_multiplier)
	if current_height < HEIGHT:
		speed *= 0.55
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(dir * speed, clampf(delta * 10.0, 0, 1))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if skill:
		skill.apply_motion(delta)
	move_and_slide()
	# Stuck detection: jump, then pick a new goal.
	if has_goal and dir != Vector3.ZERO:
		if global_position.distance_to(last_pos) < 0.6 * delta * 10.0:
			stuck_t += delta
		else:
			stuck_t = 0.0
		if stuck_t > 1.2:
			if is_on_floor():
				velocity.y = 6.5
			stuck_t = 0.0
			if state == State.PATROL:
				move_goal = _patrol_point()
			strafe_dir = -strafe_dir
	last_pos = global_position
	if is_on_floor() and hv.length() > 1.5:
		step_accum += hv.length() * delta
		if step_accum > 2.2:
			step_accum = 0.0
			AudioManager.play_3d("res://assets/audio/footsteps/footstep_grass_00%d.ogg" % (randi() % 5), global_position, -10.0, randf_range(0.9, 1.1), 22.0)


func _animate() -> void:
	var w := inv.active()
	var hs := Vector2(velocity.x, velocity.z).length()
	var mode := "ground"
	if not alive:
		mode = "dead"
	elif downed:
		mode = "downed"
	elif parachute:
		mode = "chute" if chute_open else "freefall"
	var _yaw_now := global_rotation.y
	var _turn := wrapf(_yaw_now - _last_body_yaw, -PI, PI) / maxf(get_physics_process_delta_time(), 0.001)
	_last_body_yaw = _yaw_now
	if mode != model.mode:
		model.set_mode(mode)
	model.update(get_physics_process_delta_time(), {
		"turn_rate": _turn,
		"speed": hs,
		"on_floor": (_net_floor if puppet else is_on_floor()) or parachute,
		"crouch": current_height < HEIGHT - 0.05,
		"armed": w != null,
		"pistol": w != null and w.data.category == "PISTOL",
		"firing": burst_left > 0.0 or (w != null and w.cooldown > 0.0),
		"pitch": asin(clampf(aim_dir.y, -1, 1)),
	})


func _on_died() -> void:
	name_tag.visible = false
	model.set_mode("dead")
	model.update(0.016, {})
	target = null


func _on_respawned() -> void:
	state = State.PATROL
	move_goal = _patrol_point()
	target = null
	last_seen_t = 99.0
	cur_anim = ""
	set_height(HEIGHT)
	model.set_mode("ground")


# ---------------- Helpers ----------------

func _downed_teammate(max_d: float) -> Actor:
	if target and target.alive and not target.downed and global_position.distance_to(target.global_position) < 20.0:
		return null   # deal with a standing threat first
	var best: Actor = null
	var bd := max_d
	for n in get_tree().get_nodes_in_group("actors"):
		var a: Actor = n
		if a != self and a.alive and a.downed and a.team == team:
			var d := global_position.distance_to(a.global_position)
			if d < bd:
				bd = d
				best = a
	return best


func _standing_teammate() -> Actor:
	var best: Actor = null
	var bd := 60.0
	for n in get_tree().get_nodes_in_group("actors"):
		var a: Actor = n
		if a != self and a.alive and not a.downed and a.team == team:
			var d := global_position.distance_to(a.global_position)
			if d < bd:
				bd = d
				best = a
	return best


func _on_hit_physics(from: Vector3, amount: float) -> void:
	if model:
		model.flinch(from, amount / 35.0)


func _on_knocked() -> void:
	state = State.DOWNED
	target = null
	burst_left = 0.0
	model.set_mode("downed")


func _on_revived() -> void:
	state = State.PATROL
	cur_anim = ""
	model.set_mode("ground")


func _patrol_point() -> Vector3:
	if match_node and match_node.has_method("random_patrol_point"):
		return match_node.random_patrol_point(self)
	var m := get_world_3d().navigation_map
	return NavigationServer3D.map_get_random_point(m, 1, false)


## Picks a nearby point that is hidden from `threat` (chest height ray blocked by world geometry).
func _find_cover(threat: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var away := (global_position - threat)
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var m := get_world_3d().navigation_map
	var best := global_position + away * 8.0
	for i in 10:
		var ang := _rng.randf_range(-1.6, 1.6)
		var cand := global_position + away.rotated(Vector3.UP, ang) * _rng.randf_range(5.0, 11.0)
		cand = NavigationServer3D.map_get_closest_point(m, cand)
		var q := PhysicsRayQueryParameters3D.create(threat + Vector3.UP * 1.5, cand + Vector3.UP * 1.1, 1)
		if not space.intersect_ray(q).is_empty():
			return cand
	return best


func _find_loot() -> Node3D:
	var w := inv.active()
	var needs_weapon := w == null or (w.data.category == "PISTOL" and inv.weapons[0] != null and inv.weapons[1] == null) or not inv.has_any_weapon()
	var needs_armor := armor_tier < 2
	var best: Node3D = null
	var best_d := 45.0 if needs_weapon else 22.0
	for n in get_tree().get_nodes_in_group("loot"):
		var l := n as Node3D
		if l == null or not l.visible or _ignored_loot.has(l):
			continue
		var kind: String = l.get("kind")
		var useful: bool = (kind == "weapon" and needs_weapon) or (kind == "armor" and needs_armor and int(l.get("tier")) > armor_tier) \
			or (kind == "ammo" and w != null and l.get("item_id") == "ammo_" + w.data.ammo_type and inv.get_ammo(w.data.ammo_type) < w.mag_size() * 3) or (kind == "heal" and inv.best_heal() == "") or (kind == "plate" and inv.plates < 2) or kind == "crate"
		if not useful:
			continue
		var d := global_position.distance_to(l.global_position)
		if d < best_d:
			best_d = d
			best = l
	return best


## BR drop: wingsuit glide towards the drop target, parachute opens near the ground.
func _parachute(delta: float) -> void:
	var to := drop_target - global_position
	to.y = 0
	var agl := _height_above_ground()
	if not chute_open and agl < Player.CHUTE_AUTO_AGL:
		chute_open = true
		chute_inflate = 0.0
	chute_inflate = minf(chute_inflate + delta / DropPhysics.INFLATE_TIME, 1.0) if chute_open else 0.0
	var wish := Vector3.ZERO
	var dive := 0.0
	if to.length() > 2.0:
		wish = to.normalized() * clampf(to.length() / 20.0, 0.3, 1.0)
		# Dive when the target is close below (falls faster, like players do).
		if not chute_open and to.length() < agl * 0.5:
			dive = 1.0
	var facing := -global_transform.basis.z
	velocity = DropPhysics.step(velocity, wish, facing, dive, chute_open, chute_inflate, 0.0, delta)
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(-hv.x, -hv.z), clampf(delta * 3.0, 0, 1))
	move_and_slide()
	_animate()
	if is_on_floor():
		parachute = false
		chute_open = false
		model.set_mode("ground")
		state = State.PATROL
		move_goal = global_position


func _height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 400.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return global_position.y - (hit.position.y if not hit.is_empty() else 0.0)
