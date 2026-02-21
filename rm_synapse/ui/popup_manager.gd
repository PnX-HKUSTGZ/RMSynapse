extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var max_lines: int = 8

@onready var _feed: RichTextLabel = $FeedPanel/FeedMargin/FeedVBox/FeedContent
@onready var _decision_panel: PanelContainer = $DecisionPanel

var _gs: Node = null
var _lines: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	_gs = _resolve_game_state()
	if _gs == null:
		return

	_connect_if_exists("event_received", "_on_event")
	_connect_if_exists("global_special_mechanism_updated", "_on_special")
	_connect_if_exists("robot_injury_stat_updated", "_on_injury")
	_connect_if_exists("robot_respawn_status_updated", "_on_respawn")
	_connect_if_exists("penalty_info_updated", "_on_penalty")
	_connect_if_exists("guard_ctrl_result_updated", "_on_guard_result")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_decision_panel.visible = not _decision_panel.visible

func _resolve_game_state() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	if has_node(game_state_path):
		return get_node(game_state_path)
	push_warning("[PopupManager] GameState not found at %s" % str(game_state_path))
	return null

func _connect_if_exists(signal_name: String, method_name: String) -> void:
	if _gs.has_signal(signal_name):
		_gs.connect(signal_name, Callable(self, method_name))

func _add_feed(text: String) -> void:
	var line: String = "[%s] %s" % [Time.get_time_string_from_system(), text]
	_lines.push_back(line)
	while _lines.size() > max(1, max_lines):
		_lines.pop_front()
	_feed.clear()
	for l in _lines:
		_feed.append_text(l + "\n")

func _on_event(msg) -> void:
	var event_id: int = _get_i(msg, "get_event_id", 0)
	var param: String = _get_s(msg, "get_param", "")
	_add_feed("事件 %d 参数: %s" % [event_id, param])

func _on_special(msg) -> void:
	var ids: Array = _get_arr(msg, "get_mechanism_id")
	var times: Array = _get_arr(msg, "get_mechanism_time_sec")
	_add_feed("特殊机制: id=%s time=%s" % [str(ids), str(times)])

func _on_injury(msg) -> void:
	var total: int = _get_i(msg, "get_total_damage", 0)
	var killer: int = _get_i(msg, "get_killer_id", 0)
	_add_feed("受伤统计: 总伤害 %d, 击杀者 %d" % [total, killer])

func _on_respawn(msg) -> void:
	var pending: bool = _get_b(msg, "get_is_pending_respawn", false)
	var cur: int = _get_i(msg, "get_current_respawn_progress", 0)
	var total: int = _get_i(msg, "get_total_respawn_progress", 0)
	_add_feed("复活: %s (%d/%d)" % ["进行中" if pending else "未进行", cur, total])

func _on_penalty(msg) -> void:
	var t: int = _get_i(msg, "get_penalty_type", 0)
	var sec: int = _get_i(msg, "get_penalty_effect_sec", 0)
	_add_feed("判罚: 类型 %d, 持续 %ds" % [t, sec])

func _on_guard_result(msg) -> void:
	var cmd: int = _get_i(msg, "get_command_id", 0)
	var code: int = _get_i(msg, "get_result_code", 0)
	_add_feed("哨兵控制反馈: cmd=%d result=%d" % [cmd, code])

func _get_i(msg, method_name: String, default_val: int) -> int:
	if msg != null and msg.has_method(method_name):
		return int(msg.call(method_name))
	return default_val

func _get_b(msg, method_name: String, default_val: bool) -> bool:
	if msg != null and msg.has_method(method_name):
		return bool(msg.call(method_name))
	return default_val

func _get_s(msg, method_name: String, default_val: String) -> String:
	if msg != null and msg.has_method(method_name):
		return str(msg.call(method_name))
	return default_val

func _get_arr(msg, method_name: String) -> Array:
	if msg != null and msg.has_method(method_name):
		return msg.call(method_name)
	return []
