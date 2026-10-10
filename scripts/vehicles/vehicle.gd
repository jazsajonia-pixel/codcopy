class_name Vehicle
extends VehicleBody3D
## Drivable vehicle built from a Kenney Car Kit model (CC0). Uses Godot's VehicleBody3D raycast wheels.
## Seats: 0 = driver, 1..3 passengers (squad mates). Occupants are hidden and carried along; bullets and
## explosions damage the vehicle, and a share passes through to the occupants. Running over enemies hurts.

signal destroyed(v: Vehicle)

const MODEL_SCALE := 1.45
const TYPES := {
	"suv": {"name": "SUV", "model": "res://assets/vehicles/suv.glb", "health": 900.0, "engine": 5200.0, "max_speed": 26.0, "mass": 1500.0, "seats": 4},
	"sedan": {"name": "Sedan", "model": "res://assets/vehicles/sedan.glb", "health": 650.0, "engine": 4800.0, "max_speed": 30.0, "mass": 1200.0, "seats": 4},
	"truck": {"name": "Pickup Truck", "model": "res://assets/vehicles/truck.glb", "health": 1200.0, "engine": 6200.0, "max_speed": 22.0, "mass": 2200.0, "seats": 2},
	"police": {"name": "Patrol Cruiser", "model": "res://assets/vehicles/police.glb", "health": 800.0, "engine": 5400.0, "max_speed": 31.0, "mass": 1350.0, "seats": 4},
	"van": {"name": "Van", "model": "res://assets/vehicles/van.glb", "health": 1000.0, "engine": 5000.0, "max_speed": 24.0, "mass": 1800.0, "seats": 4},
}

var kind := "suv"
var max_health := 900.0
var health := 900.0
var engine_max := 5200.0
var max_speed := 26.0
var seats: Array = []        ## Actor or null per seat
var wheels: Array = []
var model: Node3D
var alive := true
var throttle := 0.0
var steer_in := 0.0
var handbrake := false
var chase_cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.25
var engine_audio: AudioStreamPlayer3D
var _last_attacker: Actor = null
var _smoke: GPUParticles3D
var _hit_cooldown := {}      ## Actor -> time left before another run-over hit
var bumper: Area3D


func setup(p_kind: String) -> void:
	kind = p_kind if TYPES.has(p_kind) else "suv"


func _ready() -> void:
	var t: Dictionary = TYPES[kind]
	max_health = t.health
	health = max_health
	engine_max = t.engine
	max_speed = t.max_speed
	mass = t.mass
	seats.resize(int(t.seats))
	collision_layer = 1 | 4      # world (blocks bullets/players) + vehicles
	collision_mask = 1 | 4       # not actors: people never stop a car dead; the bumper area handles them
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.1, 0)
	add_to_group("vehicles")
	add_to_group("interactable")
	model = (load(t.model) as PackedScene).instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	_build_collision()
	_build_wheels()
	chase_cam = Camera3D.new()
	chase_cam.fov = 75.0
	chase_cam.far = 900.0
	chase_cam.top_level = true
	add_child(chase_cam)
	engine_audio = AudioStreamPlayer3D.new()
	var es := load("res://assets/audio/sfx/engine_loop.ogg") as AudioStreamOggVorbis
	if es:
		es.loop = true
	engine_audio.stream = es
	engine_audio.max_distance = 60.0
	engine_audio.volume_db = -8.0
	engine_audio.bus = "SFX"
	add_child(engine_audio)


func _build_collision() -> void:
	var ab := AABB()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var a2: AABB = (m as MeshInstance3D).get_aabb()
		a2.position += (m as Node3D).position
		if not str(m.get_parent().name).begins_with("wheel") and not str(m.name).begins_with("wheel"):
			ab = a2 if ab.size == Vector3.ZERO else ab.merge(a2)
	if ab.size == Vector3.ZERO:
		ab = AABB(Vector3(-0.75, 0.0, -1.35), Vector3(1.5, 1.3, 2.7))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bottom := 0.22   # leave room under the chassis for the suspension
	box.size = Vector3(ab.size.x, ab.end.y - bottom, ab.size.z) * MODEL_SCALE * Vector3(0.95, 1.0, 0.97)
	cs.shape = box
	cs.position = Vector3(ab.get_center().x, (bottom + ab.end.y) * 0.5, ab.get_center().z) * MODEL_SCALE
	add_child(cs)
	bumper = Area3D.new()
	bumper.collision_layer = 0
	bumper.collision_mask = 2
	bumper.monitorable = false
	var bcs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = box.size + Vector3(0.3, 0.0, 0.8)
	bcs.shape = bb
	bcs.position = cs.position
	bumper.add_child(bcs)
	add_child(bumper)


func _build_wheels() -> void:
	for wn in model.find_children("wheel-*", "Node3D", true, false):
		var n := wn as Node3D
		if not (str(n.name).contains("left") or str(n.name).contains("right")):
			n.visible = false   # spare wheel on the SUV's back stays decorative
			if str(n.name) == "wheel-back":
				n.visible = true
			continue
		var w := VehicleWheel3D.new()
		var front := str(n.name).contains("front")
		w.position = n.position * MODEL_SCALE
		w.use_as_steering = front
		w.use_as_traction = not front
		w.wheel_radius = 0.3 * MODEL_SCALE
		w.wheel_rest_length = 0.18
		w.suspension_travel = 0.22
		w.suspension_stiffness = 45.0
		w.suspension_max_force = mass * 20.0
		w.damping_compression = 0.9
		w.damping_relaxation = 1.2
		w.wheel_friction_slip = 3.2 if front else 2.8
		w.wheel_roll_influence = 0.03
		add_child(w)
		# Move the visual wheel under the physics wheel so it spins and steers.
		var xf := n.transform
		n.get_parent().remove_child(n)
		w.add_child(n)
		n.transform = Transform3D(xf.basis.scaled(Vector3.ONE * MODEL_SCALE), Vector3.ZERO)
		wheels.append(w)


# ---------------- Seats ----------------

func display_name() -> String:
	return TYPES[kind].get("name", kind.capitalize())


func driver() -> Actor:
	return seats[0] if seats.size() > 0 else null


func free_passenger_seat() -> int:
	for i in range(1, seats.size()):
		if seats[i] == null:
			return i
	return -1


func free_seat() -> int:
	for i in seats.size():
		if seats[i] == null:
			return i
	return -1


func occupants() -> Array:
	return seats.filter(func(a): return a != null)


func prompt() -> String:
	if not alive:
		return ""
	var s := free_seat()
	if s < 0:
		return "Vehicle full"
	return ("Drive " if s == 0 else "Ride in ") + display_name()


func interact(a: Actor) -> void:
	enter(a)


func enter(a: Actor, seat := -1) -> bool:
	if not alive or a == null or not a.alive or a.get("vehicle") != null:
		return false
	if seat < 0:
		seat = free_seat()
	if seat < 0 or seat >= seats.size() or seats[seat] != null:
		return false
	seats[seat] = a
	a.set("vehicle", self)
	a.set("vehicle_seat", seat)
	if a.has_method("on_enter_vehicle"):
		a.on_enter_vehicle(self, seat)
	AudioManager.play_3d("res://assets/audio/ui/toggle_001.ogg", global_position, -6.0, 0.8, 20.0)
	return true


func exit(a: Actor) -> void:
	var i := seats.find(a)
	if i < 0:
		return
	seats[i] = null
	a.set("vehicle", null)
	var side := global_transform.basis.x * (-1.0 if i % 2 == 0 else 1.0)
	var pos := global_position + side * 2.2 + Vector3.UP * 0.6
	# Find a clear spot (left, right, behind, roof).
	for cand in [pos, global_position - side * 2.2 + Vector3.UP * 0.6, global_position - global_transform.basis.z * 3.2 + Vector3.UP * 0.6, global_position + Vector3.UP * 2.4]:
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.45
		q.shape = sph
		q.transform = Transform3D(Basis(), cand + Vector3.UP * 0.5)
		q.collision_mask = 1
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			pos = cand
			break
	if a.has_method("on_exit_vehicle"):
		a.on_exit_vehicle(self, pos)
	_hit_cooldown[a] = 1.5   # never run over someone who just got out
	if i == 0:
		throttle = 0.0
		steer_in = 0.0
		handbrake = true


func eject_all() -> void:
	for a in occupants():
		exit(a)


## Driver input: move.y < 0 is forward (same convention as walking), move.x steers.
func drive(move: Vector2, brake: bool) -> void:
	throttle = clampf(-move.y, -1.0, 1.0)
	steer_in = clampf(-move.x, -1.0, 1.0)
	handbrake = brake


func speed() -> float:
	return linear_velocity.length()


func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


func _physics_process(delta: float) -> void:
	for k in _hit_cooldown.keys():
		_hit_cooldown[k] -= delta
		if _hit_cooldown[k] <= 0.0:
			_hit_cooldown.erase(k)
	if not alive:
		engine_force = 0.0
		brake = 20.0
		return
	var drv := driver()
	if drv == null:
		throttle = 0.0
		steer_in = 0.0
		handbrake = true
	var fs := forward_speed()
	var spd := speed()
	var steer_limit := lerpf(0.55, 0.11, clampf(spd / max_speed, 0.0, 1.0))
	steering = move_toward(steering, steer_in * steer_limit, delta * 2.5)
	var ef := 0.0
	var br := 0.0
	if throttle > 0.05:
		if fs < -1.0:
			br = 80.0 * throttle          # braking from reverse
		elif fs < max_speed:
			ef = engine_max * throttle
	elif throttle < -0.05:
		if fs > 1.0:
			br = 90.0 * -throttle         # braking
		elif fs > -max_speed * 0.35:
			ef = engine_max * 0.6 * throttle
	else:
		br = 2.5                          # engine braking / rolling resistance
	if handbrake:
		br = maxf(br, 45.0 if drv == null else 25.0)
	engine_force = ef
	brake = br
	# Anti-roll: resist rolling about the forward axis so hard turns slide instead of flipping.
	var roll_rate := angular_velocity.dot(global_transform.basis.z)
	apply_torque(-global_transform.basis.z * roll_rate * mass * 1.5)
	var tilt := global_transform.basis.y.cross(Vector3.UP).dot(global_transform.basis.z)
	apply_torque(global_transform.basis.z * tilt * mass * 9.0)
	# Simple air drag so top speed is reached smoothly.
	apply_central_force(-linear_velocity * spd * 1.4)
	# Engine sound pitch follows speed.
	if engine_audio.stream:
		if drv != null and not engine_audio.playing:
			engine_audio.play()
		elif drv == null and engine_audio.playing:
			engine_audio.stop()
		engine_audio.pitch_scale = 0.7 + clampf(spd / max_speed, 0.0, 1.0) * 0.9
	_check_run_over()
	# Keep occupants with the vehicle.
	for a in occupants():
		if is_instance_valid(a):
			a.global_position = global_position + Vector3.UP * 0.6
		else:
			seats[seats.find(a)] = null
	# Upside down for a while: allow flipping back by pressing interact? Auto-right slowly instead.
	if global_transform.basis.y.y < 0.2 and spd < 2.0:
		apply_torque(global_transform.basis.z.cross(Vector3.UP) * mass * 6.0)
	# Water / out of map
	if global_position.y < -6.0:
		_explode()


func _check_run_over() -> void:
	var spd := speed()
	if spd < 7.0:
		return
	var drv := driver()
	if drv == null:
		return   # empty / rolling vehicles are safe
	for body in bumper.get_overlapping_bodies():
		if not (body is Actor):
			continue
		var a: Actor = body
		if not a.alive or _hit_cooldown.has(a) or occupants().has(a) or not drv.is_enemy(a):
			continue
		_hit_cooldown[a] = 1.0
		var dmg := clampf((spd - 6.0) * 12.0, 30.0, 220.0)
		var push := linear_velocity * 0.6
		var side := (a.global_position - global_position)
		side.y = 0.0
		push += side.normalized() * 6.0 + Vector3.UP * 4.0
		a.velocity = push
		a.take_damage(dmg, drv, "Vehicle", false, global_position)
		linear_velocity *= 0.92


## Called from Combat for bullets/explosions/melee.
func take_vehicle_damage(amount: float, attacker: Actor) -> void:
	if not alive or amount <= 0.0:
		return
	var drv := driver()
	if attacker and drv and not attacker.is_enemy(drv):
		return   # no friendly fire on occupied friendly vehicles
	health -= amount
	_last_attacker = attacker
	# A share of incoming fire reaches the occupants through the windows.
	for a in occupants():
		a.take_damage(amount * 0.25, attacker, "Vehicle fire", false, global_position)
	if health < max_health * 0.3 and _smoke == null:
		_smoke = Effects.smoke_trail(self, Vector3(0, 1.0, 1.2))
	if health <= 0.0:
		_explode()


func _explode() -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	remove_from_group("interactable")
	var killer := _last_attacker
	for a in occupants():
		exit(a)
		a.take_damage(120.0, killer, "Vehicle explosion", false, global_position)
	Effects.explosion(global_position + Vector3.UP * 0.8, 1.6)
	AudioManager.play_3d("res://assets/audio/sfx/explosion.ogg", global_position, 4.0, 0.8, 140.0)
	Combat.explode(killer, global_position + Vector3.UP * 0.8, 7.0, 110.0, "Vehicle explosion", get_world_3d(), get_tree())
	# Burnt-out look
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.08)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = dark
	for w in wheels:
		(w as VehicleWheel3D).visible = false
	apply_central_impulse(Vector3.UP * mass * 4.0)
	destroyed.emit(self)


# ---------------- Camera ----------------

## Third-person chase camera for the local driver/passenger. `look` is the touch/mouse look delta (degrees).
func update_camera(delta: float, look: Vector2) -> void:
	cam_yaw -= deg_to_rad(look.x)
	cam_pitch = clampf(cam_pitch - deg_to_rad(look.y), deg_to_rad(-50), deg_to_rad(15))
	if look.length() < 0.01:
		# drift back behind the vehicle
		cam_yaw = lerp_angle(cam_yaw, 0.0, clampf(delta * 1.2, 0, 1))
	var heading := atan2(global_transform.basis.z.x, global_transform.basis.z.z)
	var yaw := heading + cam_yaw + PI
	var dist := 7.5
	var off := Vector3(sin(yaw) * cos(cam_pitch), -sin(cam_pitch), cos(yaw) * cos(cam_pitch)) * dist
	var pivot := global_position + Vector3.UP * 1.9
	var want := pivot + off
	var q := PhysicsRayQueryParameters3D.create(pivot, want, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = hit.position + (pivot - want).normalized() * 0.3
	chase_cam.global_position = chase_cam.global_position.lerp(want, clampf(delta * 10.0, 0, 1)) if chase_cam.global_position.distance_to(want) < 12.0 else want
	chase_cam.look_at(pivot, Vector3.UP)
