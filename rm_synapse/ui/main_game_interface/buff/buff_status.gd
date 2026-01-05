extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _name: RichTextLabel = $Name
@onready var _level: RichTextLabel = $Level
@onready var _time_bar: ProgressBar = $TimeBar
@onready var _param: RichTextLabel = $Param

var _gs: Node = null
var _robot_id: int = -1

const BUFF_NAME := {
	1: "攻击增益",
	2: "防御增益",
	3: "射击热量冷却增益",
	4: "底盘功率增益",
	5: "回血增益",
	6: "可兑换允许发弹量",
	7: "地形跨越增益"
}

func _ready() -> void:
	visible = false
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("buff_updated"):
			_gs.connect("buff_updated", Callable(self, "_on_buff"))
	else:
		push_warning("[BuffStatus] GameState not found at %s" % str(game_state_path))

func _on_buff(value) -> void:
	var entry = _pick_entry(value)
	if entry == null:
		visible = false
		return

	_robot_id = int(_getv(entry, "robot_id", -1))
	var buff_type = int(_getv(entry, "buff_type", -1))
	var buff_level = int(_getv(entry, "buff_level", 0))
	var max_time = float(_getv(entry, "buff_max_time", 0.0))
	var left_time = float(_getv(entry, "buff_left_time", 0.0))
	var param_str = str(_getv(entry, "msg_params", ""))

	if buff_type == -1:
		visible = false
		return

	var robot_name = ROBOT_ID_NAME.get(_robot_id, "ID %d" % _robot_id)
	_name.text = "%s - %s" % [robot_name, BUFF_NAME.get(buff_type, "Buff %d" % buff_type)]
	_level.text = "Lv.%d" % buff_level
	_param.text = param_str

	if max_time > 0:
		_time_bar.max_value = max_time
		_time_bar.value = clamp(left_time, 0.0, max_time)
		_time_bar.visible = true
	else:
		_time_bar.visible = false

	visible = true

func _pick_entry(data):
	if data == null:
		return null
	# If array, pick first
	if typeof(data) == TYPE_ARRAY:
		if data.size() > 0:
			return data[0]
		return null
	# If dictionary
	if typeof(data) == TYPE_DICTIONARY:
		# check direct fields
		if data.has("buff_type"):
			return data
		# try values collection
		for v in data.values():
			if typeof(v) == TYPE_DICTIONARY or v is Object:
				return v
		return null
	# Object case
	return data

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _getv(src, key_name: String, default_val):
	if src == null:
		return default_val
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val

const ROBOT_ID_NAME := {
	1: "红方英雄机器人",
	2: "红方工程机器人",
	3: "红方步兵机器人1",
	4: "红方步兵机器人2",
	5: "红方步兵机器人3",
	6: "红方空中机器人",
	7: "红方哨兵机器人",
	8: "红方飞镖",
	9: "红方雷达",
	10: "红方前哨站",
	11: "红方基地",
	101: "蓝方英雄机器人",
	102: "蓝方工程机器人",
	103: "蓝方步兵机器人1",
	104: "蓝方步兵机器人2",
	105: "蓝方步兵机器人3",
	106: "蓝方空中机器人",
	107: "蓝方哨兵机器人",
	108: "蓝方飞镖",
	109: "蓝方雷达",
	110: "蓝方前哨站",
	111: "蓝方基地"
}
