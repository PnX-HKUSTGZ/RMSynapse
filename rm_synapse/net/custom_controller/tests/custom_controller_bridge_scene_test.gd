extends Node

class FakeCustomByteBlockMessage:
	extends RefCounted
	var _data: PackedByteArray

	func _init(data: PackedByteArray) -> void:
		_data = data

	func get_data() -> PackedByteArray:
		return _data

class FakeAdapter:
	extends Node
	signal custom_byte_block(message)
	var sent_payloads: Array[PackedByteArray] = []

	func send_custom_control(data) -> int:
		if data == null:
			return -1
		var payload = data.data if data.data is PackedByteArray else PackedByteArray()
		sent_payloads.push_back(payload.duplicate())
		return 0

	func emit_custom_byte_block(data: PackedByteArray) -> void:
		emit_signal("custom_byte_block", FakeCustomByteBlockMessage.new(data))

var _errors: Array[String] = []
var _rate_limited_count := 0
var _crc_error_count := 0
var _tx_0309_count := 0

func _ready() -> void:
	var bridge_scene = preload("res://net/custom_controller/custom_controller_bridge.tscn")
	var bridge = bridge_scene.instantiate()
	bridge.adapter_path = NodePath("")
	add_child(bridge)

	var serial = bridge.get_node("Serial")
	serial.call("SetTestMode", true)

	bridge.apply_config_override_for_test({
		"enabled": true,
		"uplink_limit_hz": 30.0,
		"downlink_hz": 10.0,
		"reconnect_sec": 0.1,
		"max_tx_queue_chunks": 8,
	})

	bridge.frame_dropped_rate_limit.connect(func(_payload: PackedByteArray) -> void:
		_rate_limited_count += 1
	)
	bridge.frame_crc_error.connect(func(count: int) -> void:
		_crc_error_count += count
	)
	bridge.tx_0309_sent.connect(func(_payload: PackedByteArray) -> void:
		_tx_0309_count += 1
	)

	var adapter = FakeAdapter.new()
	add_child(adapter)
	bridge.bind_adapter_for_test(adapter)

	_test_uplink_parser_and_rate_limit(bridge, serial, adapter)
	_test_crc_error(bridge, serial)
	_test_downlink_chunking(bridge, serial, adapter)

	if _errors.is_empty():
		print("CUSTOM_CONTROLLER_BRIDGE_SCENE_TEST_OK")
	else:
		print("CUSTOM_CONTROLLER_BRIDGE_SCENE_TEST_FAIL")
		for e in _errors:
			print("FAIL:", e)
	get_tree().quit()

func _test_uplink_parser_and_rate_limit(bridge: Node, serial: Node, adapter: FakeAdapter) -> void:
	var payload = _range_bytes(0, 30)
	var frame = _to_packed(serial.call("BuildFrame", 0x0302, payload))
	if frame.is_empty():
		_errors.push_back("BuildFrame should return non-empty 0x0302 frame.")
		return

	var half = _slice_bytes(frame, 0, 12)
	var head_noise = PackedByteArray([0x01, 0x02, 0x03])
	head_noise.append_array(half)
	serial.call("InjectRxBytesForTest", head_noise)
	bridge.call("_process", 0.001)
	if adapter.sent_payloads.size() != 0:
		_errors.push_back("Partial frame should not be forwarded.")

	var remain = _slice_bytes(frame, 12, frame.size() - 12)
	var sticky = PackedByteArray()
	sticky.append_array(remain)
	sticky.append_array(frame)
	serial.call("InjectRxBytesForTest", sticky)
	bridge.call("_process", 0.001)

	if adapter.sent_payloads.size() != 1:
		_errors.push_back("Exactly one 0x0302 payload should pass under hard 30Hz rate limit.")
	elif adapter.sent_payloads[0] != payload:
		_errors.push_back("Accepted 0x0302 payload mismatch.")
	if _rate_limited_count <= 0:
		_errors.push_back("Second immediate frame should be dropped by rate limit.")

func _test_crc_error(bridge: Node, serial: Node) -> void:
	var payload = _range_bytes(50, 30)
	var frame = _to_packed(serial.call("BuildFrame", 0x0302, payload))
	if frame.size() < 9:
		_errors.push_back("BuildFrame returned invalid test frame.")
		return
	frame[frame.size() - 1] = frame[frame.size() - 1] ^ 0xFF
	serial.call("InjectRxBytesForTest", frame)
	bridge.call("_process", 0.001)
	if _crc_error_count <= 0:
		_errors.push_back("Corrupted frame should increment CRC error counter.")

func _test_downlink_chunking(bridge: Node, serial: Node, adapter: FakeAdapter) -> void:
	var raw = _range_bytes(100, 65)
	adapter.emit_custom_byte_block(raw)

	for _i in range(4):
		bridge.call("_process", 0.11)

	var tx_frames = serial.call("DrainTxFramesForTest")
	if tx_frames == null:
		_errors.push_back("DrainTxFramesForTest should return test frames.")
		return
	if tx_frames.size() != 3:
		_errors.push_back("65-byte CustomByteBlock should produce 3 x 0x0309 frames.")
		return
	if _tx_0309_count != 3:
		_errors.push_back("tx_0309_sent should be emitted once per transmitted chunk.")

	var expected_chunks = [
		_slice_bytes(raw, 0, 30),
		_slice_bytes(raw, 30, 30),
	]
	var last_chunk = PackedByteArray()
	last_chunk.resize(30)
	for i in range(5):
		last_chunk[i] = raw[60 + i]
	expected_chunks.push_back(last_chunk)

	for i in range(tx_frames.size()):
		var frame = _to_packed(tx_frames[i])
		if frame.size() != 39:
			_errors.push_back("0x0309 frame size should be 39 bytes.")
			continue
		var cmd = int(frame[5]) | (int(frame[6]) << 8)
		if cmd != 0x0309:
			_errors.push_back("Downlink cmd_id should be 0x0309.")
			continue
		var payload = _slice_bytes(frame, 7, 30)
		if payload != expected_chunks[i]:
			_errors.push_back("0x0309 payload chunk #%d mismatch." % i)

func _range_bytes(start: int, count: int) -> PackedByteArray:
	var out = PackedByteArray()
	out.resize(count)
	for i in range(count):
		out[i] = (start + i) & 0xFF
	return out

func _slice_bytes(src: PackedByteArray, begin: int, count: int) -> PackedByteArray:
	var out = PackedByteArray()
	var safe_count = maxi(count, 0)
	out.resize(safe_count)
	for i in range(safe_count):
		out[i] = src[begin + i]
	return out

func _to_packed(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		return value
	if value is Array:
		var arr: Array = value
		var out = PackedByteArray()
		out.resize(arr.size())
		for i in range(arr.size()):
			out[i] = int(arr[i]) & 0xFF
		return out
	return PackedByteArray()
