extends Node
class_name SentryStatusSyncService

signal sentry_status_sync_updated(state)
signal sentry_posture_changed(posture_id)
signal sentry_weakened_changed(is_weakened)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class SentryStatusSyncState:
	extends RefCounted
	var posture_id: int = 0
	var is_weakened: bool = false
	var last_update_msec: int = 0

	func clone() -> SentryStatusSyncState:
		var c = SentryStatusSyncState.new()
		c.posture_id = posture_id
		c.is_weakened = is_weakened
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"posture_id": posture_id,
			"is_weakened": is_weakened,
			"last_update_msec": last_update_msec
		}

var _state: SentryStatusSyncState = SentryStatusSyncState.new()
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
	_state = SentryStatusSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("sentry_status_sync_updated", _state.clone())

func ingest_sentry_status_sync(message) -> void:
	_on_sentry_status_sync(message)

func get_state() -> SentryStatusSyncState:
	return _state.clone()

func get_posture_id() -> int:
	return _state.posture_id

func get_is_weakened() -> bool:
	return _state.is_weakened

func _on_sentry_status_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[SentryStatusSyncService] Received null sentry_status_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.posture_id = int(message.get_posture_id())
	_state.is_weakened = bool(message.get_is_weakened())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("sentry_status_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryStatusSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryStatusSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("sentry_status_sync"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[SentryStatusSyncService] Adapter is invalid or missing signal: sentry_status_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.sentry_status_sync.is_connected(_on_sentry_status_sync):
		adapter.sentry_status_sync.connect(_on_sentry_status_sync)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("sentry_status_sync") and _bound_adapter.sentry_status_sync.is_connected(_on_sentry_status_sync):
			_bound_adapter.sentry_status_sync.disconnect(_on_sentry_status_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: SentryStatusSyncState) -> void:
	if _state.posture_id != old_state.posture_id:
		emit_signal("sentry_posture_changed", _state.posture_id)
	if _state.is_weakened != old_state.is_weakened:
		emit_signal("sentry_weakened_changed", _state.is_weakened)

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
