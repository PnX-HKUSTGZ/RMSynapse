extends Node

# Simple production-grade logger for Godot.
# Register this script as an Autoload singleton named "Log".

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

@export var min_level: Level = Level.DEBUG
@export var enable_timestamp: bool = true
@export var use_rich_text: bool = false
@export var include_stack_on_error: bool = true

# Remote logging hook (stub).
@export var remote_enabled: bool = false
@export var remote_endpoint: String = ""

func debug(msg) -> void:
	_log(Level.DEBUG, msg)

func info(msg) -> void:
	_log(Level.INFO, msg)

func warn(msg) -> void:
	_log(Level.WARN, msg)

func error(msg) -> void:
	_log(Level.ERROR, msg)

func _log(level: int, msg) -> void:
	if level < min_level:
		return
	var text = _format_message(level, msg)
	_emit_local(level, text)
	if remote_enabled:
		_send_remote(level, text)

func _format_message(level: int, msg) -> String:
	var level_name = _level_name(level)
	var body = str(msg)
	if enable_timestamp:
		var ts = Time.get_datetime_string_from_system()
		return "[%s] [%s] %s" % [ts, level_name, body]
	return "[%s] %s" % [level_name, body]

func _level_name(level: int) -> String:
	match level:
		Level.DEBUG:
			return "DEBUG"
		Level.INFO:
			return "INFO"
		Level.WARN:
			return "WARN"
		Level.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"

func _emit_local(level: int, text: String) -> void:
	match level:
		Level.DEBUG:
			_print_text(text)
		Level.INFO:
			_print_text(text)
		Level.WARN:
			push_warning(text)
		Level.ERROR:
			printerr(text)
			if include_stack_on_error:
				push_error(text)

func _print_text(text: String) -> void:
	if use_rich_text:
		print_rich(text)
	else:
		print(text)

func _send_remote(level: int, text: String) -> void:
	# TODO: Integrate with Sentry or your own endpoint.
	# Keep this non-blocking in production.
	pass
