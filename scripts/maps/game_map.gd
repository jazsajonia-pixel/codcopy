class_name GameMap
extends Node3D
## Base class for maps. Subclasses implement build() using MapBuilder and fill the point lists.

signal nav_ready

@export var map_name := "Map"
var b: MapBuilder
var spawns_a: Array = []      ## Array[Transform3D]
var spawns_b: Array = []
var spawns_ffa: Array = []
var patrol_points: Array = [] ## Array[Vector3]
var loot_points: Array = []   ## Array[Vector3]
var crate_points: Array = []
var pois: Array = []          ## Array[{name, pos}]
var bounds := Rect2(-50, -50, 100, 100)
var nav_baked := false


func _ready() -> void:
	b = MapBuilder.new(self, hash(map_name))
	build()
	GraphicsSettings.apply(get_tree())


func build() -> void:
	pass


func bake_navigation(threaded := false) -> void:
	if threaded:
		b.nav.bake_finished.connect(_on_baked, CONNECT_ONE_SHOT)
		b.nav.bake_navigation_mesh(true)
	else:
		b.nav.bake_navigation_mesh(false)
		_on_baked()


func _on_baked() -> void:
	nav_baked = true
	nav_ready.emit()


static func facing(pos: Vector3, look_at_pos: Vector3) -> Transform3D:
	var d := look_at_pos - pos
	d.y = 0
	var yaw := atan2(-d.x, -d.z)
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func random_patrol(rng: RandomNumberGenerator) -> Vector3:
	if patrol_points.is_empty():
		return Vector3.ZERO
	return patrol_points[rng.randi() % patrol_points.size()]
