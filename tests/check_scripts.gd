extends SceneTree
## Loads every script and scene in the project and reports failures. Run:
##   godot --headless -s res://tests/check_scripts.gd
var _done := false
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var failures := 0
	var count := 0
	for path in _walk("res://"):
		if path.begins_with("res://.godot") or path.begins_with("res://addons"):
			continue
		if path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
			count += 1
			var r = ResourceLoader.load(path)
			if r == null:
				failures += 1
				print("FAIL ", path)
			elif r is GDScript and not (r as GDScript).can_instantiate():
				failures += 1
				print("FAIL (cannot instantiate) ", path)
	print("CHECKED %d resources, %d failures" % [count, failures])
	quit(1 if failures > 0 else 0)

func _walk(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_walk(dir.path_join(sub)))
	return out
