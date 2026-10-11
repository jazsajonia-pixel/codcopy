class_name Helicopter
extends Vehicle
## Pilotable transport helicopter (Battle Royale). Rigid-body flight model:
##  - main rotor lift along the airframe's up axis, scaled by rotor RPM (spins up when a pilot boards)
##  - collective: UP / DOWN buttons (jump / crouch); hands-off holds altitude (hover assist)
##  - cyclic: the move stick tilts the airframe (nose down = forward), so thrust tilts and the
##    helicopter accelerates physically; attitude is held by a PD controller with limits
##  - yaw follows the pilot's camera heading (tail-rotor torque)
##  - quadratic air drag, crash damage from hard impacts, autorotation fall when the pilot leaves
## Seats: 0 = pilot, 1..3 passengers. Reuses Vehicle's seats / enter / exit / damage / explosion.

const LIFT_MARGIN := 0.65      ## extra lift (fraction of weight) at full collective
const MAX_TILT := 0.5         ## rad, cyclic limit (~24 deg)
const SPOOL_TIME := 2.5        ## seconds to full rotor RPM
const MAX_ALT := 220.0
const CLIMB_RATE := 9.0        ## m/s at full UP
const SINK_RATE := 7.0         ## m/s at full DOWN
const CYCLIC_ASSIST := 4.5     ## m/s^2 extra horizontal push along the stick (arcade feel)
const DRAG_K := 9.0

var collective := 0.0          ## -1 down .. +1 up
var cyclic := Vector2.ZERO     ## x roll (right +), y pitch (forward -)
var heading_target := 0.0      ## world yaw the pilot wants to face
var rpm := 0.0                 ## 0..1
var rotor: Node3D
var tail_rotor: Node3D
var _prev_vel := Vector3.ZERO
var _wash_t := 0.0
var _hp_mat: StandardMaterial3D
var autopilot_test := false    ## tests: fly without an Actor in the pilot seat


func setup(_kind: String) -> void:
	kind = "heli"


func _ready() -> void:
	kind = "heli"
	max_health = 1400.0
	health = max_health
	max_speed = 42.0
	mass = 1600.0
	seats.resize(4)
	collision_layer = 1 | 4
	collision_mask = 1 | 4
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.6, 0)
	linear_damp = 0.05
	angular_damp = 0.4
	contact_monitor = true
	max_contacts_reported = 4
	cam_dist = 13.0
	cam_height = 3.2
	add_to_group("vehicles")
	add_to_group("interactable")
	model = _build_model()
	add_child(model)
	_build_heli_collision()
	chase_cam = Camera3D.new()
	chase_cam.fov = 78.0
	chase_cam.far = 1400.0
	chase_cam.top_level = true
	add_child(chase_cam)
	engine_audio = AudioStreamPlayer3D.new()
	var es := load("res://assets/audio/sfx/engine_loop.ogg") as AudioStreamOggVorbis
	if es:
		es = es.duplicate()
		es.loop = true
	engine_audio.stream = es
	engine_audio.max_distance = 160.0
	engine_audio.volume_db = -2.0
	engine_audio.bus = "SFX"
	add_child(engine_audio)
	heading_target = rotation.y


func display_name() -> String:
	return "Helicopter"


func prompt() -> String:
	if not alive:
		return ""
	var s := free_seat()
	if s < 0:
		return "Helicopter full"
	return "Pilot Helicopter" if s == 0 else "Board Helicopter"


# ---------------- Model ----------------

func _mat(c: Color, metal := 0.2, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else model).add_child(mi)
	return mi


func _build_model() -> Node3D:
	model = Node3D.new()
	var olive := _mat(Color(0.32, 0.38, 0.24))
	_hp_mat = olive
	var dark := _mat(Color(0.12, 0.13, 0.12), 0.4, 0.5)
	var glass := _mat(Color(0.35, 0.55, 0.65, 0.55), 0.6, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Fuselage: rounded capsule body + cabin box
	var body := CapsuleMesh.new()
	body.radius = 1.05
	body.height = 4.6
	_part(body, olive, Vector3(0, 1.45, 0.2), Vector3(PI * 0.5, 0, 0))
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.9, 1.3, 2.4)
	_part(cabin, olive, Vector3(0, 1.25, 0.6))
	# Cockpit glass bubble (nose = -Z)
	var bubble := SphereMesh.new()
	bubble.radius = 0.95
	bubble.height = 1.5
	_part(bubble, glass, Vector3(0, 1.65, -1.75))
	# Tail boom + fins
	var boom := CylinderMesh.new()
	boom.top_radius = 0.18
	boom.bottom_radius = 0.38
	boom.height = 4.6
	_part(boom, olive, Vector3(0, 1.75, 4.3), Vector3(PI * 0.5 - 0.06, 0, 0))
	var fin := BoxMesh.new()
	fin.size = Vector3(0.12, 1.3, 0.8)
	_part(fin, olive, Vector3(0, 2.35, 6.4), Vector3(-0.35, 0, 0))
	var stab := BoxMesh.new()
	stab.size = Vector3(1.6, 0.08, 0.5)
	_part(stab, olive, Vector3(0, 1.85, 5.8))
	# Engine housing + mast
	var eng := BoxMesh.new()
	eng.size = Vector3(1.1, 0.55, 2.0)
	_part(eng, dark, Vector3(0, 2.55, 0.8))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.1
	mast.bottom_radius = 0.14
	mast.height = 0.5
	_part(mast, dark, Vector3(0, 3.0, 0.3))
	# Skids
	for sx in [-1.0, 1.0]:
		var skid := CylinderMesh.new()
		skid.top_radius = 0.07
		skid.bottom_radius = 0.07
		skid.height = 4.2
		_part(skid, dark, Vector3(sx * 1.15, 0.08, 0.1), Vector3(PI * 0.5, 0, 0))
		for sz in [-1.0, 1.0]:
			var strut := CylinderMesh.new()
			strut.top_radius = 0.05
			strut.bottom_radius = 0.05
			strut.height = 0.85
			_part(strut, dark, Vector3(sx * 1.0, 0.45, sz * 1.0), Vector3(0, 0, sx * 0.35))
	# Main rotor (4 blades) and tail rotor
	rotor = Node3D.new()
	rotor.position = Vector3(0, 3.3, 0.3)
	model.add_child(rotor)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.22
	hub.bottom_radius = 0.22
	hub.height = 0.18
	_part(hub, dark, Vector3.ZERO, Vector3.ZERO, rotor)
	for i in 4:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.32, 0.05, 5.4)
		var b := _part(blade, dark, Vector3.ZERO, Vector3(0, i * PI * 0.5, 0), rotor)
		b.position = Basis(Vector3.UP, i * PI * 0.5) * Vector3(0, 0, 2.7)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.22, 2.4, 6.5)
	model.add_child(tail_rotor)
	for i in 2:
		var tb := BoxMesh.new()
		tb.size = Vector3(0.04, 1.3, 0.16)
		_part(tb, dark, Vector3.ZERO, Vector3(i * PI * 0.5, 0, 0), tail_rotor)
	# Door gunner stripes / markings
	var stripe := BoxMesh.new()
	stripe.size = Vector3(1.94, 0.18, 0.5)
	_part(stripe, _mat(Color(0.85, 0.7, 0.2)), Vector3(0, 1.45, 1.6))
	return model


func _build_heli_collision() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 2.2, 4.8)
	cs.shape = box
	cs.position = Vector3(0, 1.45, 0.1)
	add_child(cs)
	var skids := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(2.5, 0.2, 4.0)
	skids.shape = sb
	skids.position = Vector3(0, 0.1, 0.1)
	add_child(skids)
	var tail := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(0.6, 0.8, 4.2)
	tail.shape = tbox
	tail.position = Vector3(0, 1.9, 4.6)
	add_child(tail)
	bumper = Area3D.new()
	bumper.collision_layer = 0
	bumper.collision_mask = 2
	bumper.monitorable = false
	add_child(bumper)


# ---------------- Controls ----------------

## move: stick (x right, y forward -). up/down: collective buttons. cam_yaw_world: where the pilot looks.
func fly(move: Vector2, up: bool, down: bool, cam_yaw_world: float) -> void:
	cyclic = move.limit_length(1.0)
	collective = (1.0 if up else 0.0) - (1.0 if down else 0.0)
	heading_target = cam_yaw_world


func drive(move: Vector2, brake: bool) -> void:
	fly(move, brake, false, heading_target)


func altitude() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 400.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return global_position.y - hit.position.y if not hit.is_empty() else 400.0


func _physics_process(delta: float) -> void:
	for k in _hit_cooldown.keys():
		_hit_cooldown[k] -= delta
		if _hit_cooldown[k] <= 0.0:
			_hit_cooldown.erase(k)
	var drv: Object = driver()
	if drv == null and autopilot_test:
		drv = self
	if not alive:
		rpm = move_toward(rpm, 0.0, delta * 0.4)
		_spin(delta)
		return
	if drv == null:
		collective = -0.4
		cyclic = Vector2.ZERO
	rpm = move_toward(rpm, 1.0 if drv != null else 0.0, delta / (SPOOL_TIME if drv != null else 6.0))
	var b := global_transform.basis
	var up := b.y
	var g := 9.8
	var weight := mass * g
	# Lift: hover thrust compensates for tilt; collective sets a target climb rate (arcade-friendly
	# vertical speed controller), and the ground cushion slows the last few metres of a descent.
	var tilt_comp := 1.0 / maxf(up.y, 0.6)
	var lift := weight * tilt_comp * rpm * rpm
	if drv != null and rpm > 0.5:
		var alt := altitude()
		var target_vy := collective * (CLIMB_RATE if collective > 0.0 else SINK_RATE)
		if collective < 0.0 and alt < 10.0:
			target_vy = lerpf(-1.6, target_vy, clampf((alt - 1.5) / 8.5, 0.0, 1.0))
		lift += (target_vy - linear_velocity.y) * mass * 2.5 * rpm
		lift = clampf(lift, 0.0, weight * 1.9)
	elif drv == null:
		lift *= 0.75   # spinning down: autorotation slows the fall a little
	apply_central_force(up * lift)
	# Attitude PD controller: cyclic -> target pitch / roll, measured in the yaw frame.
	var yaw := atan2(b.z.x, b.z.z)
	# Angles are measured as "nose down" (pitch) and "right wing up" (roll), both in radians.
	var target_pitch := -cyclic.y * MAX_TILT          # forward stick (y<0) = nose down
	var target_roll := -cyclic.x * MAX_TILT * 0.8     # right stick = right wing down
	var fwd_flat := Vector3(-sin(yaw), 0, -cos(yaw))
	var right_flat := Vector3(cos(yaw), 0, -sin(yaw))
	var cur_pitch := asin(clampf(b.z.y, -1.0, 1.0))
	var cur_roll := asin(clampf(b.x.y, -1.0, 1.0))
	var av := angular_velocity
	var k_p := mass * 6.0 * maxf(rpm, 0.2)
	var k_d := mass * 4.5
	var pitch_t := -(target_pitch - cur_pitch) * k_p - av.dot(right_flat) * k_d
	var roll_t := -(target_roll - cur_roll) * k_p - av.dot(fwd_flat) * k_d
	apply_torque(right_flat * pitch_t + fwd_flat * roll_t)
	# Yaw toward the pilot's heading (tail rotor), plus a little auto-coordination into turns.
	var yaw_err := wrapf(heading_target - yaw, -PI, PI) if drv != null else 0.0
	apply_torque(Vector3.UP * (yaw_err * mass * 8.0 * rpm - av.y * mass * 5.0))
	# Aerodynamic drag (quadratic) and a weathervane push along the nose.
	var v := linear_velocity
	apply_central_force(-v * v.length() * DRAG_K)
	if drv != null and rpm > 0.8:
		apply_central_force((fwd_flat * -cyclic.y + right_flat * cyclic.x) * mass * CYCLIC_ASSIST)
		if cyclic.length() < 0.15:
			# Stick released: hover-hold assist bleeds off horizontal speed.
			apply_central_force(-Vector3(v.x, 0, v.z) * mass * 0.7)
	# Crash damage: hard velocity changes = impacts.
	var dv := (v - _prev_vel).length()
	if dv > 9.0 and get_contact_count() > 0:
		take_vehicle_damage((dv - 9.0) * 55.0, _last_attacker)
		add_shake_occupants(clampf(dv / 15.0, 0.3, 1.0))
	_prev_vel = v
	_spin(delta)
	_rotor_wash(delta)
	if engine_audio.stream:
		if rpm > 0.05 and not engine_audio.playing:
			engine_audio.play()
		elif rpm <= 0.05 and engine_audio.playing:
			engine_audio.stop()
		engine_audio.pitch_scale = 0.5 + rpm * 0.9 + clampf(collective, 0, 1) * 0.15
	for a in occupants():
		if is_instance_valid(a):
			a.global_position = global_position + b.y * 0.9
		else:
			seats[seats.find(a)] = null
	if global_position.y < -6.0:
		_explode()


func add_shake_occupants(v: float) -> void:
	for a in occupants():
		if is_instance_valid(a):
			a.add_shake(v)


func _spin(delta: float) -> void:
	if rotor:
		rotor.rotate_y(delta * rpm * 28.0)
	if tail_rotor:
		tail_rotor.rotate_x(delta * rpm * 40.0)


func _rotor_wash(delta: float) -> void:
	if rpm < 0.6:
		return
	_wash_t -= delta
	if _wash_t > 0.0:
		return
	_wash_t = 0.25
	var alt := altitude()
	if alt < 22.0:
		Effects.burst("land", global_position - Vector3.UP * alt + Vector3.UP * 0.1, Vector3.UP, clampf(1.6 - alt * 0.06, 0.4, 1.6))


func _explode() -> void:
	if not alive:
		return
	super()
	rpm = 0.6
	apply_torque_impulse(Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)) * mass * 2.0)


## Wider, higher chase camera so the pilot can see the ground.
func update_camera(delta: float, look: Vector2) -> void:
	super(delta, look)
