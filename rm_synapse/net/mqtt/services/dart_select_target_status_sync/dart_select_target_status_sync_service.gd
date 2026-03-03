extends Node
class_name DartSelectTargetStatusSyncService

signal dart_select_target_status_sync_updated(state)
signal dart_target_changed(target_id, open)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class DartSelectTargetStatusSyncState:
	extends RefCounted
	var target_id: int = 0
	var open: int = 0
	var last_update_msec: int = 0

	func clone() -> DartSelectTargetStatusSyncState:
		var c = DartSelectTargetStatusSyncState.new()
		c.target_id = target_id
		c.open = open
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"target_id": target_id,
			"open": open,
			"last_update_msec": last_update_msec
		}

var _state: DartSelectTargetStatusSyncState = DartSelectTargetStatusSyncState.new()
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
	_state = DartSelectTargetStatusSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("dart_select_target_status_sync_updated", _state.clone())

func ingest_dart_select_target_status_sync(message) -> void:
	_on_dart_select_target_status_sync(message)

func get_state() -> DartSelectTargetStatusSyncState:
	return _state.clone()

func get_target_id() -> int:
	return _state.target_id

func get_open() -> int:
	return _state.open

func _on_dart_select_target_status_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[DartSelectTargetStatusSyncService] Received null dart_select_target_status_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.target_id = int(message.get_target_id())
	_state.open = int(message.get_open())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("dart_select_target_status_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[DartSelectTargetStatusSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[DartSelectTargetStatusSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("dart_select_target_status_sync"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[DartSelectTargetStatusSyncService] Adapter is invalid or missing signal: dart_select_target_status_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.dart_select_target_status_sync.is_connected(_on_dart_select_target_status_sync):
		adapter.dart_select_target_status_sync.connect(_on_dart_select_target_status_sync)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("dart_select_target_status_sync") and _bound_adapter.dart_select_target_status_sync.is_connected(_on_dart_select_target_status_sync):
			_bound_adapter.dart_select_target_status_sync.disconnect(_on_dart_select_target_status_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: DartSelectTargetStatusSyncState) -> void:
	if _state.target_id != old_state.target_id or _state.open != old_state.open:
		emit_signal("dart_target_changed", _state.target_id, _state.open)

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
