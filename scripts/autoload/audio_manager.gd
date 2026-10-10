extends Node
## Audio buses, pooled 2D/3D one-shot players, UI sounds and music.

const UI_SOUNDS := {
	"click": "res://assets/audio/ui/click_001.ogg",
	"click2": "res://assets/audio/ui/click_002.ogg",
	"confirm": "res://assets/audio/ui/confirmation_001.ogg",
	"back": "res://assets/audio/ui/back_001.ogg",
	"error": "res://assets/audio/ui/error_001.ogg",
	"select": "res://assets/audio/ui/select_001.ogg",
	"switch": "res://assets/audio/ui/switch_002.ogg",
	"toggle": "res://assets/audio/ui/toggle_001.ogg",
}

const POOL_3D := 28
const POOL_2D := 10

var _cache := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0
var music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 8.0
		p.max_distance = 120.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_polyphony = 2
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool2d.append(p2)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	apply_volumes()
	SaveManager.settings_changed.connect(apply_volumes)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Master", SaveManager.get_setting("audio", "master", 0.9))
	_set_bus("Music", SaveManager.get_setting("audio", "music", 0.6))
	_set_bus("SFX", SaveManager.get_setting("audio", "sfx", 0.9))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func get_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func play_3d(path: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 120.0) -> void:
	var s := get_stream(path)
	if s == null:
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	if not p.is_inside_tree():
		return
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.play()


func play_2d(path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := get_stream(path)
	if s == null:
		return
	var p := _pool2d[_i2]
	_i2 = (_i2 + 1) % POOL_2D
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func ui(sound: String = "click") -> void:
	play_2d(UI_SOUNDS.get(sound, UI_SOUNDS.click), -6.0)


func play_music(path: String, volume_db: float = -8.0) -> void:
	var s := get_stream(path)
	if s == null:
		return
	if music.stream == s and music.playing:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	music.stream = s
	music.volume_db = volume_db
	music.play()


func stop_music() -> void:
	music.stop()
