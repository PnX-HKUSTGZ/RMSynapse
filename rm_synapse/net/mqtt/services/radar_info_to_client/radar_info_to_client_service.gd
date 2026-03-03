extends Node
class_name RadarInfoToClientService

signal radar_info_updated(state)
signal target_changed(target_robot_id)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RadarInfoToClientState:
	extends RefCounted
	var target_robot_id: int = 0
	var target_pos_x: float = 0.0
	var target_pos_y: float = 0.0
	var torward_angle: float = 0.0
	var is_high_light: int = 0
	var last_update_msec: int = 0

	func clone() -> RadarInfoToClientState:
		var c = RadarInfoToClientState.new()
		c.target_robot_id = target_robot_id
		c.target_pos_x = target_pos_x
		c.target_pos_y = target_pos_y
		c.torward_angle = torward_angle
		c.is_high_light = is_high_light
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"target_robot_id": target_robot_id,
			"target_pos_x": target_pos_x,
			"target_pos_y": target_pos_y,
			"torward_angle": torward_angle,
			"is_high_light": is_high_light,
			"last_update_msec": last_update_msec
		}

var _state: RadarInfoToClientState = RadarInfoToClientState.new()
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
	_state = RadarInfoToClientState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("radar_info_updated", _state.clone())

func ingest_radar_info_to_client(message) -> void:
	_on_radar_info_to_client(message)

func get_state() -> RadarInfoToClientState:
	return _state.clone()

func get_target_robot_id() -> int:
	return _state.target_robot_id

func get_target_pos_x() -> float:
	return _state.target_pos_x

func get_target_pos_y() -> float:
	return _state.target_pos_y

func get_torward_angle() -> float:
	return _state.torward_angle

func get_is_high_light() -> int:
	return _state.is_high_light

func _on_radar_info_to_client(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RadarInfoToClientService] Received null radar_info_to_client message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.target_robot_id = int(message.get_target_robot_id())
	_state.target_pos_x = float(message.get_target_pos_x())
	_state.target_pos_y = float(message.get_target_pos_y())
	_state.torward_angle = float(message.get_torward_angle())
	_state.is_high_light = int(message.get_is_high_light())
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
	if _state.target_robot_id != old_state.target_robot_id:
		emit_signal("target_changed", _state.target_robot_id)

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
