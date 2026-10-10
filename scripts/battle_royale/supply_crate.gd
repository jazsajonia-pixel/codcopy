class_name SupplyCrate
extends Node3D
## Supply container at each point of interest. Interact to open; spills high-tier loot.

var kind := "crate"
var tier := 3
var contents: Array = []   ## Array of [kind, id, amount, attachments]


func _ready() -> void:
	add_to_group("loot")
	add_to_group("interactable")
	var model: Node3D = load("res://assets/maps/survival/chest.glb").instantiate()
	model.scale = Vector3.ONE * 3.6
	add_child(model)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.75, 0.25)
	beacon.omni_range = 4.0
	beacon.light_energy = 1.2
	beacon.position.y = 1.4
	add_child(beacon)


func prompt() -> String:
	return "Open Supply Crate"


func auto_pickup(_a: Actor) -> bool:
	return false


func interact(_a: Actor) -> void:
	if not is_inside_tree():
		return
	var i := 0
	for c in contents:
		var l := LootItem.make(c[0], c[1], c[2])
		if c.size() > 3:
			l.weapon_attachments = c[3]
		get_parent().add_child(l)
		var ang := TAU * i / maxf(contents.size(), 1)
		l.global_position = global_position + Vector3(cos(ang), 0.1, sin(ang)) * 1.4
		i += 1
	AudioManager.play_3d("res://assets/audio/ui/open_001.ogg" if ResourceLoader.exists("res://assets/audio/ui/open_001.ogg") else "res://assets/audio/sfx/loot_pickup.ogg", global_position, -4.0)
	queue_free()
