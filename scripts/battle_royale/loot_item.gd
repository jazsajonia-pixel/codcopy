class_name LootItem
extends Node3D
## Ground loot for Battle Royale: weapons, ammo, armor, heals, plates and grenades.
## Ammo/heals/plates/grenades are auto-collected when useful; weapons and armor need Interact.

var kind := "ammo"     ## weapon | ammo | armor | heal | plate | grenade
var item_id := ""      ## weapon id or GameDB.BR_ITEMS id
var amount := 1
var tier := 0
var weapon_attachments := {}
var _visual: Node3D
var _t := 0.0


static func make(p_kind: String, p_id: String, p_amount: int = 1) -> LootItem:
	var l := LootItem.new()
	l.kind = p_kind
	l.item_id = p_id
	l.amount = p_amount
	if p_kind == "armor":
		l.tier = GameDB.BR_ITEMS[p_id].tier
	return l


func _ready() -> void:
	add_to_group("loot")
	add_to_group("interactable")
	_t = randf() * TAU
	if kind == "weapon":
		var w := GameDB.get_weapon(item_id)
		_visual = load(w.model_path).instantiate()
		_visual.scale = Vector3.ONE * 1.6
	else:
		_visual = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.3, 0.35) if kind != "armor" else Vector3(0.55, 0.6, 0.25)
		(_visual as MeshInstance3D).mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = GameDB.ITEM_COLORS.get(kind, Color.WHITE)
		m.emission_enabled = true
		m.emission = m.albedo_color * 0.35
		(_visual as MeshInstance3D).material_override = m
	add_child(_visual)
	# Ground glow ring so loot reads at a glance on mobile screens.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.55
	tm.rings = 16
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = GameDB.ITEM_COLORS.get(kind, Color.WHITE)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.05
	add_child(ring)
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 70.0
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = 0.45 + sin(_t * 2.0) * 0.08
	_visual.rotation.y = _t * 0.8


func display_name() -> String:
	if kind == "weapon":
		return GameDB.get_weapon(item_id).display_name
	return GameDB.BR_ITEMS[item_id].name


func prompt() -> String:
	if kind == "ammo":
		return "%s x%d" % [display_name(), amount]
	return "Pick up %s" % display_name()


## Auto-collect cheap items. Returns true if consumed (caller should skip it as an interact target).
func auto_pickup(a: Actor) -> bool:
	if not is_inside_tree() or kind in ["weapon", "armor"]:
		return false
	return _apply(a)


func interact(a: Actor) -> void:
	if not is_inside_tree():
		return
	_apply(a)


func _apply(a: Actor) -> bool:
	var inv := a.inv
	var it: Dictionary = GameDB.BR_ITEMS.get(item_id, {})
	var ok := false
	match kind:
		"weapon":
			var w := WeaponInstance.create(item_id, weapon_attachments, "default", false)
			var dropped := inv.pick_up_weapon(w)
			inv.add_ammo(w.data.ammo_type, w.mag_size())
			if dropped:
				var l := LootItem.make("weapon", dropped.id())
				l.weapon_attachments = dropped.attachments
				get_parent().add_child(l)
				l.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			if a is Player:
				(a as Player).equip_current()
			elif a.has_method("_refresh_gun_model"):
				a.call("_refresh_gun_model")
			ok = true
		"ammo":
			var added := inv.add_ammo(it.ammo, amount)
			amount -= added
			ok = amount <= 0
			if added > 0 and not ok:
				_feedback(a)
				return false
		"armor":
			ok = a.equip_armor(it.tier, it.armor)
		"heal":
			ok = inv.add_heal(item_id, amount) > 0
		"plate":
			if inv.plates < 5:
				inv.plates += amount
				ok = true
		"grenade":
			var eid: String = it.equip
			if GameDB.EQUIPMENT[eid].kind == "lethal":
				if inv.lethal == "" or inv.lethal == eid:
					inv.lethal = eid
					if inv.lethal_count < 3:
						inv.lethal_count += 1
						ok = true
			else:
				if inv.tactical == "" or inv.tactical == eid:
					inv.tactical = eid
					if inv.tactical_count < 3:
						inv.tactical_count += 1
						ok = true
	if ok:
		_feedback(a)
		inv.changed.emit()
		queue_free()
	return ok


func _feedback(a: Actor) -> void:
	if a.is_player:
		AudioManager.play_2d("res://assets/audio/sfx/loot_pickup.ogg", -8.0, randf_range(1.0, 1.2))
