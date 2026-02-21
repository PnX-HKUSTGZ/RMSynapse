extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _line1: Label = $Panel/Margin/VBox/Line1
@onready var _line2: Label = $Panel/Margin/VBox/Line2
@onready var _line3: Label = $Panel/Margin/VBox/Line3
@onready var _line4: Label = $Panel/Margin/VBox/Line4

var _gs: Node = null

var _air_support: int = 0
var _air_left: int = 0
var _sentry_posture: int = 0
var _sentry_weak: bool = false
var _dart_target: int = 0
var _dart_open: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gs = _resolve_game_state()
	if _gs == null:
		return

	_connect_if_exists("air_support_status_sync_updated", "_on_air")
	_connect_if_exists("sentinel_status_sync_updated", "_on_sentry")
	_connect_if_exists("dart_select_target_status_sync_updated", "_on_dart")
	_connect_if_exists("robot_position_updated", "_on_pos")
	_connect_if_exists("rader_info_updated", "_on_radar")
	_connect_if_exists("robot_path_plan_info_updated", "_on_path")
	_connect_if_exists("buff_updated", "_on_buff")

func _resolve_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if has_node(game_state_path):
		return get_node(game_state_path)
	push_warning("[MiniMapPanel] GameState not found at %s" % str(game_state_path))
	return null

func _connect_if_exists(signal_name: String, method_name: String) -> void:
	if _gs.has_signal(signal_name):
		_gs.connect(signal_name, Callable(self, method_name))

func _refresh_line1() -> void:
	_line1.text = "空中支援: 状态%d 剩余%ds | 哨兵: 姿态%d 弱化%s | 飞镖: 目标%d 状态%d" % [
		_air_support,
		_air_left,
		_sentry_posture,
		"是" if _sentry_weak else "否",
		_dart_target,
		_dart_open
	]

func _on_air(msg) -> void:
	_air_support = _get_i(msg, "get_airsupport_status", 0)
	_air_left = _get_i(msg, "get_left_time", 0)
	_refresh_line1()

func _on_sentry(msg) -> void:
	_sentry_posture = _get_i(msg, "get_posture_id", 0)
	_sentry_weak = _get_b(msg, "get_is_weakened", false)
	_refresh_line1()

func _on_dart(msg) -> void:
	_dart_target = _get_i(msg, "get_target_id", 0)
	if msg != null and msg.has_method("get_open"):
		_dart_open = 1 if bool(msg.call("get_open")) else 0
	_refresh_line1()

func _on_pos(msg) -> void:
	var x: float = _get_f(msg, "get_x", 0.0)
	var y: float = _get_f(msg, "get_y", 0.0)
	var yaw: float = _get_f(msg, "get_yaw", 0.0)
	_line2.text = "定位: x=%.1f y=%.1f yaw=%.1f" % [x, y, yaw]

func _on_radar(msg) -> void:
	var rid: int = _get_i(msg, "get_target_robot_id", 0)
	var hx: int = _get_i(msg, "get_is_high_light", 0)
	_line3.text = "雷达: 目标%d 高亮%d | 路径: --" % [rid, hx]

func _on_path(msg) -> void:
	var intention: int = _get_i(msg, "get_intention", 0)
	var sx: int = _get_i(msg, "get_start_pos_x", 0)
	var sy: int = _get_i(msg, "get_start_pos_y", 0)
	_line3.text = "雷达: -- | 路径: 意图%d 起点(%d,%d)" % [intention, sx, sy]

func _on_buff(msg) -> void:
	var bt: int = _get_i(msg, "get_buff_type", 0)
	var left: int = _get_i(msg, "get_buff_left_time", 0)
	var lv: int = _get_i(msg, "get_buff_level", 0)
	_line4.text = "Buff: 类型%d 等级%d 剩余%ds" % [bt, lv, left]

func _get_i(msg, method_name: String, default_val: int) -> int:
	if msg != null and msg.has_method(method_name):
		return int(msg.call(method_name))
	return default_val

func _get_f(msg, method_name: String, default_val: float) -> float:
	if msg != null and msg.has_method(method_name):
		return float(msg.call(method_name))
	return default_val

func _get_b(msg, method_name: String, default_val: bool) -> bool:
	if msg != null and msg.has_method(method_name):
		return bool(msg.call(method_name))
	return default_val
