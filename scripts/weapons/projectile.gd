class_name Projectile
extends Node3D
## Launcher rounds. Rockets fly fast and nearly straight; grenade-launcher rounds arc under gravity,
## bounce once off the world and burst. Both explode on direct contact with an actor or vehicle.
## Collision is a swept ray per physics step, so fast rounds never tunnel through thin walls.

var shooter: Actor
var weapon_name := ""
var damage := 150.0
var radius := 5.5
var velocity := Vector3.ZERO
var gravity := 2.0
var bounces_left := 0
var life := 6.0
var fuse_after_bounce := -1.0
var _trail: GPUParticles3D
var _done := false


static func launch(by: Actor, w: WeaponInstance, from: Vector3, dir: Vector3) -> Projectile:
	var p := Projectile.new()
	p.shooter = by
	p.weapon_name = w.data.display_name
	p.damage = w.stats.damage
	var grenade := w.data.id.contains("thumper")
	p.radius = 4.5 if grenade else 6.0
	p.gravity = 9.8 if grenade else 1.5
	p.bounces_left = 1 if grenade else 0
	p.velocity = dir.normalized() * (34.0 if grenade else 62.0) + (Vector3.UP * 2.0 if grenade else Vector3.ZERO)
	by.get_tree().current_scene.add_child(p)
	p.global_position = from
	p._build(grenade)
	return p


func _build(grenade: bool) -> void:
	var body := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if grenade:
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		body.mesh = sm
		mat.albedo_color = Color(0.3, 0.35, 0.25)
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.06
		cm.height = 0.45
		body.mesh = cm
		body.rotation.x = -PI * 0.5
		mat.albedo_color = Color(0.75, 0.15, 0.1)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.25)
		l.light_energy = 2.0
		l.omni_range = 5.0
		l.position = Vector3(0, 0, 0.3)
		add_child(l)
	body.material_override = mat
	add_child(body)
	_trail = Effects.smoke_trail(self, Vector3(0, 0, 0.25))
	_trail.lifetime = 1.2


func _physics_process(delta: float) -> void:
	if _done:
		return
	life -= delta
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var ex: Array[RID] = []
	if is_instance_valid(shooter):
		ex.append(shooter.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, Combat.MASK_SHOT, ex)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col = hit.collider
		var direct: bool = col is Actor or (col != null and col.has_method("take_vehicle_damage"))
		if bounces_left > 0 and not direct:
			bounces_left -= 1
			var n: Vector3 = hit.normal
			velocity = velocity.bounce(n) * 0.45
			global_position = hit.position + n * 0.05
			fuse_after_bounce = 0.35
			AudioManager.play_3d("res://assets/audio/sfx/bullet_impact.ogg", hit.position, -8.0, 0.6, 25.0)
			return
		if col is RigidBody3D:
			(col as RigidBody3D).apply_impulse(velocity.normalized() * 30.0, hit.position - (col as RigidBody3D).global_position)
		_explode(hit.position + hit.normal * 0.2)
		return
	global_position = to
	if velocity.length() > 0.5:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)
	if fuse_after_bounce >= 0.0:
		fuse_after_bounce -= delta
		if fuse_after_bounce <= 0.0:
			_explode(global_position)
			return
	if life <= 0.0:
		_explode(global_position)


func _explode(pos: Vector3) -> void:
	_done = true
	Effects.big_explosion(pos, radius)
	AudioManager.play_3d("res://assets/audio/sfx/explosion.ogg", pos, 3.0, randf_range(0.9, 1.05), 140.0)
	Combat.explode(shooter if is_instance_valid(shooter) else null, pos, radius, damage, weapon_name, get_world_3d(), get_tree())
	set_physics_process(false)
	visible = false
	if _trail:
		_trail.emitting = false
	await get_tree().create_timer(1.5).timeout
	queue_free()
