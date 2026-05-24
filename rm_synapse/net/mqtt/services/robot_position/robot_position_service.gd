extends Node
class_name RobotPositionService

signal robot_position_updated(state)
signal position_changed(x, y, z, yaw)
signal robot_id_changed(robot_id)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotPositionState:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var yaw: float = 0.0
	var robot_id: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotPositionState:
		var c = RobotPositionState.new()
		c.x = x
		c.y = y
		c.z = z
		c.yaw = yaw
		c.robot_id = robot_id
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"x": x,
			"y": y,
			"z": z,
			"yaw": yaw,
			"robot_id": robot_id,
			"last_update_msec": last_update_msec
		}

var _state: RobotPositionState = RobotPositionState.new()
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
	_state = RobotPositionState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_position_updated", _state.clone())

func ingest_robot_position(message) -> void:
	_on_robot_position(message)

func get_state() -> RobotPositionState:
	return _state.clone()

func get_x() -> float:
	return _state.x

func get_y() -> float:
	return _state.y

func get_z() -> float:
	return _state.z

func get_yaw() -> float:
	return _state.yaw

func get_robot_id() -> int:
	return _state.robot_id

func get_planar_position() -> Vector2:
	return Vector2(_state.x, _state.y)

func _on_robot_position(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotPositionService] Received null robot_position message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.x = float(message.get_x())
	_state.y = float(message.get_y())
	_state.z = float(message.get_z())
	_state.yaw = float(message.get_yaw())
	_state.robot_id = _get_message_int(message, "get_robot_id")
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_position_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPositionService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPositionService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_position"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPositionService] Adapter is invalid or missing signal: robot_position")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_position.is_connected(_on_robot_position):
		adapter.robot_position.connect(_on_robot_position)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_position") and _bound_adapter.robot_position.is_connected(_on_robot_position):
			_bound_adapter.robot_position.disconnect(_on_robot_position)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotPositionState) -> void:
	if _state.x != old_state.x or _state.y != old_state.y or _state.z != old_state.z or _state.yaw != old_state.yaw:
		emit_signal("position_changed", _state.x, _state.y, _state.z, _state.yaw)
	if _state.robot_id != old_state.robot_id:
		emit_signal("robot_id_changed", _state.robot_id)

func _get_message_int(message, method: String) -> int:
	if method != "" and message.has_method(method):
		return int(message.call(method))
	return 0

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
