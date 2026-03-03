extends Node
class_name RobotRespawnStatusService

signal robot_respawn_status_updated(state)
signal respawn_pending_changed(is_pending_respawn)
signal respawn_progress_changed(current, total)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotRespawnStatusState:
	extends RefCounted
	var is_pending_respawn: bool = false
	var total_respawn_progress: int = 0
	var current_respawn_progress: int = 0
	var can_free_respawn: bool = false
	var gold_cost_for_respawn: int = 0
	var can_pay_for_respawn: bool = false
	var last_update_msec: int = 0

	func clone() -> RobotRespawnStatusState:
		var c = RobotRespawnStatusState.new()
		c.is_pending_respawn = is_pending_respawn
		c.total_respawn_progress = total_respawn_progress
		c.current_respawn_progress = current_respawn_progress
		c.can_free_respawn = can_free_respawn
		c.gold_cost_for_respawn = gold_cost_for_respawn
		c.can_pay_for_respawn = can_pay_for_respawn
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"is_pending_respawn": is_pending_respawn,
			"total_respawn_progress": total_respawn_progress,
			"current_respawn_progress": current_respawn_progress,
			"can_free_respawn": can_free_respawn,
			"gold_cost_for_respawn": gold_cost_for_respawn,
			"can_pay_for_respawn": can_pay_for_respawn,
			"last_update_msec": last_update_msec
		}

var _state: RobotRespawnStatusState = RobotRespawnStatusState.new()
var _bound_adapter = null
var _bind_retry_elapsed: float = 0.0
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _logged_progress_overflow: bool = false

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
	_state = RobotRespawnStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_respawn_status_updated", _state.clone())

func ingest_robot_respawn_status(message) -> void:
	_on_robot_respawn_status(message)

func get_state() -> RobotRespawnStatusState:
	return _state.clone()

func get_is_pending_respawn() -> bool:
	return _state.is_pending_respawn

func get_total_respawn_progress() -> int:
	return _state.total_respawn_progress

func get_current_respawn_progress() -> int:
	return _state.current_respawn_progress

func get_can_free_respawn() -> bool:
	return _state.can_free_respawn

func get_gold_cost_for_respawn() -> int:
	return _state.gold_cost_for_respawn

func get_can_pay_for_respawn() -> bool:
	return _state.can_pay_for_respawn

func _on_robot_respawn_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotRespawnStatusService] Received null robot_respawn_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.is_pending_respawn = bool(message.get_is_pending_respawn())
	_state.total_respawn_progress = maxi(int(message.get_total_respawn_progress()), 0)
	_state.current_respawn_progress = maxi(int(message.get_current_respawn_progress()), 0)
	_state.can_free_respawn = bool(message.get_can_free_respawn())
	_state.gold_cost_for_respawn = maxi(int(message.get_gold_cost_for_respawn()), 0)
	_state.can_pay_for_respawn = bool(message.get_can_pay_for_respawn())
	if _state.current_respawn_progress > _state.total_respawn_progress and not _logged_progress_overflow:
		_log_warn("[RobotRespawnStatusService] current_respawn_progress(%d) > total_respawn_progress(%d)." % [_state.current_respawn_progress, _state.total_respawn_progress])
		_logged_progress_overflow = true
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_respawn_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotRespawnStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotRespawnStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_respawn_status"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotRespawnStatusService] Adapter is invalid or missing signal: robot_respawn_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_respawn_status.is_connected(_on_robot_respawn_status):
		adapter.robot_respawn_status.connect(_on_robot_respawn_status)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_respawn_status") and _bound_adapter.robot_respawn_status.is_connected(_on_robot_respawn_status):
			_bound_adapter.robot_respawn_status.disconnect(_on_robot_respawn_status)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotRespawnStatusState) -> void:
	if _state.is_pending_respawn != old_state.is_pending_respawn:
		emit_signal("respawn_pending_changed", _state.is_pending_respawn)
	if _state.current_respawn_progress != old_state.current_respawn_progress or _state.total_respawn_progress != old_state.total_respawn_progress:
		emit_signal("respawn_progress_changed", _state.current_respawn_progress, _state.total_respawn_progress)

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
