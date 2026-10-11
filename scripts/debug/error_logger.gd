extends Logger
## Godot 4.5+ Logger that forwards engine/script errors to the ErrorLog autoload so they can be shown
## on screen (the Android editor's game window has no visible Output panel). Called from any thread.

var sink: Node


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var msg := rationale if rationale != "" else code
	var where := "%s:%d" % [file.get_file(), line]
	if function != "":
		where += " (%s)" % function
	# Prefer the GDScript location when a script backtrace is available.
	for bt in script_backtraces:
		if bt and bt.has_method("get_frame_count") and bt.get_frame_count() > 0:
			where = "%s:%d (%s)" % [str(bt.get_frame_file(0)).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
			break
	if is_instance_valid(sink):
		sink.call_deferred("add_error", "%s  @ %s" % [msg, where])


func _log_message(_message: String, _error: bool) -> void:
	pass
