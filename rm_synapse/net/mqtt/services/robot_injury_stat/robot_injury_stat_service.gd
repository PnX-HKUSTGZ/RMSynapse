extends Node
class_name RobotInjuryStatService

signal robot_injury_stat_updated(state)
signal injury_total_changed(total_damage)
signal killer_changed(killer_id)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotInjuryStatState:
	extends RefCounted
	var total_damage: int = 0
	var collision_damage: int = 0
	var small_projectile_damage: int = 0
	var large_projectile_damage: int = 0
	var dart_splash_damage: int = 0
	var module_offline_damage: int = 0
	var offline_damage: int = 0
	var penalty_damage: int = 0
	var server_kill_damage: int = 0
	var killer_id: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotInjuryStatState:
		var c = RobotInjuryStatState.new()
		c.total_damage = total_damage
		c.collision_damage = collision_damage
		c.small_projectile_damage = small_projectile_damage
		c.large_projectile_damage = large_projectile_damage
		c.dart_splash_damage = dart_splash_damage
		c.module_offline_damage = module_offline_damage
		c.offline_damage = offline_damage
		c.penalty_damage = penalty_damage
		c.server_kill_damage = server_kill_damage
		c.killer_id = killer_id
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"total_damage": total_damage,
			"collision_damage": collision_damage,
			"small_projectile_damage": small_projectile_damage,
			"large_projectile_damage": large_projectile_damage,
			"dart_splash_damage": dart_splash_damage,
			"module_offline_damage": module_offline_damage,
			"offline_damage": offline_damage,
			"penalty_damage": penalty_damage,
			"server_kill_damage": server_kill_damage,
			"killer_id": killer_id,
			"last_update_msec": last_update_msec
		}

var _state: RobotInjuryStatState = RobotInjuryStatState.new()
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
	_state = RobotInjuryStatState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_injury_stat_updated", _state.clone())

func ingest_robot_injury_stat(message) -> void:
	_on_robot_injury_stat(message)

func get_state() -> RobotInjuryStatState:
	return _state.clone()

func get_total_damage() -> int:
	return _state.total_damage

func get_collision_damage() -> int:
	return _state.collision_damage

func get_small_projectile_damage() -> int:
	return _state.small_projectile_damage

func get_large_projectile_damage() -> int:
	return _state.large_projectile_damage

func get_dart_splash_damage() -> int:
	return _state.dart_splash_damage

func get_module_offline_damage() -> int:
	return _state.module_offline_damage

func get_offline_damage() -> int:
	return _state.offline_damage

func get_penalty_damage() -> int:
	return _state.penalty_damage

func get_server_kill_damage() -> int:
	return _state.server_kill_damage

func get_killer_id() -> int:
	return _state.killer_id

func _on_robot_injury_stat(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotInjuryStatService] Received null robot_injury_stat message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.total_damage = int(message.get_total_damage())
	_state.collision_damage = int(message.get_collision_damage())
	_state.small_projectile_damage = int(message.get_small_projectile_damage())
	_state.large_projectile_damage = int(message.get_large_projectile_damage())
	_state.dart_splash_damage = int(message.get_dart_splash_damage())
	_state.module_offline_damage = int(message.get_module_offline_damage())
	_state.offline_damage = int(message.get_offline_damage())
	_state.penalty_damage = int(message.get_penalty_damage())
	_state.server_kill_damage = int(message.get_server_kill_damage())
	_state.killer_id = int(message.get_killer_id())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_injury_stat_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotInjuryStatService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotInjuryStatService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_injury_stat"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotInjuryStatService] Adapter is invalid or missing signal: robot_injury_stat")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_injury_stat.is_connected(_on_robot_injury_stat):
		adapter.robot_injury_stat.connect(_on_robot_injury_stat)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_injury_stat") and _bound_adapter.robot_injury_stat.is_connected(_on_robot_injury_stat):
			_bound_adapter.robot_injury_stat.disconnect(_on_robot_injury_stat)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotInjuryStatState) -> void:
	if _state.total_damage != old_state.total_damage:
		emit_signal("injury_total_changed", _state.total_damage)
	if _state.killer_id != old_state.killer_id:
		emit_signal("killer_changed", _state.killer_id)

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
