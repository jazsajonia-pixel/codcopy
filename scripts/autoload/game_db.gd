extends Node
## Static game content database: weapons (loaded from resources/weapons), attachments,
## equipment, melee, operators, skins, maps and BR items. Pure data, no gameplay logic.

const WEAPON_DIR := "res://resources/weapons/"

var weapons := {} ## id -> WeaponData

## Attachment modifiers: stat -> ["mul", x] or ["add", x]
const ATTACHMENTS := {
	"red_dot": {"slot": "optic", "name": "Red Dot Sight", "optic": "red_dot", "unlock": 1,
		"mods": {"ads_fov": ["mul", 0.95], "ads_time": ["add", 0.01]}, "desc": "Clean 1x reflex sight."},
	"holo": {"slot": "optic", "name": "Holographic Sight", "optic": "holo", "unlock": 3,
		"mods": {"ads_fov": ["mul", 0.9], "ads_time": ["add", 0.02]}, "desc": "Wide 1.5x holographic window."},
	"scope_4x": {"slot": "optic", "name": "4x Tactical Scope", "optic": "4x", "unlock": 5,
		"mods": {"ads_fov": ["set", 32.0], "ads_time": ["add", 0.06]}, "desc": "Mid-range magnified optic."},
	"scope_8x": {"slot": "optic", "name": "8x Sniper Scope", "optic": "8x", "unlock": 7,
		"mods": {"ads_fov": ["set", 16.0], "ads_time": ["add", 0.05], "scope_overlay": ["set", true]}, "desc": "High zoom for long sightlines."},
	"suppressor": {"slot": "muzzle", "name": "Monolithic Suppressor", "unlock": 4,
		"mods": {"effective_range": ["mul", 0.9], "suppressed": ["set", true]}, "desc": "Hides you from enemy radar when firing."},
	"compensator": {"slot": "muzzle", "name": "Compensator", "unlock": 2,
		"mods": {"recoil_vertical": ["mul", 0.82]}, "desc": "Reduces vertical recoil."},
	"flash_guard": {"slot": "muzzle", "name": "Flash Guard", "unlock": 2,
		"mods": {"recoil_horizontal": ["mul", 0.8]}, "desc": "Reduces horizontal recoil and flash."},
	"long_barrel": {"slot": "barrel", "name": "Long Barrel", "unlock": 3,
		"mods": {"effective_range": ["mul", 1.25], "max_range": ["mul", 1.15], "ads_time": ["add", 0.03]}, "desc": "More range, slower ADS."},
	"short_barrel": {"slot": "barrel", "name": "Short Barrel", "unlock": 3,
		"mods": {"hip_spread_deg": ["mul", 0.85], "move_speed_multiplier": ["add", 0.03], "effective_range": ["mul", 0.85]}, "desc": "Better hip fire and mobility, less range."},
	"vertical_grip": {"slot": "grip", "name": "Vertical Foregrip", "unlock": 2,
		"mods": {"recoil_vertical": ["mul", 0.88], "spread_per_shot_deg": ["mul", 0.85]}, "desc": "Steadier sustained fire."},
	"angled_grip": {"slot": "grip", "name": "Angled Grip", "unlock": 4,
		"mods": {"ads_time": ["mul", 0.88]}, "desc": "Faster aim-down-sights."},
	"extended_mag": {"slot": "magazine", "name": "Extended Magazine", "unlock": 4,
		"mods": {"mag_size": ["mul", 1.5], "reload_time": ["mul", 1.15], "reload_empty_time": ["mul", 1.15]}, "desc": "+50% capacity, slower reload."},
	"fast_mag": {"slot": "magazine", "name": "Fast Mag", "unlock": 5,
		"mods": {"reload_time": ["mul", 0.75], "reload_empty_time": ["mul", 0.75]}, "desc": "25% faster reloads."},
	"tactical_stock": {"slot": "stock", "name": "Tactical Stock", "unlock": 3,
		"mods": {"move_spread_deg": ["mul", 0.75], "recoil_recovery": ["mul", 1.15]}, "desc": "Better accuracy while moving."},
	"no_stock": {"slot": "stock", "name": "No Stock", "unlock": 6,
		"mods": {"ads_time": ["mul", 0.82], "move_speed_multiplier": ["add", 0.04], "recoil_vertical": ["mul", 1.15]}, "desc": "Fast and light, more recoil."},
}

const SLOTS := ["optic", "muzzle", "barrel", "grip", "magazine", "stock"]

const MELEE := {
	"knife": {"name": "Combat Knife", "damage": 100.0, "range": 2.2, "cooldown": 0.6, "unlock": 1},
	"hatchet": {"name": "Field Hatchet", "damage": 100.0, "range": 2.6, "cooldown": 0.85, "unlock": 2},
	"baton": {"name": "Tactical Baton", "damage": 70.0, "range": 2.4, "cooldown": 0.45, "unlock": 6},
}

const EQUIPMENT := {
	"frag": {"name": "Frag Grenade", "kind": "lethal", "fuse": 2.6, "radius": 7.0, "damage": 140.0, "count": 1, "model": "res://assets/weapons/grenade-a.glb", "unlock": 1},
	"semtex": {"name": "Sticky Charge", "kind": "lethal", "fuse": 1.6, "radius": 5.5, "damage": 150.0, "count": 1, "sticky": true, "model": "res://assets/weapons/grenade-b.glb", "unlock": 4},
	"smoke": {"name": "Smoke Grenade", "kind": "tactical", "fuse": 1.4, "radius": 6.0, "duration": 12.0, "count": 1, "model": "res://assets/weapons/grenade-b.glb", "unlock": 1},
	"flash": {"name": "Flash Grenade", "kind": "tactical", "fuse": 1.5, "radius": 10.0, "duration": 2.5, "count": 2, "model": "res://assets/weapons/grenade-a.glb", "unlock": 3},
}

const OPERATORS := [
	{"id": "op_ranger", "name": "Ranger", "faction": "Vanguard", "model": "res://assets/characters/character-male-a.glb", "unlock": 1, "bio": "Recon specialist from the northern highlands."},
	{"id": "op_viper", "name": "Viper", "faction": "Vanguard", "model": "res://assets/characters/character-female-a.glb", "unlock": 1, "bio": "Close-quarters breacher."},
	{"id": "op_atlas", "name": "Atlas", "faction": "Vanguard", "model": "res://assets/characters/character-male-b.glb", "unlock": 2, "bio": "Heavy weapons operator."},
	{"id": "op_echo", "name": "Echo", "faction": "Vanguard", "model": "res://assets/characters/character-female-b.glb", "unlock": 3, "bio": "Signals and electronic warfare."},
	{"id": "op_bishop", "name": "Bishop", "faction": "Vanguard", "model": "res://assets/characters/character-male-c.glb", "unlock": 5, "bio": "Veteran squad leader."},
	{"id": "op_nova", "name": "Nova", "faction": "Vanguard", "model": "res://assets/characters/character-female-c.glb", "unlock": 7, "bio": "Combat medic and marksman."},
	{"id": "op_kraken", "name": "Kraken", "faction": "Syndicate", "model": "res://assets/characters/character-male-d.glb", "unlock": 9, "bio": "Former naval commando."},
	{"id": "op_raven", "name": "Raven", "faction": "Syndicate", "model": "res://assets/characters/character-female-d.glb", "unlock": 11, "bio": "Night operations expert."},
	{"id": "op_ghoul", "name": "Ghoul", "faction": "Syndicate", "model": "res://assets/characters/character-male-e.glb", "unlock": 13, "bio": "Demolitions and sabotage."},
	{"id": "op_lynx", "name": "Lynx", "faction": "Syndicate", "model": "res://assets/characters/character-female-e.glb", "unlock": 15, "bio": "Long-range infiltrator."},
	{"id": "op_titan", "name": "Titan", "faction": "Syndicate", "model": "res://assets/characters/character-male-f.glb", "unlock": 18, "bio": "Juggernaut assault lead."},
	{"id": "op_zero", "name": "Zero", "faction": "Syndicate", "model": "res://assets/characters/character-female-f.glb", "unlock": 20, "bio": "Classified."},
]

## Weapon skins are material tints layered over the original model.
const SKINS := {
	"default": {"name": "Factory", "color": Color(1, 1, 1, 0.0), "unlock": 1},
	"woodland": {"name": "Woodland", "color": Color(0.25, 0.42, 0.18, 0.45), "unlock": 2},
	"desert": {"name": "Desert Tan", "color": Color(0.78, 0.64, 0.4, 0.45), "unlock": 4},
	"arctic": {"name": "Arctic", "color": Color(0.9, 0.95, 1.0, 0.5), "unlock": 6},
	"crimson": {"name": "Crimson", "color": Color(0.7, 0.08, 0.08, 0.45), "unlock": 9},
	"cobalt": {"name": "Cobalt", "color": Color(0.1, 0.3, 0.85, 0.45), "unlock": 12},
	"gold": {"name": "Gold", "color": Color(1.0, 0.78, 0.15, 0.6), "unlock": 15},
}

const MP_MODES := {
	"tdm": {"name": "Team Deathmatch", "desc": "5v5. First team to the score limit wins.", "score_limit": 40, "time_limit": 480.0, "team_size": 5},
	"dom": {"name": "Domination", "desc": "5v5. Capture and hold flags A, B and C. Each held flag scores a point every 2 seconds.", "score_limit": 100, "time_limit": 600.0, "team_size": 5},
	"ffa": {"name": "Free-For-All", "desc": "Every operator for themselves. First to 20 kills.", "score_limit": 20, "time_limit": 480.0, "players": 8},
}

const MP_MAPS := {
	"outpost": {"name": "Outpost", "desc": "Fortified desert outpost with a central compound.", "scene": "res://scenes/maps/outpost.tscn"},
	"crossroads": {"name": "Crossroads", "desc": "Urban intersection with shops and rooftops.", "scene": "res://scenes/maps/crossroads.tscn"},
}

const BR_ITEMS := {
	"ammo_rifle": {"name": "Rifle Ammo", "kind": "ammo", "ammo": "rifle", "amount": 60},
	"ammo_smg": {"name": "SMG Ammo", "kind": "ammo", "ammo": "smg", "amount": 70},
	"ammo_shotgun": {"name": "Shotgun Shells", "kind": "ammo", "ammo": "shotgun", "amount": 16},
	"ammo_sniper": {"name": "Sniper Ammo", "kind": "ammo", "ammo": "sniper", "amount": 15},
	"ammo_pistol": {"name": "Pistol Ammo", "kind": "ammo", "ammo": "pistol", "amount": 40},
	"armor_1": {"name": "Light Vest", "kind": "armor", "armor": 50.0, "tier": 1},
	"armor_2": {"name": "Tactical Vest", "kind": "armor", "armor": 100.0, "tier": 2},
	"armor_3": {"name": "Heavy Plate Carrier", "kind": "armor", "armor": 150.0, "tier": 3},
	"medkit": {"name": "Med Kit", "kind": "heal", "heal": 100.0, "use_time": 3.0, "max_stack": 5},
	"bandage": {"name": "Field Bandage", "kind": "heal", "heal": 30.0, "use_time": 1.5, "max_stack": 10},
	"plate": {"name": "Armor Plate", "kind": "plate", "armor": 50.0, "use_time": 2.0, "max_stack": 5},
	"frag": {"name": "Frag Grenade", "kind": "grenade", "equip": "frag"},
	"smoke": {"name": "Smoke Grenade", "kind": "grenade", "equip": "smoke"},
}

const ITEM_COLORS := {
	"weapon": Color(0.95, 0.75, 0.2), "ammo": Color(0.55, 0.8, 0.35), "armor": Color(0.35, 0.6, 1.0),
	"heal": Color(1.0, 0.35, 0.35), "plate": Color(0.5, 0.7, 1.0), "grenade": Color(0.9, 0.5, 0.2),
}


func _ready() -> void:
	load_weapons()


func load_weapons() -> void:
	weapons.clear()
	var dir := DirAccess.open(WEAPON_DIR)
	if dir == null:
		push_error("GameDB: weapon folder missing")
		return
	for f in dir.get_files():
		# Exported builds may list remapped files (.tres.remap); strip that suffix.
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var w := load(WEAPON_DIR + file) as WeaponData
		if w and not w.id.is_empty():
			weapons[w.id] = w


func get_weapon(id: String) -> WeaponData:
	return weapons.get(id)


const SECONDARY_CATEGORIES := ["PISTOL", "SMG", "SHOTGUN"]

## Primary slot accepts everything except pistols. Secondary slot accepts pistols, SMGs and shotguns.
func weapon_ids_for_slot(slot: String) -> Array:
	var out: Array = []
	for id in weapons.keys():
		var cat: String = weapons[id].category
		if (slot == "primary" and cat != "PISTOL") or (slot == "secondary" and cat in SECONDARY_CATEGORIES):
			out.append(id)
	out.sort_custom(func(a, b): return weapons[a].unlock_level < weapons[b].unlock_level or (weapons[a].unlock_level == weapons[b].unlock_level and a < b))
	return out


func get_operator(id: String) -> Dictionary:
	for o in OPERATORS:
		if o.id == id:
			return o
	return OPERATORS[0]


## Builds the effective stats of a weapon after applying attachments.
## Returns a Dictionary with every numeric/bool stat plus "optic" and "suppressed".
func build_stats(weapon_id: String, attachments: Dictionary = {}) -> Dictionary:
	var w: WeaponData = get_weapon(weapon_id)
	if w == null:
		return {}
	var s := {
		"damage": w.damage, "headshot_multiplier": w.headshot_multiplier, "pellets": w.pellets,
		"effective_range": w.effective_range, "max_range": w.max_range, "falloff_multiplier": w.falloff_multiplier,
		"fire_rate_rpm": w.fire_rate_rpm, "mag_size": float(w.mag_size), "reserve_ammo": w.reserve_ammo,
		"reload_time": w.reload_time, "reload_empty_time": w.reload_empty_time, "ads_time": w.ads_time,
		"move_speed_multiplier": w.move_speed_multiplier, "ads_fov": w.ads_fov, "scope_overlay": w.scope_overlay,
		"hip_spread_deg": w.hip_spread_deg, "ads_spread_deg": w.ads_spread_deg, "move_spread_deg": w.move_spread_deg,
		"spread_per_shot_deg": w.spread_per_shot_deg, "max_bloom_deg": w.max_bloom_deg,
		"recoil_vertical": w.recoil_vertical, "recoil_horizontal": w.recoil_horizontal, "recoil_recovery": w.recoil_recovery,
		"optic": "iron" if not w.scope_overlay else "8x", "suppressed": false,
	}
	for slot in attachments.keys():
		var att_id: String = attachments[slot]
		if att_id.is_empty() or not ATTACHMENTS.has(att_id):
			continue
		if not w.allowed_attachments.has(slot) or not (att_id in w.allowed_attachments[slot]):
			continue
		var a: Dictionary = ATTACHMENTS[att_id]
		if a.has("optic"):
			s.optic = a.optic
		for stat in a.mods.keys():
			var op: Array = a.mods[stat]
			match op[0]:
				"mul": s[stat] = s.get(stat, 0.0) * op[1]
				"add": s[stat] = s.get(stat, 0.0) + op[1]
				"set": s[stat] = op[1]
	s.mag_size = int(round(s.mag_size))
	return s


## Normalized 0..1 bars for the loadout comparison UI.
func stat_bars(stats: Dictionary) -> Dictionary:
	var dps: float = stats.damage * stats.pellets * stats.fire_rate_rpm / 60.0
	return {
		"Damage": clampf(stats.damage * stats.pellets / 120.0, 0, 1),
		"Fire Rate": clampf(stats.fire_rate_rpm / 1100.0, 0, 1),
		"Range": clampf(stats.effective_range / 120.0, 0, 1),
		"Accuracy": clampf(1.0 - (stats.hip_spread_deg / 8.0) * 0.5 - (stats.recoil_vertical / 3.0) * 0.5, 0, 1),
		"Mobility": clampf((stats.move_speed_multiplier - 0.8) / 0.32, 0, 1),
		"Handling": clampf(1.0 - stats.ads_time / 0.45, 0, 1),
		"DPS": clampf(dps / 450.0, 0, 1),
	}
