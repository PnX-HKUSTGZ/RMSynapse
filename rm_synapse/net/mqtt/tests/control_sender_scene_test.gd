extends Node

const RMProto = preload("res://net/mqtt/proto/generated/rm_custom_pb.gd")

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null
	var get_adapter_calls: int = 0
	var get_adapter_silent_calls: int = 0

	func get_adapter_silent():
		get_adapter_silent_calls += 1
		return adapter_ref

	func get_adapter():
		get_adapter_calls += 1
		return adapter_ref

class FakeTransport:
	extends Node
	signal raw_message(topic, payload)
	signal connected

	var published: Array[Dictionary] = []
	var subscriptions: Array[Dictionary] = []

	func publish_bytes(topic: String, payload: PackedByteArray, retain: bool, qos: int) -> int:
		published.append({
			"topic": topic,
			"payload": payload,
			"retain": retain,
			"qos": qos
		})
		return 0

	func subscribe(topic: String, qos: int) -> int:
		subscriptions.append({
			"topic": topic,
			"qos": qos
		})
		return 0

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var custom_getter = FakeAdapterGetter.new()
	var keyboard_getter = FakeAdapterGetter.new()

	var custom_sender = CustomControlSender.new()
	custom_sender.auto_start = false
	custom_sender.adapter_getter = custom_getter
	add_child(custom_sender)

	var keyboard_sender = KeyboardMouseControlSender.new()
	keyboard_sender.auto_start = false
	keyboard_sender.adapter_getter = keyboard_getter
	add_child(keyboard_sender)

	if custom_sender.adapter_getter != custom_getter:
		ok = false
		errors.append("custom sender should keep injected adapter_getter")
	if keyboard_sender.adapter_getter != keyboard_getter:
		ok = false
		errors.append("keyboard sender should keep injected adapter_getter")

	custom_sender._logged_missing = true
	keyboard_sender._logged_missing = true
	custom_sender._get_adapter()
	keyboard_sender._get_adapter()
	if custom_getter.get_adapter_silent_calls <= 0 or custom_getter.get_adapter_calls != 0:
		ok = false
		errors.append("custom sender should use get_adapter_silent on tick")
	if keyboard_getter.get_adapter_silent_calls <= 0 or keyboard_getter.get_adapter_calls != 0:
		ok = false
		errors.append("keyboard sender should use get_adapter_silent on tick")

	var adapter = ProtocolAdapter.new()
	custom_getter.adapter_ref = adapter
	keyboard_getter.adapter_ref = adapter

	var custom_data = AdapterTypes.CustomControlData.new()
	custom_data.data = PackedByteArray([1, 2, 3, 4])
	custom_sender.update_data(custom_data)

	var keyboard_data = AdapterTypes.KeyboardMouseControlData.new()
	keyboard_data.keyboard_value = 123
	keyboard_sender.update_data(keyboard_data)

	if custom_sender._get_adapter() == null:
		ok = false
		errors.append("custom sender should resolve non-null adapter")
	if keyboard_sender._get_adapter() == null:
		ok = false
		errors.append("keyboard sender should resolve non-null adapter")

	if custom_sender._logged_missing:
		ok = false
		errors.append("custom sender should treat non-null adapter as available")
	if keyboard_sender._logged_missing:
		ok = false
		errors.append("keyboard sender should treat non-null adapter as available")

	var map_adapter = ProtocolAdapter.new()
	map_adapter.auto_subscribe = false
	map_adapter._ready()
	var transport = FakeTransport.new()
	map_adapter.bind_transport(transport)
	var map_click = AdapterTypes.MapClickCmdData.new()
	map_click.is_send_all = 1
	map_click.robot_id = PackedByteArray([1, 2, 3])
	map_click.mode = 4
	map_click.enemy_id = 106
	map_click.ascii = 67
	map_click.type = 1
	map_click.map_x = 123.5
	map_click.map_y = 456.25
	if map_adapter.send_map_click_cmd(map_click) != 0:
		ok = false
		errors.append("map click cmd should send")
	if transport.published.size() != 1:
		ok = false
		errors.append("map click cmd publish count")
	else:
		var item = transport.published[0]
		if item.get("topic") != ProtocolAdapter.TOPIC_MAP_CLICK_CMD:
			ok = false
			errors.append("map click cmd topic")
		if int(item.get("qos", -1)) > ProtocolAdapter.PROTOCOL_MAX_QOS:
			ok = false
			errors.append("map click cmd qos")
		var decoded = RMProto.MapClickCmd.new()
		if decoded.from_bytes(item.get("payload", PackedByteArray())) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("map click cmd decode")
		else:
			if decoded.get_robot_id().size() != AdapterTypes.MapClickCmdData.ROBOT_ID_BYTES:
				ok = false
				errors.append("map click cmd robot_id normalized size")
			if decoded.get_robot_id()[0] != 1 or decoded.get_robot_id()[1] != 2 or decoded.get_robot_id()[2] != 3:
				ok = false
				errors.append("map click cmd robot_id preserved")
			if decoded.get_mode() != 4 or decoded.get_enemy_id() != 106 or decoded.get_ascii() != 67 or decoded.get_type() != 1:
				ok = false
				errors.append("map click cmd scalar fields")
			if absf(decoded.get_map_x() - 123.5) > 0.001 or absf(decoded.get_map_y() - 456.25) > 0.001:
				ok = false
				errors.append("map click cmd map coordinates")

	if ok:
		print("CONTROL_SENDER_SCENE_TEST_OK")
	else:
		print("CONTROL_SENDER_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
