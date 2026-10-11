class_name BagPanel
extends Control
## Battle Royale backpack (CODM "inventory" button): equipped weapons with their attachments, armor,
## ammo per type, heals, plates and grenades. Equip / use / drop items. The match keeps running
## while it is open (like CODM), so close it quickly in a fight.

signal closed

var player: Player
var _list: VBoxContainer
var _dirty := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var p := UITheme.panel()
	p.name = "BagWindow"
	center.add_child(p)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	p.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := UITheme.label("BACKPACK", 26, UITheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UITheme.button("CLOSE", close, Vector2(130, 52))
	x.name = "BagClose"
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "BagScroll"
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var s := UITheme.safe_rect(get_viewport())
	var w := clampf(s.size.x * 0.86, 360, 920)
	var h := clampf(s.size.y * 0.84, 300, 620)
	var p: Control = find_child("BagWindow", true, false)
	p.custom_minimum_size = Vector2(w, h)
	(find_child("BagScroll", true, false) as Control).custom_minimum_size = Vector2(w - 24, h - 90)


func open() -> void:
	visible = true
	_dirty = true
	if not player.inv.changed.is_connected(_mark):
		player.inv.changed.connect(_mark)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _mark() -> void:
	_dirty = true


func _process(_d: float) -> void:
	if not visible or player == null:
		return
	if not player.alive or player.downed or player.vehicle != null or player.parachute_state > 0:
		close()
		return
	if _dirty:
		_dirty = false
		_rebuild()


func _section(t: String) -> void:
	_list.add_child(UITheme.label(t, 18, UITheme.MUTED))


func _row(text: String, sub: String, actions: Array, icon: Texture2D = null) -> void:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bg.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bg.add_child(h)
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(120, 52)
		h.add_child(tr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UITheme.label(text, 20))
	if sub != "":
		var l := UITheme.label(sub, 14, UITheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	h.add_child(v)
	for a in actions:
		var b := UITheme.button(a[0], a[1], Vector2(104, 48))
		b.name = "Bag_" + a[0] + "_" + text.validate_node_name()
		h.add_child(b)
	_list.add_child(bg)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var inv := player.inv
	_section("WEAPONS")
	for i in Inventory.MAX_WEAPONS:
		var w: WeaponInstance = inv.weapons[i]
		if w == null:
			_row("Slot %d - empty" % (i + 1), "Walk over a weapon to pick it up.", [])
			continue
		var atts: Array = []
		for slot in w.attachments.keys():
			var aid: String = w.attachments[slot]
			if GameDB.ATTACHMENTS.has(aid):
				atts.append(GameDB.ATTACHMENTS[aid].name)
		var equipped := not inv.holstered and inv.current == i
		var sub := "%s ammo  |  %d in magazine  |  %s" % [w.data.ammo_type.capitalize(), w.mag, ", ".join(atts) if atts.size() > 0 else "no attachments"]
		var acts: Array = []
		if not equipped:
			acts.append(["EQUIP", func(): player.select_slot(i)])
		acts.append(["DROP", func(): drop_weapon(i)])
		_row(("> " if equipped else "") + w.data.display_name, sub, acts, WeaponIcons.get_icon(w.id()))
	_section("ARMOR")
	if player.armor_tier > 0:
		_row("Tier %d vest" % player.armor_tier, "%d / %d armor" % [roundi(player.armor), roundi(player.max_armor)], [["DROP", drop_armor]])
	else:
		_row("No armor", "Vests are blue loot.", [])
	_section("AMMO")
	var any_ammo := false
	for t in inv.ammo.keys():
		if inv.ammo[t] > 0:
			any_ammo = true
			_row("%s ammo  x%d" % [t.capitalize(), inv.ammo[t]], "", [["DROP", func(): drop_ammo(t)]])
	if not any_ammo:
		_row("No spare ammo", "", [])
	_section("SUPPLIES")
	for hid in ["medkit", "bandage"]:
		var n: int = inv.heals.get(hid, 0)
		if n > 0:
			_row("%s  x%d" % [GameDB.BR_ITEMS[hid].name, n], "Restores %d health" % int(GameDB.BR_ITEMS[hid].heal),
				[["USE", func(): _use(hid)], ["DROP", func(): drop_supply("heal", hid)]])
	if inv.plates > 0:
		_row("Armor Plate  x%d" % inv.plates, "Repairs %d armor" % int(GameDB.BR_ITEMS.plate.armor),
			[["USE", func(): _use("plate")], ["DROP", func(): drop_supply("plate", "plate")]])
	for k in ["lethal", "tactical"]:
		var eid: String = inv.get(k)
		var cnt: int = inv.get(k + "_count")
		if eid != "" and cnt > 0:
			var acts: Array = []
			if GameDB.BR_ITEMS.has(eid):
				acts.append(["DROP", func(): drop_grenade(k)])
			_row("%s  x%d" % [GameDB.EQUIPMENT[eid].name, cnt], "", acts)
	if inv.heals.get("medkit", 0) + inv.heals.get("bandage", 0) + inv.plates == 0 and inv.lethal_count + inv.tactical_count == 0:
		_row("No supplies", "", [])


func _use(id: String) -> void:
	if player.start_use(id):
		close()


func drop_weapon(i: int) -> void:
	var inv := player.inv
	var w: WeaponInstance = inv.weapons[i]
	if w == null:
		return
	w.cancel_reload()
	# Unfired rounds go back into the shared ammo pool.
	inv.add_ammo(w.data.ammo_type, w.mag)
	LootItem.drop_from(player, "weapon", w.id(), 1, w.attachments)
	inv.set_weapon(i, null)
	if inv.current == i:
		var other := (i + 1) % Inventory.MAX_WEAPONS
		if inv.weapons[other] != null:
			inv.current = other
		else:
			inv.holstered = false
	player.equip_current()
	inv.changed.emit()


func drop_armor() -> void:
	if player.armor_tier <= 0:
		return
	LootItem.drop_from(player, "armor", "armor_%d" % player.armor_tier)
	player.armor_tier = 0
	player.armor = 0.0
	player.max_armor = 0.0
	player.inv.changed.emit()


func drop_ammo(t: String) -> void:
	var n: int = player.inv.ammo.get(t, 0)
	if n <= 0:
		return
	player.inv.ammo[t] = 0
	LootItem.drop_from(player, "ammo", "ammo_" + t, n)
	player.inv.changed.emit()


func drop_supply(kind: String, id: String) -> void:
	var inv := player.inv
	if kind == "heal":
		if inv.heals.get(id, 0) <= 0:
			return
		inv.heals[id] -= 1
	else:
		if inv.plates <= 0:
			return
		inv.plates -= 1
	LootItem.drop_from(player, kind, id, 1)
	inv.changed.emit()


func drop_grenade(k: String) -> void:
	var inv := player.inv
	var eid: String = inv.get(k)
	var cnt: int = inv.get(k + "_count")
	if cnt <= 0:
		return
	inv.set(k + "_count", cnt - 1)
	LootItem.drop_from(player, "grenade", eid, 1)
	inv.changed.emit()
