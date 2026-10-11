extends Node3D
## Dev helper: renders ActorModels side by side. LINEUP_STATE = idle|armed|walk|crouch|die|chute
var models: Array = []
var t := 0.0
var state := "armed"

func _ready() -> void:
	state = OS.get_environment("LINEUP_STATE") if OS.get_environment("LINEUP_STATE") != "" else "armed"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(40, 10); floor_.mesh = pm
	add_child(floor_)
	var paths: Array = Array(OS.get_cmdline_user_args())
	for i in paths.size():
		var m := ActorModel.new()
		add_child(m)
		if String(paths[i]).begins_with("op_"):
			m.setup_operator(GameDB.get_operator(paths[i]))
		else:
			m.setup(paths[i])
		m.position = Vector3((i - (paths.size() - 1) * 0.5) * 1.3, 0, 0)
		m.rotation.y = PI + 0.5
		if state in ["armed", "walk", "crouch"]:
			var w := WeaponInstance.create("ar_m4k")
			m.set_weapon(w)
		models.append(m)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 2.2 + paths.size() * 0.75)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	if state == "chute":
		cam.position = Vector3(5.0, 3.2, 9.5)
		cam.look_at(Vector3(0, 2.6, 0))

func _process(delta: float) -> void:
	t += delta
	for m in models:
		if state == "die" and t > 0.3 and m.mode != "dead": m.set_mode("dead")
		if state == "chute" and m.mode != "chute": m.set_mode("chute")
		m.update(delta, {"speed": 3.0 if state == "walk" else 0.0, "on_floor": true, "crouch": state == "crouch", "armed": state in ["armed", "walk", "crouch"], "pitch": 0.25, "firing": false})
	if t > 1.6:
		get_viewport().get_texture().get_image().save_png("/tmp/lineup_%s.png" % state)
		get_tree().quit()
