extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _buff_label: Label = $CenterInfo/BuffLabel
@onready var _deploy_label: Label = $CenterInfo/DeployLabel
@onready var _rune_label: Label = $CenterInfo/RuneLabel
@onready var _core_label: Label = $CenterInfo/CoreLabel
@onready var _fire_rate: Label = $RightPanel/Margin/RightVBox/FireRate
@onready var _ammo: Label = $RightPanel/Margin/RightVBox/Ammo

var _gs: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): queue_redraw())
	_gs = _resolve_game_state()
	if _gs == null:
		return

	_connect_if_exists("robot_dynamic_status_updated", "_on_dynamic")
	_connect_if_exists("buff_updated", "_on_buff")
	_connect_if_exists("deploy_mode_status_sync_updated", "_on_deploy")
	_connect_if_exists("rune_status_sync_updated", "_on_rune")
	_connect_if_exists("tech_core_motion_state_sync_updated", "_on_core")

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var ring_color: Color = Color(1, 1, 1, 0.16)
	var line_color: Color = Color(1, 1, 1, 0.26)
	draw_arc(c, 54.0, 0.0, TAU, 64, ring_color, 3.0)
	draw_line(c + Vector2(-8, 0), c + Vector2(-20, 0), line_color, 2.0)
	draw_line(c + Vector2(8, 0), c + Vector2(20, 0), line_color, 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, -20), line_color, 2.0)
	draw_line(c + Vector2(0, 8), c + Vector2(0, 20), line_color, 2.0)
	# 两侧半圆弧，接近参考图视觉。
	draw_arc(c, 280.0, PI * 0.18, PI * 0.82, 48, Color(1, 1, 1, 0.08), 2.0)
	draw_arc(c, 280.0, PI * 1.18, PI * 1.82, 48, Color(1, 1, 1, 0.08), 2.0)

func _resolve_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if has_node(game_state_path):
		return get_node(game_state_path)
	push_warning("[CenterReticle] GameState not found at %s" % str(game_state_path))
	return null

func _connect_if_exists(signal_name: String, method_name: String) -> void:
	if _gs.has_signal(signal_name):
		_gs.connect(signal_name, Callable(self, method_name))

func _on_dynamic(msg) -> void:
	var fire_rate = _get_f(msg, "get_last_projectile_fire_rate", 0.0)
	var ammo = _get_i(msg, "get_remaining_ammo", 0)
	_fire_rate.text = "射击初速度: %.2f" % fire_rate
	_ammo.text = "允许发弹量: %d" % ammo

func _on_buff(msg) -> void:
	var bt: int = _get_i(msg, "get_buff_type", 0)
	var lv: int = _get_i(msg, "get_buff_level", 0)
	var left: int = _get_i(msg, "get_buff_left_time", 0)
	if bt == 0:
		_buff_label.text = "Buff: --"
	else:
		_buff_label.text = "Buff: 类型 %d 级别 %d 剩余 %ds" % [bt, lv, left]

func _on_deploy(msg) -> void:
	var s: int = _get_i(msg, "get_status", 0)
	_deploy_label.text = "部署: %s" % ("已部署" if s == 1 else "未部署")

func _on_rune(msg) -> void:
	var status: int = _get_i(msg, "get_rune_status", 0)
	var arms: int = _get_i(msg, "get_activated_arms", 0)
	var rings: int = _get_i(msg, "get_average_rings", 0)
	_rune_label.text = "能量机关: 状态 %d | 臂 %d | 环 %d" % [status, arms, rings]

func _on_core(msg) -> void:
	var max_lv: int = _get_i(msg, "get_maximum_difficulty_level", 0)
	var status: int = _get_i(msg, "get_status", 0)
	_core_label.text = "科技核心: 状态 %d | 最高难度 %d" % [status, max_lv]

func _get_i(msg, method_name: String, default_val: int) -> int:
	if msg != null and msg.has_method(method_name):
		return int(msg.call(method_name))
	return default_val

func _get_f(msg, method_name: String, default_val: float) -> float:
	if msg != null and msg.has_method(method_name):
		return float(msg.call(method_name))
	return default_val
