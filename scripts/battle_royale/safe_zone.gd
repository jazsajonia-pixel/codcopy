class_name SafeZone
extends RefCounted
## Pure shrinking safe-zone logic (unit-testable). Phases: wait -> shrink toward the next circle.

signal phase_changed(index: int, shrinking: bool)

const DEFAULT_PHASES := [
	{"wait": 40.0, "shrink": 35.0, "radius": 190.0, "dps": 1.5},
	{"wait": 50.0, "shrink": 30.0, "radius": 115.0, "dps": 2.0},
	{"wait": 40.0, "shrink": 25.0, "radius": 72.0, "dps": 4.0},
	{"wait": 30.0, "shrink": 22.0, "radius": 40.0, "dps": 7.0},
	{"wait": 25.0, "shrink": 18.0, "radius": 18.0, "dps": 10.0},
	{"wait": 15.0, "shrink": 15.0, "radius": 0.0, "dps": 16.0},
]

var phases: Array = []
var phase := 0
var shrinking := false
var timer := 0.0
var center := Vector2.ZERO
var radius := 190.0
var start_center := Vector2.ZERO
var start_radius := 190.0
var next_center := Vector2.ZERO
var next_radius := 115.0
var done := false
var rng := RandomNumberGenerator.new()
var land_check: Callable   ## optional: func(Vector2) -> bool, keeps zone centers on land


func setup(p_center: Vector2, p_radius: float, time_scale: float = 1.0, seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	phases = []
	for p in DEFAULT_PHASES:
		var q: Dictionary = p.duplicate()
		q.wait *= time_scale
		q.shrink *= time_scale
		phases.append(q)
	center = p_center
	radius = p_radius
	phase = 0
	shrinking = false
	done = false
	timer = phases[0].wait
	_pick_next()


func _pick_next() -> void:
	start_center = center
	start_radius = radius
	next_radius = phases[phase].radius
	var max_off := maxf(radius - next_radius, 0.0) * 0.8
	for i in 12:
		var a := rng.randf() * TAU
		var cand := center + Vector2(cos(a), sin(a)) * rng.randf() * max_off
		if not land_check.is_valid() or land_check.call(cand):
			next_center = cand
			return
	next_center = center


func tick(delta: float) -> void:
	if done:
		return
	timer -= delta
	if shrinking:
		var p: Dictionary = phases[phase]
		var k := clampf(1.0 - timer / maxf(p.shrink, 0.01), 0.0, 1.0)
		center = start_center.lerp(next_center, k)
		radius = lerpf(start_radius, next_radius, k)
	if timer <= 0.0:
		if not shrinking:
			shrinking = true
			timer = phases[phase].shrink
			phase_changed.emit(phase, true)
		else:
			shrinking = false
			center = next_center
			radius = next_radius
			phase += 1
			if phase >= phases.size():
				done = true
				phase = phases.size() - 1
				phase_changed.emit(phase, false)
				return
			timer = phases[phase].wait
			_pick_next()
			phase_changed.emit(phase, false)


func is_outside(p: Vector2, margin: float = 1.0) -> bool:
	return p.distance_to(center) > radius * margin


func dps() -> float:
	return phases[mini(phase, phases.size() - 1)].dps if phase > 0 or shrinking or done else 1.0


func status() -> String:
	if done:
		return "Final zone"
	if shrinking:
		return "Zone closing  %ds" % ceili(timer)
	return "Zone shrinks in %ds" % ceili(timer)
