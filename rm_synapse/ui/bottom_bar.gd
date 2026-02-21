extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _hp_label: Label = $Panel/Margin/VBox/MainRow/Stats/HPLabel
@onready var _hp_bar: ProgressBar = $Panel/Margin/VBox/MainRow/Stats/HPBar
@onready var _chassis_label: Label = $Panel/Margin/VBox/MainRow/Stats/EnergyRow/ChassisLabel
@onready var _buffer_label: Label = $Panel/Margin/VBox/MainRow/Stats/EnergyRow/BufferLabel
@onready var _status_label: Label = $Panel/Margin/VBox/MainRow/Stats/StatusLabel
@onready var _fire_rate_label: Label = $Panel/Margin/VBox/MainRow/DebugRight/FireRateLabel
@onready var _ammo_label: Label = $Panel/Margin/VBox/MainRow/DebugRight/AmmoLabel
@onready var _exp_label: Label = $Panel/Margin/VBox/MainRow/DebugRight/ExpLabel
@onready var _perf_label: Label = $Panel/Margin/VBox/MainRow/DebugRight/PerfLabel
@onready var _static_label: Label = $Panel/Margin/VBox/DebugRow/StaticLabel
@onready var _module_label: Label = $Panel/Margin/VBox/DebugRow/ModuleLabel
@onready var _key_label: Label = $Panel/Margin/VBox/DebugRow/KeyLabel

var _gs: Node = null
var _max_hp: int = 100

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gs = _resolve_game_state()
	if _gs == null:
		return

	_connect_if_exists("robot_dynamic_status_updated", "_on_dynamic")
	_connect_if_exists("robot_static_status_updated", "_on_static")
	_connect_if_exists("robot_module_status_updated", "_on_module")
	_connect_if_exists("robot_performance_selection_sync_updated", "_on_perf")

	var dynamic = _read_cached("robot_dynamic_status")
	if dynamic != null:
		_on_dynamic(dynamic)
	var st = _read_cached("robot_static_status")
	if st != null:
		_on_static(st)
	var md = _read_cached("robot_module_status")
	if md != null:
		_on_module(md)
	var pf = _read_cached("robot_performance_selection_sync")
	if pf != null:
		_on_perf(pf)

func _process(_delta: float) -> void:
	_key_label.text = "按键: %s" % _current_pressed_keys()

func _resolve_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if has_node(game_state_path):
		return get_node(game_state_path)
	push_warning("[BottomBar] GameState not found at %s" % str(game_state_path))
	return null

func _connect_if_exists(signal_name: String, method_name: String) -> void:
	if _gs.has_signal(signal_name):
		_gs.connect(signal_name, Callable(self, method_name))

func _read_cached(key: String):
	if _gs.has_method("get_value"):
		return _gs.call("get_value", key, null)
	return _gs.get(key)

func _on_dynamic(msg) -> void:
	var hp: int = _get_i(msg, "get_current_health", 0)
	var heat: float = _get_f(msg, "get_current_heat", 0.0)
	var fire_rate: float = _get_f(msg, "get_last_projectile_fire_rate", 0.0)
	var ch_energy: int = _get_i(msg, "get_current_chassis_energy", 0)
	var buf_energy: int = _get_i(msg, "get_current_buffer_energy", 0)
	var exp_cur: int = _get_i(msg, "get_current_experience", 0)
	var exp_need: int = _get_i(msg, "get_experience_for_upgrade", 0)
	var ammo: int = _get_i(msg, "get_remaining_ammo", 0)
	var out_combat: bool = _get_b(msg, "get_is_out_of_combat", false)
	var out_count: int = _get_i(msg, "get_out_of_combat_countdown", 0)
	var can_heal: bool = _get_b(msg, "get_can_remote_heal", false)
	var can_ammo: bool = _get_b(msg, "get_can_remote_ammo", false)

	_hp_label.text = "HP: %d / %d | 热量: %.1f" % [hp, _max_hp, heat]
	_hp_bar.max_value = max(1.0, float(_max_hp))
	_hp_bar.value = clampf(float(hp), 0.0, float(_max_hp))
	_chassis_label.text = "底盘:%d" % ch_energy
	_buffer_label.text = "缓冲:%d" % buf_energy
	_status_label.text = "脱战: %s(%ds) | 远程补血: %s | 远程补弹: %s" % [
		"是" if out_combat else "否",
		out_count,
		"是" if can_heal else "否",
		"是" if can_ammo else "否"
	]
	_fire_rate_label.text = "射速: %.2f" % fire_rate
	_ammo_label.text = "允许发弹量: %d" % ammo
	_exp_label.text = "经验: %d/%d" % [exp_cur, exp_need]

func _on_static(msg) -> void:
	var robot_id: int = _get_i(msg, "get_robot_id", 0)
	var robot_type: int = _get_i(msg, "get_robot_type", 0)
	var level: int = _get_i(msg, "get_level", 0)
	var conn: int = _get_i(msg, "get_connection_state", 0)
	var field_state: int = _get_i(msg, "get_field_state", 0)
	_max_hp = max(1, _get_i(msg, "get_max_health", _max_hp))
	_static_label.text = "机器人: ID %d | 类型 %d | 等级 %d | 连接 %s | 上场 %s" % [
		robot_id,
		robot_type,
		level,
		"已连接" if conn == 1 else "未连接",
		"是" if field_state == 0 else "否"
	]

func _on_module(msg) -> void:
	var rfid: int = _get_i(msg, "get_rfid", 0)
	var shooter: int = _get_i(msg, "get_small_shooter", 0)
	var video: int = _get_i(msg, "get_video_transmission", 0)
	_module_label.text = "模块: RFID %s | 17mm %s | 图传 %s" % [_module_state_name(rfid), _module_state_name(shooter), _module_state_name(video)]

func _on_perf(msg) -> void:
	var shooter: int = _get_i(msg, "get_shooter", 0)
	var chassis: int = _get_i(msg, "get_chassis", 0)
	_perf_label.text = "性能: Shooter %d | Chassis %d" % [shooter, chassis]

func _module_state_name(v: int) -> String:
	match v:
		0:
			return "离线"
		1:
			return "在线"
		2:
			return "异常"
		_:
			return "未知"

func _current_pressed_keys() -> String:
	var keys: Array[String] = []
	var pick: Array = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_Q, KEY_E, KEY_R, KEY_F]
	for k in pick:
		if Input.is_key_pressed(k):
			keys.append(OS.get_keycode_string(k).to_upper())
	if keys.is_empty():
		return "--"
	return ",".join(keys)

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
