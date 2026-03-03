extends Node
class_name RobotPerformanceSelectionSyncService

signal robot_performance_selection_sync_updated(state)
signal performance_selection_changed(shooter, chassis, sentry_control)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotPerformanceSelectionSyncState:
	extends RefCounted
	var shooter: int = 0
	var chassis: int = 0
	var sentry_control: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotPerformanceSelectionSyncState:
		var c = RobotPerformanceSelectionSyncState.new()
		c.shooter = shooter
		c.chassis = chassis
		c.sentry_control = sentry_control
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"shooter": shooter,
			"chassis": chassis,
			"sentry_control": sentry_control,
			"last_update_msec": last_update_msec
		}

var _state: RobotPerformanceSelectionSyncState = RobotPerformanceSelectionSyncState.new()
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
	_state = RobotPerformanceSelectionSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_performance_selection_sync_updated", _state.clone())

func ingest_robot_performance_selection_sync(message) -> void:
	_on_robot_performance_selection_sync(message)

func get_state() -> RobotPerformanceSelectionSyncState:
	return _state.clone()

func get_shooter() -> int:
	return _state.shooter

func get_chassis() -> int:
	return _state.chassis

func get_sentry_control() -> int:
	return _state.sentry_control

func _on_robot_performance_selection_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotPerformanceSelectionSyncService] Received null robot_performance_selection_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.shooter = int(message.get_shooter())
	_state.chassis = int(message.get_chassis())
	_state.sentry_control = int(message.get_sentry_control())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_performance_selection_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPerformanceSelectionSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPerformanceSelectionSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_performance_selection_sync"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPerformanceSelectionSyncService] Adapter is invalid or missing signal: robot_performance_selection_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_performance_selection_sync.is_connected(_on_robot_performance_selection_sync):
		adapter.robot_performance_selection_sync.connect(_on_robot_performance_selection_sync)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_performance_selection_sync") and _bound_adapter.robot_performance_selection_sync.is_connected(_on_robot_performance_selection_sync):
			_bound_adapter.robot_performance_selection_sync.disconnect(_on_robot_performance_selection_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotPerformanceSelectionSyncState) -> void:
	if _state.shooter != old_state.shooter or _state.chassis != old_state.chassis or _state.sentry_control != old_state.sentry_control:
		emit_signal("performance_selection_changed", _state.shooter, _state.chassis, _state.sentry_control)

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
