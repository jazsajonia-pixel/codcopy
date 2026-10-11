class_name WeaponPreview
extends SubViewportContainer
## Rotating 3D weapon / melee model for the loadout screen (CODM "gunsmith" style).

var vp: SubViewport
var pivot: Node3D
var _t := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	pivot = Node3D.new()
	vp.add_child(pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.05, 1.25)
	cam.fov = 32
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 0.6, -0.8)
	rim.light_color = Color(0.98, 0.77, 0.3)
	rim.light_energy = 1.2
	vp.add_child(rim)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.66)
	we.environment = env
	vp.add_child(we)


## Shows a model scene, auto-centred and scaled to fit (path = gun / melee model).
func show_model(path: String, procedural: Node3D = null) -> void:
	for c in pivot.get_children():
		c.queue_free()
	var n: Node3D = procedural
	if n == null:
		if path == "" or not ResourceLoader.exists(path):
			return
		n = (load(path) as PackedScene).instantiate()
	var holder := Node3D.new()
	pivot.add_child(holder)
	holder.add_child(n)
	var acc := [null]
	ActorModel._visible_aabb(n, Transform3D.IDENTITY, acc)
	if acc[0] == null:
		return
	var box: AABB = acc[0]
	var k := 0.9 / maxf(maxf(box.size.x, box.size.z), box.size.y * 1.6)
	holder.scale = Vector3.ONE * k
	n.position = -box.get_center()


func _process(delta: float) -> void:
	_t += delta
	if pivot:
		pivot.rotation = Vector3(0.12 + sin(_t * 0.7) * 0.06, PI * 0.5 + sin(_t * 0.45) * 0.9, 0)
