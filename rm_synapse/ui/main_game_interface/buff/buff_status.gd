extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _name: RichTextLabel = $Name
@onready var _level: RichTextLabel = $Level
@onready var _time_bar: ProgressBar = $TimeBar
@onready var _param: RichTextLabel = $Param

var _gs: Node = null
var _robot_id: int = -1
var _id_map: IdMap = null

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
	_id_map = get_node("/root/IDMap")
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

	# 1. 完整获取所有变量 (千万不能漏掉这部分)
	_robot_id = int(_getv(entry, "robot_id", -1))
	var buff_type = int(_getv(entry, "buff_type", -1))
	var buff_level = int(_getv(entry, "buff_level", 0))
	var max_time = float(_getv(entry, "buff_max_time", 0.0))
	var left_time = float(_getv(entry, "buff_left_time", 0.0))
	var param_str = str(_getv(entry, "msg_params", "")) # <--- 报错就是因为这行之前可能没了

	if buff_type == -1:
		visible = false
		return

	# 2. 更新文本显示
	var robot_name = _id_map.get_robot_name(_robot_id, true) if _id_map else "ID %d" % _robot_id
	_name.text = "%s - %s" % [robot_name, BUFF_NAME.get(buff_type, "Buff %d" % buff_type)]
	_level.text = "Lv.%d" % buff_level
	_param.text = param_str

	# 3. 更新时间条与颜色逻辑
	if max_time > 0:
		_time_bar.max_value = max_time
		_time_bar.value = clamp(left_time, 0.0, max_time)
		_time_bar.visible = true
		
		# 计算百分比
		var percent = left_time / max_time if max_time > 0 else 0.0
		
		# 获取或新建样式
		var fill_style: StyleBoxFlat
		if _time_bar.has_theme_stylebox_override("fill"):
			fill_style = _time_bar.get_theme_stylebox("fill")
		else:
			fill_style = StyleBoxFlat.new()
			_time_bar.add_theme_stylebox_override("fill", fill_style)
		
		# 样式：直角矩形
		fill_style.set_corner_radius_all(0)
		
		# 样式：动态变色 (绿 -> 黄 -> 红)
		if percent < 0.2: 
			# 红色 (快结束)
			fill_style.bg_color = Color(1, 0.25, 0.25)
			fill_style.shadow_color = Color(1, 0.5, 0.5, 0.8)
			fill_style.shadow_size = 2
		elif percent < 0.6:
			# 黄色 (剩余一半)
			fill_style.bg_color = Color(1, 0.8, 0.2)
			fill_style.shadow_color = Color(1, 0.9, 0.6, 0.8)
			fill_style.shadow_size = 2
		else:
			# 绿色 (充足)
			fill_style.bg_color = Color(0.2, 0.8, 0.3)
			fill_style.shadow_color = Color(0.5, 1, 0.6, 0.8)
			fill_style.shadow_size = 2
			
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
