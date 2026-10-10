class_name Actor
extends CharacterBody3D
## Shared base for the player and bots: health, armor, team, inventory, weapon firing,
## equipment, melee, healing and death. Movement/aiming lives in subclasses.

signal died(victim: Actor, killer: Actor, weapon_name: String, headshot: bool)
signal damaged(amount: float, from_pos: Vector3, attacker: Actor)
signal shot_fired(actor: Actor, suppressed: bool)
signal hit_confirmed(headshot: bool, killed: bool)
signal item_used(item_id: String)
signal knocked(victim: Actor, attacker: Actor, weapon_name: String)
signal revived(victim: Actor, reviver: Actor)

const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const DOWNED_HEIGHT := 0.9
const DOWN_HEALTH := 100.0     ## "bleed" health while knocked down
const BLEED_TIME := 30.0       ## seconds until a downed operator dies on their own
const REVIVE_TIME := 4.0       ## seconds a teammate must hold interact
const REVIVE_HEALTH := 35.0

## Squad knock-down state (Battle Royale duos/squads). Solo and Multiplayer never enable it.
var can_be_downed := false
var down_check := Callable()   ## optional: returns false if this actor must die instead (squad wiped)
var downed := false
var knocked_by: Actor = null
var knocked_weapon := ""
var revive_progress := 0.0
var reviver: Actor = null
var _revive_touch := 0.0
const RADIUS := 0.38
const GRAVITY := 22.0

var actor_name := "Operator"
var team := 0                 ## FFA uses a unique team per actor
var is_player := false
var max_health := 100.0
var health := 100.0
var armor := 0.0
var max_armor := 0.0
var armor_tier := 0
var alive := true
var kills := 0
var deaths := 0
var assists := 0
var score := 0
var streak := 0
var shots_fired := 0
var shots_hit := 0
var headshot_kills := 0
var regen_enabled := true
var regen_delay := 4.0
var regen_rate := 30.0
var invulnerable_time := 0.0
var current_height := HEIGHT

var inv := Inventory.new()
var operator_id := "op_ranger"

var _since_damage := 99.0
var _damagers := {}           ## Actor -> last damage time (msec), for assists
var flash_time := 0.0
var shake := 0.0
var melee_cooldown := 0.0
var equip_cooldown := 0.0

## Timed item usage (heal/plate)
var using_item := ""
var use_left := 0.0
var use_total := 0.0

var collision: CollisionShape3D
var vehicle: Vehicle = null     ## vehicle this actor is sitting in
var vehicle_seat := -1
var capsule: CapsuleShape3D


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)


func _ready() -> void:
	add_to_group("actors")
	if collision == null:
		capsule = CapsuleShape3D.new()
		capsule.radius = RADIUS
		capsule.height = HEIGHT
		collision = CollisionShape3D.new()
		collision.shape = capsule
		collision.position.y = HEIGHT * 0.5
		add_child(collision)


func set_height(h: float) -> void:
	current_height = h
	capsule.height = h
	collision.position.y = h * 0.5


func parachute_active() -> bool:
	return false


func is_enemy(other: Actor) -> bool:
	return other != null and other != self and other.team != team


func is_headshot(hit_pos: Vector3) -> bool:
	return hit_pos.y - global_position.y > current_height * 0.8


func eye_position() -> Vector3:
	return global_position + Vector3.UP * (current_height - 0.15)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * current_height * 0.62


func head_point() -> Vector3:
	return global_position + Vector3.UP * (current_height - 0.2)


## Returns true if this damage killed the actor.
func take_damage(amount: float, attacker: Actor, weapon_name: String = "", headshot: bool = false, from_pos: Vector3 = Vector3.ZERO) -> bool:
	if not alive or amount <= 0.0:
		return false
	if attacker != null and attacker != self and not attacker.is_enemy(self):
		return false
	if invulnerable_time > 0.0 and attacker != null:
		return false
	var dmg := amount
	if armor > 0.0 and attacker != null:
		var absorbed := minf(armor, dmg * 0.75)
		armor -= absorbed
		dmg -= absorbed
	health -= dmg
	_since_damage = 0.0
	if attacker and attacker != self:
		_damagers[attacker] = Time.get_ticks_msec()
		attacker.shots_hit += 1
		attacker.hit_confirmed.emit(headshot, health <= 0.0)
	_cancel_use()
	damaged.emit(amount, from_pos, attacker)
	if health <= 0.0:
		if can_be_downed and not downed and (not down_check.is_valid() or down_check.call(self)):
			_knock(attacker, weapon_name)
			return false
		health = 0.0
		_die(attacker if attacker else knocked_by, weapon_name if attacker else knocked_weapon, headshot)
		return true
	return false


func _knock(attacker: Actor, weapon_name: String) -> void:
	if vehicle and is_instance_valid(vehicle):
		vehicle.exit(self)
	downed = true
	health = DOWN_HEALTH
	armor = 0.0
	knocked_by = attacker
	knocked_weapon = weapon_name
	revive_progress = 0.0
	_cancel_use()
	for w in inv.weapons:
		if w:
			w.cancel_reload()
	set_height(DOWNED_HEIGHT)
	_on_knocked()
	knocked.emit(self, attacker, weapon_name)


## A teammate holds interact on this downed actor. Returns true when the revive completes.
func revive_tick(by: Actor, delta: float) -> bool:
	if not downed or not alive or by == null or not by.alive or by.downed or by.is_enemy(self):
		return false
	if reviver != null and reviver != by and _revive_touch > 0.0 and is_instance_valid(reviver):
		return false   # someone else is already reviving; no stacking
	reviver = by
	_revive_touch = 0.25
	revive_progress += delta / REVIVE_TIME
	if revive_progress < 1.0:
		return false
	downed = false
	revive_progress = 0.0
	reviver = null
	health = REVIVE_HEALTH
	knocked_by = null
	set_height(HEIGHT)
	by.score += 50
	_on_revived()
	revived.emit(self, by)
	return true


## Kill a downed actor outright (e.g. the rest of the squad was eliminated).
func finish_off() -> void:
	if alive and downed:
		health = 0.0
		_die(knocked_by, knocked_weapon if knocked_weapon != "" else "Bled out", false)


func _on_knocked() -> void:
	pass


func _on_revived() -> void:
	pass


func _die(killer: Actor, weapon_name: String, headshot: bool) -> void:
	if vehicle and is_instance_valid(vehicle):
		vehicle.exit(self)
	alive = false
	downed = false
	revive_progress = 0.0
	deaths += 1
	streak = 0
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	var now := Time.get_ticks_msec()
	for a in _damagers.keys():
		if is_instance_valid(a) and a != killer and now - int(_damagers[a]) < 10000:
			a.assists += 1
			a.score += 40
	_damagers.clear()
	_on_died()
	died.emit(self, killer, weapon_name, headshot)


## Vehicle hooks (overridden by Player for cameras/HUD).
func on_enter_vehicle(_v: Vehicle, seat: int) -> void:
	vehicle_seat = seat
	velocity = Vector3.ZERO
	# Take the body out of physics immediately (a deferred disable lets it push the car for a frame).
	collision_layer = 0
	collision_mask = 0
	collision.set_deferred("disabled", true)
	_cancel_use()
	for w in inv.weapons:
		if w:
			w.cancel_reload()
	_set_body_visible(false)


func on_exit_vehicle(v: Vehicle, pos: Vector3) -> void:
	vehicle_seat = -1
	global_position = pos
	velocity = v.linear_velocity * 0.4 if v else Vector3.ZERO
	collision_layer = 2
	collision_mask = 1 | 2
	collision.set_deferred("disabled", not alive)
	_set_body_visible(true)


## Occupants stay "visible" for game logic (zone, targeting); only their models are hidden.
func _set_body_visible(v: bool) -> void:
	for c in get_children():
		if c is Node3D and not (c is CollisionShape3D) and not (c is Camera3D) and c.name != "Head":
			(c as Node3D).visible = v


## Hook for subclasses (animations, camera).
func _on_died() -> void:
	pass


func respawn_at(xform: Transform3D) -> void:
	global_transform = xform
	health = max_health
	alive = true
	velocity = Vector3.ZERO
	flash_time = 0.0
	invulnerable_time = 2.0
	_since_damage = 99.0
	collision.set_deferred("disabled", false)
	inv.refill_equipment()
	for w in inv.weapons:
		if w:
			w.mag = w.mag_size()
			w._reserve = int(w.stats.reserve_ammo)
			w.cancel_reload()
	_on_respawned()


func _on_respawned() -> void:
	pass


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)


func add_shake(v: float) -> void:
	shake = minf(shake + v, 1.5)


func apply_flash(duration: float) -> void:
	flash_time = maxf(flash_time, duration)


func tick_common(delta: float) -> void:
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	flash_time = maxf(flash_time - delta, 0.0)
	shake = maxf(shake - delta * 2.5, 0.0)
	melee_cooldown = maxf(melee_cooldown - delta, 0.0)
	equip_cooldown = maxf(equip_cooldown - delta, 0.0)
	_since_damage += delta
	if alive and regen_enabled and _since_damage > regen_delay and health < max_health:
		health = minf(health + regen_rate * delta, max_health)
	var w := inv.active()
	if w:
		w.tick(delta)
	if downed and alive:
		if _revive_touch > 0.0:
			_revive_touch -= delta     # being revived: bleed-out pauses
		else:
			revive_progress = 0.0
			reviver = null
			health -= DOWN_HEALTH / BLEED_TIME * delta
			if health <= 0.0:
				health = 0.0
				_die(knocked_by, knocked_weapon if knocked_weapon != "" else "Bled out", false)
				return
	if using_item != "":
		use_left -= delta
		if use_left <= 0.0:
			_finish_use()


# ---------------- Weapons ----------------

## Fire the active weapon if possible. `trigger` is the held state this frame.
func process_trigger(trigger: bool, origin: Vector3, dir: Vector3, muzzle: Vector3, ads: bool, moving: bool) -> Dictionary:
	var w := inv.active()
	if w == null or not alive or downed or using_item != "":
		return {}
	if not w.try_fire(trigger):
		if trigger and w.mag == 0 and not w.reloading:
			w.start_reload()
			_on_reload_started(w)
		return {}
	var spread := w.spread_deg(ads, moving, not is_on_floor())
	var res := Combat.fire_hitscan(self, origin, dir, w, spread, muzzle, true)
	var loud: bool = not w.stats.suppressed
	AudioManager.play_3d(w.data.fire_sound, muzzle, -2.0 if loud else -16.0, randf_range(0.95, 1.05), 160.0 if loud else 30.0)
	shot_fired.emit(self, not loud)
	shots_fired += 1
	_on_shot(w, res)
	if w.mag == 0 and w.get_reserve() > 0:
		w.start_reload()
		_on_reload_started(w)
	return res


func request_reload() -> bool:
	var w := inv.active()
	if w and alive and w.start_reload():
		_on_reload_started(w)
		return true
	return false


func _on_shot(_w: WeaponInstance, _res: Dictionary) -> void:
	pass


func _on_reload_started(w: WeaponInstance) -> void:
	AudioManager.play_3d(w.data.reload_sound, global_position + Vector3.UP, -6.0, 1.0, 30.0)


func do_melee(origin: Vector3, dir: Vector3) -> bool:
	if melee_cooldown > 0.0 or not alive or downed:
		return false
	var m: Dictionary = GameDB.MELEE.get(inv.melee, GameDB.MELEE.knife)
	melee_cooldown = m.cooldown
	AudioManager.play_3d("res://assets/audio/sfx/melee.ogg", origin, -6.0, randf_range(0.9, 1.1), 20.0)
	return Combat.melee(self, origin, dir, m.range, m.damage, m.name)


## kind: "lethal" | "tactical". Returns true if thrown.
func throw_equipment(kind: String, origin: Vector3, dir: Vector3) -> bool:
	if equip_cooldown > 0.0 or not alive or downed:
		return false
	var eid := inv.lethal if kind == "lethal" else inv.tactical
	var count := inv.lethal_count if kind == "lethal" else inv.tactical_count
	if eid.is_empty() or count <= 0:
		return false
	if kind == "lethal":
		inv.lethal_count -= 1
	else:
		inv.tactical_count -= 1
	equip_cooldown = 0.8
	var g := Grenade.new()
	g.setup(self, eid)
	get_tree().current_scene.add_child(g)
	g.global_position = origin + dir * 0.6
	g.linear_velocity = dir * 17.0 + Vector3.UP * 3.5 + velocity * 0.5
	inv.changed.emit()
	return true


# ---------------- Items (BR) ----------------

func start_use(item_id: String) -> bool:
	if using_item != "" or not alive or downed:
		return false
	var it: Dictionary = GameDB.BR_ITEMS.get(item_id, {})
	if it.is_empty():
		return false
	if it.kind == "heal":
		if inv.heals.get(item_id, 0) <= 0 or health >= max_health:
			return false
	elif it.kind == "plate":
		if inv.plates <= 0 or max_armor <= 0.0 or armor >= max_armor:
			return false
	else:
		return false
	var w := inv.active()
	if w:
		w.cancel_reload()
	using_item = item_id
	use_total = it.use_time
	use_left = use_total
	return true


func _cancel_use() -> void:
	using_item = ""
	use_left = 0.0


func _finish_use() -> void:
	var it: Dictionary = GameDB.BR_ITEMS[using_item]
	if it.kind == "heal":
		inv.heals[using_item] = inv.heals.get(using_item, 0) - 1
		heal(it.heal)
	elif it.kind == "plate":
		inv.plates -= 1
		armor = minf(armor + it.armor, max_armor)
	var used := using_item
	using_item = ""
	inv.changed.emit()
	item_used.emit(used)


func equip_armor(tier: int, amount: float) -> bool:
	if tier < armor_tier or (tier == armor_tier and armor >= max_armor):
		return false
	armor_tier = tier
	max_armor = amount
	armor = amount
	return true
