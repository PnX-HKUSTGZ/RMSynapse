extends Node
class_name NetworkTransport

signal connected
signal disconnected(reason)
signal connection_failed(reason)
signal raw_message(topic, payload)
signal text_message(topic, text)

@export var broker_url: String = "192.168.12.1:3333"
@export var auto_connect: bool = true
@export var auto_reconnect: bool = true
@export var reconnect_delay_ms: int = 2000
@export var ping_interval_sec: int = 30
@export var binary_messages: bool = true
@export var client_id: String = ""
@export var username: String = ""
@export var password: String = ""

var _mqtt: Node
var _connected: bool = false
var _shutting_down: bool = false
var _desired_subscriptions: Dictionary = {}
var _reconnect_timer: Timer

func _ready() -> void:
	_mqtt = preload("res://addons/mqtt/mqtt.gd").new()
	add_child(_mqtt)
	_mqtt.received_message.connect(_on_received_message)
	_mqtt.broker_connected.connect(_on_broker_connected)
	_mqtt.broker_disconnected.connect(_on_broker_disconnected)
	_mqtt.broker_connection_failed.connect(_on_broker_connection_failed)

	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_on_reconnect_timeout)
	add_child(_reconnect_timer)

	_apply_settings()

	if auto_connect:
		connect_to_broker()

func _apply_settings() -> void:
	if _mqtt == null:
		return
	_mqtt.binarymessages = binary_messages
	var mqtt_verbose = 0
	if Log.min_level <= Log.Level.DEBUG:
		mqtt_verbose = 2
	elif Log.min_level <= Log.Level.INFO:
		mqtt_verbose = 1
	_mqtt.verbose_level = mqtt_verbose
	_mqtt.pinginterval = ping_interval_sec
	if client_id != "":
		_mqtt.client_id = client_id
	if username == "":
		_mqtt.set_user_pass(null, null)
	else:
		_mqtt.set_user_pass(username, password)

func is_broker_connected() -> bool:
	return _connected

func connect_to_broker() -> bool:
	_shutting_down = false
	_apply_settings()
	_reconnect_timer.stop()
	Log.info("[NetworkTransport] Connecting to broker: %s" % broker_url)
	return _mqtt.connect_to_broker(broker_url)

func disconnect_from_broker() -> void:
	_shutting_down = true
	_reconnect_timer.stop()
	Log.info("[NetworkTransport] Disconnecting from broker")
	if _mqtt != null:
		_mqtt.disconnect_from_server()

func restart_connection() -> bool:
	disconnect_from_broker()
	_shutting_down = false
	Log.info("[NetworkTransport] Restarting broker connection")
	return connect_to_broker()

func subscribe(topic: String, qos: int = 0, remember: bool = true) -> void:
	if remember:
		_desired_subscriptions[topic] = qos
	if _connected:
		Log.info("[NetworkTransport] Subscribe topic=%s qos=%d" % [topic, qos])
		_mqtt.subscribe(topic, qos)

func unsubscribe(topic: String) -> void:
	_desired_subscriptions.erase(topic)
	if _connected:
		Log.info("[NetworkTransport] Unsubscribe topic=%s" % topic)
		_mqtt.unsubscribe(topic)

func publish_bytes(topic: String, payload: PackedByteArray, retain: bool = false, qos: int = 0) -> int:
	if not _connected or _mqtt == null:
		Log.warn("[NetworkTransport] Drop bytes publish while broker is disconnected: %s" % topic)
		return -1
	if not binary_messages:
		binary_messages = true
		_mqtt.binarymessages = true
	Log.debug("[NetworkTransport] Publish bytes topic=%s size=%d qos=%d retain=%s" % [topic, payload.size(), qos, str(retain)])
	return _mqtt.publish(topic, payload, retain, qos)

func publish_text(topic: String, text: String, retain: bool = false, qos: int = 0) -> int:
	if not _connected or _mqtt == null:
		Log.warn("[NetworkTransport] Drop text publish while broker is disconnected: %s" % topic)
		return -1
	var previous_binary_messages := binary_messages
	binary_messages = false
	_mqtt.binarymessages = false
	Log.debug("[NetworkTransport] Publish text topic=%s len=%d qos=%d retain=%s" % [topic, text.length(), qos, str(retain)])
	var result := int(_mqtt.publish(topic, text, retain, qos))
	binary_messages = previous_binary_messages
	_mqtt.binarymessages = previous_binary_messages
	return result

func clear_subscriptions() -> void:
	_desired_subscriptions.clear()

func _on_received_message(topic, message) -> void:
	if message is PackedByteArray:
		Log.debug("[NetworkTransport] Recv bytes topic=%s size=%d" % [topic, message.size()])
	else:
		Log.debug("[NetworkTransport] Recv text topic=%s len=%d" % [topic, str(message).length()])
	if message is PackedByteArray:
		emit_signal("raw_message", topic, message)
	else:
		emit_signal("text_message", topic, message)

func _on_broker_connected() -> void:
	_connected = true
	Log.info("[NetworkTransport] Broker connected")
	for topic in _desired_subscriptions.keys():
		_mqtt.subscribe(topic, int(_desired_subscriptions[topic]))
	emit_signal("connected")

func _on_broker_disconnected() -> void:
	_connected = false
	Log.warn("[NetworkTransport] Broker disconnected")
	emit_signal("disconnected", "broker_disconnected")
	_schedule_reconnect()

func _on_broker_connection_failed() -> void:
	_connected = false
	Log.warn("[NetworkTransport] Broker connection failed")
	emit_signal("connection_failed", "broker_connection_failed")
	_schedule_reconnect()

func _schedule_reconnect() -> void:
	if not auto_reconnect:
		return
	if _shutting_down:
		return
	var delay_ms = reconnect_delay_ms
	if delay_ms < 0:
		delay_ms = 0
	Log.info("[NetworkTransport] Reconnect scheduled in %d ms" % delay_ms)
	_reconnect_timer.stop()
	_reconnect_timer.wait_time = float(delay_ms) / 1000.0
	_reconnect_timer.start()

func _on_reconnect_timeout() -> void:
	if _shutting_down:
		return
	Log.info("[NetworkTransport] Reconnect attempt")
	connect_to_broker()
