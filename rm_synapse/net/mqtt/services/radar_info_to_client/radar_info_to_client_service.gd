extends Node
class_name RadarInfoToClientService

signal radar_info_updated(state)
signal radar_entries_changed(entries)

const ENTRY_COUNT := 12

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RadarRobotInfo:
	extends RefCounted
	var target_pos_x_cm: int = 0
	var target_pos_y_cm: int = 0
	var is_high_light: int = 0

	func clone() -> RadarRobotInfo:
		var c = RadarRobotInfo.new()
		c.target_pos_x_cm = target_pos_x_cm
		c.target_pos_y_cm = target_pos_y_cm
		c.is_high_light = is_high_light
		return c

	func to_dict() -> Dictionary:
		return {
			"target_pos_x_cm": target_pos_x_cm,
			"target_pos_y_cm": target_pos_y_cm,
			"is_high_light": is_high_light,
		}

class RadarInfoToClientState:
	extends RefCounted
	var entries: Array = []
	var last_update_msec: int = 0

	func clone() -> RadarInfoToClientState:
		var c = RadarInfoToClientState.new()
		for entry in entries:
			c.entries.append(entry.clone())
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		var entry_dicts: Array = []
		for entry in entries:
			entry_dicts.append(entry.to_dict())
		return {
			"entries": entry_dicts,
			"last_update_msec": last_update_msec,
		}

var _state: RadarInfoToClientState = _make_default_state()
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
	_state = _make_default_state()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("radar_info_updated", _state.clone())

func ingest_radar_info_to_client(message) -> void:
	_on_radar_info_to_client(message)

func get_state() -> RadarInfoToClientState:
	return _state.clone()

func get_entries() -> Array:
	var entries: Array = []
	for entry in _state.entries:
		entries.append(entry.clone())
	return entries

func get_entry(index: int) -> RadarRobotInfo:
	if index < 0 or index >= _state.entries.size():
		return null
	return _state.entries[index].clone()

func get_entry_count() -> int:
	return _state.entries.size()

func _make_default_state() -> RadarInfoToClientState:
	var state = RadarInfoToClientState.new()
	state.entries = _make_default_entries()
	return state

func _make_default_entries() -> Array:
	var entries: Array = []
	for _i in range(ENTRY_COUNT):
		entries.append(RadarRobotInfo.new())
	return entries

func _on_radar_info_to_client(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RadarInfoToClientService] Received null radar_info_to_client message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.entries = _make_default_entries()
	var incoming_entries = message.get_radar_single_robot_info()
	var copy_count = mini(incoming_entries.size(), ENTRY_COUNT)
	for i in range(copy_count):
		var src = incoming_entries[i]
		var dst: RadarRobotInfo = _state.entries[i]
		dst.target_pos_x_cm = int(src.get_target_pos_x())
		dst.target_pos_y_cm = int(src.get_target_pos_y())
		dst.is_high_light = int(src.get_is_high_light())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("radar_info_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RadarInfoToClientService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RadarInfoToClientService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("radar_info_to_client"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RadarInfoToClientService] Adapter is invalid or missing signal: radar_info_to_client")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.radar_info_to_client.is_connected(_on_radar_info_to_client):
		adapter.radar_info_to_client.connect(_on_radar_info_to_client)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("radar_info_to_client") and _bound_adapter.radar_info_to_client.is_connected(_on_radar_info_to_client):
			_bound_adapter.radar_info_to_client.disconnect(_on_radar_info_to_client)
	_bound_adapter = null

func _emit_change_signals(old_state: RadarInfoToClientState) -> void:
	if _entries_changed(old_state.entries, _state.entries):
		emit_signal("radar_entries_changed", get_entries())

func _entries_changed(old_entries: Array, new_entries: Array) -> bool:
	if old_entries.size() != new_entries.size():
		return true
	for i in range(new_entries.size()):
		var old_entry = old_entries[i]
		var new_entry = new_entries[i]
		if old_entry.target_pos_x_cm != new_entry.target_pos_x_cm:
			return true
		if old_entry.target_pos_y_cm != new_entry.target_pos_y_cm:
			return true
		if old_entry.is_high_light != new_entry.is_high_light:
			return true
	return false

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
