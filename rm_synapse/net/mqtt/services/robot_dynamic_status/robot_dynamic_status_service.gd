extends Node
class_name RobotDynamicStatusService

signal robot_dynamic_status_updated(state)
signal health_changed(current_health)
signal energy_changed(chassis_energy, buffer_energy)
signal combat_state_changed(is_out_of_combat, out_of_combat_countdown)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotDynamicStatusState:
	extends RefCounted
	var current_health: int = 0
	var current_heat: float = 0.0
	var last_projectile_fire_rate: float = 0.0
	var current_chassis_energy: int = 0
	var current_buffer_energy: int = 0
	var current_experience: int = 0
	var experience_for_upgrade: int = 0
	var total_projectiles_fired: int = 0
	var remaining_ammo: int = 0
	var is_out_of_combat: bool = false
	var out_of_combat_countdown: int = 0
	var can_remote_heal: bool = false
	var can_remote_ammo: bool = false
	var last_update_msec: int = 0

	func clone() -> RobotDynamicStatusState:
		var c = RobotDynamicStatusState.new()
		c.current_health = current_health
		c.current_heat = current_heat
		c.last_projectile_fire_rate = last_projectile_fire_rate
		c.current_chassis_energy = current_chassis_energy
		c.current_buffer_energy = current_buffer_energy
		c.current_experience = current_experience
		c.experience_for_upgrade = experience_for_upgrade
		c.total_projectiles_fired = total_projectiles_fired
		c.remaining_ammo = remaining_ammo
		c.is_out_of_combat = is_out_of_combat
		c.out_of_combat_countdown = out_of_combat_countdown
		c.can_remote_heal = can_remote_heal
		c.can_remote_ammo = can_remote_ammo
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"current_health": current_health,
			"current_heat": current_heat,
			"last_projectile_fire_rate": last_projectile_fire_rate,
			"current_chassis_energy": current_chassis_energy,
			"current_buffer_energy": current_buffer_energy,
			"current_experience": current_experience,
			"experience_for_upgrade": experience_for_upgrade,
			"total_projectiles_fired": total_projectiles_fired,
			"remaining_ammo": remaining_ammo,
			"is_out_of_combat": is_out_of_combat,
			"out_of_combat_countdown": out_of_combat_countdown,
			"can_remote_heal": can_remote_heal,
			"can_remote_ammo": can_remote_ammo,
			"last_update_msec": last_update_msec
		}

var _state: RobotDynamicStatusState = RobotDynamicStatusState.new()
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
	_state = RobotDynamicStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_dynamic_status_updated", _state.clone())

func ingest_robot_dynamic_status(message) -> void:
	_on_robot_dynamic_status(message)

func get_state() -> RobotDynamicStatusState:
	return _state.clone()

func get_current_health() -> int:
	return _state.current_health

func get_current_heat() -> float:
	return _state.current_heat

func get_last_projectile_fire_rate() -> float:
	return _state.last_projectile_fire_rate

func get_current_chassis_energy() -> int:
	return _state.current_chassis_energy

func get_current_buffer_energy() -> int:
	return _state.current_buffer_energy

func get_current_experience() -> int:
	return _state.current_experience

func get_experience_for_upgrade() -> int:
	return _state.experience_for_upgrade

func get_total_projectiles_fired() -> int:
	return _state.total_projectiles_fired

func get_remaining_ammo() -> int:
	return _state.remaining_ammo

func get_is_out_of_combat() -> bool:
	return _state.is_out_of_combat

func get_out_of_combat_countdown() -> int:
	return _state.out_of_combat_countdown

func get_can_remote_heal() -> bool:
	return _state.can_remote_heal

func get_can_remote_ammo() -> bool:
	return _state.can_remote_ammo

func _on_robot_dynamic_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotDynamicStatusService] Received null robot_dynamic_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.current_health = int(message.get_current_health())
	_state.current_heat = float(message.get_current_heat())
	_state.last_projectile_fire_rate = float(message.get_last_projectile_fire_rate())
	_state.current_chassis_energy = int(message.get_current_chassis_energy())
	_state.current_buffer_energy = int(message.get_current_buffer_energy())
	_state.current_experience = int(message.get_current_experience())
	_state.experience_for_upgrade = int(message.get_experience_for_upgrade())
	_state.total_projectiles_fired = int(message.get_total_projectiles_fired())
	_state.remaining_ammo = int(message.get_remaining_ammo())
	_state.is_out_of_combat = bool(message.get_is_out_of_combat())
	_state.out_of_combat_countdown = int(message.get_out_of_combat_countdown())
	_state.can_remote_heal = bool(message.get_can_remote_heal())
	_state.can_remote_ammo = bool(message.get_can_remote_ammo())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_dynamic_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotDynamicStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotDynamicStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_dynamic_status"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotDynamicStatusService] Adapter is invalid or missing signal: robot_dynamic_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_dynamic_status.is_connected(_on_robot_dynamic_status):
		adapter.robot_dynamic_status.connect(_on_robot_dynamic_status)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_dynamic_status") and _bound_adapter.robot_dynamic_status.is_connected(_on_robot_dynamic_status):
			_bound_adapter.robot_dynamic_status.disconnect(_on_robot_dynamic_status)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotDynamicStatusState) -> void:
	if _state.current_health != old_state.current_health:
		emit_signal("health_changed", _state.current_health)
	if _state.current_chassis_energy != old_state.current_chassis_energy or _state.current_buffer_energy != old_state.current_buffer_energy:
		emit_signal("energy_changed", _state.current_chassis_energy, _state.current_buffer_energy)
	if _state.is_out_of_combat != old_state.is_out_of_combat or _state.out_of_combat_countdown != old_state.out_of_combat_countdown:
		emit_signal("combat_state_changed", _state.is_out_of_combat, _state.out_of_combat_countdown)

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
