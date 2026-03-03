extends Node

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

	if ok:
		print("CONTROL_SENDER_SCENE_TEST_OK")
	else:
		print("CONTROL_SENDER_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
