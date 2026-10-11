class_name DropPhysics
extends RefCounted
## Shared flight model for the Battle Royale drop (player and bots).
##
## Wingsuit: gravity vs. quadratic drag gives a terminal sink rate that depends on body attitude
## (level glide ~13 m/s, belly-flop ~20 m/s, head-down dive ~52 m/s). Forward speed builds with
## inertia (~30 m/s gliding) and excess dive speed converts into forward speed when you pull out.
## Parachute: the canopy inflates over ~1 s (opening shock), then descends at ~4 m/s and flies
## forward slowly (max ~8 m/s) with sluggish steering. Pulling back flares (slower sink, brakes).

const G := 9.8
const MAX_DRAG := 40.0           ## m/s^2 cap (~4 g) keeps the opening shock stable
const GLIDE_SINK := 13.0
const BELLY_SINK := 20.0
const DIVE_SINK := 52.0
const GLIDE_FWD := 30.0
const DRIFT_FWD := 6.0
const DIVE_FWD := 14.0
const CHUTE_SINK := 4.2
const FLARE_SINK := 2.6
const CHUTE_FWD := 8.0
const CHUTE_IDLE_FWD := 2.0      ## canopies always fly forward a little
const INFLATE_TIME := 1.1


## v: current velocity. wish: horizontal steering vector (length 0..1, world space).
## facing: horizontal unit vector the jumper faces. dive: 0..1 (looking down). brake: 0..1 (flare).
## inflate: 0..1 canopy inflation (ignored for the wingsuit). Returns the new velocity.
static func step(v: Vector3, wish: Vector3, facing: Vector3, dive: float, chute: bool, inflate: float, brake: float, delta: float) -> Vector3:
	var vh := Vector3(v.x, 0.0, v.z)
	var vy := v.y
	var vt: float
	var push := clampf(wish.length(), 0.0, 1.0)
	if not chute:
		vt = lerpf(lerpf(BELLY_SINK, GLIDE_SINK, push), DIVE_SINK, dive)
		var target_h := lerpf(lerpf(DRIFT_FWD, GLIDE_FWD, push), DIVE_FWD, dive)
		var excess := maxf(-vy - vt, 0.0)      # falling faster than this attitude allows -> swoop
		var dir := wish.normalized() if push > 0.05 else (vh.normalized() if vh.length() > 0.5 else facing)
		var want_h := dir * (target_h + excess * 0.6)
		vh += (want_h - vh) * clampf(delta * 0.9, 0.0, 1.0)
	else:
		var k := ease(clampf(inflate, 0.0, 1.0), 0.6)
		vt = lerpf(30.0, lerpf(CHUTE_SINK, FLARE_SINK, brake), k)
		var dir := wish.normalized() if push > 0.05 else facing
		var spd := lerpf(CHUTE_IDLE_FWD, CHUTE_FWD, push) * (1.0 - 0.65 * brake)
		# Inflating canopy bleeds speed fast; afterwards steering is slow and floaty.
		vh = vh.move_toward(dir * spd, delta * lerpf(9.0, 2.2, k))
	# Vertical: gravity minus quadratic drag (only opposes downward motion).
	var drag := 0.0
	if vy < 0.0:
		drag = minf(G * (vy / vt) * (vy / vt), MAX_DRAG)
	vy += (-G + drag) * delta
	return Vector3(vh.x, vy, vh.z)
