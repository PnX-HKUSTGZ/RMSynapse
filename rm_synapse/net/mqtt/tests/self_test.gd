extends Node

const MQTT_ROOT_PATH := "/root/Mqtt"
const ADAPTER_PATH := "/root/Mqtt/Adapter"
const TRANSPORT_PATH := "/root/Mqtt/Transport"
var _adapter = null

var _send_cunter: int = 0

func _ready() -> void:
	set_process(true)
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

	_adapter = adapter
	adapter.decoded_message.connect(func(_topic, _msg):
		print("decoded_message received")
	)

	_finish(ok, errors)

func _process(_delta: float) -> void:
	_send_cunter += 1
	if _send_cunter % 300 != 0:
		return
	if _adapter == null:
		print("Adapter not ready, skipping test")
		return
	var data = AdapterTypes.KeyboardMouseControlData.new()
	data.mouse_x = 1
	data.mouse_y = 2
	data.mouse_z = 0
	data.left_button_down = false
	data.right_button_down = false
	data.mid_button_down = false
	data.keyboard_value = 0
	var send_res = _adapter.send_keyboard_mouse_control(data)
	print("send_keyboard_mouse_control result:", send_res)

func _finish(ok: bool, errors: Array[String]) -> void:
	if ok:
		print("SELF_TEST_OK")
	else:
		print("SELF_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
