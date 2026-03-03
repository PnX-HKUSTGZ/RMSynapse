extends Node
class_name SentryCtrlResultService

signal sentry_ctrl_result_updated(state)
signal command_result_changed(command_id, result_code)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class SentryCtrlResultState:
	extends RefCounted
	var command_id: int = 0
	var result_code: int = 0
	var last_update_msec: int = 0

	func clone() -> SentryCtrlResultState:
		var c = SentryCtrlResultState.new()
		c.command_id = command_id
		c.result_code = result_code
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"command_id": command_id,
			"result_code": result_code,
			"last_update_msec": last_update_msec
		}

var _state: SentryCtrlResultState = SentryCtrlResultState.new()
var _bound_adapter = null
var _bind_retry_elapsed: float = 0.0
var _logged_missing: bool = false
var _logged_null_message: bool = false

func _ready() -> void:
	_try_bind_adapter()
	set_process(true)

func _process(delta: float) -> void:
	var interval = maxf(bind_retry_interval_sec, 0.1)
	_bind_retry_elapsed += delta
	if _bind_retry_elapsed < interval:
		return
	_bind_retry_elapsed = 0.0
	_try_bind_adapter()

func _exit_tree() -> void:
	_disconnect_bound_adapter()

func clear_cache() -> void:
	var old_state = _state.clone()
	_state = SentryCtrlResultState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("sentry_ctrl_result_updated", _state.clone())

func ingest_sentry_ctrl_result(message) -> void:
	_on_sentry_ctrl_result(message)

func get_state() -> SentryCtrlResultState:
	return _state.clone()

func get_command_id() -> int:
	return _state.command_id

func get_result_code() -> int:
	return _state.result_code

func _on_sentry_ctrl_result(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[SentryCtrlResultService] Received null sentry_ctrl_result message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.command_id = int(message.get_command_id())
	_state.result_code = int(message.get_result_code())
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("sentry_ctrl_result_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryCtrlResultService] adapter_getter is not set.")
			_logged_missing = true
		return

	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryCtrlResultService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("sentry_ctrl_result"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryCtrlResultService] Adapter is invalid or missing signal: sentry_ctrl_result")
			_logged_missing = true
		return

	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.sentry_ctrl_result.is_connected(_on_sentry_ctrl_result):
		adapter.sentry_ctrl_result.connect(_on_sentry_ctrl_result)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("sentry_ctrl_result") and _bound_adapter.sentry_ctrl_result.is_connected(_on_sentry_ctrl_result):
			_bound_adapter.sentry_ctrl_result.disconnect(_on_sentry_ctrl_result)
	_bound_adapter = null

func _emit_change_signals(old_state: SentryCtrlResultState) -> void:
	if _state.command_id != old_state.command_id or _state.result_code != old_state.result_code:
		emit_signal("command_result_changed", _state.command_id, _state.result_code)

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)

func _log_warn(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("warn"):
		logger.warn(message)
		return
	push_warning(message)
