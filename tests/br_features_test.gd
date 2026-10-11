extends Node3D
## "brfeat" suite: third-person camera, weapon slots / weapon bar, auto loot, backpack, and the
## wingsuit + parachute drop, on a flat test ground with a real Player node.

var passed := 0
var failed := 0
var p: Player
var ui: CanvasLayer


func check(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  " + name)
	else:
		failed += 1
		print("  FAIL  " + name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = pos
	add_child(b)
	return b


func _loot(kind: String, id: String, n: int = 1) -> LootItem:
	var l := LootItem.make(kind, id, n)
	add_child(l)
	l.global_position = p.global_position
	return l


func _count_loot(id: String) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("loot"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.item_id == id:
			c += 1
	return c


func _run() -> void:
	MatchConfig.autoplay_player = false
	MatchConfig.mode = "br"
	SaveManager.set_setting("controls", "br_view", "tpp")
	SaveManager.set_setting("controls", "auto_loot", true)
	_box(Vector3(0, -1, 0), Vector3(800, 2, 800))
	ui = CanvasLayer.new()
	add_child(ui)
	p = Player.new()
	p.position = Vector3(0, 0.1, 0)
	add_child(p)
	p.inv.use_ammo_pools = true
	p.inv.ammo.rifle = 60
	p.inv.pick_up_weapon(WeaponInstance.create("ar_m4k", {}, "default", false))
	p.equip_current()
	p.touch_mode = true
	await _frames(60)

	# --- Third-person camera (BR) ---
	check(p.cam_tpp > 0.99 and p.camera.position.z > 2.5, "BR starts in third person (camera %.1f m behind)" % p.camera.position.z)
	check(not p._body_shadow_only and not p.view_model.visible, "third person shows the body, hides first-person arms")
	p.ads_on = true
	await _frames(40)
	check(p.cam_tpp < 0.35 and p.view_model.visible, "ADS in third person switches to the first-person sight")
	p.ads_on = false
	await _frames(40)
	var wall := _box(Vector3(0, 1.5, 1.6), Vector3(6, 4, 0.4))
	await _frames(3)
	check(p.camera.position.length() < 1.6, "camera pulls in when a wall is behind the player (%.2f m)" % p.camera.position.length())
	wall.queue_free()
	await _frames(3)
	p.input.toggle_view = true
	await _frames(40)
	check(SaveManager.get_setting("controls", "br_view", "") == "fpp" and p.cam_tpp == 0.0 and p._body_shadow_only, "VIEW toggle switches to first person")
	p.input.toggle_view = true
	await _frames(40)
	check(p.cam_tpp > 0.99, "VIEW toggle switches back to third person")
	MatchConfig.mode = "tdm"
	await _frames(40)
	check(p.cam_tpp == 0.0, "Multiplayer is always first person")
	p.input.toggle_view = true
	await _frames(20)
	check(SaveManager.get_setting("controls", "br_view", "") == "tpp", "VIEW toggle does nothing in Multiplayer")
	MatchConfig.mode = "br"
	await _frames(40)

	# --- Auto loot ---
	var l1 := _loot("weapon", "smg_kr")
	await _frames(20)
	check(p.inv.weapons[1] != null and p.inv.weapons[1].id() == "smg_kr" and p.inv.current == 0, "auto loot: weapon goes into the empty slot, gun in hand stays")
	var bag := BagPanel.new()
	bag.player = p
	ui.add_child(bag)
	bag.drop_weapon(1)
	await _frames(30)
	check(p.inv.weapons[1] == null and _count_loot("smg_kr") == 1, "bag DROP puts the weapon on the ground and it is not instantly re-looted")
	SaveManager.set_setting("controls", "auto_loot", false)
	for n in get_tree().get_nodes_in_group("loot"):
		n.queue_free()
	var l2 := _loot("weapon", "sg_breacher")
	await _frames(20)
	check(p.inv.weapons[1] == null and is_instance_valid(l2), "auto loot off: weapons need Interact")
	SaveManager.set_setting("controls", "auto_loot", true)
	await _frames(20)
	check(p.inv.weapons[1] != null and p.inv.weapons[1].id() == "sg_breacher", "auto loot on again picks it up")
	var a2 := _loot("armor", "armor_2")
	await _frames(20)
	check(p.armor_tier == 2 and not is_instance_valid(a2), "auto loot wears better armor")
	var a1 := _loot("armor", "armor_1")
	await _frames(20)
	check(p.armor_tier == 2 and is_instance_valid(a1), "worse armor is left on the ground")
	a1.queue_free()

	# --- Weapon slots (weapon bar / 1-2-3 keys) ---
	p.input.select_slot = 2
	await _frames(3)
	check(p.inv.holstered and p.inv.active() == null, "slot 3 = fists (weapons holstered)")
	p.input.fire = true
	await _frames(3)
	p.input.fire = false
	check(p.melee_cooldown > 0.0, "FIRE with fists out does a melee attack")
	p.input.select_slot = 1
	await _frames(3)
	check(not p.inv.holstered and p.inv.current == 1, "slot 2 equips the second weapon")
	p.input.select_slot = 2
	await _frames(2)
	p.input.switch_weapon = true
	await _frames(2)
	check(p.inv.active() != null, "SWAP from fists draws a weapon")
	var bar := WeaponBar.new()
	bar.player = p
	bar.br_mode = true
	ui.add_child(bar)
	await _frames(2)
	var rects := bar._layout()
	check(rects.size() == 3, "BR weapon bar shows weapon 1, weapon 2 and fists")
	bar.tap((rects[0].rect as Rect2).get_center())
	check(p.input.select_slot == 0, "tapping a weapon card selects that slot")
	await _frames(3)
	check(p.inv.current == 0 and not p.inv.holstered, "slot 1 equipped after the tap")
	bar.br_mode = false
	rects = bar._layout()
	check(rects.size() == 2 and rects[0].id == "weapon" and rects[1].id == "knife", "Multiplayer weapon bar shows only the gun and the knife")
	bar.tap((rects[0].rect as Rect2).get_center())
	check(p.input.select_slot == 0 or p.input.inspect, "tapping the Multiplayer gun card draws / inspects the one gun")
	await _frames(2)

	# --- Backpack ---
	p.inv.heals.medkit = 2
	p.inv.plates = 2
	bag.open()
	await _frames(3)
	var buttons := bag.find_children("Bag_*", "Button", true, false)
	check(buttons.size() >= 6, "backpack lists weapons, ammo and supplies with buttons (%d)" % buttons.size())
	var rifle: int = p.inv.ammo.rifle
	bag.drop_ammo("rifle")
	check(p.inv.ammo.rifle == 0 and _count_loot("ammo_rifle") == 1, "backpack drops ammo (%d rounds)" % rifle)
	bag.drop_supply("heal", "medkit")
	check(p.inv.heals.medkit == 1 and _count_loot("medkit") == 1, "backpack drops a med kit")
	bag.close()
	await _frames(2)

	# --- Wingsuit + parachute ---
	for n in get_tree().get_nodes_in_group("loot"):
		n.queue_free()
	p.global_position = Vector3(0, 220, 0)
	p.velocity = Vector3.ZERO
	p.parachute_state = 1
	p.drop_grace = 0.0
	for i in 120:
		p.input.move = Vector2(0, -1)
		p.pitch = -0.1
		await get_tree().physics_frame
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	check(hs > 20.0 and -p.velocity.y < 20.0, "wingsuit glide: %.0f m/s forward, %.0f m/s down" % [hs, -p.velocity.y])
	check(p.cam_tpp > 0.99 and p.camera.position.z > 6.0, "drop camera is third person and far back")
	for i in 240:   # physics-based: the dive accelerates under gravity against drag
		p.input.move = Vector2(0, -1)
		p.pitch = -1.3
		await get_tree().physics_frame
	check(-p.velocity.y > 35.0, "diving falls faster (%.0f m/s down)" % -p.velocity.y)
	p.input.jump = true
	await _frames(2)
	check(p.parachute_state == 2, "JUMP opens the parachute early")
	p.input.move = Vector2.ZERO
	await _frames(90)
	check(-p.velocity.y < 7.0, "parachute descends slowly (%.1f m/s)" % -p.velocity.y)
	var mag := p.inv.active().mag
	p.input.fire = true
	await _frames(20)
	p.input.fire = false
	check(p.inv.active().mag < mag, "can fire from the hip under the parachute")
	p.input.jump = true
	await _frames(2)
	check(p.parachute_state == 1 or p.agl <= Player.CHUTE_MIN_CUT_AGL, "JUMP closes the parachute again when high enough (agl %.0f)" % p.agl)
	var opened_at := -1.0
	for i in 1200:
		p.pitch = -1.3
		p.input.move = Vector2.ZERO
		await get_tree().physics_frame
		if p.parachute_state == 2 and opened_at < 0.0:
			opened_at = p.agl
		if p.parachute_state == 0:
			break
	check(opened_at > 0.0 and opened_at <= Player.CHUTE_AUTO_AGL + 2.0, "parachute auto-opens near the ground (%.0f m)" % opened_at)
	check(p.parachute_state == 0 and p.is_on_floor(), "landed")
	# --- Damage numbers ---
	var ov := HudOverlay.new()
	ov.player = p
	ui.add_child(ov)
	p.damage_dealt.connect(ov.on_damage_dealt)
	var dummy := Player.new()
	add_child(dummy)
	dummy.global_position = Vector3(5, 0.1, 0)
	await _frames(2)
	SaveManager.set_setting("controls", "damage_numbers", true)
	p.damage_dealt.emit(dummy, 20.0, false, false)
	p.damage_dealt.emit(dummy, 25.0, true, false)
	check(ov.dmg_numbers.size() == 1 and is_equal_approx(ov.dmg_numbers[0].amount, 45.0) and ov.dmg_numbers[0].head, "rapid hits stack into one damage number (45, headshot)")
	await _frames(70)
	check(ov.dmg_numbers.is_empty(), "damage numbers fade out")
	SaveManager.set_setting("controls", "damage_numbers", false)
	p.damage_dealt.emit(dummy, 20.0, false, false)
	check(ov.dmg_numbers.is_empty(), "damage numbers setting off hides them")
	SaveManager.set_setting("controls", "damage_numbers", true)
	print("=== RESULT brfeat: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
