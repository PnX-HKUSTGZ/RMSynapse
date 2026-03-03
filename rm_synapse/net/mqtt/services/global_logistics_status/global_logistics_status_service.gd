extends Node
class_name GlobalLogisticsStatusService

signal global_logistics_status_updated(state)
signal economy_changed(remaining_economy, total_economy_obtained)
signal tech_level_changed(tech_level)
signal encryption_level_changed(encryption_level)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class GlobalLogisticsStatusState:
	extends RefCounted
	var remaining_economy: int = 0
	var total_economy_obtained: int = 0
	var tech_level: int = 0
	var encryption_level: int = 0
	var last_update_msec: int = 0

	func clone() -> GlobalLogisticsStatusState:
		var c = GlobalLogisticsStatusState.new()
		c.remaining_economy = remaining_economy
		c.total_economy_obtained = total_economy_obtained
		c.tech_level = tech_level
		c.encryption_level = encryption_level
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"remaining_economy": remaining_economy,
			"total_economy_obtained": total_economy_obtained,
			"tech_level": tech_level,
			"encryption_level": encryption_level,
			"last_update_msec": last_update_msec
		}

var _state: GlobalLogisticsStatusState = GlobalLogisticsStatusState.new()
var _adapter_bound: bool = false
var _bound_adapter = null
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _logged_negative_field: Dictionary = {}
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
	_state = GlobalLogisticsStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("global_logistics_status_updated", _state.clone())

func ingest_global_logistics_status(message) -> void:
	_on_global_logistics_status(message)

func get_state() -> GlobalLogisticsStatusState:
	return _state.clone()

func get_remaining_economy() -> int:
	return _state.remaining_economy

func get_total_economy_obtained() -> int:
	return _state.total_economy_obtained

func get_tech_level() -> int:
	return _state.tech_level

func get_encryption_level() -> int:
	return _state.encryption_level

func _on_global_logistics_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[GlobalLogisticsStatusService] Received null global_logistics_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()

	_state.remaining_economy = _to_non_negative_int(message.get_remaining_economy(), "remaining_economy")
	_state.total_economy_obtained = _to_non_negative_int(message.get_total_economy_obtained(), "total_economy_obtained")
	_state.tech_level = _to_non_negative_int(message.get_tech_level(), "tech_level")
	_state.encryption_level = _to_non_negative_int(message.get_encryption_level(), "encryption_level")
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("global_logistics_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalLogisticsStatusService] adapter_getter is not set.")
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
			_log_error("[GlobalLogisticsStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalLogisticsStatusService] Adapter getter returned non-object value")
			_logged_missing = true
		return
	if not adapter.has_signal("global_logistics_status"):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GlobalLogisticsStatusService] Adapter is missing signal: global_logistics_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.global_logistics_status.is_connected(_on_global_logistics_status):
		adapter.global_logistics_status.connect(_on_global_logistics_status)
	_adapter_bound = true
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("global_logistics_status") and _bound_adapter.global_logistics_status.is_connected(_on_global_logistics_status):
			_bound_adapter.global_logistics_status.disconnect(_on_global_logistics_status)
	_bound_adapter = null

func _to_non_negative_int(value, field_name: String) -> int:
	var v = int(value)
	if v >= 0:
		return v
	if not _logged_negative_field.has(field_name):
		_log_warn("[GlobalLogisticsStatusService] %s got negative value %d, clamped to 0." % [field_name, v])
		_logged_negative_field[field_name] = true
	return 0

func _emit_change_signals(old_state: GlobalLogisticsStatusState) -> void:
	if _state.remaining_economy != old_state.remaining_economy or _state.total_economy_obtained != old_state.total_economy_obtained:
		emit_signal("economy_changed", _state.remaining_economy, _state.total_economy_obtained)
	if _state.tech_level != old_state.tech_level:
		emit_signal("tech_level_changed", _state.tech_level)
	if _state.encryption_level != old_state.encryption_level:
		emit_signal("encryption_level_changed", _state.encryption_level)

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
