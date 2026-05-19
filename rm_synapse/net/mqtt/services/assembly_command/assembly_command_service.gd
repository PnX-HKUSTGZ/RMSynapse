extends Node
class_name AssemblyCommandService

signal request_started(request_id, operation, difficulty)
signal request_finished(request_id, error_code)

enum ErrorCode {
	OK = 0,
	OVERRIDDEN = 1,
	SEND_REJECTED = 2,
	PROTOCOL_REJECTED = 3,
	VERIFY_TIMEOUT = 4,
	CANCELED = 5,
}

@export var bind_retry_interval_sec: float = 1.0
@export var resend_interval_sec: float = 1.0
@export var default_timeout_sec: float = 5.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

var _bound_adapter = null
var _bind_retry_elapsed: float = 0.0
var _resend_elapsed: float = 0.0
var _next_request_id: int = 1
var _pending: Dictionary = {}
var _last_error_code: int = ErrorCode.OK
var _logged_missing: bool = false
var _motion_seq: int = 0
var _last_sync_status: String = ""
var _has_last_sync_status: bool = false

func _ready() -> void:
	_try_bind_adapter()
	set_process(true)

func _process(delta: float) -> void:
	_process_bind(delta)
	_process_request(delta)

func _exit_tree() -> void:
	_disconnect_bound_adapter()

func request_assembly_command(operation: int, difficulty: int, timeout_sec: float = -1.0) -> int:
	if _has_pending():
		_finish_pending(ErrorCode.OVERRIDDEN)

	var request_id = _next_request_id
	_next_request_id += 1
	_pending = {
		"id": request_id,
		"operation": int(operation),
		"difficulty": int(difficulty),
		"deadline_msec": _make_deadline_msec(timeout_sec),
		"motion_seq": _motion_seq,
		"start_status_known": _has_last_sync_status,
		"start_status": _last_sync_status,
		"had_send_success": false,
	}
	_resend_elapsed = 0.0
	emit_signal("request_started", request_id, int(operation), int(difficulty))

	if _send_pending_once():
		_pending["had_send_success"] = true
	return request_id

func cancel(request_id: int) -> bool:
	if not _has_pending():
		return false
	if int(_pending.get("id", 0)) != int(request_id):
		return false
	_finish_pending(ErrorCode.CANCELED)
	return true

func is_running() -> bool:
	return _has_pending()

func get_last_error_code() -> int:
	return _last_error_code

func _on_tech_core_motion_state_sync(message) -> void:
	_motion_seq += 1
	if message == null:
		return
	var current_status := _get_tech_core_signature(message)
	_last_sync_status = current_status
	_has_last_sync_status = true
	if not _has_pending():
		return
	var begin_seq = int(_pending.get("motion_seq", -1))
	if _motion_seq <= begin_seq:
		return
	var start_known = bool(_pending.get("start_status_known", false))
	var start_status = str(_pending.get("start_status", ""))
	if start_known and current_status == start_status:
		return
	_finish_pending(ErrorCode.OK)

func _process_bind(delta: float) -> void:
	var interval = maxf(bind_retry_interval_sec, 0.1)
	_bind_retry_elapsed += delta
	if _bind_retry_elapsed < interval:
		return
	_bind_retry_elapsed = 0.0
	_try_bind_adapter()

func _process_request(delta: float) -> void:
	if not _has_pending():
		return

	if Time.get_ticks_msec() >= int(_pending.get("deadline_msec", 0)):
		if bool(_pending.get("had_send_success", false)):
			_finish_pending(ErrorCode.VERIFY_TIMEOUT)
		else:
			_finish_pending(ErrorCode.SEND_REJECTED)
		return

	_resend_elapsed += delta
	if _resend_elapsed < maxf(resend_interval_sec, 0.1):
		return
	_resend_elapsed = 0.0
	if _send_pending_once():
		_pending["had_send_success"] = true

func _send_pending_once() -> bool:
	if not _has_pending():
		return false
	if _bound_adapter == null or not is_instance_valid(_bound_adapter):
		_try_bind_adapter()
	if _bound_adapter == null:
		return false

	var data = AdapterTypes.AssemblyCommandData.new()
	data.operation = int(_pending.get("operation", 0))
	data.difficulty = int(_pending.get("difficulty", 0))
	var ret = int(_bound_adapter.send_assembly_command(data))
	return ret >= 0

func _finish_pending(error_code: int) -> void:
	if not _has_pending():
		return
	var request_id = int(_pending.get("id", 0))
	_pending.clear()
	_resend_elapsed = 0.0
	_last_error_code = int(error_code)
	emit_signal("request_finished", request_id, _last_error_code)

func _has_pending() -> bool:
	return not _pending.is_empty()

func _make_deadline_msec(timeout_sec: float) -> int:
	var timeout = timeout_sec
	if timeout <= 0.0:
		timeout = default_timeout_sec
	return Time.get_ticks_msec() + int(maxf(timeout, 0.1) * 1000.0)

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AssemblyCommandService] adapter_getter is not set.")
			_logged_missing = true
		return

	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AssemblyCommandService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("tech_core_motion_state_sync"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AssemblyCommandService] Adapter is invalid or missing signal: tech_core_motion_state_sync")
			_logged_missing = true
		return

	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.tech_core_motion_state_sync.is_connected(_on_tech_core_motion_state_sync):
		adapter.tech_core_motion_state_sync.connect(_on_tech_core_motion_state_sync)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("tech_core_motion_state_sync") and _bound_adapter.tech_core_motion_state_sync.is_connected(_on_tech_core_motion_state_sync):
			_bound_adapter.tech_core_motion_state_sync.disconnect(_on_tech_core_motion_state_sync)
	_bound_adapter = null

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)

func _get_message_int(message, method: String, fallback_method: String) -> int:
	if method != "" and message.has_method(method):
		return int(message.call(method))
	if fallback_method != "" and message.has_method(fallback_method):
		return int(message.call(fallback_method))
	return 0

func _get_tech_core_signature(message) -> String:
	return "%d:%d:%d:%d:%d:%d:%d:%d" % [
		_get_message_int(message, "get_maximum_difficulty_level", ""),
		_get_message_int(message, "get_basic_state", "get_status"),
		_get_message_int(message, "get_putin_state", ""),
		_get_message_int(message, "get_move_state", ""),
		_get_message_int(message, "get_rotate_state", ""),
		_get_message_int(message, "get_enemy_core_status", ""),
		_get_message_int(message, "get_remain_time_all", ""),
		_get_message_int(message, "get_remain_time_step", ""),
	]
