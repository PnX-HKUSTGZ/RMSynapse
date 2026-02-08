# 脱战倒计时专属Label脚本：直接挂在OutOfCombat/OutOfCombatCnt Label/RichTextLabel节点上
extends Label

# 编辑器可视化配置（检查器直接改，无需动代码）
@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var target_robot_id: int = -1
@export var countdown_text_format: String = "脱战倒计时：%ds"

# 私有状态变量（脱战核心逻辑，与原代码一致）
var _gs: Node = null
var _is_out_of_combat: bool = false
var _ooc_countdown: int = 0

func _ready():
	"""节点就绪：初始化+连接GameState信号"""
	_reset_ooc_state()
	_gs = _resolve_game_state()
	if _gs and _gs.has_signal("robot_dynamic_status_updated"):
		_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_robot_dynamic_updated"))
	else:
		push_warning("[OutOfCombatLabel] GameState未找到或无对应信号，路径：%s" % str(game_state_path))

func _reset_ooc_state():
	"""重置脱战状态：初始隐藏+清空文本"""
	_is_out_of_combat = false
	_ooc_countdown = 0
	self.text = ""
	self.visible = false

func _on_robot_dynamic_updated(value):
	"""GameState动态信号回调：解析脱战数据"""
	var robot_entry = _pick_target_robot_entry(value)
	if robot_entry == null:
		return

	# 读取脱战核心字段（与原代码字段完全一致，兼容现有工程）
	_is_out_of_combat = _get_val(robot_entry, "is_out_of_combat", _is_out_of_combat)
	_ooc_countdown = int(_get_val(robot_entry, "out_of_combat_countdown", _ooc_countdown))

	# 更新标签显隐和文本
	_update_label_display()

func _update_label_display():
	"""核心显示逻辑：战斗中显示倒计时，脱战隐藏（与原代码完全一致）"""
	self.visible = not _is_out_of_combat
	if not _is_out_of_combat:
		self.text = countdown_text_format % _ooc_countdown
	else:
		self.text = ""

func _pick_target_robot_entry(data):
	"""筛选目标机器人条目（复用原代码的ID筛选/数据兼容逻辑）"""
	if data == null:
		return null
	if typeof(data) == TYPE_DICTIONARY:
		if target_robot_id != -1 and data.has(target_robot_id):
			return data[target_robot_id]
		if _is_target_robot(data):
			return data
		for val in data.values():
			if _is_target_robot(val):
				return val
	elif typeof(data) == TYPE_ARRAY:
		for val in data:
			if _is_target_robot(val):
				return val
	else:
		if _is_target_robot(data):
			return data
	return null

func _is_target_robot(entry):
	"""判断是否为目标机器人（原代码_maybe_match逻辑）"""
	if target_robot_id == -1:
		return true
	var robot_id = _get_val(entry, "robot_id", -1)
	return robot_id == target_robot_id

func _get_val(src, key_name: String, default_val):
	"""安全获取值（复用原代码逻辑，容错处理）"""
	if src == null:
		return default_val
	if typeof(src) == TYPE_DICTIONARY and src.has(key_name):
		return src.get(key_name, default_val)
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val

func _resolve_game_state():
	"""获取GameState节点（兼容路径+单例，与原代码一致）"""
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null
