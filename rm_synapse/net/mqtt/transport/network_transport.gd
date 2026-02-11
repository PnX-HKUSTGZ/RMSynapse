extends Node
class_name NetworkTransport

signal connected
signal disconnected(reason)
signal connection_failed(reason)
signal raw_message(topic, payload)
signal text_message(topic, text)

@export var broker_url: String = "192.168.12.1:3333"
@export var auto_connect: bool = false
@export var auto_reconnect: bool = true
@export var reconnect_delay_ms: int = 2000
@export var ping_interval_sec: int = 30
@export var verbose_level: int = 1
@export var binary_messages: bool = true
@export var client_id: String = ""
@export var username: String = ""
@export var password: String = ""

var _mqtt: Node
var _connected: bool = false
var _shutting_down: bool = false
var _desired_subscriptions: Dictionary = {}
var _reconnect_timer: Timer

const LOG_PREFIX := "[NetworkTransport] "

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

func _log(level: int, message: String) -> void:
	if verbose_level >= level:
		print(LOG_PREFIX + message)

func _apply_settings() -> void:
	if _mqtt == null:
		return
	_mqtt.binarymessages = binary_messages
	_mqtt.verbose_level = verbose_level
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
	_log(1, "Connecting to broker: %s" % broker_url)
	return _mqtt.connect_to_broker(broker_url)

func disconnect_from_broker() -> void:
	_shutting_down = true
	_reconnect_timer.stop()
	_log(1, "Disconnecting from broker")
	if _mqtt != null:
		_mqtt.disconnect_from_server()

func restart_connection() -> bool:
	disconnect_from_broker()
	_shutting_down = false
	_log(1, "Restarting broker connection")
	return connect_to_broker()

func subscribe(topic: String, qos: int = 0, remember: bool = true) -> void:
	if remember:
		_desired_subscriptions[topic] = qos
	if _connected:
		_log(1, "Subscribe topic=%s qos=%d" % [topic, qos])
		_mqtt.subscribe(topic, qos)

func unsubscribe(topic: String) -> void:
	_desired_subscriptions.erase(topic)
	if _connected:
		_log(1, "Unsubscribe topic=%s" % topic)
		_mqtt.unsubscribe(topic)

func publish_bytes(topic: String, payload: PackedByteArray, retain: bool = false, qos: int = 0) -> int:
	if not binary_messages:
		binary_messages = true
		_mqtt.binarymessages = true
	_log(2, "Publish bytes topic=%s size=%d qos=%d retain=%s" % [topic, payload.size(), qos, str(retain)])
	return _mqtt.publish(topic, payload, retain, qos)

func publish_text(topic: String, text: String, retain: bool = false, qos: int = 0) -> int:
	if binary_messages:
		binary_messages = false
		_mqtt.binarymessages = false
	_log(2, "Publish text topic=%s len=%d qos=%d retain=%s" % [topic, text.length(), qos, str(retain)])
	return _mqtt.publish(topic, text, retain, qos)

func clear_subscriptions() -> void:
	_desired_subscriptions.clear()

func _on_received_message(topic, message) -> void:
	if verbose_level >= 2:
		if message is PackedByteArray:
			_log(2, "Recv bytes topic=%s size=%d" % [topic, message.size()])
		else:
			_log(2, "Recv text topic=%s len=%d" % [topic, str(message).length()])
	if message is PackedByteArray:
		emit_signal("raw_message", topic, message)
	else:
		emit_signal("text_message", topic, message)

func _on_broker_connected() -> void:
	_connected = true
	_log(1, "Broker connected")
	for topic in _desired_subscriptions.keys():
		_mqtt.subscribe(topic, int(_desired_subscriptions[topic]))
	emit_signal("connected")

func _on_broker_disconnected() -> void:
	_connected = false
	_log(1, "Broker disconnected")
	emit_signal("disconnected", "broker_disconnected")
	_schedule_reconnect()

func _on_broker_connection_failed() -> void:
	_connected = false
	_log(1, "Broker connection failed")
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
	_log(1, "Reconnect scheduled in %d ms" % delay_ms)
	_reconnect_timer.stop()
	_reconnect_timer.wait_time = float(delay_ms) / 1000.0
	_reconnect_timer.start()

func _on_reconnect_timeout() -> void:
	if _shutting_down:
		return
	_log(1, "Reconnect attempt")
	connect_to_broker()
