extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var display_duration: float = 2.0

var _queue: Array = []
var _timer: float = 0.0
var _current: Dictionary = {}
var _gs: Node = null

@onready var _label: RichTextLabel = $EventLabel
@onready var _bg: ColorRect = $Background

const EVENT_NAME := {
	1: "击杀事件",
	2: "基地/前哨被摧毁",
	3: "能量机关可激活次数变化",
	4: "能量机关进入可激活状态",
	5: "当前能量机关激活次数灯亮数量变化",
	6: "能量机关被激活",
	7: "己方英雄进入部署模式",
	8: "己方英雄造成狙击伤害",
	9: "对方英雄造成狙击伤害",
	10: "己方四级空中支援",
	11: "己方空中支援被打断",
	12: "对方四级空中支援",
	13: "对方空中支援被打断",
	14: "飞镖命中",
	15: "双方飞镖门开启",
	16: "己方基地遭到攻击",
	17: "双方前哨站转移",
	18: "双方基地护甲展开"
}

func _ready() -> void:
	if _label:
		_label.text = ""
	_gs = _resolve_game_state()
	if _gs and _gs.has_signal("event_received"):
		_gs.connect("event_received", Callable(self, "_on_event_received"))
	else:
		push_warning("[GameEvent] GameState not found or no event_received signal.")

func _process(delta: float) -> void:
	if _current.is_empty():
		if _queue.size() > 0:
			_current = _queue.pop_front()
			_timer = display_duration
			_label.text = _current.get("text", "")
			if _bg:
				_bg.visible = true
	else:
		_timer -= delta
		if _timer <= 0.0:
			_current.clear()
			_label.text = ""
			if _bg:
				_bg.visible = false

func _on_event_received(value) -> void:
	var text = _format_event(value)
	_queue.append({"text": text})

func _format_event(ev) -> String:
	var id = _get_val(ev, "event_id", -1)
	var param = _get_val(ev, "param", "")
	var event_name = EVENT_NAME.get(id, "事件")
	if param != "" and param != null:
		return "%s: %s" % [event_name, param]
	else:
		return "%s" % event_name

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_"+key_name):
		return src.call("get_"+key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null
