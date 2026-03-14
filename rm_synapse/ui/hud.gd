extends CanvasLayer

@onready var web = $CefTexture
@onready var map_web = $CefMap

enum MessagePriority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CRITICAL = 3
}

@export var message_default_duration := 3.5
@export var message_max_count := 6

var _pending_message_items: Array[Dictionary] = []
var _pending_bridge_payloads: Array[Dictionary] = []
var _message_seq := 0

var page_ready := false
var update_rate := 0.0
var acc := 0.0

var event = EventService.new()
var hud_data_bridge = HudDataBridge.new()

const BRIDGE_SIGNAL_TO_PROTO_KEY := {
	"game_status_updated": "GameStatus",
	"global_unit_status_updated": "GlobalUnitStatus",
	"global_logistics_status_updated": "GlobalLogisticsStatus",
	"global_special_mechanism_updated": "GlobalSpecialMechanism",
	"event_received": "Event",
	"robot_injury_stat_updated": "RobotInjuryStat",
	"robot_respawn_status_updated": "RobotRespawnStatus",
	"robot_static_status_updated": "RobotStaticStatus",
	"robot_dynamic_status_updated": "RobotDynamicStatus",
	"robot_module_status_updated": "RobotModuleStatus",
	"robot_position_updated": "RobotPosition",
	"buff_updated": "Buff",
	"penalty_info_updated": "PenaltyInfo",
	"robot_path_plan_info_updated": "RobotPathPlanInfo",
	"radar_info_updated": "RadarInfoToClient",
	"robot_performance_selection_sync_updated": "RobotPerformanceSelectionSync",
	"deploy_mode_status_sync_updated": "DeployModeStatusSync",
	"tech_core_motion_state_sync_updated": "TechCoreMotionStateSync",
	"rune_status_sync_updated": "RuneStatusSync",
	"sentry_status_sync_updated": "SentryStatusSync",
	"dart_select_target_status_sync_updated": "DartSelectTargetStatusSync",
	"sentry_ctrl_result_updated": "SentryCtrlResult",
	"air_support_status_sync_updated": "AirSupportStatusSync",
	"custom_byte_block_received": "CustomByteBlock"
}


func _ready():
	randomize()
	print("HUD ready. Press A to send DEFAULT_UI_STATE, B for 100Hz test, C to stop.")
	set_process(true)
	set_process_input(true)

	if web and web.has_signal("load_finished"):
		web.load_finished.connect(func(_url: String, status: int) -> void:
			page_ready = (status >= 200 and status < 300)
			print("CEF load_finished status=", status, " page_ready=", page_ready)
			if page_ready:
				_flush_pending_bridge_payloads()
				_flush_pending_messages()
		)

	if hud_data_bridge.get_parent() == null:
		add_child(hud_data_bridge)
	_bind_bridge_signals()

func _bind_bridge_signals() -> void:
	for signal_name in BRIDGE_SIGNAL_TO_PROTO_KEY.keys():
		var proto_key: String = BRIDGE_SIGNAL_TO_PROTO_KEY[signal_name]
		if not hud_data_bridge.has_signal(signal_name):
			push_warning("HudDataBridge missing signal: %s" % signal_name)
			continue
		var callback := Callable(self, "_on_bridge_signal_received").bind(signal_name, proto_key)
		if not hud_data_bridge.is_connected(signal_name, callback):
			hud_data_bridge.connect(signal_name, callback)

func _on_bridge_signal_received(value, signal_name: String, proto_key: String) -> void:
	var payload := {
		proto_key: _normalize_bridge_value(proto_key, value)
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)
	print("Bridge->UI ", signal_name, " => ", proto_key)

func _normalize_bridge_value(proto_key: String, value):
	if value == null:
		return {}
	if proto_key == "Event":
		if value is Object and value.has_method("get_event_id") and value.has_method("get_param"):
			return {
				"event_id": int(value.call("get_event_id")),
				"param": str(value.call("get_param"))
			}
	if proto_key == "CustomByteBlock":
		var data_bytes = null
		if value is PackedByteArray:
			data_bytes = value
		elif value is Object and value.has_method("get_data"):
			data_bytes = value.call("get_data")
		if data_bytes is PackedByteArray:
			return {"data": _bytes_to_int_array(data_bytes)}
	if value is Dictionary or value is Array:
		return value
	if value is PackedByteArray:
		return {"data": _bytes_to_int_array(value)}
	if value is Object and value.has_method("to_dict"):
		var dict_value = value.call("to_dict")
		if dict_value is Dictionary or dict_value is Array:
			return dict_value
	return {"value": str(value)}

func _bytes_to_int_array(bytes: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	for b in bytes:
		out.append(int(b))
	return out

func _input(input_event):
	if input_event.is_action_pressed("map"):
		if map_web:
			map_web.visible = !map_web.visible
			if map_web.visible:
				map_web.move_to_front()
			print("Toggle map UI:", map_web.visible)

	if input_event is InputEventKey and input_event.keycode == KEY_Q and input_event.pressed and not input_event.echo:
		_spawn_mock_message()

func _priority_to_level(priority: int) -> String:
	match priority:
		MessagePriority.CRITICAL:
			return "critical"
		MessagePriority.HIGH:
			return "important"
		_:
			return "normal"

func _build_message_item(text: String, duration: float, priority: int, tag: String = "") -> Dictionary:
	var ttl := duration if duration > 0.0 else message_default_duration
	ttl = max(ttl, 0.2)
	_message_seq += 1
	var now_ms := Time.get_ticks_msec()
	var item := {
		"id": "gd-msg-%s-%s" % [str(now_ms), str(_message_seq)],
		"level": _priority_to_level(priority),
		"text": text,
		"duration": int(round(ttl * 1000.0)),
		"timestamp": now_ms
	}
	if not tag.strip_edges().is_empty():
		item["tag"] = tag.strip_edges()
	return item

func _push_message_items(items: Array[Dictionary]) -> void:
	if items.is_empty():
		return

	if not page_ready:
		for item in items:
			_pending_message_items.append(item)
		while _pending_message_items.size() > max(message_max_count, 1):
			_pending_message_items.remove_at(0)
		return

	push_payload({
		"messageCenter": {
			"items": items
		}
	})

func _flush_pending_messages() -> void:
	if not page_ready or _pending_message_items.is_empty():
		return
	var pending: Array[Dictionary] = _pending_message_items.duplicate(true)
	_pending_message_items.clear()
	push_payload({
		"messageCenter": {
			"items": pending
		}
	})

func _flush_pending_bridge_payloads() -> void:
	if not page_ready or _pending_bridge_payloads.is_empty():
		return
	var pending: Array[Dictionary] = _pending_bridge_payloads.duplicate(true)
	_pending_bridge_payloads.clear()
	for payload in pending:
		print("Flushing pending bridge payload: ", payload)
		push_payload(payload)

func add_message(text: String, duration := -1.0, priority := MessagePriority.MEDIUM, tag := "") -> void:
	var trimmed_text := text.strip_edges()
	if trimmed_text.is_empty():
		return
	var item := _build_message_item(trimmed_text, duration, priority, tag)
	var items: Array[Dictionary] = [item]
	_push_message_items(items)

func _spawn_mock_message():
	var msgs := [
		{ "text": "🔥 英雄 [狂战士] 击杀了 [突击手]", "duration": 4.0, "priority": MessagePriority.HIGH, "tag": "mock-kill" },
		{ "text": "⚠️ 全局播报：左侧基地正在遭受攻击！", "duration": 6.0, "priority": MessagePriority.CRITICAL, "tag": "mock-base-under-attack" },
		{ "text": "🛡️ 团队护甲升级完毕", "duration": 3.5, "priority": MessagePriority.MEDIUM, "tag": "mock-armor-upgrade" },
		{ "text": "💠 队友占领了前哨站", "duration": 3.0, "priority": MessagePriority.LOW, "tag": "mock-outpost" }
	]
	var sample: Dictionary = msgs[randi() % msgs.size()]
	add_message(sample["text"], sample["duration"], sample["priority"], sample["tag"])

func push_payload(payload: Dictionary) -> void:
	if not page_ready:
		print("CEF page not ready, skip push")
		return
	if web:
		var json := JSON.stringify(payload)
		print("Pushing HUD payload bytes=", json.length())
		web.eval("if (window.godotPush) { window.godotPush(" + json + "); }")
