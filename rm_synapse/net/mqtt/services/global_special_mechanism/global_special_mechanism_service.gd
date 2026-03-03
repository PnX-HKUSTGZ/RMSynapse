extends Node
class_name GlobalSpecialMechanismService

signal global_special_mechanism_updated(state)
signal active_effects_changed(effects)

const EFFECT_NAMES := [
	"Unknown",
	"己方堡垒被对方占领计时",
	"对方堡垒被己方占领计时"
]

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class MechanismState:
	extends RefCounted
	var id: int = 0
	var remaining_sec: int = 0

	func clone() -> MechanismState:
		var c = MechanismState.new()
		c.id = id
		c.remaining_sec = remaining_sec
		return c

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"remaining_sec": remaining_sec
		}

class GlobalSpecialMechanismState:
	extends RefCounted
	var effects: Array[MechanismState] = []
	var last_update_msec: int = 0

	func clone() -> GlobalSpecialMechanismState:
		var c = GlobalSpecialMechanismState.new()
		var copied_effects: Array[MechanismState] = []
		for effect in effects:
			copied_effects.append(effect.clone())
		c.effects = copied_effects
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		var effect_dicts: Array = []
		for effect in effects:
			effect_dicts.append(effect.to_dict())
		return {
			"effects": effect_dicts,
			"last_update_msec": last_update_msec
		}

var _state: GlobalSpecialMechanismState = GlobalSpecialMechanismState.new()
var _bound_adapter = null
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _logged_mismatch: bool = false
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
	_state = GlobalSpecialMechanismState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("global_special_mechanism_updated", _state.clone())

func ingest_global_special_mechanism(message) -> void:
	_on_global_special_mechanism(message)

func get_state() -> GlobalSpecialMechanismState:
	return _state.clone()

func get_active_effects() -> Array[MechanismState]:
	var result: Array[MechanismState] = []
	for effect in _state.effects:
		result.append(effect.clone())
	return result

func get_effect_name(effect_id: int) -> String:
	if effect_id >= 0 and effect_id < EFFECT_NAMES.size():
		return EFFECT_NAMES[effect_id]
	return "Unknown"

func _on_global_special_mechanism(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[GlobalSpecialMechanismService] Received null global_special_mechanism message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	var ids = message.get_mechanism_id()
	var times = message.get_mechanism_time_sec()
	var count = mini(ids.size(), times.size())

	if ids.size() != times.size() and not _logged_mismatch:
		_log_warn("[GlobalSpecialMechanismService] mechanism_id/time length mismatch: %d vs %d" % [ids.size(), times.size()])
		_logged_mismatch = true

	var effects: Array[MechanismState] = []
	for i in range(count):
		var effect = MechanismState.new()
		effect.id = int(ids[i])
		effect.remaining_sec = maxi(int(times[i]), 0)
		effects.append(effect)

	_state.effects = effects
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("global_special_mechanism_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[GlobalSpecialMechanismService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = null
	if adapter_getter.has_method("get_adapter_silent"):
		adapter = adapter_getter.get_adapter_silent()
	else:
		adapter = adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[GlobalSpecialMechanismService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[GlobalSpecialMechanismService] Adapter getter returned non-object value")
			_logged_missing = true
		return
	if not adapter.has_signal("global_special_mechanism"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[GlobalSpecialMechanismService] Adapter is missing signal: global_special_mechanism")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.global_special_mechanism.is_connected(_on_global_special_mechanism):
		adapter.global_special_mechanism.connect(_on_global_special_mechanism)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("global_special_mechanism") and _bound_adapter.global_special_mechanism.is_connected(_on_global_special_mechanism):
			_bound_adapter.global_special_mechanism.disconnect(_on_global_special_mechanism)
	_bound_adapter = null

func _emit_change_signals(old_state: GlobalSpecialMechanismState) -> void:
	if not _effects_equal(_state.effects, old_state.effects):
		emit_signal("active_effects_changed", get_active_effects())

func _effects_equal(a: Array[MechanismState], b: Array[MechanismState]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i].id != b[i].id or a[i].remaining_sec != b[i].remaining_sec:
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
