extends Node3D
func _ready():
	for p in ["res://assets/characters/toon/Character_Soldier.gltf", "res://assets/characters/toon/Character_Hazmat.gltf", "res://assets/characters/toon/Character_Enemy.gltf"]:
		var n = load(p).instantiate()
		var out := []
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if String(m.get_parent().name).begins_with("Index1"): continue
			for i in m.mesh.get_surface_count():
				var mat = m.mesh.surface_get_material(i)
				out.append("%s/%d:%s %s" % [m.name, i, mat.resource_name if mat else "-", str(mat.albedo_color) if mat is StandardMaterial3D else ""])
		print(p.get_file(), " ", out)
	get_tree().quit()
