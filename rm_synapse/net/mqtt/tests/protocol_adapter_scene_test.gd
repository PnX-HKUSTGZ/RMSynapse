extends Node

const RMProto = preload("res://net/mqtt/proto/generated/rm_custom_pb.gd")

class FakeTransport:
	extends Node
	signal raw_message(topic, payload)
	signal connected()

	var publishes: Array[Dictionary] = []
	var subscriptions: Array[Dictionary] = []

	func publish_bytes(topic: String, payload: PackedByteArray, retain: bool = false, qos: int = 0) -> int:
		publishes.append({
			"topic": topic,
			"payload": payload.duplicate(),
			"retain": retain,
			"qos": qos,
		})
		return 0

	func subscribe(topic: String, qos: int = 0) -> void:
		subscriptions.append({
			"topic": topic,
			"qos": qos,
		})

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var transport = FakeTransport.new()
	var adapter = ProtocolAdapter.new()
	adapter.auto_subscribe = false
	add_child(transport)
	add_child(adapter)
	adapter.bind_transport(transport)

	var custom_ok = AdapterTypes.CustomControlData.new()
	custom_ok.data = _make_bytes(30)
	if adapter.send_custom_control(custom_ok) != 0:
		ok = false
		errors.append("custom_control 30 bytes should send")
	var custom_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_CUSTOM_CONTROL)
	if custom_publish.is_empty():
		ok = false
		errors.append("custom_control publish missing")
	else:
		var custom_msg = RMProto.CustomControl.new()
		if custom_msg.from_bytes(custom_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("custom_control decode")
		elif custom_msg.get_data().size() != 30:
			ok = false
			errors.append("custom_control data size")

	var publish_count_before_oversize = transport.publishes.size()
	var custom_oversize = AdapterTypes.CustomControlData.new()
	custom_oversize.data = _make_bytes(31)
	if adapter.send_custom_control(custom_oversize) != -1:
		ok = false
		errors.append("custom_control >30 bytes should reject")
	if transport.publishes.size() != publish_count_before_oversize:
		ok = false
		errors.append("custom_control oversize should not publish")

	var map_click = AdapterTypes.MapClickInfoNotifyData.new()
	map_click.is_send_all = 1
	map_click.robot_id = PackedByteArray([1, 2, 3, 4, 5, 6, 7])
	map_click.mode = 2
	map_click.enemy_id = 3
	map_click.ascii = 65
	map_click.type = 4
	map_click.map_x = 12.5
	map_click.map_y = 34.75
	if adapter.send_map_click_info_notify(map_click) != 0:
		ok = false
		errors.append("map_click send")
	var map_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY)
	if map_publish.is_empty():
		ok = false
		errors.append("map_click publish missing")
	else:
		var map_msg = RMProto.MapClickInfoNotify.new()
		if map_msg.from_bytes(map_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("map_click decode")
		else:
			if map_msg.get_is_send_all() != 1 or map_msg.get_mode() != 2 or map_msg.get_enemy_id() != 3:
				ok = false
				errors.append("map_click scalar values")
			if map_msg.get_ascii() != 65 or map_msg.get_type() != 4:
				ok = false
				errors.append("map_click mode/type values")
			if not is_equal_approx(map_msg.get_map_x(), 12.5) or not is_equal_approx(map_msg.get_map_y(), 34.75):
				ok = false
				errors.append("map_click map coordinates")
			if map_msg.get_robot_id() != PackedByteArray([1, 2, 3, 4, 5, 6, 7]):
				ok = false
				errors.append("map_click robot_id")
		var field_numbers = _parse_field_numbers(map_publish["payload"], errors, "map_click")
		if field_numbers != [1, 2, 3, 4, 5, 6, 7, 8]:
			ok = false
			errors.append("map_click field numbers")
		if field_numbers.has(9) or field_numbers.has(10):
			ok = false
			errors.append("map_click should not encode legacy screen fields")

	var publish_count_before_rate_limit = transport.publishes.size()
	if adapter.send_map_click_info_notify(map_click) != -1:
		ok = false
		errors.append("map_click rate limit")
	if transport.publishes.size() != publish_count_before_rate_limit:
		ok = false
		errors.append("map_click rate limit should not publish")
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY] = Time.get_ticks_msec() - ProtocolAdapter.MAP_CLICK_MIN_INTERVAL_MSEC
	if adapter.send_map_click_info_notify(map_click) != 0:
		ok = false
		errors.append("map_click resend after interval")

	var air_support = AdapterTypes.AirSupportCommandData.new()
	air_support.command_id = 0
	if adapter.send_air_support_command(air_support) != 0:
		ok = false
		errors.append("air_support command 0 send")
	var air_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_AIR_SUPPORT_COMMAND)
	if air_publish.is_empty():
		ok = false
		errors.append("air_support publish missing")
	else:
		var air_payload: PackedByteArray = air_publish["payload"]
		if air_payload.size() != 0:
			ok = false
			errors.append("air_support command_id 0 should serialize as default empty payload")

	if ok:
		print("PROTOCOL_ADAPTER_SCENE_TEST_OK")
	else:
		print("PROTOCOL_ADAPTER_SCENE_TEST_FAIL")
		for error in errors:
			print("FAIL:", error)
	get_tree().quit()

func _latest_publish(transport: FakeTransport, topic: String) -> Dictionary:
	for i in range(transport.publishes.size() - 1, -1, -1):
		var publish = transport.publishes[i]
		if String(publish.get("topic", "")) == topic:
			return publish
	return {}

func _make_bytes(length: int) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize(length)
	for i in range(length):
		data[i] = i % 256
	return data

func _parse_field_numbers(bytes: PackedByteArray, errors: Array[String], label: String) -> Array[int]:
	var fields: Array[int] = []
	var offset = 0
	while offset < bytes.size():
		var tag_result = _read_varint(bytes, offset)
		if not bool(tag_result.get("ok", false)):
			errors.append("%s invalid tag varint" % label)
			return []
		offset = int(tag_result.get("offset", offset))
		var tag = int(tag_result.get("value", 0))
		if tag == 0:
			errors.append("%s zero tag" % label)
			return []
		fields.append(tag >> 3)
		var wire_type = tag & 0x07
		match wire_type:
			0:
				var value_result = _read_varint(bytes, offset)
				if not bool(value_result.get("ok", false)):
					errors.append("%s invalid value varint" % label)
					return []
				offset = int(value_result.get("offset", offset))
			1:
				offset += 8
			2:
				var length_result = _read_varint(bytes, offset)
				if not bool(length_result.get("ok", false)):
					errors.append("%s invalid length varint" % label)
					return []
				var size = int(length_result.get("value", 0))
				offset = int(length_result.get("offset", offset)) + size
			5:
				offset += 4
			_:
				errors.append("%s unsupported wire type %d" % [label, wire_type])
				return []
		if offset > bytes.size():
			errors.append("%s field overrun" % label)
			return []
	return fields

func _read_varint(bytes: PackedByteArray, start_offset: int) -> Dictionary:
	var value: int = 0
	var shift: int = 0
	var offset = start_offset
	while offset < bytes.size() and shift < 64:
		var current = int(bytes[offset])
		value |= (current & 0x7F) << shift
		offset += 1
		if (current & 0x80) == 0:
			return {
				"ok": true,
				"value": value,
				"offset": offset,
			}
		shift += 7
	return {
		"ok": false,
		"value": 0,
		"offset": start_offset,
	}
