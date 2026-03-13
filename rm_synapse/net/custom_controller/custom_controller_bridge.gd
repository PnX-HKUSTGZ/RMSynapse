extends Node

signal serial_connected(port: String, baud_rate: int)
signal serial_disconnected(reason: String)
signal frame_0302_accepted(payload: PackedByteArray)
signal frame_crc_error(count: int)
signal frame_dropped_rate_limit(payload: PackedByteArray)
signal tx_0309_sent(payload: PackedByteArray)

const CHUNK_0309_BYTES := 30
const RX_REPORT_INTERVAL_SEC := 5.0

@export var enabled: bool = true
@export var port: String = "/dev/ttyUSB0"
@export var baud_rate: int = 115200
@export var data_bits: int = 8
@export var stop_bits: int = 1
@export var parity: String = "none"
@export var uplink_limit_hz: float = 30.0
@export var downlink_hz: float = 10.0
@export var reconnect_sec: float = 1.0
@export var max_rx_buffer: int = 4096
@export var max_tx_queue_chunks: int = 256
@export var adapter_path: NodePath = NodePath("/root/Mqtt/Adapter")
@export var adapter_rebind_interval_sec: float = 0.5

var _applied_serial_config: Dictionary = {}
var _adapter_bind_elapsed: float = 0.0
var _reconnect_elapsed: float = 0.0
var _downlink_elapsed: float = 0.0
var _last_uplink_usec: int = 0
var _was_serial_open: bool = false
var _logged_open_failure: bool = false
var _adapter: Object = null
var _tx_queue: Array[PackedByteArray] = []
var _rx_report_elapsed: float = 0.0
var _rx_0302_since_report: int = 0
var _tx_0309_since_report: int = 0
var _ignored_cmd_since_report: int = 0
var _crc_error_since_report: int = 0

@onready var _serial := $Serial

func _ready() -> void:
	_apply_serial_config(true)
	_try_bind_adapter()
	set_process(true)

func _exit_tree() -> void:
	_unbind_adapter()
	_serial_call("ClosePort")

func _process(delta: float) -> void:
	_apply_serial_config()
	_process_adapter_bind(delta)
	_process_serial_open(delta)
	_process_serial_pump()
	_process_downlink(delta)
	_process_message_type_report(delta)
	_emit_serial_state_if_changed()

func bind_adapter_for_test(adapter: Object) -> void:
	_rebind_adapter(adapter)

func apply_config_override_for_test(values: Dictionary) -> void:
	if values.has("enabled"):
		enabled = _to_bool(values["enabled"])
	if values.has("port"):
		port = str(values["port"])
	if values.has("baud_rate"):
		baud_rate = int(values["baud_rate"])
	if values.has("data_bits"):
		data_bits = int(values["data_bits"])
	if values.has("stop_bits"):
		stop_bits = int(values["stop_bits"])
	if values.has("parity"):
		parity = str(values["parity"])
	if values.has("uplink_limit_hz"):
		uplink_limit_hz = _as_float(values["uplink_limit_hz"])
	if values.has("downlink_hz"):
		downlink_hz = _as_float(values["downlink_hz"])
	if values.has("reconnect_sec"):
		reconnect_sec = _as_float(values["reconnect_sec"])
	if values.has("max_rx_buffer"):
		max_rx_buffer = int(values["max_rx_buffer"])
	if values.has("max_tx_queue_chunks"):
		max_tx_queue_chunks = int(values["max_tx_queue_chunks"])
	_apply_serial_config(true)

func _process_adapter_bind(delta: float) -> void:
	if String(adapter_path) == "":
		return
	_adapter_bind_elapsed += delta
	if _adapter_bind_elapsed < maxf(adapter_rebind_interval_sec, 0.1):
		return
	_adapter_bind_elapsed = 0.0
	_try_bind_adapter()

func _process_serial_open(delta: float) -> void:
	var enabled_value = _to_bool(_applied_serial_config.get("enabled", true))
	if not enabled_value:
		_reconnect_elapsed = 0.0
		_logged_open_failure = false
		_serial_call("ClosePort")
		return

	if _is_serial_open():
		_reconnect_elapsed = 0.0
		_logged_open_failure = false
		return

	_reconnect_elapsed += delta
	var reconnect_interval = maxf(_as_float(_applied_serial_config.get("reconnect_sec", 1.0)), 0.1)
	if _reconnect_elapsed < reconnect_interval:
		return
	_reconnect_elapsed = 0.0
	var ok = _to_bool(_serial_call("OpenPort"))
	if not ok and not _logged_open_failure:
		_log_warn("[CustomControllerBridge] Failed to open serial port: %s" % str(_applied_serial_config.get("port", "")))
		_logged_open_failure = true

func _process_serial_pump() -> void:
	if not _is_serial_open():
		return

	_serial_call("Pump")
	var crc_errors = int(_serial_call("ConsumeCrcErrorCount"))
	if crc_errors > 0:
		_crc_error_since_report += crc_errors
		emit_signal("frame_crc_error", crc_errors)
		_log_warn("[CustomControllerBridge] Serial unpack failed: %d frame(s) failed CRC/header validation." % crc_errors)
	var ignored_cmd_count = int(_serial_call("ConsumeIgnoredFrameCount"))
	if ignored_cmd_count > 0:
		_ignored_cmd_since_report += ignored_cmd_count

	var frames = _serial_call("DrainFrames0302")
	if frames == null:
		return
	for frame in frames:
		var payload := _to_packed_bytes(frame)
		if payload.size() != CHUNK_0309_BYTES:
			continue
		_rx_0302_since_report += 1
		_handle_uplink_0302(payload)

func _process_downlink(delta: float) -> void:
	if _tx_queue.is_empty():
		return
	if not _to_bool(_applied_serial_config.get("enabled", true)):
		return
	if not _is_serial_open():
		return

	_downlink_elapsed += delta
	var hz = maxf(_as_float(_applied_serial_config.get("downlink_hz", 10.0)), 0.1)
	var interval = 1.0 / hz
	if _downlink_elapsed < interval:
		return
	_downlink_elapsed = 0.0

	var payload = _tx_queue.pop_front()
	var ok = _to_bool(_serial_call("Send0309", [payload]))
	if ok:
		_tx_0309_since_report += 1
		emit_signal("tx_0309_sent", payload)
	else:
		_log_warn("[CustomControllerBridge] Send0309 failed, frame dropped.")

func _handle_uplink_0302(payload: PackedByteArray) -> void:
	var hz = maxf(_as_float(_applied_serial_config.get("uplink_limit_hz", 30.0)), 1.0)
	var min_interval_usec = int(1000000.0 / hz)
	var now = Time.get_ticks_usec()
	if _last_uplink_usec > 0 and (now - _last_uplink_usec) < min_interval_usec:
		emit_signal("frame_dropped_rate_limit", payload)
		return

	if _adapter == null:
		_log_warn("[CustomControllerBridge] Adapter not bound, drop uplink 0x0302 frame.")
		return

	var data = AdapterTypes.CustomControlData.new()
	data.data = payload
	var ret = int(_adapter.call("send_custom_control", data))
	if ret >= 0:
		_last_uplink_usec = now
		emit_signal("frame_0302_accepted", payload)

func _on_custom_byte_block(message) -> void:
	if message == null:
		return
	if not message.has_method("get_data"):
		return
	var raw = message.get_data()
	var bytes := _to_packed_bytes(raw)
	if bytes.is_empty():
		return
	_enqueue_0309_chunks(bytes)

func _enqueue_0309_chunks(raw: PackedByteArray) -> void:
	var total = raw.size()
	var offset = 0
	while offset < total:
		var chunk = PackedByteArray()
		chunk.resize(CHUNK_0309_BYTES)
		for i in range(CHUNK_0309_BYTES):
			var src = offset + i
			chunk[i] = raw[src] if src < total else 0
		_enqueue_chunk(chunk)
		offset += CHUNK_0309_BYTES

func _enqueue_chunk(chunk: PackedByteArray) -> void:
	var max_chunks = maxi(int(_applied_serial_config.get("max_tx_queue_chunks", 256)), 1)
	while _tx_queue.size() >= max_chunks:
		_tx_queue.pop_front()
	_tx_queue.push_back(chunk)

func _try_bind_adapter() -> void:
	var node: Object = null
	if String(adapter_path) != "":
		node = get_node_or_null(adapter_path)
	_rebind_adapter(node)

func _rebind_adapter(node: Object) -> void:
	if _adapter == node:
		return
	_unbind_adapter()
	_adapter = node
	if _adapter == null:
		return
	if not _adapter.has_signal("custom_byte_block"):
		_log_warn("[CustomControllerBridge] Adapter missing signal: custom_byte_block")
		_adapter = null
		return
	var cb = Callable(self, "_on_custom_byte_block")
	if not _adapter.is_connected("custom_byte_block", cb):
		_adapter.connect("custom_byte_block", cb)

func _unbind_adapter() -> void:
	if _adapter == null:
		return
	if is_instance_valid(_adapter):
		var cb = Callable(self, "_on_custom_byte_block")
		if _adapter.has_signal("custom_byte_block") and _adapter.is_connected("custom_byte_block", cb):
			_adapter.disconnect("custom_byte_block", cb)
	_adapter = null

func _emit_serial_state_if_changed() -> void:
	var is_open = _is_serial_open()
	if is_open == _was_serial_open:
		return
	_was_serial_open = is_open
	if is_open:
		emit_signal("serial_connected", str(_applied_serial_config.get("port", "")), int(_applied_serial_config.get("baud_rate", 115200)))
	else:
		emit_signal("serial_disconnected", "serial_closed")

func _process_message_type_report(delta: float) -> void:
	if not _to_bool(_applied_serial_config.get("enabled", true)):
		_rx_report_elapsed = 0.0
		_reset_report_counters()
		return
	_rx_report_elapsed += delta
	if _rx_report_elapsed < RX_REPORT_INTERVAL_SEC:
		return
	_rx_report_elapsed = 0.0
	var type_parts: Array[String] = []
	if _rx_0302_since_report > 0:
		type_parts.push_back("0x0302(rx)=%d" % _rx_0302_since_report)
	if _tx_0309_since_report > 0:
		type_parts.push_back("0x0309(tx)=%d" % _tx_0309_since_report)
	if _ignored_cmd_since_report > 0:
		type_parts.push_back("other_cmd=%d" % _ignored_cmd_since_report)
	if not type_parts.is_empty():
		var suffix = ""
		if _crc_error_since_report > 0:
			suffix = ", crc_fail=%d" % _crc_error_since_report
		_log_info("[CustomControllerBridge] Message types sampled(%.1fs): %s%s" % [RX_REPORT_INTERVAL_SEC, ", ".join(type_parts), suffix])
	else:
		_log_warn("[CustomControllerBridge] Message types sampled(%.1fs): no custom controller frame received." % RX_REPORT_INTERVAL_SEC)
	_reset_report_counters()

func _reset_report_counters() -> void:
	_rx_0302_since_report = 0
	_tx_0309_since_report = 0
	_ignored_cmd_since_report = 0
	_crc_error_since_report = 0

func _apply_serial_config(force: bool = false) -> void:
	var next_config = _normalized_serial_config()
	if not force and next_config == _applied_serial_config:
		return
	_applied_serial_config = next_config
	_serial_call("Configure", [
		str(_applied_serial_config.get("port", "/dev/ttyUSB0")),
		int(_applied_serial_config.get("baud_rate", 115200)),
		int(_applied_serial_config.get("data_bits", 8)),
		int(_applied_serial_config.get("stop_bits", 1)),
		str(_applied_serial_config.get("parity", "none")),
		int(_applied_serial_config.get("max_rx_buffer", 4096)),
	])
	_downlink_elapsed = 0.0
	_reconnect_elapsed = 0.0
	_logged_open_failure = false
	if not _to_bool(_applied_serial_config.get("enabled", true)):
		_serial_call("ClosePort")

func _normalized_serial_config() -> Dictionary:
	return {
		"enabled": enabled,
		"port": _normalized_port(port),
		"baud_rate": maxi(baud_rate, 1200),
		"data_bits": clampi(data_bits, 5, 8),
		"stop_bits": 2 if stop_bits == 2 else 1,
		"parity": _normalized_parity(parity),
		"uplink_limit_hz": maxf(uplink_limit_hz, 1.0),
		"downlink_hz": maxf(downlink_hz, 0.1),
		"reconnect_sec": maxf(reconnect_sec, 0.1),
		"max_rx_buffer": maxi(max_rx_buffer, 512),
		"max_tx_queue_chunks": maxi(max_tx_queue_chunks, 1),
	}

func _normalized_port(value: String) -> String:
	var p = value.strip_edges()
	return p if p != "" else "/dev/ttyUSB0"

func _normalized_parity(value: String) -> String:
	var p = value.to_lower().strip_edges()
	if p == "odd" or p == "even" or p == "mark" or p == "space":
		return p
	return "none"

func _serial_call(method_name: String, args: Array = []) -> Variant:
	if _serial == null:
		return null
	if _serial.has_method(method_name):
		return _serial.callv(method_name, args)
	var snake = method_name.to_snake_case()
	if _serial.has_method(snake):
		return _serial.callv(snake, args)
	return null

func _is_serial_open() -> bool:
	return _to_bool(_serial_call("IsPortOpen"))

func _to_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return absf(float(value)) > 0.00001
		TYPE_STRING:
			var s = str(value).to_lower().strip_edges()
			return s == "true" or s == "1" or s == "yes" or s == "on"
		_:
			return false

func _as_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT:
		return value
	if typeof(value) == TYPE_INT:
		return float(value)
	return float(str(value))

func _to_packed_bytes(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		return (value as PackedByteArray).duplicate()
	if value is Array:
		var arr: Array = value
		var out = PackedByteArray()
		out.resize(arr.size())
		for i in range(arr.size()):
			out[i] = int(arr[i]) & 0xFF
		return out
	return PackedByteArray()

func _log_warn(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("warn"):
		logger.warn(message)
		return
	push_warning(message)

func _log_info(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("info"):
		logger.info(message)
		return
	print(message)
