extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var low_rate_sender_path: NodePath = NodePath("/root/MqttNet/LowRateSender")

@onready var _status: RichTextLabel = $CoreStatusShow
var _sender: Node = null
var _active := false

const STATUS_TEXT := {
	1: "未进入装配",
	2: "难度选择完成，核心移动中",
	3: "核心到位，可装配",
	4: "当前步骤完成，可进行下一步",
	5: "装配全部完成",
	6: "已确认装配，核心移动中"
}

func _ready() -> void:
	_set_visible(false)
	var gs = get_node_or_null(game_state_path)
	_sender = get_node_or_null(low_rate_sender_path)
	if gs and gs.has_signal("tech_core_motion_state_sync_updated"):
		gs.connect("tech_core_motion_state_sync_updated", Callable(self, "_on_state"))
	else:
		push_error("[AssemblyProgress] GameState node not found or missing signal.")

func _process(_delta: float) -> void:
	if not _active:
		return
	if InputMap.has_action("ui_cancel") and Input.is_action_just_pressed("ui_cancel"):
		_send_cancel()
	elif Input.is_key_pressed(KEY_ESCAPE): # 兜底
		_send_cancel()

func _on_state(value) -> void:
	if value == null:
		_set_visible(false)
		return
	var st = int(_getv(value, "status", 0))
	_active = st in STATUS_TEXT.keys()
	_set_visible(_active)
	if _status:
		_status.text = STATUS_TEXT.get(st, "未知")

func _set_visible(flag: bool) -> void:
	visible = flag

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

func _send_cancel() -> void:
	if _sender and _sender.has_method("set_assembly_command"):
		_sender.set_assembly_command(2, 0) # 2=取消装配
	else:
		push_warning("[AssemblyProgress] LowRateSender not found or missing set_assembly_command")
