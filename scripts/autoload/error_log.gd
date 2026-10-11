extends Node
## Collects engine/script errors at runtime and shows them in a small on-screen panel so problems on
## devices without a visible console (phones, the Godot Android editor) can be screenshotted.
## Uses the Logger API (Godot 4.5+); on older versions it only shows the build label.

const BUILD := "0.5.1 (2026-10-11)"
const MAX_LINES := 8
## Errors that are known and harmless (they only occur at exit or in tests).
const IGNORE := ["ObjectDB instances leaked", "resources still in use at exit", "RID allocations", "PagedAllocator"]

var errors: PackedStringArray = []
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _logger: Object


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ClassDB.class_exists("Logger") and OS.has_method("add_logger"):
		var scr = load("res://scripts/debug/error_logger.gd")
		if scr:
			_logger = scr.new()
			_logger.sink = self
			OS.call("add_logger", _logger)
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.02, 0.02, 0.88)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(500, 0)
	_panel.add_child(_label)
	_panel.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			_panel.visible = false)


func add_error(msg: String) -> void:
	for s in IGNORE:
		if msg.contains(s):
			return
	if errors.size() > 0 and errors[errors.size() - 1] == msg:
		return
	errors.append(msg)
	if errors.size() > 40:
		errors.remove_at(0)
	if not _label:
		return
	var tail := errors.slice(maxi(0, errors.size() - MAX_LINES))
	_label.text = "ERRORS (build %s) - tap to hide\n%s" % [BUILD, "\n".join(tail)]
	_panel.visible = true


func _exit_tree() -> void:
	if _logger and OS.has_method("remove_logger"):
		OS.call("remove_logger", _logger)
