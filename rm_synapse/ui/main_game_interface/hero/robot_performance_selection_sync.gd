extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var low_rate_sender_path: NodePath = NodePath("/root/MqttNet/LowRateSender")
@export var toggle_action: String = "h"
@onready var select_robot: OptionButton = $ColorRect/VBoxContainer/OptionButton
@onready var select_per: OptionButton = $ColorRect/VBoxContainer/OptionButton2
@onready var tongbu: Label = $ColorRect/Label4     
@onready var _confirm: Button = $ColorRect/Button
@onready var _cancel: Button = $ColorRect/Button2
@onready var select_sync: Label = $CanvasLayer/ColorRect2/Label

var _gs: Node = null
var _sender: Node = null
var _keycode : int = KEY_NONE
var _prekey_state : bool = false
var show_tongbu : bool = false

func _ready() -> void:
	select_robot.item_selected.connect(_on_option_button_item_selected)
	select_per.item_selected.connect(_update_label_text)
	
	select_per.clear()
	select_per.add_item("请先选择机器人", 0)
	select_per.disabled = true
	
	_update_label_text()
	tongbu.visible = show_tongbu
	
	visible = false
	_gs = get_node_or_null(game_state_path)
	if _gs:
		if _gs.has_signal("robot_performance_selection_sync_updated"):
			_gs.connect("robot_performance_selection_sync_updated", Callable(self, "_on_updated"))
	else:
		push_warning("[RobotPerformance] GameState not found at %s" % str(game_state_path))
		
	_sender = get_node_or_null(low_rate_sender_path)
	_confirm.pressed.connect(_on_confirm_pressed)
	_cancel.pressed.connect(_on_cancel_pressed)
	
	_keycode = OS.find_keycode_from_string(toggle_action)
	if _keycode == KEY_NONE:
		_keycode = KEY_H
		push_warning("快捷键解析失败，默认使用H键")

# 核心修复1：机器人选完后，强制触发Label更新
func _on_option_button_item_selected(index: int) -> void:
	select_per.clear()
	match index:
		-1:
			select_per.add_item("请先选择机器人", 0)
			select_per.disabled = true
		0:
			select_per.add_item("近战优先", 0)
			select_per.add_item("远程优先", 1)
			select_per.disabled = false
		1:
			select_per.add_item("功率优先", 0)
			select_per.add_item("血量优先", 1)
			select_per.add_item("爆发优先", 2)
			select_per.add_item("冷却优先", 3)
			select_per.disabled = false
		_:
			select_per.add_item("无对应策略", 0)
			select_per.disabled = true
	select_per.select(0)
	_update_label_text()  # 强制触发Label更新，确保默认选项文本显示

# 核心修复2：优化容错，确保文本正确获取
func _update_label_text() -> void:
	var robot_selected_idx = select_robot.selected if select_robot else -1
	var per_selected_idx = select_per.selected if select_per else -1
	
	# 容错处理：防止索引越界
	var robot_text = "未选择机器人"
	var per_text = "未选择策略"
	if robot_selected_idx != -1 and robot_selected_idx < select_robot.get_item_count():
		robot_text = select_robot.get_item_text(robot_selected_idx)
	if per_selected_idx != -1 and per_selected_idx < select_per.get_item_count():
		per_text = select_per.get_item_text(per_selected_idx)
	
	tongbu.text = "选择：%s | %s" % [robot_text, per_text]
	
	tongbu.visible = show_tongbu

func _process(delta: float) -> void:
	var curr_key_state = Input.is_key_pressed(KEY_H)
	if curr_key_state and not _prekey_state:
		visible = not visible
		print("性能选择UI显隐切换：", visible)
	_prekey_state = curr_key_state

# 核心修复3：按钮点击后，强制刷新Label文本
func _on_confirm_pressed() -> void:
	_send_cmd(1)
	show_tongbu=true
	_update_label_text()  # 确保文本是最新的
	tongbu.visible = show_tongbu

func _on_cancel_pressed() -> void:
	_send_cmd(2)
	show_tongbu=false
	select_robot.select(-1)
	select_per.select(-1)
	_update_label_text()  # 确保文本是最新的
	tongbu.visible = show_tongbu

func _on_updated(value) -> void:
	var robot_text = value.get_shooter()
	var per_text = value.get_chassis()
	select_sync.text = "当前状态：%s | %s" % [robot_text, per_text]
	
func _send_cmd(op: int) -> void:
	if _sender and _sender.has_method("set_robot_performance_selection"):
		var diff = select_per.get_selected_id()
		_sender.set_robot_performance_selection(op, diff)
	else:
		push_warning("[RobotPerformance] LowRateSender not found or missing set_robot_performance_selection")

func _getv(src, key, def):
	if src == null:
		return def
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key, def)
	if src.has_method("get_" + key):
		return src.call("get_" + key)
	if src.has_method("has") and src.has(key):
		return src.get(key)
	return def
