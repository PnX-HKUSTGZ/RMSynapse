extends Node
class_name CommonCommandRemoteBuyAmmoService

const CMD_TYPE := 5
const RESULT_INVALID_PARAM := -2

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

var _last_send_result: int = -1
var _logged_missing: bool = false

func send_once(param: int = 0) -> int:
	if CMD_TYPE == 1 and int(param) % 10 != 0:
		_last_send_result = RESULT_INVALID_PARAM
		return _last_send_result

	var adapter = _get_adapter()
	if adapter == null:
		_last_send_result = -1
		return _last_send_result

	var data = AdapterTypes.CommonCommandData.new()
	data.cmd_type = CMD_TYPE
	data.param = int(param)
	_last_send_result = int(adapter.send_common_command(data))
	return _last_send_result

func get_last_send_result() -> int:
	return _last_send_result

func _get_adapter():
	if adapter_getter == null:
		if not _logged_missing:
			_log_error("[CommonCommandRemoteBuyAmmoService] adapter_getter is not set.")
			_logged_missing = true
		return null

	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		if not _logged_missing:
			_log_error("[CommonCommandRemoteBuyAmmoService] ProtocolAdapter not available.")
			_logged_missing = true
		return null
	_logged_missing = false
	return adapter

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)
