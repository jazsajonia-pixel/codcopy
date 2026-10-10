class_name WeaponData
extends Resource
## Data-driven weapon definition. Add a new .tres in res://resources/weapons/ to add a weapon;
## GameDB discovers every file in that folder automatically.

enum FireMode { AUTO, SEMI, BOLT, PUMP }

@export var id: String = ""
@export var display_name: String = ""
@export_enum("AR", "SMG", "SHOTGUN", "SNIPER", "LMG", "PISTOL") var category: String = "AR"
@export var description: String = ""
@export_file("*.glb") var model_path: String = ""
@export var fire_mode: FireMode = FireMode.AUTO
@export var burst_count: int = 1

@export_group("Damage")
@export var damage: float = 25.0
@export var headshot_multiplier: float = 1.5
@export var pellets: int = 1
## Damage stays 100% until effective_range, then lerps to falloff_multiplier at max_range.
@export var effective_range: float = 30.0
@export var max_range: float = 120.0
@export var falloff_multiplier: float = 0.6

@export_group("Handling")
@export var fire_rate_rpm: float = 700.0
@export var mag_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 2.0
@export var reload_empty_time: float = 2.6
@export var ads_time: float = 0.22
@export var move_speed_multiplier: float = 1.0
@export var ads_fov: float = 60.0
@export var scope_overlay: bool = false

@export_group("Accuracy")
@export var hip_spread_deg: float = 3.0
@export var ads_spread_deg: float = 0.4
@export var move_spread_deg: float = 2.0
@export var spread_per_shot_deg: float = 0.25
@export var max_bloom_deg: float = 3.0
@export var recoil_vertical: float = 0.8
@export var recoil_horizontal: float = 0.35
@export var recoil_recovery: float = 9.0

@export_group("Presentation")
@export_file("*.ogg", "*.wav") var fire_sound: String = ""
@export_file("*.ogg", "*.wav") var reload_sound: String = ""
@export var ammo_type: String = "rifle" ## rifle | smg | shotgun | sniper | pistol
@export var view_offset: Vector3 = Vector3(0.18, -0.17, -0.38)
@export var ads_offset: Vector3 = Vector3(0.0, -0.075, -0.28)
@export var tracer_every: int = 2
@export var unlock_level: int = 1
@export var allowed_attachments: Dictionary = {} ## slot -> Array[String] of attachment ids


func shot_interval() -> float:
	return 60.0 / maxf(fire_rate_rpm, 1.0)


func damage_at(distance: float) -> float:
	if distance <= effective_range:
		return damage
	if distance >= max_range:
		return damage * falloff_multiplier
	var t := (distance - effective_range) / maxf(max_range - effective_range, 0.01)
	return damage * lerpf(1.0, falloff_multiplier, t)


## Ideal time-to-kill against a target with the given HP, ignoring misses.
func ttk(target_hp: float = 100.0, distance: float = 10.0) -> float:
	var per_shot := damage_at(distance) * pellets
	var shots := ceili(target_hp / maxf(per_shot, 0.01))
	return (shots - 1) * shot_interval()
