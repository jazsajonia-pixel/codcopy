class_name PhysicsProp
extends RigidBody3D
## Loose physics object placed on maps: bullets nudge it, explosions throw it, vehicles shove it.
## Explosive barrels / gas tanks take damage and blow up (chain reactions included).

const KINDS := {
	"barrel": {"model": "res://assets/props/toon/ExplodingBarrel.gltf", "mass": 18.0, "health": 45.0, "explosive": true, "radius": 6.5, "damage": 125.0},
	"gas_tank": {"model": "res://assets/props/toon/GasTank.gltf", "mass": 40.0, "health": 70.0, "explosive": true, "radius": 8.0, "damage": 140.0},
	"crate": {"model": "res://assets/props/toon/Crate.gltf", "mass": 14.0, "health": 0.0},
	"boxes": {"model": "res://assets/props/toon/CardboardBoxes_1.gltf", "mass": 4.0, "health": 0.0},
	"pallet": {"model": "res://assets/props/toon/Pallet.gltf", "mass": 10.0, "health": 0.0},
}

var kind := "crate"
var health := 0.0
var exploded := false
var _last_attacker: Actor = null
var _fuse := -1.0
var _fire: GPUParticles3D


static func spawn(parent: Node, k: String, pos: Vector3, yaw: float = 0.0) -> PhysicsProp:
	var p := PhysicsProp.new()
	p.kind = k
	parent.add_child(p)
	p.global_position = pos
	p.rotation.y = yaw
	return p


func _ready() -> void:
	var d: Dictionary = KINDS.get(kind, KINDS.crate)
	mass = d.mass
	health = d.health
	collision_layer = 1
	collision_mask = 1 | 2
	add_to_group("physics_props")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	pm.bounce = 0.15
	physics_material_override = pm
	angular_damp = 1.5
	linear_damp = 0.2
	var m: Node3D = load(d.model).instantiate()
	add_child(m)
	var acc: Array = [null]
	ActorModel._visible_aabb(m, Transform3D.IDENTITY, acc)
	var box: AABB = acc[0] if acc[0] != null else AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 0.8, 0.8))
	var cs := CollisionShape3D.new()
	if kind in ["barrel", "gas_tank"]:
		var cy := CylinderShape3D.new()
		cy.radius = maxf(box.size.x, box.size.z) * 0.48
		cy.height = box.size.y
		cs.shape = cy
	else:
		var bs := BoxShape3D.new()
		bs.size = box.size
		cs.shape = bs
	cs.position = box.get_center()
	add_child(cs)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 140.0


func take_prop_damage(amount: float, attacker: Actor) -> void:
	var d: Dictionary = KINDS.get(kind, KINDS.crate)
	if exploded or not d.get("explosive", false):
		return
	if attacker:
		_last_attacker = attacker
	health -= amount
	if health <= 0.0 and _fuse < 0.0:
		# Short cook-off so chain reactions ripple instead of all popping in one frame.
		_fuse = randf_range(0.08, 0.35)
		_fire = Effects.smoke_trail(self, Vector3(0, 1.0, 0))


func _physics_process(delta: float) -> void:
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			_explode()
	if global_position.y < -60.0:
		queue_free()


func _explode() -> void:
	if exploded:
		return
	exploded = true
	var d: Dictionary = KINDS[kind]
	var pos := global_position + Vector3.UP * 0.5
	remove_from_group("physics_props")
	Effects.big_explosion(pos, d.radius)
	AudioManager.play_3d("res://assets/audio/sfx/explosion.ogg", pos, 3.0, randf_range(0.85, 1.0), 120.0)
	Combat.explode(_last_attacker if is_instance_valid(_last_attacker) else null, pos, d.radius, d.damage, "Barrel", get_world_3d(), get_tree())
	queue_free()
