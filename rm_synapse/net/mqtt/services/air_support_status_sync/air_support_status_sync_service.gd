extends Node
class_name AirSupportStatusSyncService

signal air_support_status_sync_updated(state)
signal air_support_state_changed(airsupport_status, left_time)
signal air_support_targeted_changed(is_being_targeted)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class AirSupportStatusSyncState:
	extends RefCounted
	var airsupport_status: int = 0
	var left_time: int = 0
	var cost_coins: int = 0
	var is_being_targeted: int = 0
	var shooter_status: int = 0
	var last_update_msec: int = 0

	func clone() -> AirSupportStatusSyncState:
		var c = AirSupportStatusSyncState.new()
		c.airsupport_status = airsupport_status
		c.left_time = left_time
		c.cost_coins = cost_coins
		c.is_being_targeted = is_being_targeted
		c.shooter_status = shooter_status
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"airsupport_status": airsupport_status,
			"left_time": left_time,
			"cost_coins": cost_coins,
			"is_being_targeted": is_being_targeted,
			"shooter_status": shooter_status,
			"last_update_msec": last_update_msec
		}

var _state: AirSupportStatusSyncState = AirSupportStatusSyncState.new()
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
	_state = AirSupportStatusSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("air_support_status_sync_updated", _state.clone())

func ingest_air_support_status_sync(message) -> void:
	_on_air_support_status_sync(message)

func get_state() -> AirSupportStatusSyncState:
	return _state.clone()

func get_airsupport_status() -> int:
	return _state.airsupport_status

func get_left_time() -> int:
	return _state.left_time

func get_cost_coins() -> int:
	return _state.cost_coins

func get_is_being_targeted() -> int:
	return _state.is_being_targeted

func get_shooter_status() -> int:
	return _state.shooter_status

func _on_air_support_status_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[AirSupportStatusSyncService] Received null air_support_status_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.airsupport_status = int(message.get_airsupport_status())
	_state.left_time = int(message.get_left_time())
	_state.cost_coins = int(message.get_cost_coins())
	_state.is_being_targeted = int(message.get_is_being_targeted())
	_state.shooter_status = int(message.get_shooter_status())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("air_support_status_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AirSupportStatusSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AirSupportStatusSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("air_support_status_sync"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AirSupportStatusSyncService] Adapter is invalid or missing signal: air_support_status_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.air_support_status_sync.is_connected(_on_air_support_status_sync):
		adapter.air_support_status_sync.connect(_on_air_support_status_sync)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("air_support_status_sync") and _bound_adapter.air_support_status_sync.is_connected(_on_air_support_status_sync):
			_bound_adapter.air_support_status_sync.disconnect(_on_air_support_status_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: AirSupportStatusSyncState) -> void:
	if _state.airsupport_status != old_state.airsupport_status or _state.left_time != old_state.left_time:
		emit_signal("air_support_state_changed", _state.airsupport_status, _state.left_time)
	if _state.is_being_targeted != old_state.is_being_targeted:
		emit_signal("air_support_targeted_changed", _state.is_being_targeted)

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
