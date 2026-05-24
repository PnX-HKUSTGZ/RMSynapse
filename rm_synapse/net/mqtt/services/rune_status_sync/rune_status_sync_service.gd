extends Node
class_name RuneStatusSyncService

signal rune_status_sync_updated(state)
signal rune_status_changed(rune_status)
signal rune_arms_changed(activated_arms, average_rings)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RuneStatusSyncState:
	extends RefCounted
	var rune_status: int = 0
	var activated_arms: int = 0
	var average_rings: float = 0.0
	var last_update_msec: int = 0

	func clone() -> RuneStatusSyncState:
		var c = RuneStatusSyncState.new()
		c.rune_status = rune_status
		c.activated_arms = activated_arms
		c.average_rings = average_rings
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"rune_status": rune_status,
			"activated_arms": activated_arms,
			"average_rings": average_rings,
			"last_update_msec": last_update_msec
		}

var _state: RuneStatusSyncState = RuneStatusSyncState.new()
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
	_state = RuneStatusSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("rune_status_sync_updated", _state.clone())

func ingest_rune_status_sync(message) -> void:
	_on_rune_status_sync(message)

func get_state() -> RuneStatusSyncState:
	return _state.clone()

func get_rune_status() -> int:
	return _state.rune_status

func get_activated_arms() -> int:
	return _state.activated_arms

func get_average_rings() -> float:
	return _state.average_rings

func get_rune_status_name(status: int) -> String:
	return "Unknown"

func _on_rune_status_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RuneStatusSyncService] Received null rune_status_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.rune_status = int(message.get_rune_status())
	_state.activated_arms = int(message.get_activated_arms())
	_state.average_rings = float(message.get_average_rings())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("rune_status_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RuneStatusSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RuneStatusSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("rune_status_sync"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RuneStatusSyncService] Adapter is invalid or missing signal: rune_status_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.rune_status_sync.is_connected(_on_rune_status_sync):
		adapter.rune_status_sync.connect(_on_rune_status_sync)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("rune_status_sync") and _bound_adapter.rune_status_sync.is_connected(_on_rune_status_sync):
			_bound_adapter.rune_status_sync.disconnect(_on_rune_status_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: RuneStatusSyncState) -> void:
	if _state.rune_status != old_state.rune_status:
		emit_signal("rune_status_changed", _state.rune_status)
	if _state.activated_arms != old_state.activated_arms or _state.average_rings != old_state.average_rings:
		emit_signal("rune_arms_changed", _state.activated_arms, _state.average_rings)

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
