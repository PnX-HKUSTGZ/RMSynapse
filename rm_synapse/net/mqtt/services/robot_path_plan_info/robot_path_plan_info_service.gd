extends Node
class_name RobotPathPlanInfoService

signal robot_path_plan_info_updated(state)
signal path_plan_changed(intention, point_count)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class PathPointOffset:
	extends RefCounted
	var dx: int = 0
	var dy: int = 0

	func clone() -> PathPointOffset:
		var c = PathPointOffset.new()
		c.dx = dx
		c.dy = dy
		return c

	func to_dict() -> Dictionary:
		return {"dx": dx, "dy": dy}

class RobotPathPlanInfoState:
	extends RefCounted
	var intention: int = 0
	var start_pos_x: int = 0
	var start_pos_y: int = 0
	var offsets: Array[PathPointOffset] = []
	var sender_id: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotPathPlanInfoState:
		var c = RobotPathPlanInfoState.new()
		c.intention = intention
		c.start_pos_x = start_pos_x
		c.start_pos_y = start_pos_y
		var copied_offsets: Array[PathPointOffset] = []
		for offset in offsets:
			copied_offsets.append(offset.clone())
		c.offsets = copied_offsets
		c.sender_id = sender_id
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		var offset_dicts: Array = []
		for offset in offsets:
			offset_dicts.append(offset.to_dict())
		return {
			"intention": intention,
			"start_pos_x": start_pos_x,
			"start_pos_y": start_pos_y,
			"offsets": offset_dicts,
			"sender_id": sender_id,
			"last_update_msec": last_update_msec
		}

var _state: RobotPathPlanInfoState = RobotPathPlanInfoState.new()
var _bound_adapter = null
var _bind_retry_elapsed: float = 0.0
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _logged_mismatch: bool = false

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
	_state = RobotPathPlanInfoState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_path_plan_info_updated", _state.clone())

func ingest_robot_path_plan_info(message) -> void:
	_on_robot_path_plan_info(message)

func get_state() -> RobotPathPlanInfoState:
	return _state.clone()

func get_offsets() -> Array[PathPointOffset]:
	var result: Array[PathPointOffset] = []
	for offset in _state.offsets:
		result.append(offset.clone())
	return result

func get_sender_id() -> int:
	return _state.sender_id

func get_absolute_points() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var current = Vector2i(_state.start_pos_x, _state.start_pos_y)
	for offset in _state.offsets:
		current += Vector2i(offset.dx, offset.dy)
		points.append(current)
	return points

func _on_robot_path_plan_info(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotPathPlanInfoService] Received null robot_path_plan_info message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.intention = int(message.get_intention())
	_state.start_pos_x = int(message.get_start_pos_x())
	_state.start_pos_y = int(message.get_start_pos_y())
	_state.sender_id = int(message.get_sender_id())

	var xs = message.get_offset_x()
	var ys = message.get_offset_y()
	var count = mini(xs.size(), ys.size())
	if xs.size() != ys.size() and not _logged_mismatch:
		_log_warn("[RobotPathPlanInfoService] offset_x/y length mismatch: %d vs %d" % [xs.size(), ys.size()])
		_logged_mismatch = true

	var offsets: Array[PathPointOffset] = []
	for i in range(count):
		var offset = PathPointOffset.new()
		offset.dx = int(xs[i])
		offset.dy = int(ys[i])
		offsets.append(offset)
	_state.offsets = offsets
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_path_plan_info_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPathPlanInfoService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPathPlanInfoService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_path_plan_info"):
		disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotPathPlanInfoService] Adapter is invalid or missing signal: robot_path_plan_info")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_path_plan_info.is_connected(_on_robot_path_plan_info):
		adapter.robot_path_plan_info.connect(_on_robot_path_plan_info)
	_logged_missing = false

func disconnect_bound_adapter() -> void:
	_disconnect_bound_adapter()

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_path_plan_info") and _bound_adapter.robot_path_plan_info.is_connected(_on_robot_path_plan_info):
			_bound_adapter.robot_path_plan_info.disconnect(_on_robot_path_plan_info)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotPathPlanInfoState) -> void:
	if _state.intention != old_state.intention or _state.offsets.size() != old_state.offsets.size() or not _offsets_equal(_state.offsets, old_state.offsets):
		emit_signal("path_plan_changed", _state.intention, _state.offsets.size())

func _offsets_equal(a: Array[PathPointOffset], b: Array[PathPointOffset]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i].dx != b[i].dx or a[i].dy != b[i].dy:
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
