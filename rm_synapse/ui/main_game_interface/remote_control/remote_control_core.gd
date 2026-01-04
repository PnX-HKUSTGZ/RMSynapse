extends Control
class_name RemoteControlCore

const DEFAULT_BINDINGS := {
	"w": 0, "a": 1, "s": 2, "d": 3,
	"shift": 4, "ctrl": 5, "space": 6,
	"q": 7, "e": 8, "r": 9, "f": 10,
	"1": 11, "2": 12, "3": 13, "4": 14, "5": 15, "6": 16, "7": 17,
	"z": 18, "x": 19, "c": 20
}

@export var remote_control_path: NodePath = NodePath("/root/MqttNet/RemoteControlSender")
@export var mouse_sensitivity: float = 1.0
@export var invert_y: bool = false
@export var auto_capture_input: bool = true
@export var _binding_map: Dictionary = DEFAULT_BINDINGS

const MAX_BITS := 32

var _rc: RemoteControlService
var _wheel_delta := 0
var _last_frame: Dictionary = {}

func _ready() -> void:
	_rc = _resolve_rc()
	_binding_map = DEFAULT_BINDINGS.duplicate()
	set_process(true)
	set_process_unhandled_input(true)

func _process(_delta: float) -> void:
	if _rc == null or not auto_capture_input:
		return
	var frame = _capture_frame()
	_last_frame = frame
	_update_display(frame)
	_send_frame(frame)

func _unhandled_input(event: InputEvent) -> void:
	if not auto_capture_input:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel_delta += 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_delta -= 1

func _capture_frame() -> Dictionary:
	var v := Input.get_last_mouse_velocity()
	var dx := int(round(v.x * mouse_sensitivity))
	var dy := int(round(v.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)))
	var dz := _wheel_delta
	_wheel_delta = 0
	var mask = _build_mask()
	var btn_l = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var btn_r = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var btn_m = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	return {
		"dx": dx, "dy": dy, "dz": dz,
		"mask": mask,
		"l": btn_l, "r": btn_r, "m": btn_m
	}

func _build_mask() -> int:
	var m := 0
	for action in _binding_map.keys():
		var bit: int = int(_binding_map[action])
		if bit < 0 or bit >= MAX_BITS:
			push_warning("bind action '%s' to invalid bit %d" % [action, bit])
			continue
		if _action_pressed(action):
			m |= 1 << bit
	return m

func _action_pressed(action: String) -> bool:
	var lower = action.to_lower()
	var keycode = OS.find_keycode_from_string(lower)
	if keycode == 0:
		keycode = OS.find_keycode_from_string(lower.to_upper())
	if keycode == 0:
		return false
	return Input.is_key_pressed(keycode)

func is_action_pressed(action: String) -> bool:
	return _action_pressed(action)

func _update_display(frame) -> void:
	# 鼠标指示器
	_update_mouse_indicator(frame.dx, frame.dy, frame.dz, frame.l, frame.r, frame.m)
	# 按键指示
	_update_input_indicator()
	_update_capture_indicator()

func _update_input_indicator() -> void:
	var input_indicator : Label = get_node("InputLabelShow") as Label
	if not input_indicator:
		push_error("InputLabelShow 节点未找到，无法更新显示。")
		return
	# 水平靠左，垂直居中由控件属性控制
	input_indicator.text = _current_input_text()

func _update_capture_indicator() -> void:
	var capture_indicator : Label = get_node("CaptureLabelShow") as Label
	if not capture_indicator:
		push_error("CaptureLabelShow 节点未找到，无法更新显示。")
		return
	# 水平靠左，垂直居中由控件属性控制
	capture_indicator.text = _current_actions_text()
	

func _update_mouse_indicator(dx : int, dy : int, dz : int, l : bool, r : bool, m : bool) -> void:
	var mouse_indicator : Node
	var mouse_left_arrow : TextureRect
	var mouse_right_arrow : TextureRect
	var mouse_up_arrow : TextureRect
	var mouse_down_arrow : TextureRect
	var middle_up_arrow : TextureRect
	var middle_down_arrow : TextureRect
	var mouse_left_indicator : ColorRect
	var mouse_right_indicator : ColorRect
	var mouse_middle_indicator : ColorRect

	# 获取节点
	mouse_indicator = get_node("MouseIndicator")
	if not mouse_indicator:
		push_error("MouseIndicator 节点未找到，无法更新显示。")
		return
	mouse_left_arrow = mouse_indicator.get_node("mouse_left_arrow")
	mouse_right_arrow = mouse_indicator.get_node("mouse_right_arrow")
	mouse_up_arrow = mouse_indicator.get_node("mouse_up_arrow")
	mouse_down_arrow = mouse_indicator.get_node("mouse_down_arrow")
	middle_up_arrow = mouse_indicator.get_node("middle_up_arrow")
	middle_down_arrow = mouse_indicator.get_node("middle_down_arrow")
	mouse_left_indicator = mouse_indicator.get_node("mouse_left_indicator")
	mouse_right_indicator = mouse_indicator.get_node("mouse_right_indicator")
	mouse_middle_indicator = mouse_indicator.get_node("mouse_middle_indicator")

	if not mouse_left_arrow:
		push_error("mouse_left_arrow 节点未找到，无法更新显示。")
		return
	if not mouse_right_arrow:
		push_error("mouse_right_arrow 节点未找到，无法更新显示。")
		return
	if not mouse_up_arrow:
		push_error("mouse_up_arrow 节点未找到，无法更新显示。")
		return
	if not mouse_down_arrow:
		push_error("mouse_down_arrow 节点未找到，无法更新显示。")
		return
	if not middle_up_arrow:
		push_error("middle_up_arrow 节点未找到，无法更新显示。")
		return
	if not middle_down_arrow:
		push_error("middle_down_arrow 节点未找到，无法更新显示。")
		return
	if not mouse_left_indicator:
		push_error("mouse_left_indicator 节点未找到，无法更新显示。")
		return
	if not mouse_right_indicator:
		push_error("mouse_right_indicator 节点未找到，无法更新显示。")
		return
	if not mouse_middle_indicator:
		push_error("mouse_middle_indicator 节点未找到，无法更新显示。")
		return

	# dx
	if dx < 0:
		mouse_left_arrow.visible = true
		mouse_right_arrow.visible = false
	elif dx > 0:
		mouse_left_arrow.visible = false
		mouse_right_arrow.visible = true
	else:
		mouse_left_arrow.visible = false
		mouse_right_arrow.visible = false
	# dy
	if dy < 0:
		mouse_up_arrow.visible = true
		mouse_down_arrow.visible = false
	elif dy > 0:
		mouse_up_arrow.visible = false
		mouse_down_arrow.visible = true
	else:
		mouse_up_arrow.visible = false
		mouse_down_arrow.visible = false
	# dz
	if dz < 0:
		middle_up_arrow.visible = false
		middle_down_arrow.visible = true
	elif dz > 0:
		middle_up_arrow.visible = true
		middle_down_arrow.visible = false
	else:
		middle_up_arrow.visible = false
		middle_down_arrow.visible = false
	# buttons
	mouse_left_indicator.color = Color(0.1,0.6,0.9,0.6) if l else Color(0.4,0.4,0.4,0.4)
	mouse_right_indicator.color = Color(0.1,0.6,0.9,0.6) if r else Color(0.4,0.4,0.4,0.4)
	mouse_middle_indicator.color = Color(0.1,0.6,0.9,0.6) if m else Color(0.4,0.4,0.4,0.4)

func _current_actions_text() -> String:
	var arr: Array = []
	for action in _binding_map.keys():
		if _action_pressed(action):
			arr.append(action)
	return ",".join(arr)

func _current_input_text() -> String:
	var keys: Array = []
	# 字母 a-z
	for i in range(KEY_A, KEY_Z + 1):
		if Input.is_key_pressed(i):
			keys.append(char(i).to_lower())
	# 数字 0-9
	for i in range(KEY_0, KEY_9 + 1):
		if Input.is_key_pressed(i):
			keys.append(char(i))
	# 功能键 F1-F12
	for i in range(KEY_F1, KEY_F12 + 1):
		if Input.is_key_pressed(i):
			keys.append("f%d" % (i - KEY_F1 + 1))
	# 修饰键
	if Input.is_key_pressed(KEY_SHIFT):
		keys.append("shift")
	if Input.is_key_pressed(KEY_CTRL):
		keys.append("ctrl")
	if Input.is_key_pressed(KEY_ALT):
		keys.append("alt")
	if Input.is_key_pressed(KEY_META):
		keys.append("meta")
	if Input.is_key_pressed(KEY_CAPSLOCK):
		keys.append("capslock")
	if Input.is_key_pressed(KEY_TAB):
		keys.append("tab")
	# 特殊键
	if Input.is_key_pressed(KEY_SPACE):
		keys.append("space")
	if Input.is_key_pressed(KEY_ENTER):
		keys.append("enter")
	if Input.is_key_pressed(KEY_ESCAPE):
		keys.append("esc")
	if Input.is_key_pressed(KEY_BACKSPACE):
		keys.append("backspace")
	if Input.is_key_pressed(KEY_DELETE):
		keys.append("del")
	if Input.is_key_pressed(KEY_INSERT):
		keys.append("insert")
	if Input.is_key_pressed(KEY_HOME):
		keys.append("home")
	if Input.is_key_pressed(KEY_END):
		keys.append("end")
	if Input.is_key_pressed(KEY_PAGEUP):
		keys.append("pageup")
	if Input.is_key_pressed(KEY_PAGEDOWN):
		keys.append("pagedown")
	# 方向键
	if Input.is_key_pressed(KEY_UP):
		keys.append("↑")
	if Input.is_key_pressed(KEY_DOWN):
		keys.append("↓")
	if Input.is_key_pressed(KEY_LEFT):
		keys.append("←")
	if Input.is_key_pressed(KEY_RIGHT):
		keys.append("→")
	# 符号键
	if Input.is_key_pressed(KEY_MINUS):
		keys.append("-")
	if Input.is_key_pressed(KEY_EQUAL):
		keys.append("=")
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		keys.append("[")
	if Input.is_key_pressed(KEY_BRACKETRIGHT):
		keys.append("]")
	if Input.is_key_pressed(KEY_BACKSLASH):
		keys.append("\\")
	if Input.is_key_pressed(KEY_SEMICOLON):
		keys.append(";")
	if Input.is_key_pressed(KEY_APOSTROPHE):
		keys.append("'")
	if Input.is_key_pressed(KEY_COMMA):
		keys.append(",")
	if Input.is_key_pressed(KEY_PERIOD):
		keys.append(".")
	if Input.is_key_pressed(KEY_SLASH):
		keys.append("/")
	if Input.is_key_pressed(KEY_QUOTELEFT):
		keys.append("`")

	return ",".join(keys)

func _send_frame(frame: Dictionary) -> void:
	_rc.update_mouse(frame.dx, frame.dy, frame.dz)
	_rc.set_buttons(frame.l, frame.r, frame.m)
	_rc.set_keyboard_mask(frame.mask)

func get_last_frame() -> Dictionary:
	return _last_frame.duplicate()

func current_pressed_string() -> String:
	return _current_actions_text()

func set_sensitivity(v: float) -> void:
	mouse_sensitivity = max(v, 0.01)
	print("Set mouse_sensitivity to %f" % mouse_sensitivity)

func set_invert_y(flag: bool) -> void:
	print("Set invert_y to %s" % flag)
	invert_y = flag

func set_binding(bit: int, action: String) -> void:
	if bit < 0 or bit >= MAX_BITS:
		push_warning("try to set binding to invalid bit %d" % bit)
		return
	for key in _binding_map.keys():
		if int(_binding_map[key]) == bit:
			_binding_map.erase(key)

	# 检查绑定是否存在对应按键
	if action == "" or action == "none":
		return
	var lower = action.to_lower()
	var keycode = OS.find_keycode_from_string(lower)
	if keycode == 0:
		keycode = OS.find_keycode_from_string(lower.to_upper())
	if keycode == 0:
		push_warning("action '%s' is not a valid key name, binding ignored" % action)
		return

	_binding_map[action] = bit
	print("Set binding: %s -> %d" % [action, bit])

func reset_bindings() -> void:
	_binding_map = DEFAULT_BINDINGS.duplicate()

func bindings_preview() -> String:
	var pairs := []
	for key in _binding_map.keys():
		pairs.append("%s->%d" % [key, int(_binding_map[key])])
	pairs.sort()
	return ", ".join(pairs)

func action_for_bit(bit: int) -> String:
	for key in _binding_map.keys():
		if int(_binding_map[key]) == bit:
			return key
	return "none"

func _resolve_rc() -> RemoteControlService:
	if remote_control_path != NodePath("") and has_node(remote_control_path):
		return get_node(remote_control_path) as RemoteControlService
	if Engine.has_singleton("MqttNet") and Engine.get_singleton("MqttNet").has_node("RemoteControlSender"):
		return Engine.get_singleton("MqttNet").get_node("RemoteControlSender") as RemoteControlService
	push_error("RemoteControlService 未找到，请检查路径或场景挂载。") 
	return null
