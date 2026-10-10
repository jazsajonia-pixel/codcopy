extends VBoxContainer
## Loadout editor: 3 saved loadouts; primary/secondary/melee/lethal/tactical; per-weapon attachments
## and skins (all unlocked by level only - there are no paid items); stat bars with comparison.

var menu: Control
var slot := "primary"
var lo_buttons: Array = []
var slot_buttons := {}
var list_box: VBoxContainer
var detail: VBoxContainer
var name_edit: LineEdit
var compare_stats := {}


func _lo() -> Dictionary:
	return SaveManager.current_loadout()


func _level() -> int:
	return int(SaveManager.profile.level)


func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.add_child(UITheme.label("LOADOUT", 34, UITheme.ACCENT))
	for i in 3:
		var b := UITheme.button(str(i + 1), func(): _select_loadout(i), Vector2(64, 56), "select")
		b.toggle_mode = true
		top.add_child(b)
		lo_buttons.append(b)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(240, 52)
	name_edit.max_length = 18
	name_edit.text_submitted.connect(func(_t): _rename())
	name_edit.focus_exited.connect(_rename)
	top.add_child(name_edit)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size = Vector2(250, 0)
	body.add_child(slots)
	for s in ["primary", "secondary", "melee", "lethal", "tactical"]:
		var b := UITheme.button("", func(): _select_slot(s), Vector2(250, 70), "select")
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slots.add_child(b)
		slot_buttons[s] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(dscroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	dscroll.add_child(detail)
	_select_loadout(int(SaveManager.profile.loadout_index))


func _rename() -> void:
	var t := name_edit.text.strip_edges()
	if t != "" and t != _lo().name:
		_lo().name = t
		SaveManager.save_profile()


func _select_loadout(i: int) -> void:
	SaveManager.profile.loadout_index = i
	SaveManager.save_profile()
	for j in lo_buttons.size():
		lo_buttons[j].set_pressed_no_signal(j == i)
	name_edit.text = _lo().name
	compare_stats = {}
	_select_slot(slot)


func _slot_text(s: String) -> String:
	var lo := _lo()
	match s:
		"primary", "secondary":
			return "%s\n%s" % [s.to_upper(), GameDB.get_weapon(lo[s]).display_name]
		"melee":
			return "MELEE\n%s" % GameDB.MELEE[lo.melee].name
		_:
			return "%s\n%s" % [s.to_upper(), GameDB.EQUIPMENT[lo[s]].name]


func _select_slot(s: String) -> void:
	slot = s
	for k in slot_buttons.keys():
		slot_buttons[k].set_pressed_no_signal(k == s)
		slot_buttons[k].text = _slot_text(k)
	for c in list_box.get_children():
		c.queue_free()
	var lo := _lo()
	var options: Array = []   # [id, name, unlock]
	match s:
		"primary", "secondary":
			for id in GameDB.weapon_ids_for_slot(s):
				var w := GameDB.get_weapon(id)
				options.append([id, "%s  (%s)" % [w.display_name, w.category], w.unlock_level])
		"melee":
			for id in GameDB.MELEE.keys():
				options.append([id, GameDB.MELEE[id].name, GameDB.MELEE[id].unlock])
		"lethal", "tactical":
			for id in GameDB.EQUIPMENT.keys():
				if GameDB.EQUIPMENT[id].kind == s:
					options.append([id, GameDB.EQUIPMENT[id].name, GameDB.EQUIPMENT[id].unlock])
	for o in options:
		var locked: bool = _level() < int(o[2])
		var txt: String = o[1] + ("   [LVL %d]" % o[2] if locked else "")
		var b := UITheme.button(txt, func(): _choose(o[0]), Vector2(260, 56), "select")
		b.toggle_mode = true
		b.set_pressed_no_signal(lo[s] == o[0])
		b.disabled = locked
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		list_box.add_child(b)
	_show_detail()


func _choose(id: String) -> void:
	var lo := _lo()
	if slot in ["primary", "secondary"]:
		compare_stats = GameDB.build_stats(lo[slot], lo.attachments.get(lo[slot], {}))
		# Same weapon can't be in both slots.
		var other := "secondary" if slot == "primary" else "primary"
		if lo[other] == id:
			return
	lo[slot] = id
	SaveManager.save_profile()
	_select_slot(slot)


func _show_detail() -> void:
	for c in detail.get_children():
		c.queue_free()
	var lo := _lo()
	match slot:
		"primary", "secondary":
			_weapon_detail(lo[slot])
		"melee":
			var m: Dictionary = GameDB.MELEE[lo.melee]
			detail.add_child(UITheme.label(m.name, 26, UITheme.ACCENT))
			detail.add_child(UITheme.label("Damage %d   Range %.1f m   Cooldown %.2f s" % [m.damage, m.range, m.cooldown], 18))
		_:
			var e: Dictionary = GameDB.EQUIPMENT[lo[slot]]
			detail.add_child(UITheme.label(e.name, 26, UITheme.ACCENT))
			var t := "Fuse %.1f s   Radius %.1f m   Count %d" % [e.fuse, e.radius, e.count]
			if e.has("damage"):
				t += "   Damage %d" % e.damage
			if e.has("duration"):
				t += "   Duration %.1f s" % e.duration
			detail.add_child(UITheme.label(t, 18))


func _weapon_detail(id: String) -> void:
	var lo := _lo()
	var w := GameDB.get_weapon(id)
	if not lo.attachments.has(id):
		lo.attachments[id] = {}
	var att: Dictionary = lo.attachments[id]
	var stats := GameDB.build_stats(id, att)
	var title := UITheme.label("%s  -  %s" % [w.display_name, w.category], 24, UITheme.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(title)
	var desc := UITheme.label(w.description, 16, UITheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(desc)
	var bars := GameDB.stat_bars(stats)
	var cmp := GameDB.stat_bars(compare_stats) if not compare_stats.is_empty() else {}
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(grid)
	for k in bars.keys():
		grid.add_child(UITheme.label(k, 16))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(150, 12)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.step = 0.001
		pb.value = bars[k]
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(pb)
		var delta := ""
		var col := UITheme.MUTED
		if cmp.has(k):
			var dv: float = bars[k] - cmp[k]
			if absf(dv) > 0.005:
				delta = "%+d" % int(round(dv * 100))
				col = UITheme.GOOD if dv > 0 else UITheme.ENEMY
		grid.add_child(UITheme.label(delta, 16, col))
	var sl := UITheme.label("Damage %d x%d   %d RPM   Mag %d   Range %d m   Reload %.1f s" % [
		stats.damage, stats.pellets, stats.fire_rate_rpm, stats.mag_size, stats.effective_range, stats.reload_time], 15, UITheme.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(sl)
	detail.add_child(UITheme.label("ATTACHMENTS", 18, UITheme.MUTED))
	var ag := GridContainer.new()
	ag.columns = 2
	detail.add_child(ag)
	for s in GameDB.SLOTS:
		var allowed: Array = w.allowed_attachments.get(s, [])
		if allowed.is_empty():
			continue
		ag.add_child(UITheme.label(s.capitalize(), 16))
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(220, 48)
		ob.add_item("None")
		ob.set_item_metadata(0, "")
		var sel := 0
		for a_id in allowed:
			var a: Dictionary = GameDB.ATTACHMENTS[a_id]
			var locked: bool = _level() < int(a.unlock)
			ob.add_item(a.name + ("  [LVL %d]" % a.unlock if locked else ""))
			var idx := ob.item_count - 1
			ob.set_item_metadata(idx, a_id)
			ob.set_item_disabled(idx, locked)
			ob.set_item_tooltip(idx, a.desc)
			if att.get(s, "") == a_id:
				sel = idx
		ob.select(sel)
		ob.item_selected.connect(func(i):
			compare_stats = GameDB.build_stats(id, att)
			var v: String = ob.get_item_metadata(i)
			if v == "":
				att.erase(s)
			else:
				att[s] = v
			SaveManager.save_profile()
			AudioManager.ui("select")
			_show_detail.call_deferred())
		ag.add_child(ob)
	detail.add_child(UITheme.label("SKIN", 18, UITheme.MUTED))
	var srow := HFlowContainer.new()
	detail.add_child(srow)
	var cur: String = lo.skins.get(id, "default")
	for sk in GameDB.SKINS.keys():
		var info: Dictionary = GameDB.SKINS[sk]
		var locked: bool = _level() < int(info.unlock)
		var b := UITheme.button(info.name + ("\nLVL %d" % info.unlock if locked else ""), func():
			lo.skins[id] = sk
			SaveManager.save_profile()
			_show_detail.call_deferred(), Vector2(120, 56), "select")
		b.toggle_mode = true
		b.set_pressed_no_signal(cur == sk)
		b.disabled = locked
		b.add_theme_font_size_override("font_size", 15)
		var c: Color = info.color
		if c.a > 0.0:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(c.r, c.g, c.b, 0.85)
			sb.set_corner_radius_all(6)
			sb.border_color = UITheme.ACCENT if cur == sk else Color(0, 0, 0, 0)
			sb.set_border_width_all(3)
			b.add_theme_stylebox_override("normal", sb)
		srow.add_child(b)
	var note := UITheme.label("All items unlock by leveling up. There are no paid items.", 14, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(note)
