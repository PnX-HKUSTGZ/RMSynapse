extends Node

# 这个类用于封装获取ProtocolAdapter的逻辑，方便在其他地方调用获取ProtocolAdapter实例
class_name MQTTProtocolAdapterGetter

@export var adapter_path: NodePath = NodePath("/root/Mqtt/Adapter")
@export var transport_path: NodePath = NodePath("/root/Mqtt/Transport")

func get_adapter() -> ProtocolAdapter:
	var root = _get_tree_root()
	if root == null:
		_log_warn("[MQTTProtocolAdapterGetter] SceneTree root is not available.")
		return null
	var adapter = root.get_node_or_null(adapter_path) as ProtocolAdapter
	if adapter == null:
		_log_warn("[MQTTProtocolAdapterGetter] Adapter not found at %s" % str(adapter_path))
	return adapter

func get_transport() -> NetworkTransport:
	var root = _get_tree_root()
	if root == null:
		_log_warn("[MQTTProtocolAdapterGetter] SceneTree root is not available.")
		return null
	var transport = root.get_node_or_null(transport_path) as NetworkTransport
	if transport == null:
		_log_warn("[MQTTProtocolAdapterGetter] Transport not found at %s" % str(transport_path))
	return transport

func _log_warn(message: String) -> void:
	var root = _get_tree_root()
	if root != null:
		var logger = root.get_node_or_null("Log")
		if logger != null and logger.has_method("warn"):
			logger.warn(message)
			return
	push_warning(message)

func _get_tree_root() -> Window:
	var main_loop = Engine.get_main_loop()
	if main_loop == null:
		return null
	return main_loop.root
