extends Node3D
## Visual QA for first-person arms: renders weapons in several states. Needs a display (xvfb-run).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 res://tests/vm_shots.tscn -- [out_dir]

var cam: Camera3D
var vm: ViewModel
var out := "/tmp/vm"
var jobs: Array = []   # [weapon_id|"", state]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.55, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 80
	cam.near = 0.03
	add_child(cam)
	vm = ViewModel.new()
	cam.add_child(vm)
	var ids := ["ar_m4k", "pistol_p9", "sg_breacher", "sniper_ls7", "smg_vx"]
	var only := OS.get_environment("VM_ONLY")
	if only != "":
		for id in only.split(","):
			for st in ["hip", "ads"]:
				jobs.append([id, st])
		jobs.append(["", "knife"])
		jobs.append(["", "knife_slash"])
		jobs.append(["ar_m4k", "inspect"])
		_run.call_deferred()
		return
	for id in ids:
		jobs.append([id, "hip"])
	for st in ["ads", "reload_a", "reload_b", "sprint", "cycle", "throw", "heal", "melee"]:
		jobs.append(["ar_m4k", st])
	jobs.append(["sg_breacher", "cycle"])
	jobs.append(["sniper_ls7", "cycle"])
	jobs.append(["pistol_p9", "reload_b"])
	jobs.append(["", "unarmed"])
	jobs.append(["", "punch"])
	_run.call_deferred()

func _run() -> void:
	for j in jobs:
		var id: String = j[0]
		var st: String = j[1]
		var w: WeaponInstance = WeaponInstance.create(id) if id != "" else null
		vm.set_weapon(w)
		vm.set_melee("knife" if st.begins_with("knife") else "")
		vm.switch_t = 0.0
		vm.ads = 0.0
		vm.use_item = ""
		var sprint := st == "sprint"
		var frames := 40 if st != "inspect" else 50
		for f in frames:
			if w:
				if st == "ads": vm.ads = 1.0
				if st.begins_with("reload"):
					w.reloading = true
					w.reload_total = 2.0
					w.reload_left = 2.0 * (0.9 if st == "reload_a" else 0.55)
				if st == "cycle":
					w.cooldown = 60.0 / float(w.stats.fire_rate_rpm) * 0.45
				if st == "heal":
					vm.use_item = "medkit"
			if st == "throw" and f == frames - 14: vm.on_throw()
			if (st == "melee" or st == "punch" or st == "knife_slash") and f == frames - 6: vm.on_melee()
			if st == "inspect" and f == 4: vm.inspect()
			vm.animate(1.0 / 60.0, Vector2.ZERO, 1.0 if sprint else 0.0, true, sprint)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id if id != "" else "none", st]))
	get_tree().quit()
