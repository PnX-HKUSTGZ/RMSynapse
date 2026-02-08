extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var target_robot_id: int = -1

@onready var _bar: ProgressBar = $Bar
@onready var _label: RichTextLabel = $Label

var _gs: Node = null
var _max_val: int = 0
var _cur_val: int = 0

func _ready() -> void:
	_reset()
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_static_status_updated"):
			_gs.connect("robot_static_status_updated", Callable(self, "_on_static"))
		if _gs.has_signal("robot_dynamic_status_updated"):
			_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic"))
	else:
		push_warning("[ChassisEnergy] GameState not found at %s" % str(game_state_path))

func _reset() -> void:
	_max_val = 0
	_cur_val = 0
	if _bar:
		_bar.max_value = 1
		_bar.value = 0
	if _label:
		_label.text = "底盘: --/--"

func _on_static(value) -> void:
	var entry = _pick_entry(value)
	if entry:
		_max_val = int(_get_val(entry, "max_chassis_energy", _max_val))
		_apply()

func _on_dynamic(value) -> void:
	var entry = _pick_entry(value)
	if entry:
		_cur_val = int(_get_val(entry, "current_chassis_energy", _cur_val))
		_apply()

func _apply() -> void:
	if _label:
		_label.text = "底盘: %d/%d" % [_cur_val, _max_val]

	if _bar:
		var safe_max = max(1, _max_val)
		_bar.max_value = safe_max
		_bar.value = clamp(_cur_val, 0, safe_max)

		# --- 颜色动态变化逻辑 ---
		
		# 1. 计算当前能量百分比 (0.0 到 1.0)
		var percent = float(_cur_val) / float(safe_max)
		
		# 2. 获取或创建样式盒
		var fill_style: StyleBoxFlat
		if _bar.has_theme_stylebox_override("fill"):
			fill_style = _bar.get_theme_stylebox("fill")
		else:
			fill_style = StyleBoxFlat.new()
			_bar.add_theme_stylebox_override("fill", fill_style)
		
		# 3. 形状设置：保持直角 (直切风格)
		fill_style.set_corner_radius_all(0)
		
		# 4. 颜色混合：从蓝到红
		# 定义两端的颜色
		var low_color = Color(0.2, 0.6, 1)    # 低能量：科幻蓝
		var high_color = Color(1, 0.25, 0.25) # 高能量：过载红
		
		# 使用 lerp 进行混合：percent 越接近 0 越蓝，越接近 1 越红
		fill_style.bg_color = low_color.lerp(high_color, percent)
		
		# 5. 添加动态发光 (光晕颜色跟随主颜色)
		fill_style.shadow_color = fill_style.bg_color
		fill_style.shadow_size = 3

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _pick_entry(data):
	if data == null:
		return null
	if typeof(data) == TYPE_DICTIONARY:
		if target_robot_id != -1 and data.has(target_robot_id):
			return data[target_robot_id]
		if _maybe_match(data):
			return data
		for v in data.values():
			if _maybe_match(v):
				return v
		return null
	if typeof(data) == TYPE_ARRAY:
		for v in data:
			if _maybe_match(v):
				return v
		return null
	if _maybe_match(data):
		return data
	return null

func _maybe_match(entry) -> bool:
	if target_robot_id == -1:
		return true
	var rid = _get_val(entry, "robot_id", -1)
	return rid == target_robot_id

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		if src.has(key_name):
			return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	push_warning("[ChassisEnergy] missing key %s on %s, default %s" % [key_name, str(src), str(default_val)])
	return default_val
