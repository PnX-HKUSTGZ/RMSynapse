extends Node
class_name PenaltyInfoService

signal penalty_info_updated(state)
signal penalty_type_changed(penalty_type)
signal penalty_effect_changed(penalty_effect_sec)
signal penalty_count_changed(total_penalty_num)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class PenaltyInfoState:
	extends RefCounted
	var penalty_type: int = 0
	var penalty_effect_sec: int = 0
	var total_penalty_num: int = 0
	var last_update_msec: int = 0

	func clone() -> PenaltyInfoState:
		var c = PenaltyInfoState.new()
		c.penalty_type = penalty_type
		c.penalty_effect_sec = penalty_effect_sec
		c.total_penalty_num = total_penalty_num
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"penalty_type": penalty_type,
			"penalty_effect_sec": penalty_effect_sec,
			"total_penalty_num": total_penalty_num,
			"last_update_msec": last_update_msec
		}

var _state: PenaltyInfoState = PenaltyInfoState.new()
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
	_state = PenaltyInfoState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("penalty_info_updated", _state.clone())

func ingest_penalty_info(message) -> void:
	_on_penalty_info(message)

func get_state() -> PenaltyInfoState:
	return _state.clone()

func get_penalty_type() -> int:
	return _state.penalty_type

func get_penalty_effect_sec() -> int:
	return _state.penalty_effect_sec

func get_total_penalty_num() -> int:
	return _state.total_penalty_num

func _on_penalty_info(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[PenaltyInfoService] Received null penalty_info message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.penalty_type = int(message.get_penalty_type())
	_state.penalty_effect_sec = int(message.get_penalty_effect_sec())
	_state.total_penalty_num = int(message.get_total_penalty_num())
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("penalty_info_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[PenaltyInfoService] adapter_getter is not set.")
			_logged_missing = true
		return

	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[PenaltyInfoService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("penalty_info"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[PenaltyInfoService] Adapter is invalid or missing signal: penalty_info")
			_logged_missing = true
		return

	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.penalty_info.is_connected(_on_penalty_info):
		adapter.penalty_info.connect(_on_penalty_info)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("penalty_info") and _bound_adapter.penalty_info.is_connected(_on_penalty_info):
			_bound_adapter.penalty_info.disconnect(_on_penalty_info)
	_bound_adapter = null

func _emit_change_signals(old_state: PenaltyInfoState) -> void:
	if _state.penalty_type != old_state.penalty_type:
		emit_signal("penalty_type_changed", _state.penalty_type)
	if _state.penalty_effect_sec != old_state.penalty_effect_sec:
		emit_signal("penalty_effect_changed", _state.penalty_effect_sec)
	if _state.total_penalty_num != old_state.total_penalty_num:
		emit_signal("penalty_count_changed", _state.total_penalty_num)

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
