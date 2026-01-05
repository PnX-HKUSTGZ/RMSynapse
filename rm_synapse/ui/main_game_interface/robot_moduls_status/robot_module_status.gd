extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

const ONLINE_TEX := preload("res://ui/main_game_interface/robot_moduls_status/module_online.svg")
const OFFLINE_TEX := preload("res://ui/main_game_interface/robot_moduls_status/module_offline.svg")

const MODULE_FIELDS := [
	{"field": "power_manager", "node": "PowerManager"},
	{"field": "rfid", "node": "RFID"},
	{"field": "light_strip", "node": "LightStrip"},
	{"field": "small_shooter", "node": "SmallShooter"},
	{"field": "big_shooter", "node": "BigShooter"},
	{"field": "uwb", "node": "UWB"},
	{"field": "armor", "node": "Armor"},
	{"field": "video_transmission", "node": "Video"},
	{"field": "capacitor", "node": "Capacitor"},
	{"field": "main_controller", "node": "MainController"}
]

var _gs: Node = null

func _ready() -> void:
	_set_all(false)
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_module_status_updated"):
			_gs.connect("robot_module_status_updated", Callable(self, "_on_module"))
	else:
		push_warning("[RobotModuleStatus] GameState not found at %s" % str(game_state_path))

func _on_module(value) -> void:
	if value == null:
		return
	for item in MODULE_FIELDS:
		var node_path = item.node
		var on_val = int(_get_val(value, item.field, 0))
		_set_one(node_path, on_val == 1)

func _set_all(online: bool) -> void:
	for item in MODULE_FIELDS:
		_set_one(item.node, online)

func _set_one(node_name: String, online: bool) -> void:
	var tex_rect = _find_icon(node_name)
	var label = _find_label(node_name)
	if tex_rect:
		if online:
			tex_rect.texture = ONLINE_TEX
		else:
			tex_rect.texture = OFFLINE_TEX
	if label:
		if online:
			label.text = "在线 - " + _pretty_name(node_name)
		else:
			label.text = "离线 - " + _pretty_name(node_name)

func _find_icon(node_name: String) -> TextureRect:
	if has_node("VBox/HBox1/" + node_name + "/Icon"):
		return get_node("VBox/HBox1/" + node_name + "/Icon") as TextureRect
	if has_node("VBox/HBox2/" + node_name + "/Icon"):
		return get_node("VBox/HBox2/" + node_name + "/Icon") as TextureRect
	push_warning("[RobotModuleStatus] cannot find icon for %s" % node_name)
	return null

func _find_label(node_name: String) -> RichTextLabel:

	if has_node("VBox/HBox1/" + node_name + "/Name"):
		return get_node("VBox/HBox1/" + node_name + "/Name") as RichTextLabel
	if has_node("VBox/HBox2/" + node_name + "/Name"):
		return get_node("VBox/HBox2/" + node_name + "/Name") as RichTextLabel
	push_warning("[RobotModuleStatus] cannot find label for %s" % node_name)
	return null

func _pretty_name(raw: String) -> String:
	match raw:
		"PowerManager": return "电源管理"
		"RFID": return "RFID"
		"LightStrip": return "灯条"
		"SmallShooter": return "17mm"
		"BigShooter": return "42mm"
		"UWB": return "UWB"
		"Armor": return "装甲"
		"Video": return "图传"
		"Capacitor": return "电容"
		"MainController": return "主控"
		_: return raw

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

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
	push_warning("[RobotModuleStatus] missing key %s, default %s" % [key_name, str(default_val)])
	return default_val
