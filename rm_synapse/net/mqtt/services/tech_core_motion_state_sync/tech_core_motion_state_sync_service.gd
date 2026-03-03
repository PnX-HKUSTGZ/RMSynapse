extends Node
class_name TechCoreMotionStateSyncService

signal tech_core_motion_state_sync_updated(state)
signal tech_core_status_changed(status, enemy_core_status)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class TechCoreMotionStateSyncState:
	extends RefCounted
	var maximum_difficulty_level: int = 0
	var status: int = 0
	var enemy_core_status: int = 0
	var remain_time_all: int = 0
	var remain_time_step: int = 0
	var last_update_msec: int = 0

	func clone() -> TechCoreMotionStateSyncState:
		var c = TechCoreMotionStateSyncState.new()
		c.maximum_difficulty_level = maximum_difficulty_level
		c.status = status
		c.enemy_core_status = enemy_core_status
		c.remain_time_all = remain_time_all
		c.remain_time_step = remain_time_step
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"maximum_difficulty_level": maximum_difficulty_level,
			"status": status,
			"enemy_core_status": enemy_core_status,
			"remain_time_all": remain_time_all,
			"remain_time_step": remain_time_step,
			"last_update_msec": last_update_msec
		}

var _state: TechCoreMotionStateSyncState = TechCoreMotionStateSyncState.new()
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
	_state = TechCoreMotionStateSyncState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("tech_core_motion_state_sync_updated", _state.clone())

func ingest_tech_core_motion_state_sync(message) -> void:
	_on_tech_core_motion_state_sync(message)

func get_state() -> TechCoreMotionStateSyncState:
	return _state.clone()

func get_maximum_difficulty_level() -> int:
	return _state.maximum_difficulty_level

func get_status() -> int:
	return _state.status

func get_enemy_core_status() -> int:
	return _state.enemy_core_status

func get_remain_time_all() -> int:
	return _state.remain_time_all

func get_remain_time_step() -> int:
	return _state.remain_time_step

func _on_tech_core_motion_state_sync(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[TechCoreMotionStateSyncService] Received null tech_core_motion_state_sync message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.maximum_difficulty_level = int(message.get_maximum_difficulty_level())
	_state.status = int(message.get_status())
	_state.enemy_core_status = int(message.get_enemy_core_status())
	_state.remain_time_all = int(message.get_remain_time_all())
	_state.remain_time_step = int(message.get_remain_time_step())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("tech_core_motion_state_sync_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[TechCoreMotionStateSyncService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[TechCoreMotionStateSyncService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("tech_core_motion_state_sync"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[TechCoreMotionStateSyncService] Adapter is invalid or missing signal: tech_core_motion_state_sync")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.tech_core_motion_state_sync.is_connected(_on_tech_core_motion_state_sync):
		adapter.tech_core_motion_state_sync.connect(_on_tech_core_motion_state_sync)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("tech_core_motion_state_sync") and _bound_adapter.tech_core_motion_state_sync.is_connected(_on_tech_core_motion_state_sync):
			_bound_adapter.tech_core_motion_state_sync.disconnect(_on_tech_core_motion_state_sync)
	_bound_adapter = null

func _emit_change_signals(old_state: TechCoreMotionStateSyncState) -> void:
	if _state.status != old_state.status or _state.enemy_core_status != old_state.enemy_core_status:
		emit_signal("tech_core_status_changed", _state.status, _state.enemy_core_status)

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
