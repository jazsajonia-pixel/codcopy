class_name Player
extends Actor
## First-person player controller. Reads a PlayerInput filled by keyboard/mouse, the touch HUD
## or the test autopilot, and drives movement, camera, weapons and interaction.

signal weapon_changed(w: WeaponInstance)
signal interact_target_changed(target: Node)
signal killed_enemy(victim: Actor, headshot: bool)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.2
const CROUCH_SPEED := 2.7
const ADS_SPEED_MULT := 0.62
const JUMP_VELOCITY := 7.0
const ACCEL_GROUND := 13.0
const ACCEL_AIR := 3.5
const SLIDE_SPEED := 10.5
const SLIDE_TIME := 0.75

var input := PlayerInput.new()
var head: Node3D
var camera: Camera3D
var view_model: ViewModel

var yaw := 0.0
var pitch := 0.0
var crouching := false
var sprinting := false
var sliding := false
var slide_t := 0.0
var slide_dir := Vector3.ZERO
var sprint_latched := false
var ads_on := false
var ads_blend := 0.0
var recoil_cam := Vector2.ZERO    ## visual recoil (recovers)
var base_fov := 80.0
var bob_t := 0.0
var step_accum := 0.0
var was_on_floor := true
var land_dip := 0.0
var interact_target: Node = null
var _interact_scan := 0.0
var aim_assist_target: Actor = null
var death_cam_target: Actor = null
var death_time := 0.0
var touch_mode := false
var parachute_state := 0          ## 0 none, 1 freefall, 2 chute (set by BR deploy)
var allow_input := true
var on_target := false            ## crosshair currently over an enemy
var _jump_at := -10000


func parachute_active() -> bool:
	return parachute_state > 0


## True if jump was pressed in the last 250 ms (used by the BR plane/parachute flow).
func jump_recent() -> bool:
	return Time.get_ticks_msec() - _jump_at < 250


func consume_jump() -> void:
	_jump_at = -10000


func _ready() -> void:
	super._ready()
	is_player = true
	head = Node3D.new()
	head.position.y = HEIGHT - 0.15
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.03
	camera.far = 900.0
	camera.current = true
	head.add_child(camera)
	view_model = ViewModel.new()
	camera.add_child(view_model)
	base_fov = float(SaveManager.get_setting("graphics", "fov", 80.0))
	camera.fov = base_fov
	inv.changed.connect(_on_inv_changed)
	SaveManager.settings_changed.connect(func(): base_fov = float(SaveManager.get_setting("graphics", "fov", 80.0)))
	yaw = rotation.y


func equip_current() -> void:
	view_model.set_weapon(inv.active())
	weapon_changed.emit(inv.active())


func _on_inv_changed() -> void:
	if view_model.weapon != inv.active():
		equip_current()


func look_dir() -> Vector3:
	return -camera.global_transform.basis.z


# ---------------- Input ----------------

func _unhandled_input(event: InputEvent) -> void:
	if not allow_input or touch_mode or MatchConfig.autoplay_player:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.08 * float(SaveManager.get_setting("controls", "mouse_sensitivity", 1.0)) * _ads_sens_mult()
		input.look += event.relative * sens
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"): input.jump = true
	elif event.is_action_pressed("crouch"): input.crouch = true
	elif event.is_action_pressed("reload"): input.reload = true
	elif event.is_action_pressed("switch_weapon"): input.switch_weapon = true
	elif event.is_action_pressed("lethal"): input.lethal = true
	elif event.is_action_pressed("tactical"): input.tactical = true
	elif event.is_action_pressed("melee"): input.melee = true
	elif event.is_action_pressed("interact"): input.interact = true
	elif event.is_action_pressed("heal"): input.heal = true
	elif event.is_action_pressed("plate"): input.plate = true
	elif event.is_action_pressed("ads") and SaveManager.get_setting("controls", "ads_mode", "toggle") == "toggle":
		input.ads_toggle = true


func _poll_keyboard() -> void:
	if touch_mode or MatchConfig.autoplay_player:
		return
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Gamepad left stick
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		mv = stick.limit_length(1.0)
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.15:
		input.look += rs * 3.2 * float(SaveManager.get_setting("controls", "look_sensitivity", 1.0)) * _ads_sens_mult()
	input.move = mv
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	input.fire = Input.is_action_pressed("fire") and (captured or Input.get_connected_joypads().size() > 0)
	input.sprint_held = Input.is_action_pressed("sprint")
	if SaveManager.get_setting("controls", "ads_mode", "toggle") == "hold":
		input.ads_held = Input.is_action_pressed("ads")


func _ads_sens_mult() -> float:
	if ads_blend < 0.5:
		return 1.0
	var c: Dictionary = SaveManager.settings.controls
	var mult: float = c.ads_sensitivity
	var w := inv.active()
	if w:
		match w.stats.optic:
			"red_dot": mult *= c.optic_red_dot
			"holo": mult *= c.optic_holo
			"4x": mult *= c.optic_4x
			"8x": mult *= c.optic_8x
	return mult


## Touch HUD calls this with a raw drag delta in pixels.
func touch_look(delta_px: Vector2) -> void:
	var sens := 0.16 * float(SaveManager.get_setting("controls", "look_sensitivity", 1.0)) * _ads_sens_mult()
	if aim_assist_target != null:
		sens *= 0.6   # aim-assist friction
	input.look += delta_px * sens


# ---------------- Main loop ----------------

func _physics_process(delta: float) -> void:
	tick_common(delta)
	if MatchConfig.autoplay_player:
		_autopilot(delta)
	else:
		_poll_keyboard()
	if not alive:
		_death_cam(delta)
		input.clear_pressed()
		return
	if not allow_input:
		input.move = Vector2.ZERO
		input.fire = false
	if input.jump:
		_jump_at = Time.get_ticks_msec()
	view_model.use_item = using_item
	view_model.use_progress = 1.0 - use_left / maxf(use_total, 0.01) if using_item != "" else 0.0
	_apply_look(delta)
	_handle_actions()
	_move(delta)
	_handle_weapon(delta)
	_scan_interact(delta)
	input.clear_pressed()


func _apply_look(delta: float) -> void:
	var lk := input.look
	if SaveManager.get_setting("controls", "invert_y", false):
		lk.y = -lk.y
	if SaveManager.get_setting("controls", "gyro_enabled", false) and touch_mode:
		var gyro := Input.get_gyroscope()
		if gyro.length() > 0.01:
			var gs := float(SaveManager.get_setting("controls", "gyro_sensitivity", 1.0)) * rad_to_deg(delta) * 1.2
			lk += Vector2(-gyro.x, -gyro.y) * gs * _ads_sens_mult()
	yaw -= deg_to_rad(lk.x)
	pitch = clampf(pitch - deg_to_rad(lk.y), deg_to_rad(-85), deg_to_rad(85))
	_aim_assist(delta, lk)
	rotation.y = yaw
	recoil_cam = recoil_cam.lerp(Vector2.ZERO, clampf(delta * 10.0, 0, 1))
	var shake_amt := shake * float(SaveManager.get_setting("accessibility", "camera_shake", 1.0))
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt * 0.02
	head.rotation = Vector3(pitch + recoil_cam.y + sh.y, recoil_cam.x + sh.x, 0)
	view_model.animate(delta, lk, Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED, is_on_floor(), sprinting)


func _aim_assist(delta: float, lk: Vector2) -> void:
	aim_assist_target = null
	on_target = false
	var assist: bool = SaveManager.get_setting("controls", "aim_assist", true) and touch_mode
	var fwd := look_dir()
	var eye := camera.global_position
	var best := deg_to_rad(5.0 if ads_blend > 0.5 else 3.5)
	for n in get_tree().get_nodes_in_group("actors"):
		var a: Actor = n
		if not a.alive or not a.visible or not is_enemy(a):
			continue
		var to := a.aim_point() - eye
		var dist := to.length()
		if dist > 60.0:
			continue
		var ang := fwd.angle_to(to / dist)
		if ang < best:
			best = ang
			aim_assist_target = a
	if aim_assist_target:
		var q := PhysicsRayQueryParameters3D.create(eye, aim_assist_target.aim_point(), 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			aim_assist_target = null
	if aim_assist_target:
		on_target = fwd.angle_to((aim_assist_target.aim_point() - eye).normalized()) < deg_to_rad(2.0)
	if not assist or aim_assist_target == null:
		if not assist:
			aim_assist_target = null
		return
	# Gentle magnetism only while the player is actively moving or looking (never locks on).
	if lk.length() > 0.01 or input.move.length() > 0.1:
		var to2 := (aim_assist_target.aim_point() - eye).normalized()
		var target_yaw := atan2(-to2.x, -to2.z)
		var target_pitch := asin(clampf(to2.y, -1, 1))
		yaw = lerp_angle(yaw, target_yaw, clampf(delta * 2.2, 0, 0.08))
		pitch = lerpf(pitch, target_pitch, clampf(delta * 1.6, 0, 0.06))


func _handle_actions() -> void:
	var w := inv.active()
	if input.switch_weapon and inv.cycle():
		AudioManager.play_2d("res://assets/audio/ui/switch_002.ogg", -10.0)
	if input.reload:
		request_reload()
	if input.ads_toggle:
		ads_on = not ads_on
	if SaveManager.get_setting("controls", "ads_mode", "toggle") == "hold" and not touch_mode:
		ads_on = input.ads_held
	if input.melee:
		do_melee(camera.global_position, look_dir())
		view_model.on_melee()
	if input.lethal and throw_equipment("lethal", camera.global_position, look_dir()):
		view_model.on_throw()
	if input.tactical and throw_equipment("tactical", camera.global_position, look_dir()):
		view_model.on_throw()
	if input.heal:
		var h := inv.best_heal()
		if h != "":
			start_use(h)
	if input.plate:
		start_use("plate")
	if input.interact and interact_target and is_instance_valid(interact_target):
		interact_target.interact(self)
		interact_target = null
		interact_target_changed.emit(null)
	if w == null:
		ads_on = false


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if parachute_state > 0:
		_parachute_move(delta)
		return
	# Sprint logic: hold shift, toggle, or push the touch joystick fully forward.
	var forward_input := input.move.y < -0.5
	if input.sprint_toggle:
		sprint_latched = not sprint_latched
	var want_sprint := (input.sprint_held or input.touch_sprint or sprint_latched) and forward_input
	if not forward_input:
		sprint_latched = false
	if input.fire or ads_on or using_item != "":
		want_sprint = false
	# Crouch / slide
	if input.crouch:
		if sprinting and on_floor and not sliding:
			sliding = true
			slide_t = SLIDE_TIME
			slide_dir = -transform.basis.z
			crouching = true
			AudioManager.play_2d("res://assets/audio/footsteps/footstep_grass_002.ogg", -6.0, 0.7)
		else:
			crouching = not crouching
	if input.jump:
		if crouching and not sliding:
			crouching = false
		elif on_floor:
			velocity.y = JUMP_VELOCITY
			sliding = false
			AudioManager.play_2d("res://assets/audio/footsteps/footstep_concrete_001.ogg", -10.0, 1.1)
	sprinting = want_sprint and not crouching and on_floor or (want_sprint and sprinting and not on_floor)
	if sliding:
		slide_t -= delta
		if slide_t <= 0.0 or not on_floor:
			sliding = false
	var target_h := CROUCH_HEIGHT if crouching or sliding else HEIGHT
	if not is_equal_approx(current_height, target_h):
		if target_h > current_height and _blocked_above():
			crouching = true
		else:
			set_height(move_toward(current_height, target_h, delta * 5.0))
	head.position.y = lerpf(head.position.y, current_height - 0.15 - land_dip, clampf(delta * 14.0, 0, 1))
	land_dip = move_toward(land_dip, 0.0, delta * 0.8)

	var w := inv.active()
	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	if w:
		speed *= float(w.stats.move_speed_multiplier)
	if ads_blend > 0.5:
		speed *= ADS_SPEED_MULT
	if using_item != "":
		speed *= 0.5
	var wish := (transform.basis * Vector3(input.move.x, 0, input.move.y))
	wish.y = 0
	wish = wish.limit_length(1.0)
	var target := wish * speed
	var hv := Vector3(velocity.x, 0, velocity.z)
	if sliding:
		var k := slide_t / SLIDE_TIME
		target = slide_dir * lerpf(CROUCH_SPEED, SLIDE_SPEED, k) + wish * 1.5
		hv = hv.lerp(target, clampf(delta * 6.0, 0, 1))
	else:
		hv = hv.lerp(target, clampf(delta * (ACCEL_GROUND if on_floor else ACCEL_AIR), 0, 1))
	velocity.x = hv.x
	velocity.z = hv.z
	if not on_floor:
		velocity.y -= GRAVITY * delta
	var fall_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		land_dip = clampf(fall_speed * 0.012, 0.0, 0.15)
		if fall_speed > 4.0:
			AudioManager.play_2d("res://assets/audio/sfx/land.ogg", -8.0)
		if fall_speed > 16.0:
			take_damage((fall_speed - 16.0) * 6.0, null, "Fall")
	was_on_floor = is_on_floor()
	# Footsteps
	if is_on_floor() and hv.length() > 1.0 and not sliding:
		step_accum += hv.length() * delta
		var stride := 2.4 if sprinting else 1.9
		if step_accum > stride:
			step_accum = 0.0
			var f := "res://assets/audio/footsteps/footstep_concrete_00%d.ogg" % (randi() % 5)
			AudioManager.play_2d(f, -16.0 if crouching else -11.0, randf_range(0.9, 1.1))


func _blocked_above() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * current_height, global_position + Vector3.UP * (HEIGHT + 0.1), 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _parachute_move(delta: float) -> void:
	var wish := (transform.basis * Vector3(input.move.x, 0, input.move.y)).limit_length(1.0)
	var fall := 38.0 if parachute_state == 1 else 6.5
	var horiz := 22.0 if parachute_state == 1 else 12.0
	if parachute_state == 1 and pitch < deg_to_rad(-45):
		fall = 52.0   # dive
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(wish * horiz, clampf(delta * 2.0, 0, 1))
	velocity = Vector3(hv.x, move_toward(velocity.y, -fall, delta * 30.0), hv.z)
	move_and_slide()
	if is_on_floor():
		parachute_state = 0
		land_dip = 0.15
		AudioManager.play_2d("res://assets/audio/sfx/land.ogg", -4.0)


func _handle_weapon(delta: float) -> void:
	var w := inv.active()
	if w == null:
		ads_blend = move_toward(ads_blend, 0.0, delta * 6.0)
		return
	var can_aim := ads_on and not sprinting and using_item == "" and parachute_state == 0
	var ads_speed := 1.0 / maxf(float(w.stats.ads_time), 0.05)
	ads_blend = move_toward(ads_blend, 1.0 if can_aim else 0.0, delta * ads_speed)
	view_model.ads = ads_blend
	var target_fov := lerpf(base_fov, float(w.stats.ads_fov), ads_blend)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 18.0, 0, 1))
	var auto_fire: bool = SaveManager.get_setting("controls", "auto_fire", false) and touch_mode and on_target
	var trigger := (input.fire or auto_fire) and not view_model.is_busy() and parachute_state == 0
	if trigger and sprinting:
		sprinting = false
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	var origin := camera.global_position
	var res := process_trigger(trigger, origin, look_dir(), view_model.muzzle_global(), ads_blend > 0.6, moving)
	if not res.is_empty():
		pass


func _on_shot(w: WeaponInstance, res: Dictionary) -> void:
	view_model.on_shot()
	var rv: float = w.stats.recoil_vertical * (0.65 if ads_blend > 0.5 else 1.0)
	var rh: float = w.stats.recoil_horizontal * randf_range(-1, 1)
	if crouching:
		rv *= 0.85
	pitch = clampf(pitch + deg_to_rad(rv * 0.55), deg_to_rad(-85), deg_to_rad(85))
	yaw += deg_to_rad(rh * 0.4)
	recoil_cam += Vector2(deg_to_rad(rh * 0.3), deg_to_rad(rv * 0.5))
	add_shake(0.05 * rv)


func _on_reload_started(w: WeaponInstance) -> void:
	AudioManager.play_2d(w.data.reload_sound, -6.0)


func _scan_interact(delta: float) -> void:
	_interact_scan -= delta
	if _interact_scan > 0.0:
		return
	_interact_scan = 0.15
	var best: Node = null
	var best_d := 2.8
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null or not n3.visible:
			continue
		var d := global_position.distance_to(n3.global_position)
		if d < best_d:
			if n.has_method("auto_pickup") and n.auto_pickup(self):
				continue
			best_d = d
			best = n
	if best != interact_target:
		interact_target = best
		interact_target_changed.emit(best)


# ---------------- Death / respawn ----------------

func _on_died() -> void:
	death_time = 0.0
	ads_on = false
	ads_blend = 0.0
	view_model.visible = false
	using_item = ""


func set_death_cam_target(killer: Actor) -> void:
	death_cam_target = killer


func _death_cam(delta: float) -> void:
	death_time += delta
	head.position.y = lerpf(head.position.y, 0.4, clampf(delta * 3.0, 0, 1))
	if death_cam_target and is_instance_valid(death_cam_target) and death_cam_target != self:
		var to := death_cam_target.head_point() - camera.global_position
		if to.length() > 0.5:
			var t := camera.global_transform.looking_at(death_cam_target.head_point(), Vector3.UP)
			camera.global_transform = camera.global_transform.interpolate_with(t, clampf(delta * 3.0, 0, 1))
	camera.fov = lerpf(camera.fov, base_fov, clampf(delta * 4.0, 0, 1))


func _on_respawned() -> void:
	view_model.visible = true
	camera.transform = Transform3D.IDENTITY
	head.position.y = HEIGHT - 0.15
	set_height(HEIGHT)
	crouching = false
	sliding = false
	yaw = rotation.y
	pitch = 0.0
	death_cam_target = null
	equip_current()


# ---------------- Test autopilot ----------------
## Used only by automated tests: aims at the nearest visible enemy and fires through the normal pipeline.

var _auto_retarget := 0.0
var _auto_target: Actor = null
var _auto_wander := Vector3.ZERO
var _auto_path := PackedVector3Array()
var _auto_i := 0
var _auto_repath := 0.0
var _auto_goal := Vector3.ZERO
var _auto_loot: Node3D = null
var _auto_ignored := {}
var _auto_stuck := 0.0
var _auto_last_pos := Vector3.ZERO


## Test autopilot goal: BR -> zone, then useful loot; otherwise patrol points.
func _auto_pick_goal(m: Node) -> Vector3:
	if m and m.has_method("outside_zone") and m.outside_zone(global_position, 0.9):
		_auto_loot = null
		return m.zone_target()
	if inv.use_ammo_pools:
		var best_d := 70.0
		_auto_loot = null
		for n in get_tree().get_nodes_in_group("loot"):
			var l := n as Node3D
			if _auto_ignored.has(l):
				continue
			var kind = l.get("kind")
			var want: bool = kind == "crate" or (kind == "weapon" and (not inv.has_any_weapon() or inv.weapons[1] == null)) \
				or (kind == "armor" and int(l.get("tier")) > armor_tier) or (kind in ["heal", "plate"] and inv.best_heal() == "")
			var w := inv.active()
			if kind == "ammo" and w and l.get("item_id") == "ammo_" + w.data.ammo_type and w.get_reserve() < w.mag_size() * 2:
				want = true
			if not want:
				continue
			var d := global_position.distance_to(l.global_position)
			if d < best_d:
				best_d = d
				_auto_loot = l
		if _auto_loot:
			return _auto_loot.global_position
	if m and m.has_method("random_patrol_point") and (global_position.distance_to(_auto_wander) < 3.0 or _auto_wander == Vector3.ZERO):
		_auto_wander = m.random_patrol_point(null)
	return _auto_wander

func _autopilot(delta: float) -> void:
	input.move = Vector2.ZERO
	input.fire = false
	_auto_retarget -= delta
	if _auto_retarget <= 0.0:
		_auto_retarget = 0.3
		_auto_target = null
		var best := 70.0
		for n in get_tree().get_nodes_in_group("actors"):
			var a: Actor = n
			if not a.alive or not a.visible or not is_enemy(a) or a.parachute_active():
				continue
			var d := global_position.distance_to(a.global_position)
			if d < best:
				var q := PhysicsRayQueryParameters3D.create(eye_position(), a.aim_point(), 1)
				if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					best = d
					_auto_target = a
	if _auto_target and _auto_target.alive:
		var to := (_auto_target.aim_point() - camera.global_position).normalized()
		var ty := atan2(-to.x, -to.z)
		var tp := asin(clampf(to.y, -1, 1))
		input.look = Vector2(-rad_to_deg(angle_difference(yaw, ty)), -rad_to_deg(tp - pitch)) * clampf(delta * 8.0, 0, 1)
		input.fire = absf(angle_difference(yaw, ty)) < 0.08
		input.move = Vector2(0, -0.3)
	else:
		_auto_repath -= delta
		var m := get_tree().current_scene
		if _auto_repath <= 0.0 or _auto_path.is_empty():
			_auto_repath = 1.0
			_auto_goal = _auto_pick_goal(m)
			_auto_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, _auto_goal, true)
			_auto_i = 0
		# Loot / crates in reach
		if _auto_loot and is_instance_valid(_auto_loot):
			var near := global_position.distance_to(_auto_loot.global_position) < 2.4
			if near or interact_target == _auto_loot:
				_auto_loot.interact(self)
				if is_instance_valid(_auto_loot):
					_auto_ignored[_auto_loot] = true
				_auto_loot = null
				_auto_path = PackedVector3Array()
			else:
				# Give up on loot we cannot reach.
				_auto_stuck += delta
				if global_position.distance_to(_auto_last_pos) > 2.0:
					_auto_last_pos = global_position
					_auto_stuck = 0.0
				if _auto_stuck > 4.0:
					_auto_ignored[_auto_loot] = true
					_auto_loot = null
					_auto_stuck = 0.0
					_auto_repath = 0.0
		var nxt := _auto_goal
		while _auto_i < _auto_path.size() and Vector2(_auto_path[_auto_i].x - global_position.x, _auto_path[_auto_i].z - global_position.z).length() < 1.0:
			_auto_i += 1
		if _auto_i < _auto_path.size():
			nxt = _auto_path[_auto_i]
		var to2 := (nxt - global_position)
		var ty2 := atan2(-to2.x, -to2.z)
		input.look = Vector2(-rad_to_deg(angle_difference(yaw, ty2)) * clampf(delta * 6.0, 0, 1), rad_to_deg(pitch) * 0.1)
		input.move = Vector2(0, -1) if absf(angle_difference(yaw, ty2)) < 1.2 else Vector2(0, -0.2)
	if inv.use_ammo_pools and using_item == "":
		if health < 60.0 and inv.best_heal() != "" and _auto_target == null:
			input.heal = true
		elif armor < max_armor - 20.0 and inv.plates > 0 and _auto_target == null:
			input.plate = true
	var w := inv.active()
	if w and w.mag == 0:
		input.reload = true
