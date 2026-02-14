extends Node

# 这个类用于封装获取ProtocolAdapter的逻辑，方便在其他地方调用获取ProtocolAdapter实例
class_name MQTTProtocolAdapterGetter

@export var adapter_path: NodePath = NodePath("/root/Mqtt/Adapter")
@export var transport_path: NodePath = NodePath("/root/Mqtt/Transport")

func get_adapter() -> ProtocolAdapter:
	var adapter = Engine.get_main_loop().root.get_node(adapter_path) as ProtocolAdapter
	if adapter == null:
		Log.warn("[MQTTProtocolAdapterGetter] Adapter not found at %s" % str(adapter_path))
	return adapter

func get_transport() -> NetworkTransport:
	var transport = Engine.get_main_loop().root.get_node(transport_path) as NetworkTransport
	if transport == null:
		Log.warn("[MQTTProtocolAdapterGetter] Transport not found at %s" % str(transport_path))
	return transport
