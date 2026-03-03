extends Node
class_name AirSupportCommandService

signal request_started(request_id, command_id)
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

func _ready() -> void:
	_try_bind_adapter()
	set_process(true)

func _process(delta: float) -> void:
	_process_bind(delta)
	_process_request(delta)

func _exit_tree() -> void:
	_disconnect_bound_adapter()

func request_air_support_command(command_id: int, timeout_sec: float = -1.0) -> int:
	if _has_pending():
		_finish_pending(ErrorCode.OVERRIDDEN)

	var request_id = _next_request_id
	_next_request_id += 1
	_pending = {
		"id": request_id,
		"command_id": int(command_id),
		"expected_status": _expected_status_for_command(int(command_id)),
		"deadline_msec": _make_deadline_msec(timeout_sec),
		"had_send_success": false,
	}
	_resend_elapsed = 0.0
	emit_signal("request_started", request_id, int(command_id))

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

func _on_air_support_status_sync(message) -> void:
	if not _has_pending() or message == null:
		return
	var expected_status = int(_pending.get("expected_status", -1))
	if expected_status < 0:
		return
	if int(message.get_airsupport_status()) == expected_status:
		_finish_pending(ErrorCode.OK)

func _expected_status_for_command(command_id: int) -> int:
	if command_id == 1 or command_id == 2:
		return 1
	if command_id == 3:
		return 0
	return -1

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

	var data = AdapterTypes.AirSupportCommandData.new()
	data.command_id = int(_pending.get("command_id", 0))
	var ret = int(_bound_adapter.send_air_support_command(data))
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
			_log_error("[AirSupportCommandService] adapter_getter is not set.")
			_logged_missing = true
		return

	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AirSupportCommandService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("air_support_status_sync"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[AirSupportCommandService] Adapter is invalid or missing signal: air_support_status_sync")
			_logged_missing = true
		return

	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.air_support_status_sync.is_connected(_on_air_support_status_sync):
		adapter.air_support_status_sync.connect(_on_air_support_status_sync)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("air_support_status_sync") and _bound_adapter.air_support_status_sync.is_connected(_on_air_support_status_sync):
			_bound_adapter.air_support_status_sync.disconnect(_on_air_support_status_sync)
	_bound_adapter = null

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)
