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
var _message_seq := 0

var page_ready := false
var update_rate := 0.0
var acc := 0.0

var event = EventService.new()
var hud_data_bridge = HudDataBridge.new()


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
				_flush_pending_messages()
		)

	if hud_data_bridge.get_parent() == null:
		add_child(hud_data_bridge)
	if not hud_data_bridge.game_status_updated.is_connected(_on_game_status_updated):
		hud_data_bridge.game_status_updated.connect(_on_game_status_updated)
	if not hud_data_bridge.robot_static_status_updated.is_connected(_on_robot_static_status_updated):
		hud_data_bridge.robot_static_status_updated.connect(_on_robot_static_status_updated)

func _on_game_status_updated(new_status):
	print("Game status changed: ", new_status)
	if new_status is Dictionary:
		push_payload(new_status)

func _on_robot_static_status_updated(new_status):
	print("Robot static status updated: ", new_status)

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
