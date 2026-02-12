extends Node

const MQTT_ROOT_PATH := "/root/Mqtt"
const ADAPTER_PATH := "/root/Mqtt/Adapter"
const TRANSPORT_PATH := "/root/Mqtt/Transport"

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var mqtt_root = get_node_or_null(MQTT_ROOT_PATH)
	if mqtt_root == null:
		ok = false
		errors.append("Autoload Mqtt not found at /root/Mqtt")
		_finish(ok, errors)
		return

	var adapter = get_node_or_null(ADAPTER_PATH)
	var transport = get_node_or_null(TRANSPORT_PATH)
	if adapter == null:
		ok = false
		errors.append("Adapter node not found at /root/Mqtt/Adapter")
	if transport == null:
		ok = false
		errors.append("Transport node not found at /root/Mqtt/Transport")
	if not ok:
		_finish(ok, errors)
		return

	adapter.decoded_message.connect(func(_topic, _msg):
		print("decoded_message received")
	)

	_finish(ok, errors)

func _finish(ok: bool, errors: Array[String]) -> void:
	if ok:
		print("SELF_TEST_OK")
	else:
		print("SELF_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
