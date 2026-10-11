class_name Inventory
extends RefCounted
## Carried items shared by the player and bots in both modes.
## Multiplayer: weapons keep their own reserve ammo. Battle Royale: shared ammo pools by type.

signal changed

const MAX_WEAPONS := 2
const MAX_AMMO := {"rifle": 240, "smg": 280, "shotgun": 48, "sniper": 40, "pistol": 150, "rocket": 8}

var weapons: Array = [null, null] ## WeaponInstance per slot
var current := 0
var holstered := false            ## fists / melee out (player weapon bar); active() returns null
var use_ammo_pools := false
var ammo := {"rifle": 0, "smg": 0, "shotgun": 0, "sniper": 0, "pistol": 0, "rocket": 0}
var lethal := ""
var lethal_count := 0
var tactical := ""
var tactical_count := 0
var melee := "knife"
var heals := {"medkit": 0, "bandage": 0}
var plates := 0


func active() -> WeaponInstance:
	if holstered:
		return null
	var w = weapons[current]
	if w == null:
		for i in MAX_WEAPONS:
			if weapons[i] != null:
				current = i
				return weapons[i]
	return w


func has_any_weapon() -> bool:
	return weapons[0] != null or weapons[1] != null


func set_weapon(slot: int, w: WeaponInstance) -> WeaponInstance:
	var old = weapons[slot]
	if w:
		w.inventory = weakref(self)
	weapons[slot] = w
	changed.emit()
	return old


func switch_to(slot: int) -> bool:
	if slot < 0 or slot >= MAX_WEAPONS or weapons[slot] == null or (slot == current and not holstered):
		return false
	var a := active()
	if a:
		a.cancel_reload()
	holstered = false
	current = slot
	changed.emit()
	return true


## Next weapon. With a single gun (Multiplayer) this toggles between the gun and the melee weapon.
func cycle() -> bool:
	if holstered:
		return switch_to(current) or switch_to((current + 1) % MAX_WEAPONS)
	if switch_to((current + 1) % MAX_WEAPONS):
		return true
	return weapons[(current + 1) % MAX_WEAPONS] == null and has_any_weapon() and holster()


## Put weapons away (fists / melee). Returns false if already holstered.
func holster() -> bool:
	if holstered:
		return false
	var a := active()
	if a:
		a.cancel_reload()
	holstered = true
	changed.emit()
	return true


## BR pickup: fills an empty slot or replaces the active weapon. Returns the dropped weapon (or null).
func pick_up_weapon(w: WeaponInstance, equip: bool = true) -> WeaponInstance:
	for i in MAX_WEAPONS:
		if weapons[i] == null:
			if equip or not has_any_weapon() or holstered:
				current = i
				holstered = false
			set_weapon(i, w)
			return null
	holstered = false
	var dropped = set_weapon(current, w)
	return dropped


func get_ammo(t: String) -> int:
	return int(ammo.get(t, 0))


func take_ammo(t: String, n: int) -> int:
	var have := get_ammo(t)
	var taken := mini(have, n)
	ammo[t] = have - taken
	changed.emit()
	return taken


## Returns the amount actually added (capped).
func add_ammo(t: String, n: int) -> int:
	var cap: int = MAX_AMMO.get(t, 999)
	var have := get_ammo(t)
	var added := clampi(cap - have, 0, n)
	ammo[t] = have + added
	changed.emit()
	return added


func add_heal(item_id: String, n: int = 1) -> int:
	var cap: int = GameDB.BR_ITEMS[item_id].get("max_stack", 5)
	var have: int = heals.get(item_id, 0)
	var added := clampi(cap - have, 0, n)
	heals[item_id] = have + added
	changed.emit()
	return added


func best_heal() -> String:
	if heals.get("medkit", 0) > 0:
		return "medkit"
	if heals.get("bandage", 0) > 0:
		return "bandage"
	return ""


## Fill from a saved loadout (Multiplayer). Multiplayer is one gun + melee (CODM-lite rules):
## the secondary slot stays empty unless the caller explicitly passes with_secondary.
func load_from_loadout(lo: Dictionary, with_secondary: bool = false) -> void:
	use_ammo_pools = false
	var att: Dictionary = lo.get("attachments", {})
	var skins: Dictionary = lo.get("skins", {})
	set_weapon(0, WeaponInstance.create(lo.primary, att.get(lo.primary, {}), skins.get(lo.primary, "default")))
	var sec: String = lo.get("secondary", "")
	set_weapon(1, WeaponInstance.create(sec, att.get(sec, {}), skins.get(sec, "default")) if with_secondary and sec != "" else null)
	current = 0
	holstered = false
	melee = lo.get("melee", "knife")
	lethal = lo.get("lethal", "frag")
	lethal_count = GameDB.EQUIPMENT.get(lethal, {}).get("count", 1)
	tactical = lo.get("tactical", "smoke")
	tactical_count = GameDB.EQUIPMENT.get(tactical, {}).get("count", 1)
	changed.emit()


func refill_equipment() -> void:
	lethal_count = GameDB.EQUIPMENT.get(lethal, {}).get("count", 1) if not lethal.is_empty() else 0
	tactical_count = GameDB.EQUIPMENT.get(tactical, {}).get("count", 1) if not tactical.is_empty() else 0
