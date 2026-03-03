extends Node
class_name BuffService

signal buff_updated(state)
signal buff_target_changed(robot_id)
signal buff_timer_changed(left_time, max_time)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class BuffState:
	extends RefCounted
	var robot_id: int = 0
	var buff_type: int = 0
	var buff_level: int = 0
	var buff_max_time: int = 0
	var buff_left_time: int = 0
	var last_update_msec: int = 0

	func clone() -> BuffState:
		var c = BuffState.new()
		c.robot_id = robot_id
		c.buff_type = buff_type
		c.buff_level = buff_level
		c.buff_max_time = buff_max_time
		c.buff_left_time = buff_left_time
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"robot_id": robot_id,
			"buff_type": buff_type,
			"buff_level": buff_level,
			"buff_max_time": buff_max_time,
			"buff_left_time": buff_left_time,
			"last_update_msec": last_update_msec
		}

var _state: BuffState = BuffState.new()
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
	_state = BuffState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("buff_updated", _state.clone())

func ingest_buff(message) -> void:
	_on_buff(message)

func get_state() -> BuffState:
	return _state.clone()

func get_robot_id() -> int:
	return _state.robot_id

func get_buff_type() -> int:
	return _state.buff_type

func get_buff_level() -> int:
	return _state.buff_level

func get_buff_max_time() -> int:
	return _state.buff_max_time

func get_buff_left_time() -> int:
	return _state.buff_left_time

func _on_buff(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[BuffService] Received null buff message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.robot_id = int(message.get_robot_id())
	_state.buff_type = int(message.get_buff_type())
	_state.buff_level = int(message.get_buff_level())
	_state.buff_max_time = maxi(int(message.get_buff_max_time()), 0)
	_state.buff_left_time = maxi(int(message.get_buff_left_time()), 0)
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("buff_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[BuffService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[BuffService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("buff"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[BuffService] Adapter is invalid or missing signal: buff")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.buff.is_connected(_on_buff):
		adapter.buff.connect(_on_buff)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("buff") and _bound_adapter.buff.is_connected(_on_buff):
			_bound_adapter.buff.disconnect(_on_buff)
	_bound_adapter = null

func _emit_change_signals(old_state: BuffState) -> void:
	if _state.robot_id != old_state.robot_id:
		emit_signal("buff_target_changed", _state.robot_id)
	if _state.buff_left_time != old_state.buff_left_time or _state.buff_max_time != old_state.buff_max_time:
		emit_signal("buff_timer_changed", _state.buff_left_time, _state.buff_max_time)

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
