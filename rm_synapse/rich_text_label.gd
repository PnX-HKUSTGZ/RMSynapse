extends RichTextLabel

var _sender: Node = null

func _ready() -> void:
	visible = false
	var mqtt_root := get_tree().get_root().get_node_or_null("Mqtt")
	if mqtt_root:
		_sender = mqtt_root.get_node_or_null("Adapter")
		if _sender and _sender.has_signal("message_sent"):
			_sender.connect("message_sent", Callable(self, "_on_mqtt_sent"))
		else:
			_log_error("Adapter node not found under Mqtt.")
	else:
		_log_error("Mqtt autoload not found; demo未激活。")

func _on_mqtt_sent(topic, size, result, qos) -> void:
	# 简单示例：收到任意发送事件后显示标签，并更新内容
	visible = true
	text = "MQTT sent: %s (size=%s, result=%s, qos=%s)" % [topic, str(size), str(result), str(qos)]

func _log_error(msg: String) -> void:
	push_error("%s [RichTextLabel][ERR] %s" % [Time.get_datetime_string_from_system(), msg])
