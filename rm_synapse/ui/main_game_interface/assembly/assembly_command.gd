extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var low_rate_sender_path: NodePath = NodePath("/root/MqttNet/LowRateSender")
@export var toggle_action: String = "p"

@onready var _status: Label = $VBox/Status
@onready var _dropdown: OptionButton = $VBox/RowSelect/Dropdown
@onready var _confirm: Button = $VBox/RowButtons/ConfirmBtn
@onready var _cancel: Button = $VBox/RowButtons/CancelBtn

var _gs: Node = null
var _sender: Node = null
var _max_level: int = 0
var _keycode : int = KEY_NONE
var _prekey_state : bool = false

const STATUS_TEXT := {
	1: "未进入装配",
	2: "已选难度 核心移动中",
	3: "核心到位 可进行装配",
	4: "步骤完成 可进行下一步",
	5: "装配完成",
	6: "已确认装配 核心移动中"
}

func _ready() -> void:

	# 检查 toggle_action
	_keycode = OS.find_keycode_from_string(toggle_action)
	if _keycode == KEY_NONE:
		push_error("[AssemblyCommand] Invalid toggle_action: %s" % toggle_action)

	# 检查节点在不在
	if not _status:
		push_error("[AssemblyCommand] Status Label node not found.")
	if not _dropdown:
		push_error("[AssemblyCommand] Dropdown OptionButton node not found.")
	if not _confirm:
		push_error("[AssemblyCommand] Confirm Button node not found.")
	if not _cancel:
		push_error("[AssemblyCommand] Cancel Button node not found.")

	visible = false
	_gs = get_node_or_null(game_state_path)
	_sender = get_node_or_null(low_rate_sender_path)
	if _gs and _gs.has_signal("tech_core_motion_state_sync_updated"):
		_gs.connect("tech_core_motion_state_sync_updated", Callable(self, "_on_motion_state"))
	_confirm.pressed.connect(_on_confirm_pressed)
	_cancel.pressed.connect(_on_cancel_pressed)
	_update_status(0)

func _process(_d):
	# 只有当按下的时候才切换
	var curr_key_state : bool = Input.is_key_pressed(_keycode)
	if curr_key_state != _prekey_state and curr_key_state == true:
		print("111")
		visible = not visible
	_prekey_state = curr_key_state

func _on_motion_state(value) -> void:
	if value == null:
		_update_status(0)
		visible = false
		return
	_max_level = int(_getv(value, "maximum_difficulty_level", 0))
	_fill_dropdown()
	var st = int(_getv(value, "status", 0))
	_update_status(st)
	visible = st in [2,3,4,5]

func _update_status(st: int) -> void:
	_status.text = "状态: %s" % STATUS_TEXT.get(st, "未知")

func _fill_dropdown() -> void:
	_dropdown.clear()
	if _max_level <= 0:
		_dropdown.add_item("无可选难度", 0)
		_dropdown.disabled = true
		return
	_dropdown.disabled = false
	for level in range(1, _max_level + 1):
		_dropdown.add_item("装配难度 %d" % level, level)
	_dropdown.select(0)

func _on_confirm_pressed() -> void:
	_send_cmd(1)

func _on_cancel_pressed() -> void:
	_send_cmd(2)

func _send_cmd(op: int) -> void:
	if _sender and _sender.has_method("set_assembly_command"):
		var diff = _dropdown.get_selected_id()
		_sender.set_assembly_command(op, diff)
	else:
		push_warning("[AssemblyCommand] LowRateSender not found or missing set_assembly_command")

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
