extends Control

const COLOR_OK := Color(0.14, 0.85, 0.56)
const COLOR_FAIL := Color(0.89, 0.36, 0.36)
const COLOR_IDLE := Color(0.5, 0.5, 0.5)
const COLOR_WARN := Color(0.95, 0.77, 0.25)

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var video_canvas_path: NodePath = NodePath("/root/RMVideoCanvas")

var _gs: Node = null
var _video: Node = null

func _ready() -> void:
	# 默认状态
	set_mqtt_up_status("MQTT 上行: 未连接", COLOR_IDLE)
	set_mqtt_down_status("MQTT 下行: 未连接", COLOR_IDLE)
	set_video_status("视频流: 未连接", COLOR_IDLE)
	set_robot_conn_status("机器人连接: 未知", COLOR_IDLE)
	set_robot_field_status("上场状态: 未知", COLOR_IDLE)
	set_robot_alive_status("存活状态: 未知", COLOR_IDLE)
	_gs = _resolve_game_state()
	if _gs:
		print("[NetStatus] GameState resolved: ", _gs)
		if _gs.has_signal("mqtt_connected"):
			_gs.connect("mqtt_connected", Callable(self, "_on_mqtt_connected"))
		else:
			push_warning("[NetStatus] GameState has NO mqtt_connected/mqtt_disconnected signals.")

		if _gs.has_signal("mqtt_disconnected"):
			_gs.connect("mqtt_disconnected", Callable(self, "_on_mqtt_disconnected"))
		else:
			push_warning("[NetStatus] GameState has NO mqtt_disconnected/mqtt_connected signals.")

		if _gs.has_signal("mqtt_connection_failed"):
			_gs.connect("mqtt_connection_failed", Callable(self, "_on_mqtt_disconnected"))
		else:
			push_warning("[NetStatus] GameState has NO mqtt_connected/mqtt_disconnected/mqtt_connection_failed signals.")

		if _gs.has_signal("robot_static_status_updated"):
			_gs.connect("robot_static_status_updated", Callable(self, "_on_robot_static_status"))
		else:
			push_warning("[NetStatus] GameState missing robot_static_status_updated signal.")
	else:
		push_warning("[NetStatus] GameState node NOT found.")

	_video = _resolve_video()
	if _video:
		print("[NetStatus] Video canvas resolved: ", _video)
		if _video.has_signal("stream_state_changed"):
			_video.connect("stream_state_changed", Callable(self, "_on_video_stream_state"))
		else:
			push_warning("[NetStatus] Video canvas has NO stream_state_changed signal.")
	else:
		push_warning("[NetStatus] Video canvas NOT found.")

func set_mqtt_up_status(text: String, color: Color = Color(0.23, 0.91, 0.56)) -> void:
	_set_row_status($"VBox/RowUpMQTT/Status", text, color)

func set_mqtt_down_status(text: String, color: Color = Color(0.23, 0.91, 0.56)) -> void:
	_set_row_status($"VBox/RowDownMQTT/Status", text, color)

func set_video_status(text: String, color: Color = Color(0.23, 0.91, 0.56)) -> void:
	_set_row_status($"VBox/RowVideo/Status", text, color)

func set_robot_conn_status(text: String, color: Color = COLOR_IDLE) -> void:
	_set_row_status($"VBox/RowRobotConn/Status", text, color)

func set_robot_field_status(text: String, color: Color = COLOR_IDLE) -> void:
	_set_row_status($"VBox/RowRobotField/Status", text, color)

func set_robot_alive_status(text: String, color: Color = COLOR_IDLE) -> void:
	_set_row_status($"VBox/RowRobotAlive/Status", text, color)

func _set_row_status(label: Label, text: String, color: Color) -> void:
	if label == null:
		return
	label.text = text
	label.add_theme_color_override("font_color", color)

func _on_mqtt_connected() -> void:
	set_mqtt_up_status("MQTT 上行: 已连接", COLOR_OK)
	set_mqtt_down_status("MQTT 下行: 已连接", COLOR_OK)

func _on_mqtt_disconnected() -> void:
	set_mqtt_up_status("MQTT 上行: 未连接", COLOR_FAIL)
	set_mqtt_down_status("MQTT 下行: 未连接", COLOR_FAIL)

func _on_video_stream_state(is_streaming: bool) -> void:
	if is_streaming:
		set_video_status("视频流: 正在接收", COLOR_OK)
	else:
		set_video_status("视频流: 未接收", COLOR_FAIL)

func _on_robot_static_status(value) -> void:
	var conn = int(_get_val(value, "connection_state", -1))
	match conn:
		1: set_robot_conn_status("机器人连接: 已连接", COLOR_OK)
		0: set_robot_conn_status("机器人连接: 未连接", COLOR_FAIL)
		_: set_robot_conn_status("机器人连接: 未知", COLOR_IDLE)

	var field = int(_get_val(value, "field_state", -1))
	match field:
		0: set_robot_field_status("上场状态: 已上场", COLOR_OK)
		1: set_robot_field_status("上场状态: 未上场", COLOR_WARN)
		_: set_robot_field_status("上场状态: 未知", COLOR_IDLE)

	var alive = int(_get_val(value, "alive_state", -1))
	match alive:
		1: set_robot_alive_status("存活状态: 存活", COLOR_OK)
		2: set_robot_alive_status("存活状态: 阵亡", COLOR_FAIL)
		0: set_robot_alive_status("存活状态: 未知", COLOR_IDLE)
		_: set_robot_alive_status("存活状态: 未知", COLOR_IDLE)

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _resolve_video() -> Node:
	if video_canvas_path != NodePath("") and has_node(video_canvas_path):
		return get_node(video_canvas_path)
	# 尝试在树中搜索 RMVideoCanvas
	if get_tree():
		var root = get_tree().root
		if root:
			var candidate = root.find_child("RMVideoCanvas", true, false)
			if candidate:
				return candidate
	return null

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val
