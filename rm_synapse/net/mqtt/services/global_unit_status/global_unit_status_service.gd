extends Node
class_name GlobalUnitStatusService

signal global_unit_status_updated(state)
signal base_state_changed(ally_base, enemy_base)
signal outpost_state_changed(ally_outpost, enemy_outpost)
signal robot_status_changed(robot_health, robot_bullets)
signal total_damage_changed(total_damage_ally, total_damage_enemy)

const BASE_STATUS_NAMES := [
	"无敌",
	"解除无敌，护甲未展开",
	"解除无敌，护甲展开"
]

const OUTPOST_STATUS_NAMES := [
	"无敌",
	"存活，解除无敌，中部装甲旋转",
	"存活，解除无敌，中部装甲停转",
	"被击毁，不可重建",
	"被击毁，可重建",
	"被击毁，重建中"
]

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class BaseState:
	extends RefCounted
	var health: int = 0
	var status: int = 0
	var shield: int = 0

	func clone() -> BaseState:
		var c = BaseState.new()
		c.health = health
		c.status = status
		c.shield = shield
		return c

	func to_dict() -> Dictionary:
		return {
			"health": health,
			"status": status,
			"shield": shield
		}

class OutpostState:
	extends RefCounted
	var health: int = 0
	var status: int = 0

	func clone() -> OutpostState:
		var c = OutpostState.new()
		c.health = health
		c.status = status
		return c

	func to_dict() -> Dictionary:
		return {
			"health": health,
			"status": status
		}

class GlobalUnitStatusState:
	extends RefCounted
	var ally_base: BaseState = BaseState.new()
	var enemy_base: BaseState = BaseState.new()
	var ally_outpost: OutpostState = OutpostState.new()
	var enemy_outpost: OutpostState = OutpostState.new()
	var robot_health: Array[int] = []
	var robot_bullets: Array[int] = []
	var total_damage_ally: int = 0
	var total_damage_enemy: int = 0
	var last_update_msec: int = 0

	func clone() -> GlobalUnitStatusState:
		var c = GlobalUnitStatusState.new()
		c.ally_base = ally_base.clone()
		c.enemy_base = enemy_base.clone()
		c.ally_outpost = ally_outpost.clone()
		c.enemy_outpost = enemy_outpost.clone()
		c.robot_health = robot_health.duplicate()
		c.robot_bullets = robot_bullets.duplicate()
		c.total_damage_ally = total_damage_ally
		c.total_damage_enemy = total_damage_enemy
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"ally_base": ally_base.to_dict(),
			"enemy_base": enemy_base.to_dict(),
			"ally_outpost": ally_outpost.to_dict(),
			"enemy_outpost": enemy_outpost.to_dict(),
			"robot_health": robot_health.duplicate(),
			"robot_bullets": robot_bullets.duplicate(),
			"total_damage_ally": total_damage_ally,
			"total_damage_enemy": total_damage_enemy,
			"last_update_msec": last_update_msec
		}

var _state: GlobalUnitStatusState = GlobalUnitStatusState.new()
var _adapter_bound: bool = false
var _bound_adapter = null
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _bind_retry_elapsed: float = 0.0

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
	_state = GlobalUnitStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("global_unit_status_updated", _state.clone())

func ingest_global_unit_status(message) -> void:
	_on_global_unit_status(message)

func get_state() -> GlobalUnitStatusState:
	return _state.clone()

func get_ally_base() -> BaseState:
	return _state.ally_base.clone()

func get_enemy_base() -> BaseState:
	return _state.enemy_base.clone()

func get_ally_outpost() -> OutpostState:
	return _state.ally_outpost.clone()

func get_enemy_outpost() -> OutpostState:
	return _state.enemy_outpost.clone()

func get_robot_health() -> Array[int]:
	return _state.robot_health.duplicate()

func get_robot_bullets() -> Array[int]:
	return _state.robot_bullets.duplicate()

func get_total_damage_ally() -> int:
	return _state.total_damage_ally

func get_total_damage_enemy() -> int:
	return _state.total_damage_enemy

func get_base_status_name(status: int) -> String:
	if status >= 0 and status < BASE_STATUS_NAMES.size():
		return BASE_STATUS_NAMES[status]
	return "Unknown"

func get_outpost_status_name(status: int) -> String:
	if status >= 0 and status < OUTPOST_STATUS_NAMES.size():
		return OUTPOST_STATUS_NAMES[status]
	return "Unknown"

func _on_global_unit_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[GlobalUnitStatusService] Received null global_unit_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()

	_state.ally_base.health = int(message.get_base_health())
	_state.ally_base.status = int(message.get_base_status())
	_state.ally_base.shield = int(message.get_base_shield())
	_state.ally_outpost.health = int(message.get_outpost_health())
	_state.ally_outpost.status = int(message.get_outpost_status())

	_state.enemy_base.health = int(message.get_enemy_base_health())
	_state.enemy_base.status = int(message.get_enemy_base_status())
	_state.enemy_base.shield = int(message.get_enemy_base_shield())
	_state.enemy_outpost.health = int(message.get_enemy_outpost_health())
	_state.enemy_outpost.status = int(message.get_enemy_outpost_status())

	_state.robot_health = _to_int_array(message.get_robot_health())
	_state.robot_bullets = _to_int_array(message.get_robot_bullets())
	_state.total_damage_ally = int(message.get_total_damage_ally())
	_state.total_damage_enemy = int(message.get_total_damage_enemy())
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("global_unit_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalUnitStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = null
	if adapter_getter.has_method("get_adapter_silent"):
		adapter = adapter_getter.get_adapter_silent()
	else:
		adapter = adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalUnitStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalUnitStatusService] Adapter getter returned non-object value")
			_logged_missing = true
		return
	if not adapter.has_signal("global_unit_status"):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalUnitStatusService] Adapter is missing signal: global_unit_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.global_unit_status.is_connected(_on_global_unit_status):
		adapter.global_unit_status.connect(_on_global_unit_status)
	_adapter_bound = true
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("global_unit_status") and _bound_adapter.global_unit_status.is_connected(_on_global_unit_status):
			_bound_adapter.global_unit_status.disconnect(_on_global_unit_status)
	_bound_adapter = null

func _emit_change_signals(old_state: GlobalUnitStatusState) -> void:
	if _is_base_changed(_state.ally_base, old_state.ally_base) or _is_base_changed(_state.enemy_base, old_state.enemy_base):
		emit_signal("base_state_changed", _state.ally_base.clone(), _state.enemy_base.clone())
	if _is_outpost_changed(_state.ally_outpost, old_state.ally_outpost) or _is_outpost_changed(_state.enemy_outpost, old_state.enemy_outpost):
		emit_signal("outpost_state_changed", _state.ally_outpost.clone(), _state.enemy_outpost.clone())
	if not _int_array_equals(_state.robot_health, old_state.robot_health) or not _int_array_equals(_state.robot_bullets, old_state.robot_bullets):
		emit_signal("robot_status_changed", _state.robot_health.duplicate(), _state.robot_bullets.duplicate())
	if _state.total_damage_ally != old_state.total_damage_ally or _state.total_damage_enemy != old_state.total_damage_enemy:
		emit_signal("total_damage_changed", _state.total_damage_ally, _state.total_damage_enemy)

func _is_base_changed(a: BaseState, b: BaseState) -> bool:
	return a.health != b.health or a.status != b.status or a.shield != b.shield

func _is_outpost_changed(a: OutpostState, b: OutpostState) -> bool:
	return a.health != b.health or a.status != b.status

func _to_int_array(values) -> Array[int]:
	var result: Array[int] = []
	for v in values:
		result.append(int(v))
	return result

func _int_array_equals(a: Array[int], b: Array[int]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

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
