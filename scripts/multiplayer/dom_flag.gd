class_name DomFlag
extends Node3D
## Domination capture point: a pole, a flag and a ground ring. Stand inside with no living enemies
## to capture; contested flags don't move. Built from primitive meshes (original, no assets).

signal captured(flag: DomFlag, team: int)

const RADIUS := 5.0
const CAPTURE_TIME := 6.0      ## seconds for one operator to flip a neutral flag (enemy-owned: 2x)

var letter := "A"
var owner_team := -1           ## -1 neutral
var progress := 0.0            ## -1 (team 1) .. +1 (team 0)
var capturing_team := -1
var contested := false
var _flag_mat := StandardMaterial3D.new()
var _ring_mat := StandardMaterial3D.new()
var _flag: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	add_to_group("dom_flags")
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.08
	pm.height = 4.0
	pole.mesh = pm
	pole.position.y = 2.0
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.75, 0.75, 0.78)
	pmat.metallic = 0.6
	pole.material_override = pmat
	add_child(pole)
	_flag = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.3, 0.8, 0.04)
	_flag.mesh = fm
	_flag.position = Vector3(0.68, 3.5, 0)
	_flag.material_override = _flag_mat
	add_child(_flag)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = RADIUS - 0.18
	rm.outer_radius = RADIUS
	rm.rings = 48
	ring.mesh = rm
	ring.scale.y = 0.15
	ring.position.y = 0.06
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_label = Label3D.new()
	_label.text = letter
	_label.font_size = 96
	_label.pixel_size = 0.01
	_label.outline_size = 16
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 4.6
	add_child(_label)
	_refresh_color()


## Advances capture from who is standing inside. Returns nothing; emits captured on a flip.
func tick(delta: float, actors: Array) -> void:
	var count := {0: 0, 1: 0}
	for a in actors:
		if not is_instance_valid(a) or not a.alive or a.team > 1 or a.team < 0:
			continue
		var d := Vector2(a.global_position.x - global_position.x, a.global_position.z - global_position.z).length()
		if d <= RADIUS and absf(a.global_position.y - global_position.y) < 3.0:
			count[a.team] += 1
	contested = count[0] > 0 and count[1] > 0
	capturing_team = -1
	if contested or (count[0] == 0 and count[1] == 0):
		return
	var t := 0 if count[0] > 0 else 1
	if t == owner_team and absf(progress) >= 1.0:
		return
	capturing_team = t
	var n: int = count[t]
	var rate := (1.0 + 0.5 * float(mini(n, 3) - 1)) / CAPTURE_TIME
	var dir := 1.0 if t == 0 else -1.0
	progress = clampf(progress + dir * rate * delta, -1.0, 1.0)
	if absf(progress) >= 1.0 and owner_team != t:
		owner_team = t
		_refresh_color()
		captured.emit(self, t)
	elif owner_team != -1 and owner_team != t and signf(progress) != (1.0 if owner_team == 0 else -1.0):
		owner_team = -1   # pulled back to neutral
		_refresh_color()


## Colors are drawn from the local player's perspective (friendly blue / enemy red).
var viewer_team := 0


func _refresh_color() -> void:
	var c := Color(0.85, 0.85, 0.85)
	if owner_team != -1:
		c = UITheme.FRIENDLY if owner_team == viewer_team else Bot._enemy_color()
	_flag_mat.albedo_color = c
	_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.55)
	if _label:
		_label.text = letter
		_label.modulate = c


func set_viewer_team(t: int) -> void:
	viewer_team = t
	_refresh_color()
