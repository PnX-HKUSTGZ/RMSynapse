extends Node

class FakeTransport:
	extends NetworkTransport

	func _ready() -> void:
		pass

class FakeProtocolAdapter:
	extends ProtocolAdapter
	var bind_calls: int = 0
	var last_transport: Node = null
	var bound_transport: Node = null

	func _ready() -> void:
		pass

	func bind_transport(node: Node) -> void:
		bind_calls += 1
		last_transport = node
		bound_transport = node

	func is_transport_bound(node: Node) -> bool:
		return bound_transport == node

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var setter = MQTTClientSetter.new()
	var adapter = FakeProtocolAdapter.new()
	var transport = FakeTransport.new()
	transport.name = "Transport"
	add_child(transport)
	add_child(adapter)

	adapter.transport_path = transport.get_path()
	setter.force_rebind = false
	setter._bind_adapter_transport(adapter, transport)
	if adapter.bind_calls != 1 or adapter.last_transport != transport:
		ok = false
		errors.append("bind should call adapter.bind_transport once even with same transport_path")

	setter._bind_adapter_transport(adapter, transport)
	if adapter.bind_calls != 1:
		ok = false
		errors.append("second bind should be skipped when already bound and force_rebind is false")

	var transport_2 = FakeTransport.new()
	transport_2.name = "Transport2"
	add_child(transport_2)
	setter._bind_adapter_transport(adapter, transport_2)
	if adapter.bind_calls != 2 or adapter.last_transport != transport_2:
		ok = false
		errors.append("bind should run when target transport instance changes")

	setter.force_rebind = true
	setter._bind_adapter_transport(adapter, transport)
	if adapter.bind_calls != 3 or adapter.last_transport != transport:
		ok = false
		errors.append("force_rebind path should still call bind_transport")

	if ok:
		print("MQTT_CLIENT_SETTER_SCENE_TEST_OK")
	else:
		print("MQTT_CLIENT_SETTER_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
