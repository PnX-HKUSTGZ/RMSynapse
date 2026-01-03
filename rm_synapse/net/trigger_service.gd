extends Node
class_name TriggerService

# 触发式上行：仅发送 MapClickInfoNotify（云台手地图点击标记）。

@export var mqtt_sender_path: NodePath = NodePath("/root/MQTTSender")
@export_enum("off", "info", "debug") var verbose: String = "info"
@export var cooldown_ms: int = 0
@export var buffer_limit: int = 50

signal fire_failed(topic, reason)

var sender: MqttSender
var _last_sent := {}   # key -> timestamp_ms
var _buffer: Array = [] # 缓冲队列

const Proto = preload("res://protocol/generated/rm_proto.gd")

func _ready() -> void:
	sender = _resolve_sender()

func fire_map_click(
	is_send_all: int,
	robot_id: PackedByteArray,
	mode: int,
	enemy_id: int,
	ascii: int,
	type: int,
	screen_x: int,
	screen_y: int,
	map_x: float,
	map_y: float
) -> void:
	_fire_topic("MapClickInfoNotify", func():
		var msg = Proto.MapClickInfoNotify.new()
		msg.set_is_send_all(is_send_all)
		msg.set_robot_id(robot_id)
		msg.set_mode(mode)
		msg.set_enemy_id(enemy_id)
		msg.set_ascii(ascii)
		msg.set_type(type)
		msg.set_screen_x(screen_x)
		msg.set_screen_y(screen_y)
		msg.set_map_x(map_x)
		msg.set_map_y(map_y)
		return msg.to_bytes()
	)

func _fire_topic(topic: String, payload_builder: Callable, qos: int = 1, retain: bool = false, cooldown_override_ms: int = -1) -> void:
	var payload: PackedByteArray = payload_builder.call()
	var now_ms = Time.get_ticks_msec()
	var cd = cooldown_override_ms if cooldown_override_ms >= 0 else cooldown_ms
	var key = topic + ":" + str(_hash_bytes(payload))
	if cd > 0 and _last_sent.has(key) and now_ms - _last_sent[key] < cd:
		_log_debug("Cooldown drop %s" % topic)
		return
	if sender == null:
		if _buffer.size() >= buffer_limit:
			_log_warn("Buffer full, drop %s" % topic)
			fire_failed.emit(topic, "no_sender")
			return
		_buffer.append({"topic": topic, "payload": payload, "qos": qos, "retain": retain})
		_log_info("Buffered %s len=%d (sender missing)" % [topic, payload.size()])
		return
	sender.enqueue_event(topic, payload, qos, retain)
	_last_sent[key] = now_ms
	_log_info("Fire %s len=%d qos=%d" % [topic, payload.size(), qos])

func flush_buffer():
	if sender == null:
		return
	while _buffer.size() > 0:
		var it = _buffer.pop_front()
		sender.enqueue_event(it.topic, it.payload, it.qos, it.retain)

func _resolve_sender() -> MqttSender:
	if Engine.has_singleton("MQTTSender"):
		return Engine.get_singleton("MQTTSender")
	if mqtt_sender_path != NodePath("") and has_node(mqtt_sender_path):
		return get_node(mqtt_sender_path) as MqttSender
	push_error("MQTTSender not found; set mqtt_sender_path.")
	return null

func _hash_bytes(b: PackedByteArray) -> int:
	var h: int = 2166136261
	for byte in b:
		h = h ^ byte
		h = int((h * 16777619) & 0xFFFFFFFF)
	return h

func _vlevel() -> int:
	match verbose:
		"debug": return 2
		"info": return 1
		_: return 0

func _log_info(msg:String) -> void:
	if _vlevel() >= 1:
		print("%s [Trigger] %s" % [Time.get_datetime_string_from_system(), msg])

func _log_debug(msg:String) -> void:
	if _vlevel() >= 2:
		print("%s [Trigger][DBG] %s" % [Time.get_datetime_string_from_system(), msg])

func _log_warn(msg:String) -> void:
	print("%s [Trigger][WARN] %s" % [Time.get_datetime_string_from_system(), msg])
