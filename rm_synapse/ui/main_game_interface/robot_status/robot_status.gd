extends Node2D

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var target_robot_id: int = -1   # -1 表示不筛选，取第一条

@onready var _robot_logo: TextureRect = $RobotLogo
@onready var _id_label: RichTextLabel = $RobotIDShow
@onready var _id_show: Label = $IDShow
@onready var _type_label: RichTextLabel = $RobotTypeShow
@onready var _level_label: RichTextLabel = $Level
@onready var _chassis_label: RichTextLabel = $RobotChassisProShow
@onready var _shooter_label: RichTextLabel = $RobotShooterProShow
@onready var _hp_bar: ProgressBar = $HPBar
@onready var _hp_show: RichTextLabel = $HPShow
@onready var _conn_label: RichTextLabel = $RobotConnectShow
@onready var _field_label: RichTextLabel = $RobotFieldShow
@onready var _exp_bar: ProgressBar = $ExpBar
@onready var _exp_show: RichTextLabel = $ExpShow

var _gs: Node = null
var _id_map: IdMap = null
var _max_hp: int = 0
var _cur_exp: int = 0
var _max_exp: int = 0

const SHOOTER_MAP := {
	1: "冷却优先",
	2: "爆发优先",
	3: "英雄近战优先",
	4: "英雄远程优先"
}

const CHASSIS_MAP := {
	1: "血量优先",
	2: "功率优先",
	3: "英雄近战优先",
	4: "英雄远程优先"
}

const id_2_logo : = {
	1: "res://imgs/yingxiong.png",
	2: "res://imgs/gongcheng.png",
	3: "res://imgs/bubing.png",
	4: "res://imgs/bubing.png",
	5: "res://imgs/bubing.png",
	6: "res://imgs/kongzhong.png",
	7: "res://imgs/shaobing.png",
	8: "res://imgs/feibiao.png",
	9: "res://imgs/leida.png"
}

const id_2_scale : ={
	1: 0.35,
	2: 0.4,
	3: 0.07,
	4: 0.07,
	5: 0.07,
	6: 0.4,
	7: 0.4,
	8: 0.13,
	9: 0.13
}

func _ready() -> void:
	_reset_ui()
	_id_map = get_node("/root/IDMap")
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_static_status_updated"):
			_gs.connect("robot_static_status_updated", Callable(self, "_on_static"))
		if _gs.has_signal("robot_dynamic_status_updated"):
			_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic"))
	else:
		push_warning("[RobotStatus] GameState not found at %s" % str(game_state_path))

func _reset_ui() -> void:
	_max_hp = 0
	if _robot_logo: _robot_logo.texture=load("res://icon.svg")
	if _id_label: _id_label.text = "ID: --"
	if _id_show: _id_show.text = "--"
	if _type_label: _type_label.text = "Type: --"
	if _level_label: _level_label.text = "Level: --"
	if _chassis_label: _chassis_label.text = "底盘: --"
	if _shooter_label: _shooter_label.text = "发射: --"
	if _conn_label: _conn_label.text = "连接:未知"
	if _field_label: _field_label.text = "上场:未知"
	if _hp_bar:
		_hp_bar.max_value = 100
		_hp_bar.value = 0
	if _hp_show:
		_hp_show.text = "--/--"
	if _exp_bar:
		_exp_bar.max_value = 1
		_exp_bar.value = 0
	if _exp_show:
		_exp_show.text = "--/--"

func _on_static(value) -> void:
	var entry = _pick_entry(value)
	if entry == null:
		return
	var robot_id = _get_val(entry, "robot_id", target_robot_id)
	var robot_type = _get_val(entry, "robot_type", -1)
	var level = _get_val(entry, "level", -1)
	var shooter = _get_val(entry, "performance_system_shooter", -1)
	var chassis = _get_val(entry, "performance_system_chassis", -1)
	_max_hp = int(_get_val(entry, "max_health", _max_hp))
	var conn_state = int(_get_val(entry, "connection_state", -1))
	var field_state = int(_get_val(entry, "field_state", -1))

	if _id_label: _id_label.text = "ID: %s" % str(robot_id)
	if _id_show: _id_show.text = "%s" % str(robot_id)
	if _robot_logo: 
		var target_path = id_2_logo.get(robot_id, "res://icon.svg")
		# 加载图片并设置
		_robot_logo.texture = load(target_path)
	if _type_label:
		_type_label.text = _format_id_and_type(robot_id, robot_type)
		var target_scale = id_2_scale.get(robot_id, 1)
		# 等比例赋值（x/y同比例，避免拉伸）
		_robot_logo.scale = Vector2(target_scale, target_scale)
		
	if _level_label: _level_label.text = "Level: %s" % str(level)
	if _chassis_label: _chassis_label.text = CHASSIS_MAP.get(chassis, "底盘: --")
	if _shooter_label: _shooter_label.text = SHOOTER_MAP.get(shooter, "发射: --")
	if _conn_label: _conn_label.text = _format_conn(conn_state)
	if _field_label: _field_label.text = _format_field(field_state)
	if _hp_bar:
		_hp_bar.max_value = max(1, _max_hp)
		_hp_bar.value = min(_hp_bar.max_value, _hp_bar.value)
	_update_hp_show()

func _on_dynamic(value) -> void:
	var entry = _pick_entry(value)
	if entry == null:
		return
	var current_hp = int(_get_val(entry, "current_health", -1))
	_max_exp = int(_get_val(entry, "experience_for_upgrade", _max_exp))
	_cur_exp = int(_get_val(entry, "current_experience", _cur_exp))
	if current_hp < 0:
		return
	if _hp_bar:
		_hp_bar.value = clamp(current_hp, 0, max(1, _hp_bar.max_value))
	_update_hp_show()
	if _exp_bar:
		_exp_bar.max_value = max(1, _max_exp)
		_exp_bar.value = clamp(_cur_exp, 0, _exp_bar.max_value)
	_update_exp_show()

func _update_hp_show() -> void:
	if _hp_show == null or _hp_bar == null:
		return
	
	var current = int(_hp_bar.value)
	var maxv = int(_hp_bar.max_value)
	_hp_show.text = "%d/%d" % [current, maxv]
	
	if maxv <= 0: return
	var hp_percent = float(current) / float(maxv)

	# 1. 获取或创建样式
	var fill_style: StyleBoxFlat
	if _hp_bar.has_theme_stylebox_override("fill"):
		fill_style = _hp_bar.get_theme_stylebox("fill")
	else:
		fill_style = StyleBoxFlat.new()
		_hp_bar.add_theme_stylebox_override("fill", fill_style)

	# 2. 设置样式参数 (核心修正部分)
	# 确保圆角和你的设计一致（可选）
	fill_style.corner_radius_top_left = 150
	fill_style.corner_radius_top_right = 5
	fill_style.corner_radius_bottom_right = 175
	fill_style.corner_radius_bottom_left = 30
	
	# 设置颜色和发光（阴影）
	if hp_percent < 0.3:
		fill_style.bg_color = Color(1.0, 0.012, 0.2, 1.0)        # 橙红色背景
		fill_style.shadow_color = Color(0.729, 0.0, 0.357, 0.761) # ❌ 改正：这里是 shadow_color
		fill_style.shadow_size = 4                       # ✅ 新增：必须设置大小，否则看不见光晕
	elif hp_percent < 0.6:
		fill_style.bg_color = Color(0.0, 0.89, 0.89, 1.0)
		fill_style.shadow_color = Color(0.71, 0.933, 0.988, 0.922)
		fill_style.shadow_size = 4
	else:
		fill_style.bg_color = Color(0.251, 0.459, 1.0, 0.957)       # 正常蓝色
		fill_style.shadow_color = Color(0.384, 0.918, 1.0, 0.588)
		fill_style.shadow_size = 2

func _update_exp_show() -> void:
	if _exp_show == null or _exp_bar == null:
		return
	var current = int(_exp_bar.value)
	var maxv = int(_exp_bar.max_value)
	_exp_show.text = "%d/%d" % [current, maxv]

func _pick_entry(data):
	# 兼容单条、数组、字典(id->条目)
	if data == null:
		return null
	if typeof(data) == TYPE_DICTIONARY:
		if target_robot_id != -1 and data.has(target_robot_id):
			return data[target_robot_id]
		# 若值本身是条目
		if _maybe_match(data):
			return data
		# 取第一个
		for v in data.values():
			if _maybe_match(v):
				return v
		return null
	if typeof(data) == TYPE_ARRAY:
		for v in data:
			if _maybe_match(v):
				return v
		return null
	# 单对象
	if _maybe_match(data):
		return data
	return null

func _maybe_match(entry) -> bool:
	if target_robot_id == -1:
		return true
	var rid = _get_val(entry, "robot_id", -1)
	return rid == target_robot_id

func _format_conn(state: int) -> String:
	match state:
		0: return "连接:未连"
		1: return "连接:已连"
		_: return "连接:未知"

func _format_field(state: int) -> String:
	match state:
		0: return "上场:是"
		1: return "上场:否"
		_: return "上场:未知"

func _format_alive(state: int) -> String:
	match state:
		1: return "存活:是"
		2: return "存活:阵亡"
		0: return "存活:未知"
		_: return "存活:未知"

func _format_id_and_type(robot_id: int, robot_type: int) -> String:
	var id_name = _id_map.get_robot_name(robot_id) if _id_map else "未知机器人"
	var type_name = _id_map.get_robot_type_name(robot_type) if _id_map else "类型:未知"
	return "%s\n类型:%s" % [id_name, type_name]

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
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
	push_warning("[RobotStatus] missing key %s on %s, use default %s" % [key_name, str(src), str(default_val)])
	return default_val
