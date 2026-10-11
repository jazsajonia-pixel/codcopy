extends Node
## Persistent player data: settings (ConfigFile), profile/progression, loadouts and HUD layout (JSON).
## All data lives in user:// so it survives app restarts on desktop and Android.

signal settings_changed
signal profile_changed

const SETTINGS_PATH := "user://settings.cfg"
const PROFILE_PATH := "user://profile.json"

## XP needed to go from level N to N+1 grows linearly.
const XP_BASE := 1000
const XP_STEP := 250
const MAX_LEVEL := 50

var save_dir_override := "" ## used by tests to isolate files

var settings := {}
var profile := {}

const DEFAULT_SETTINGS := {
	"controls": {
		"scheme": "auto",            # auto | touch | keyboard
		"look_sensitivity": 1.0,
		"ads_sensitivity": 0.7,
		"optic_red_dot": 1.0,       # multiplier applied on top of ADS sensitivity
		"optic_holo": 0.95,
		"optic_4x": 0.6,
		"optic_8x": 0.4,
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"gyro_enabled": false,
		"gyro_sensitivity": 1.0,
		"aim_assist": true,
		"sprint_mode": "auto",      # auto (push joystick fully forward) | toggle
		"ads_mode": "toggle",       # toggle | hold
		"auto_fire": false,          # fire automatically when crosshair is on an enemy
		"br_view": "tpp",            # Battle Royale camera: tpp | fpp (Multiplayer is always first person)
		"auto_loot": true,           # BR: weapons into empty slots + better armor picked up automatically
		"damage_numbers": true,      # floating damage numbers on hits
	},
	"audio": {
		"master": 0.9,
		"music": 0.6,
		"sfx": 0.9,
	},
	"graphics": {
		"preset": "medium",         # low | medium | high | custom
		"render_scale": 0.85,
		"shadows": true,
		"effects_quality": 1,        # 0 low, 1 medium, 2 high
		"msaa": false,
		"fps_target": 60,
		"fov": 80.0,
		"show_fps": false,
		"arm_skin": "pale",          # first-person arms texture: pale | dark
	},
	"accessibility": {
		"enemy_color": "red",       # red | orange | magenta
		"hitmarker_scale": 1.0,
		"camera_shake": 1.0,
		"hud_scale": 1.0,
		"hud_opacity": 0.75,
	},
	"bots": {
		"difficulty": "normal",      # easy | normal | hard
	},
	"hud_layout": {},               # id -> {x, y, size, opacity, visible} (normalized positions)
}

const DEFAULT_PROFILE := {
	"name": "Recruit",
	"xp": 0,
	"level": 1,
	"credits": 0,
	"matches": 0,
	"wins": 0,
	"kills": 0,
	"deaths": 0,
	"operator": "op_ranger",
	"loadout_index": 0,
	"loadouts": [
		{"name": "Assault", "primary": "ar_m4k", "secondary": "pistol_p9", "melee": "knife",
		 "lethal": "frag", "tactical": "smoke", "attachments": {}, "skins": {}},
		{"name": "Close Quarters", "primary": "smg_vx", "secondary": "pistol_p9", "melee": "hatchet",
		 "lethal": "frag", "tactical": "smoke", "attachments": {}, "skins": {}},
		{"name": "Long Range", "primary": "sniper_ls7", "secondary": "smg_vx", "melee": "knife",
		 "lethal": "frag", "tactical": "smoke", "attachments": {}, "skins": {}},
	],
}


func _ready() -> void:
	InputSetup.register()
	load_all()
	settings_changed.connect(func(): GraphicsSettings.apply(get_tree()))
	GraphicsSettings.apply.call_deferred(get_tree())


func _path(p: String) -> String:
	if save_dir_override.is_empty():
		return p
	return save_dir_override.path_join(p.get_file())


func load_all() -> void:
	settings = _deep_merge(DEFAULT_SETTINGS.duplicate(true), _load_settings())
	profile = _deep_merge(DEFAULT_PROFILE.duplicate(true), _load_json(_path(PROFILE_PATH)))
	# Ensure there are always 3 loadouts.
	while profile.loadouts.size() < 3:
		profile.loadouts.append(DEFAULT_PROFILE.loadouts[profile.loadouts.size()].duplicate(true))


func _load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(_path(SETTINGS_PATH)) != OK:
		return {}
	var out := {}
	for section in cfg.get_sections():
		out[section] = {}
		for key in cfg.get_section_keys(section):
			out[section][key] = cfg.get_value(section, key)
	return out


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section in settings.keys():
		var sec: Dictionary = settings[section]
		for key in sec.keys():
			cfg.set_value(section, key, sec[key])
	cfg.save(_path(SETTINGS_PATH))
	settings_changed.emit()


func save_profile() -> void:
	var f := FileAccess.open(_path(PROFILE_PATH), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))
	profile_changed.emit()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	return data if data is Dictionary else {}


## Merge b into a recursively (b wins). Keeps defaults for keys missing in saved data.
func _deep_merge(a: Dictionary, b: Dictionary) -> Dictionary:
	for k in b.keys():
		if a.has(k) and a[k] is Dictionary and b[k] is Dictionary and k != "hud_layout":
			a[k] = _deep_merge(a[k], b[k])
		else:
			a[k] = b[k]
	return a


func get_setting(section: String, key: String, fallback = null):
	if settings.has(section) and settings[section].has(key):
		return settings[section][key]
	return fallback


func set_setting(section: String, key: String, value) -> void:
	if not settings.has(section):
		settings[section] = {}
	settings[section][key] = value


func reset_settings_section(section: String) -> void:
	settings[section] = DEFAULT_SETTINGS[section].duplicate(true)


# ---------------- Loadouts ----------------

func current_loadout() -> Dictionary:
	return profile.loadouts[clampi(int(profile.loadout_index), 0, profile.loadouts.size() - 1)]


# ---------------- Progression ----------------

static func xp_for_next(level: int) -> int:
	return XP_BASE + XP_STEP * (level - 1)


## Adds XP, handles level-ups. Returns array of levels gained.
func add_xp(amount: int) -> Array:
	var gained: Array = []
	profile.xp = int(profile.xp) + amount
	while int(profile.level) < MAX_LEVEL and int(profile.xp) >= xp_for_next(int(profile.level)):
		profile.xp = int(profile.xp) - xp_for_next(int(profile.level))
		profile.level = int(profile.level) + 1
		gained.append(profile.level)
	return gained


func record_match(result: Dictionary) -> Dictionary:
	## result: {kills, deaths, won, score, mode}
	var xp := int(result.get("kills", 0)) * 100 + int(result.get("assists", 0)) * 40 + int(result.get("score", 0)) / 2 + 200
	if result.get("won", false):
		xp += 500
	var credits := 50 + int(result.get("kills", 0)) * 10 + (100 if result.get("won", false) else 0)
	profile.matches = int(profile.matches) + 1
	profile.kills = int(profile.kills) + int(result.get("kills", 0))
	profile.deaths = int(profile.deaths) + int(result.get("deaths", 0))
	if result.get("won", false):
		profile.wins = int(profile.wins) + 1
	profile.credits = int(profile.credits) + credits
	var levels := add_xp(xp)
	save_profile()
	return {"xp": xp, "credits": credits, "levels": levels}
