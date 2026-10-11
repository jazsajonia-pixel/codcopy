class_name WeaponInstance
extends RefCounted
## Runtime state of one carried weapon: magazine, reserve, cooldown, reload and bloom.
## Stats come from GameDB.build_stats(), so attachments are already applied.

signal reloaded
signal fired

var data: WeaponData
var stats: Dictionary
var attachments: Dictionary
var skin: String = "default"
var mag: int = 0
var _reserve: int = 0
var inventory: WeakRef = null ## Inventory; when it uses shared ammo pools (BR), reserve comes from there.

var cooldown := 0.0
var reloading := false
var reload_left := 0.0
var reload_total := 0.0
var bloom := 0.0
var _trigger_released := true


static func create(weapon_id: String, p_attachments: Dictionary = {}, p_skin: String = "default", full_reserve: bool = true) -> WeaponInstance:
	var w := WeaponInstance.new()
	w.data = GameDB.get_weapon(weapon_id)
	if w.data == null:
		push_error("Unknown weapon: %s" % weapon_id)
		return null
	w.attachments = p_attachments.duplicate()
	w.skin = p_skin
	w.stats = GameDB.build_stats(weapon_id, w.attachments)
	w.mag = int(w.stats.mag_size)
	w._reserve = int(w.stats.reserve_ammo) if full_reserve else 0
	return w


func id() -> String:
	return data.id


func _inv():
	return inventory.get_ref() if inventory else null


func get_reserve() -> int:
	var inv = _inv()
	if inv and inv.use_ammo_pools:
		return inv.get_ammo(data.ammo_type)
	return _reserve


func _take_reserve(n: int) -> int:
	var inv = _inv()
	if inv and inv.use_ammo_pools:
		return inv.take_ammo(data.ammo_type, n)
	var t := mini(n, _reserve)
	_reserve -= t
	return t


func add_reserve(n: int) -> void:
	_reserve += n


func mag_size() -> int:
	return int(stats.mag_size)


func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	bloom = maxf(bloom - delta * stats.max_bloom_deg * 2.5, 0.0)
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			_finish_reload()


## Call every physics frame with the trigger state. Returns true when a shot should be fired now.
func try_fire(trigger_down: bool) -> bool:
	if not trigger_down:
		_trigger_released = true
		return false
	if reloading:
		# Shotguns and bolt rifles can interrupt a reload to fire if a round is loaded.
		if mag > 0 and (data.fire_mode == WeaponData.FireMode.PUMP):
			cancel_reload()
		else:
			return false
	if cooldown > 0.0:
		return false
	if mag <= 0:
		if _trigger_released:
			_trigger_released = false
			AudioManager.play_2d("res://assets/audio/weapons/dryfire.ogg", -8.0)
		return false
	if data.fire_mode != WeaponData.FireMode.AUTO and not _trigger_released:
		return false
	_trigger_released = false
	mag -= 1
	cooldown = 60.0 / maxf(float(stats.fire_rate_rpm), 1.0)
	bloom = minf(bloom + stats.spread_per_shot_deg, stats.max_bloom_deg)
	fired.emit()
	return true


func can_reload() -> bool:
	return not reloading and mag < mag_size() and get_reserve() > 0


func start_reload() -> bool:
	if not can_reload():
		return false
	reloading = true
	reload_total = stats.reload_empty_time if mag == 0 else stats.reload_time
	reload_left = reload_total
	return true


func cancel_reload() -> void:
	reloading = false
	reload_left = 0.0


func _finish_reload() -> void:
	reloading = false
	var need := mag_size() - mag
	mag += _take_reserve(need)
	reloaded.emit()


func reload_progress() -> float:
	if not reloading or reload_total <= 0.0:
		return 0.0
	return 1.0 - reload_left / reload_total


## Total cone half-angle in degrees for the next shot. The HUD crosshair draws exactly this cone.
func spread_deg(ads: bool, moving: bool, airborne: bool, sliding: bool = false, crouched: bool = false) -> float:
	var s: float = stats.ads_spread_deg if ads else stats.hip_spread_deg
	if crouched and not ads:
		s *= 0.8
	if moving:
		s += stats.move_spread_deg * (0.35 if ads else 1.0)
	if airborne:
		s += 2.5
	if sliding:
		s += 0.8
	return s + bloom
