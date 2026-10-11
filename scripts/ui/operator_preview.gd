class_name OperatorPreview
extends SubViewportContainer
## Small isolated 3D stage showing an operator model (idle animation) with an optional weapon.

var vp: SubViewport
var stage: Node3D
var model: Node3D
var turntable := true
var _yaw := 0.6


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 5.6)
	cam.rotation_degrees.x = -6
	cam.fov = 38
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2, 2)
	fill.light_energy = 0.8
	fill.light_color = Color(0.9, 0.75, 0.45)
	vp.add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.48)
	env.ambient_light_energy = 0.8
	we.environment = env
	vp.add_child(we)
	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.2
	cyl.height = 0.12
	floor_mi.mesh = cyl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.18, 0.15)
	floor_mi.material_override = fm
	floor_mi.position.y = -0.06
	vp.add_child(floor_mi)


func set_operator(op_id: String, weapon_id: String = "") -> void:
	if model:
		model.queue_free()
	var op := GameDB.get_operator(op_id)
	var am := ActorModel.new()
	stage.add_child(am)
	am.setup_operator(op)
	am.rotation.y = PI
	model = am
	_armed = weapon_id != ""
	if _armed:
		am.set_weapon(WeaponInstance.create(weapon_id))
	_emote_t = 1.6   # greet the player with a wave / nod when the operator changes


var _armed := false
var _emote_t := 0.0


func _process(delta: float) -> void:
	if turntable:
		_yaw += delta * 0.4
	stage.rotation.y = _yaw
	if model is ActorModel:
		_emote_t = maxf(_emote_t - delta, 0.0)
		(model as ActorModel).update(delta, {"speed": 0.0, "on_floor": true, "armed": _armed and _emote_t <= 0.0, "pitch": 0.0, "emote": _emote_t > 0.0})
