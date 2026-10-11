class_name WeaponIcons
extends RefCounted
## Renders each weapon's 3D model once (side view, off-screen SubViewport) and turns it into a white
## silhouette icon, like the weapon icons on mobile shooter HUDs. Returns null until the icon is
## ready (and always on the headless test renderer, where nothing is drawn).

const SIZE := Vector2i(256, 112)
static var _cache := {}
static var _pending := {}


static func get_icon(weapon_id: String) -> Texture2D:
	if _cache.has(weapon_id):
		return _cache[weapon_id]
	if DisplayServer.get_name() == "headless" or _pending.has(weapon_id):
		return null
	_pending[weapon_id] = true
	_render(weapon_id)
	return null


static func _render(weapon_id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var data := GameDB.get_weapon(weapon_id)
	if tree == null or data == null:
		return
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var model: Node3D = load(data.model_path).instantiate()
	vp.add_child(model)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 60, 0)
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	tree.root.add_child(vp)
	await tree.process_frame
	if not is_instance_valid(vp):
		return
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var length := maxf(box.size.z, 0.1)
	var aspect := float(SIZE.x) / SIZE.y
	cam.size = maxf(length * 1.08 / aspect, box.size.y * 1.15)
	cam.position = c + Vector3(maxf(box.size.x, 1.0) * 4.0 + 2.0, 0, 0)
	cam.look_at(c, Vector3.UP)
	cam.far = 50.0
	for i in 3:
		await tree.process_frame
	if not is_instance_valid(vp):
		return
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	# White silhouette with the model's own shading kept subtly in the alpha edge.
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.02:
				var lum := clampf(px.get_luminance() * 0.35 + 0.75, 0.0, 1.0)
				img.set_pixel(x, y, Color(lum, lum, lum, px.a))
	_cache[weapon_id] = ImageTexture.create_from_image(img)
