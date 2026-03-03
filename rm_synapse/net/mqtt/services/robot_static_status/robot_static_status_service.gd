extends Node
class_name RobotStaticStatusService

signal robot_static_status_updated(state)
signal robot_identity_changed(robot_id, robot_type)
signal robot_capability_changed(level, max_health, max_power)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotStaticStatusState:
	extends RefCounted
	var connection_state: int = 0
	var field_state: int = 0
	var alive_state: int = 0
	var robot_id: int = 0
	var robot_type: int = 0
	var performance_system_shooter: int = 0
	var performance_system_chassis: int = 0
	var level: int = 0
	var max_health: int = 0
	var max_heat: int = 0
	var heat_cooldown_rate: float = 0.0
	var max_power: int = 0
	var max_buffer_energy: int = 0
	var max_chassis_energy: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotStaticStatusState:
		var c = RobotStaticStatusState.new()
		c.connection_state = connection_state
		c.field_state = field_state
		c.alive_state = alive_state
		c.robot_id = robot_id
		c.robot_type = robot_type
		c.performance_system_shooter = performance_system_shooter
		c.performance_system_chassis = performance_system_chassis
		c.level = level
		c.max_health = max_health
		c.max_heat = max_heat
		c.heat_cooldown_rate = heat_cooldown_rate
		c.max_power = max_power
		c.max_buffer_energy = max_buffer_energy
		c.max_chassis_energy = max_chassis_energy
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"connection_state": connection_state,
			"field_state": field_state,
			"alive_state": alive_state,
			"robot_id": robot_id,
			"robot_type": robot_type,
			"performance_system_shooter": performance_system_shooter,
			"performance_system_chassis": performance_system_chassis,
			"level": level,
			"max_health": max_health,
			"max_heat": max_heat,
			"heat_cooldown_rate": heat_cooldown_rate,
			"max_power": max_power,
			"max_buffer_energy": max_buffer_energy,
			"max_chassis_energy": max_chassis_energy,
			"last_update_msec": last_update_msec
		}

var _state: RobotStaticStatusState = RobotStaticStatusState.new()
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
	_state = RobotStaticStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_static_status_updated", _state.clone())

func ingest_robot_static_status(message) -> void:
	_on_robot_static_status(message)

func get_state() -> RobotStaticStatusState:
	return _state.clone()

func get_connection_state() -> int:
	return _state.connection_state

func get_field_state() -> int:
	return _state.field_state

func get_alive_state() -> int:
	return _state.alive_state

func get_robot_id() -> int:
	return _state.robot_id

func get_robot_type() -> int:
	return _state.robot_type

func get_performance_system_shooter() -> int:
	return _state.performance_system_shooter

func get_performance_system_chassis() -> int:
	return _state.performance_system_chassis

func get_level() -> int:
	return _state.level

func get_max_health() -> int:
	return _state.max_health

func get_max_heat() -> int:
	return _state.max_heat

func get_heat_cooldown_rate() -> float:
	return _state.heat_cooldown_rate

func get_max_power() -> int:
	return _state.max_power

func get_max_buffer_energy() -> int:
	return _state.max_buffer_energy

func get_max_chassis_energy() -> int:
	return _state.max_chassis_energy

func _on_robot_static_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotStaticStatusService] Received null robot_static_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.connection_state = int(message.get_connection_state())
	_state.field_state = int(message.get_field_state())
	_state.alive_state = int(message.get_alive_state())
	_state.robot_id = int(message.get_robot_id())
	_state.robot_type = int(message.get_robot_type())
	_state.performance_system_shooter = int(message.get_performance_system_shooter())
	_state.performance_system_chassis = int(message.get_performance_system_chassis())
	_state.level = int(message.get_level())
	_state.max_health = int(message.get_max_health())
	_state.max_heat = int(message.get_max_heat())
	_state.heat_cooldown_rate = float(message.get_heat_cooldown_rate())
	_state.max_power = int(message.get_max_power())
	_state.max_buffer_energy = int(message.get_max_buffer_energy())
	_state.max_chassis_energy = int(message.get_max_chassis_energy())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_static_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotStaticStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotStaticStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_static_status"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotStaticStatusService] Adapter is invalid or missing signal: robot_static_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_static_status.is_connected(_on_robot_static_status):
		adapter.robot_static_status.connect(_on_robot_static_status)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_static_status") and _bound_adapter.robot_static_status.is_connected(_on_robot_static_status):
			_bound_adapter.robot_static_status.disconnect(_on_robot_static_status)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotStaticStatusState) -> void:
	if _state.robot_id != old_state.robot_id or _state.robot_type != old_state.robot_type:
		emit_signal("robot_identity_changed", _state.robot_id, _state.robot_type)
	if _state.level != old_state.level or _state.max_health != old_state.max_health or _state.max_power != old_state.max_power:
		emit_signal("robot_capability_changed", _state.level, _state.max_health, _state.max_power)

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
