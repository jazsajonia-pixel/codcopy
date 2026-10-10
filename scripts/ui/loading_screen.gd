extends Control
## Loading screen: shows mode/map and a tip while the match scene loads in a background thread.

const TIPS := [
	"Sliding: sprint, then press crouch.",
	"Suppressors keep you off the enemy radar when you fire.",
	"Headshots deal extra damage on every weapon.",
	"In Battle Royale, armor plates restore armor; medkits and bandages restore health.",
	"Drag on the FIRE button to aim while shooting.",
	"Customize every touch button in Settings > Controls > Customize HUD layout.",
	"Smoke grenades block enemy line of sight - bots cannot see through them either.",
]

var bar: ProgressBar
var path := ""
var _t := 0.0


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(640, 0)
	c.add_child(v)
	var mode_name: String = "Battle Royale" if MatchConfig.mode == "br" else GameDB.MP_MODES[MatchConfig.mode].name
	var map_name: String = "Isla Verde" if MatchConfig.mode == "br" else GameDB.MP_MAPS[MatchConfig.map_id].name
	v.add_child(UITheme.label(mode_name.to_upper(), 44, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label(map_name, 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label("Bots: %s   Offline match" % MatchConfig.bot_difficulty.capitalize(), 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(640, 14)
	bar.show_percentage = false
	v.add_child(bar)
	var tip := UITheme.label("TIP: " + TIPS[randi() % TIPS.size()], 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	AudioManager.stop_music()
	path = MatchConfig.match_scene()
	# Synchronous load on the main thread. Threaded loading failed to compile the HUD script on real
	# displays ("referenced non-existent resource hud.gd"), which left matches with no HUD/touch controls.
	_load_after_frames.call_deferred()


func _load_after_frames() -> void:
	bar.value = 15.0
	await get_tree().process_frame
	await get_tree().process_frame
	var packed := load(path) as PackedScene
	bar.value = 100.0
	while _t < 0.6:
		await get_tree().process_frame
	if packed == null:
		push_error("Failed to load " + path)
		MatchConfig.to_menu()
		return
	get_tree().change_scene_to_packed(packed)


func _process(delta: float) -> void:
	_t += delta
