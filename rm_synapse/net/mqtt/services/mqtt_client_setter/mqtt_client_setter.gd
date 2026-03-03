extends Node
class_name MQTTClientSetter

@export_group("Behavior")
@export var apply_on_ready: bool = true
@export var defer_apply: bool = true

@export_group("Node Paths")
@export var adapter_path: NodePath = NodePath("/root/Mqtt/Adapter")
@export var transport_path: NodePath = NodePath("/root/Mqtt/Transport")

@export_group("Adapter Settings")
@export var adapter_auto_subscribe: bool = true
@export var bind_transport_on_apply: bool = true
@export var force_rebind: bool = false

@export_group("Transport Settings")
@export var broker_url: String = "127.0.0.1:3333"
@export var auto_connect: bool = false
@export var auto_reconnect: bool = true
@export var reconnect_delay_ms: int = 2000
@export var ping_interval_sec: int = 30
@export var binary_messages: bool = true
@export var client_id: String = ""
@export var username: String = ""
@export var password: String = ""
@export var connect_after_apply: bool = false

func _ready() -> void:
	if not apply_on_ready:
		return
	if defer_apply:
		call_deferred("apply_settings")
	else:
		apply_settings()

func apply_settings() -> void:
	var adapter = get_adapter()
	var transport = get_transport()

	if adapter == null:
		Log.warn("[MQTTClientSetter] Adapter not found at %s" % str(adapter_path))
	if transport == null:
		Log.warn("[MQTTClientSetter] Transport not found at %s" % str(transport_path))

	if transport != null:
		_apply_transport_settings(transport)
	if adapter != null:
		_apply_adapter_settings(adapter, transport)

	if transport != null and (connect_after_apply or auto_connect):
		if not transport.is_broker_connected():
			transport.connect_to_broker()

func get_adapter() -> ProtocolAdapter:
	return _get_node(adapter_path) as ProtocolAdapter

func get_transport() -> NetworkTransport:
	return _get_node(transport_path) as NetworkTransport

func _apply_transport_settings(transport: NetworkTransport) -> void:
	transport.broker_url = broker_url
	transport.auto_connect = auto_connect
	transport.auto_reconnect = auto_reconnect
	transport.reconnect_delay_ms = reconnect_delay_ms
	transport.ping_interval_sec = ping_interval_sec
	transport.binary_messages = binary_messages
	transport.client_id = client_id
	transport.username = username
	transport.password = password

func _apply_adapter_settings(adapter: ProtocolAdapter, transport: NetworkTransport) -> void:
	adapter.auto_subscribe = adapter_auto_subscribe
	if transport != null:
		adapter.transport_path = transport.get_path()
		if bind_transport_on_apply:
			_bind_adapter_transport(adapter, transport)

func _bind_adapter_transport(adapter: ProtocolAdapter, transport: NetworkTransport) -> void:
	# Keep force_rebind meaningful without depending on private adapter fields.
	if not force_rebind and adapter.has_method("is_transport_bound") and adapter.is_transport_bound(transport):
		return
	adapter.bind_transport(transport)

func _get_node(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	var root = get_tree().root
	if root == null:
		return null
	return root.get_node_or_null(path)
