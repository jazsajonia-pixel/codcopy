extends Node3D
## Dev helper: renders a model from the side (+X camera looking -X) to /tmp/r/<name>.png
##   xvfb-run -a godot res://tests/model_shot.tscn -- res://path/model.glb [more...]
var paths: Array = []
var i := 0
var f := 0
var cur: Node3D
var cam: Camera3D

func _ready() -> void:
	paths = Array(OS.get_cmdline_user_args())
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.6, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	# axis markers: red = -Z (forward), green = +Y
	var mz := MeshInstance3D.new(); var bz := BoxMesh.new(); bz.size = Vector3(0.01, 0.01, 0.3); mz.mesh = bz; mz.position = Vector3(0, 0, -0.15)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color.RED; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mz.material_override = mat; add_child(mz)

func _process(_d: float) -> void:
	if i >= paths.size():
		get_tree().quit(); return
	if f == 0:
		if cur: cur.queue_free()
		cur = load(paths[i]).instantiate()
		add_child(cur)
		var acc: Array = [null]
		ActorModel._visible_aabb(cur, Transform3D.IDENTITY, acc)
		var b: AABB = acc[0]
		cam.size = maxf(b.size.y, b.size.z) * 1.3
		if OS.get_environment("SHOT_SIDE") == "z":
			cam.size = maxf(b.size.y, b.size.x) * 1.3
			cam.position = Vector3(b.get_center().x, b.get_center().y, 5)
			cam.look_at(Vector3(b.get_center().x, b.get_center().y, 0))
		else:
			cam.position = Vector3(5, b.get_center().y, b.get_center().z)
			cam.look_at(Vector3(0, b.get_center().y, b.get_center().z))
	f += 1
	if f == 4:
		get_viewport().get_texture().get_image().save_png("/tmp/r/" + str(paths[i]).get_file().get_basename() + ".png")
		i += 1; f = 0
