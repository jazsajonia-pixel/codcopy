class_name Grenade
extends RigidBody3D
## Thrown lethal/tactical equipment: frag, sticky charge, smoke and flash.

var thrower: Actor
var equip_id := "frag"
var data: Dictionary
var fuse := 2.5
var _stuck_to: Node3D = null
var _stuck_offset := Vector3.ZERO
var _done := false


func setup(p_thrower: Actor, p_id: String) -> void:
	thrower = p_thrower
	equip_id = p_id
	data = GameDB.EQUIPMENT[p_id]
	fuse = data.fuse


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | (2 if data.get("sticky", false) else 0)
	mass = 0.4
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.09
	shape.shape = sph
	add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	var model: Node3D = load(data.model).instantiate()
	model.scale = Vector3.ONE * 0.9
	model.position.y = -0.1
	add_child(model)
	add_collision_exception_with(thrower)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if data.get("sticky", false) and _stuck_to == null and body is Node3D:
		_stuck_to = body
		_stuck_offset = global_position - (body as Node3D).global_position
		freeze = true
	else:
		AudioManager.play_3d("res://assets/audio/sfx/land.ogg", global_position, -18.0, 1.6, 15.0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _stuck_to and is_instance_valid(_stuck_to):
		global_position = _stuck_to.global_position + _stuck_offset
	fuse -= delta
	if fuse <= 0.0:
		_detonate()


func _detonate() -> void:
	_done = true
	var pos := global_position
	match equip_id:
		"frag", "semtex":
			Effects.big_explosion(pos, data.radius)
			AudioManager.play_3d("res://assets/audio/sfx/explosion.ogg", pos, 4.0, randf_range(0.9, 1.05), 200.0)
			Combat.explode(thrower if is_instance_valid(thrower) else null, pos, data.radius, data.damage, data.name, get_world_3d(), get_tree())
		"smoke":
			Effects.smoke(pos, data.radius, data.duration)
			AudioManager.play_3d("res://assets/audio/sfx/explosion_low.ogg", pos, -8.0, 1.4, 60.0)
		"flash":
			Effects.explosion(pos, 2.0)
			AudioManager.play_3d("res://assets/audio/sfx/explosion_low.ogg", pos, 2.0, 1.8, 90.0)
			var space := get_world_3d().direct_space_state
			for n in get_tree().get_nodes_in_group("actors"):
				var a: Actor = n
				if not a.alive:
					continue
				var eye := a.eye_position()
				var dist := eye.distance_to(pos)
				if dist > data.radius:
					continue
				if thrower and is_instance_valid(thrower) and not thrower.is_enemy(a) and a != thrower:
					continue
				var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.15, eye, 1)
				if not space.intersect_ray(q).is_empty():
					continue
				var facing := 1.0
				if a.has_method("look_dir"):
					facing = clampf(0.4 + 0.6 * a.look_dir().dot((pos - eye).normalized()), 0.3, 1.0)
				a.apply_flash(data.duration * facing * (1.0 - dist / data.radius * 0.5))
	queue_free()
