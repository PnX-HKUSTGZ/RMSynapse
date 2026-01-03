extends RichTextLabel

var _sender: Node = null

func _ready() -> void:
	visible = false
	# 当前项目把所有 MQTT 逻辑打包到 autoload 场景 `MqttNet`
	# 其中子节点名为 "MQTTSender"（见 net/mqtt_net.tscn）
	var net_root: Node = null
	if Engine.has_singleton("MqttNet"):
		net_root = Engine.get_singleton("MqttNet")
	elif get_tree().get_root().has_node("MqttNet"):
		net_root = get_tree().get_root().get_node("MqttNet")
	if net_root:
		_sender = net_root.get_node_or_null("MQTTSender")
		if _sender and _sender.has_signal("sent"):
			_sender.connect("sent", Callable(self, "_on_mqtt_sent"))
		else:
			_log_error("MQTTSender node not found under MqttNet.")
	else:
		_log_error("MqttNet autoload not found; demo未激活。")

func _on_mqtt_sent(topic, pid) -> void:
	# 简单示例：收到任意发送事件后显示标签，并更新内容
	visible = true
	text = "MQTT sent: %s (pid=%s)" % [topic, str(pid)]

func _log_error(msg: String) -> void:
	push_error("%s [RichTextLabel][ERR] %s" % [Time.get_datetime_string_from_system(), msg])
