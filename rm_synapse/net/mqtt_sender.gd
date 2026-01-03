extends Node
class_name MqttSender

# Shared MQTT sender with three entrypoints:
# - enqueue_latest: high-rate, keep only newest per topic
# - enqueue_event: trigger-style, buffered with retry/ack
# - publish_now: direct send (for low-rate timers)

@export var mqtt_path: NodePath = NodePath("/root/MQTT")
@export_enum("off", "info", "debug", "trace") var verbose: String = "info"
@export var ack_timeout_sec: float = 2.0
@export var max_retries: int = 3
@export var max_batch_per_frame: int = 20
@export var buffer_limit_events: int = 50
@export var drop_highrate_on_disconnect: bool = true

signal sent(topic, pid)
signal ack(pid)
signal send_failed(topic, reason, pid)

const LVL_OFF := 0
const LVL_INFO := 1
const LVL_DEBUG := 2
const LVL_TRACE := 3

var mqtt: Node
var _latest := {}            # topic -> {payload, qos, retain}
var _events: Array = []      # queue of {topic,payload,qos,retain}
var _pending := {}           # pid -> {topic,payload,qos,retain,retries_left,deadline}
var _log_counter := 0

func _ready() -> void:
	mqtt = _resolve_mqtt()
	if mqtt != null and mqtt.has_signal("publish_acknowledge"):
		mqtt.connect("publish_acknowledge", Callable(self, "_on_ack"))

func _process(_delta: float) -> void:
	# resend pending if timeout
	var now = Time.get_ticks_msec() / 1000.0
	var to_retry := []
	for pid in _pending.keys():
		var entry = _pending[pid]
		if now >= entry.deadline:
			to_retry.append(pid)
	for pid in to_retry:
		_retry_pid(pid)
	_send_batch()

func enqueue_latest(topic: String, payload: PackedByteArray, qos: int = 0, retain: bool = false) -> void:
	_latest[topic] = { "payload": payload, "qos": qos, "retain": retain }
	_log_debug("enqueue_latest %s len=%d qos=%d retain=%s" % [topic, payload.size(), qos, str(retain)])

func enqueue_event(topic: String, payload: PackedByteArray, qos: int = 1, retain: bool = false) -> void:
	if _events.size() >= buffer_limit_events:
		_log_warn("Event buffer full, drop %s" % topic)
		return
	_events.append({ "topic": topic, "payload": payload, "qos": qos, "retain": retain })
	_log_debug("enqueue_event %s len=%d qos=%d retain=%s qsize=%d" % [topic, payload.size(), qos, str(retain), _events.size()])

func publish_now(topic: String, payload: PackedByteArray, qos: int = 1, retain: bool = false) -> void:
	_log_debug("publish_now %s len=%d qos=%d retain=%s" % [topic, payload.size(), qos, str(retain)])
	_send_one({ "topic": topic, "payload": payload, "qos": qos, "retain": retain })

func _send_batch() -> void:
	if mqtt == null:
		return
	var sent_count := 0
	# send one latest per topic
	var to_remove: Array = []
	for topic in _latest.keys():
		if sent_count >= max_batch_per_frame:
			break
		var item = _latest[topic]
		_send_one({ "topic": topic, "payload": item.payload, "qos": item.qos, "retain": item.retain })
		sent_count += 1
		to_remove.append(topic)
	for t in to_remove:
		_latest.erase(t)
	# send events in FIFO
	while sent_count < max_batch_per_frame and _events.size() > 0:
		var item = _events.pop_front()
		_send_one(item)
		sent_count += 1
	_log_debug("batch sent=%d latest_rem=%d events_rem=%d" % [sent_count, _latest.size(), _events.size()])

func _send_one(item: Dictionary) -> void:
	if mqtt == null:
		_log_warn("MQTT missing, drop %s" % item.topic)
		return
	if mqtt.brokerconnectmode != mqtt.BCM_CONNECTED:
		# 严格阻断所有发送（高频/低频/触发）未连接时直接丢弃
		_log_warn("Not connected, drop %s" % item.topic)
		return
	var pid = mqtt.publish(item.topic, item.payload, item.retain, item.qos)
	_log_counter += 1
	if _log_counter % 500 == 0:
		_log_debug("Publish %s len=%d pid=%s qos=%d (every 500th)" % [item.topic, item.payload.size(), str(pid), item.qos])
	sent.emit(item.topic, pid)
	if item.qos > 0 and pid != 0:
		_pending[pid] = {
			"topic": item.topic,
			"payload": item.payload,
			"qos": item.qos,
			"retain": item.retain,
			"retries_left": max_retries,
			"deadline": Time.get_ticks_msec()/1000.0 + ack_timeout_sec
		}

func _on_ack(pid) -> void:
	if _pending.has(pid):
		_pending.erase(pid)
		ack.emit(pid)

func _retry_pid(pid) -> void:
	if not _pending.has(pid):
		return
	var entry = _pending[pid]
	if entry.retries_left <= 0:
		_log_warn("Send failed %s pid=%s" % [entry.topic, str(pid)])
		_pending.erase(pid)
		send_failed.emit(entry.topic, "ack_timeout", pid)
		return
	entry.retries_left -= 1
	entry.deadline = Time.get_ticks_msec()/1000.0 + ack_timeout_sec
	_pending[pid] = entry
	_log_debug("Retry pid=%s topic=%s retries_left=%d" % [str(pid), entry.topic, entry.retries_left])
	_send_one(entry)

func _resolve_mqtt() -> Node:
	if Engine.has_singleton("MQTT"):
		return Engine.get_singleton("MQTT")
	var root_mqtt = get_node_or_null("/root/MQTT")
	if root_mqtt != null:
		_log_info("Using AutoLoad MQTT instance")
		return root_mqtt
	if mqtt_path != NodePath("") and has_node(mqtt_path):
		_log_info("Using MQTT instance at %s" % str(mqtt_path))
		return get_node(mqtt_path)
	push_error("MQTT instance not found; set mqtt_path or AutoLoad MQTT.")
	return null

func _vlevel() -> int:
	match verbose:
		"off": return LVL_OFF
		"debug": return LVL_DEBUG
		"trace": return LVL_TRACE
		_: return LVL_INFO

func _log_info(msg:String) -> void:
	if _vlevel() >= LVL_INFO:
		print("%s [MqttSender][INFO] %s" % [Time.get_datetime_string_from_system(), msg])

func _log_debug(msg:String) -> void:
	if _vlevel() >= LVL_DEBUG:
		print("%s [MqttSender][DEBUG] %s" % [Time.get_datetime_string_from_system(), msg])

func _log_warn(msg:String) -> void:
	print("%s [MqttSender][WARN] %s" % [Time.get_datetime_string_from_system(), msg])

func _log_error(msg:String) -> void:
	push_error("%s [MqttSender][ERROR] %s" % [Time.get_datetime_string_from_system(), msg])
