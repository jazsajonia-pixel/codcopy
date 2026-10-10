class_name GraphicsSettings
extends RefCounted
## Applies graphics settings to the running game. Every exposed option maps to a real engine setting.

const PRESETS := {
	"low": {"render_scale": 0.7, "shadows": false, "effects_quality": 0, "msaa": false, "fps_target": 30},
	"medium": {"render_scale": 0.85, "shadows": true, "effects_quality": 1, "msaa": false, "fps_target": 60},
	"high": {"render_scale": 1.0, "shadows": true, "effects_quality": 2, "msaa": true, "fps_target": 60},
}


static func apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	for k in PRESETS[name].keys():
		SaveManager.set_setting("graphics", k, PRESETS[name][k])
	SaveManager.set_setting("graphics", "preset", name)


static func apply(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var vp := tree.root
	var g: Dictionary = SaveManager.settings.graphics
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = clampf(float(g.render_scale), 0.5, 1.0)
	vp.msaa_3d = Viewport.MSAA_2X if g.msaa else Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 2048 if g.shadows else 0
	Engine.max_fps = int(g.fps_target)
	# Directional light shadows are toggled per-scene by WorldEnv helpers (they read the same setting).
	for light in tree.get_nodes_in_group("sun"):
		(light as DirectionalLight3D).shadow_enabled = bool(g.shadows)
		(light as DirectionalLight3D).directional_shadow_max_distance = 60.0 if int(g.effects_quality) < 2 else 110.0
