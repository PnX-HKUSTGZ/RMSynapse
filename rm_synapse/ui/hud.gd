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
@export var keyboard_mouse_transport_enabled := true

var _pending_message_items: Array[Dictionary] = []
var _pending_bridge_payloads: Array[Dictionary] = []
var _message_seq := 0

var page_ready := false
var update_rate := 0.0
var acc := 0.0

var event = EventService.new()
var hud_data_bridge = HudDataBridge.new()
var hud_operation_bridge = HudOperationBridge.new()
var keyboard_mouse_sender = KeyboardMouseControlSender.new()
var adapter_getter = MQTTProtocolAdapterGetter.new()

var _transport: NetworkTransport = null
var _mqtt_connected := false
var _transport_retry_elapsed := 0.0
var _link_push_elapsed := 0.0
var _last_data_update_msec := 0
var _command_panel_open := false
var _map_page_ready := false
var _control_focus_active := true
var _mouse_delta := Vector2.ZERO
var _mouse_wheel_delta := 0
var _left_button_down := false
var _right_button_down := false
var _mid_button_down := false
var _pressed_key_bits: Dictionary = {}
var _pending_map_payloads: Array[Dictionary] = []

const KEYBOARD_BIT_BY_PHYSICAL_KEY := {
	KEY_W: 0,
	KEY_S: 1,
	KEY_A: 2,
	KEY_D: 3,
	KEY_SHIFT: 4,
	KEY_CTRL: 5,
	KEY_Q: 6,
	KEY_E: 7,
	KEY_R: 8,
	KEY_F: 9,
	KEY_G: 10,
	KEY_Z: 11,
	KEY_X: 12,
	KEY_C: 13,
	KEY_V: 14,
	KEY_B: 15
}

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

const MAP_PROTO_KEYS := {
	"GlobalUnitStatus": true,
	"RobotPosition": true,
	"RobotPathPlanInfo": true,
	"RadarInfoToClient": true
}


func _ready():
	randomize()
	print("HUD ready. Press A to send DEFAULT_UI_STATE, B for 100Hz test, C to stop.")
	set_process(true)
	set_process_input(true)

	if web and web.has_signal("load_finished"):
		web.load_finished.connect(func(_url: String, status: int) -> void:
			page_ready = _is_successful_cef_load(status)
			print("CEF load_finished status=", status, " page_ready=", page_ready)
			if page_ready:
				_push_link_status()
				_flush_pending_bridge_payloads()
				_flush_pending_messages()
		)
	_connect_cef_ipc_signals(web, "hud")
	if map_web and map_web.has_signal("load_finished"):
		map_web.load_finished.connect(func(_url: String, status: int) -> void:
			_map_page_ready = _is_successful_cef_load(status)
			print("CEF map load_finished status=", status, " map_page_ready=", _map_page_ready)
			if _map_page_ready:
				_push_map_snapshot()
				_flush_pending_map_payloads()
		)
	_connect_cef_ipc_signals(map_web, "map")

	hud_data_bridge.adapter_getter = adapter_getter
	if hud_data_bridge.get_parent() == null:
		add_child(hud_data_bridge)
	_bind_bridge_signals()

	hud_operation_bridge.adapter_getter = adapter_getter
	if hud_operation_bridge.get_parent() == null:
		add_child(hud_operation_bridge)
	if not hud_operation_bridge.operation_status.is_connected(_on_operation_status):
		hud_operation_bridge.operation_status.connect(_on_operation_status)
	keyboard_mouse_sender.adapter_getter = adapter_getter
	keyboard_mouse_sender.auto_start = keyboard_mouse_transport_enabled
	if keyboard_mouse_sender.get_parent() == null:
		add_child(keyboard_mouse_sender)
	if not keyboard_mouse_transport_enabled:
		keyboard_mouse_sender.stop_sending()
	_set_control_focus(true)
	_try_bind_transport_signals()

func _is_successful_cef_load(status: int) -> bool:
	return status == 0 or (status >= 200 and status < 400)

func _connect_cef_ipc_signals(target: Object, source: String) -> void:
	if target == null:
		return
	for signal_name in ["ipc_message", "ipc_data_message", "ipc_binary_message"]:
		if not target.has_signal(signal_name):
			continue
		var callback := Callable(self, "_on_web_ipc_message").bind(source)
		if not target.is_connected(signal_name, callback):
			target.connect(signal_name, callback)

func _process(delta: float) -> void:
	if keyboard_mouse_transport_enabled:
		_update_keyboard_mouse_sender()

	_transport_retry_elapsed += delta
	if _transport_retry_elapsed >= 1.0:
		_transport_retry_elapsed = 0.0
		_try_bind_transport_signals()

	_link_push_elapsed += delta
	if _link_push_elapsed >= 1.0:
		_link_push_elapsed = 0.0
		_push_link_status()

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
	_last_data_update_msec = Time.get_ticks_msec()
	var payload := {
		proto_key: _normalize_bridge_value(proto_key, value)
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)
	if _should_push_to_map(proto_key) and _map_page_ready and map_web != null and map_web.visible:
		push_map_payload(payload)
	elif _should_push_to_map(proto_key) and map_web != null and map_web.visible:
		_pending_map_payloads.append(payload)
	print("Bridge->UI ", signal_name, " => ", proto_key)
	_push_link_status()

func _should_push_to_map(proto_key: String) -> bool:
	return MAP_PROTO_KEYS.has(proto_key)

func _on_web_ipc_message(message, source: String = "hud") -> void:
	var parsed = _parse_ipc_payload(message)
	if not (parsed is Dictionary):
		return
	if str(parsed.get("channel", "")) != "hudOperate":
		return
	var operation = parsed.get("operation", {})
	if operation is Dictionary:
		var operation_type := str(operation.get("type", ""))
		print("UI->Godot source=", source, " operation=", operation_type)
		if operation_type == "toggleCommandPanel":
			if source == "map":
				return
			_toggle_command_panel()
			return
		if operation_type == "setCommandPanelOpen":
			if source == "map":
				return
			_set_command_panel_open(bool(operation.get("open", false)))
			return
		if operation_type == "mapClick":
			if source != "map" or map_web == null or not map_web.visible:
				push_warning("Ignore mapClick from inactive source: %s" % source)
				return
			_send_map_click(operation)
			return
		if source == "map":
			push_warning("Ignore non-map operation from map page: %s" % operation_type)
			return
	hud_operation_bridge.handle_operation(operation)

func _parse_ipc_payload(message):
	if message is Dictionary:
		return message
	if message is Array and message.size() > 0:
		return _parse_ipc_payload(message[0])
	if message is PackedByteArray:
		var byte_text: String = message.get_string_from_utf8()
		return _parse_ipc_payload(byte_text)
	var message_text: String = str(message)
	var json := JSON.new()
	var err: Error = json.parse(message_text)
	if err != OK:
		push_warning("Invalid HUD IPC payload: %s" % message_text)
		return null
	return json.data

func _on_operation_status(status: Dictionary) -> void:
	var level := "normal"
	if str(status.get("state", "")) == "failed":
		level = "critical"
	elif str(status.get("state", "")) == "pending":
		level = "important"
	var label := str(status.get("label", "操作"))
	var state := str(status.get("state", "idle"))
	var code := int(status.get("code", 0))
	var text := "%s: %s" % [label, state]
	if code != 0:
		text += " (%d)" % code
	push_payload({
		"commandStatus": status,
		"messageCenter": {
			"items": [
				_build_message_item(text, 2.5, MessagePriority.CRITICAL if level == "critical" else MessagePriority.HIGH, "cmd-%s" % str(status.get("operationType", "")))
			]
		}
	})

func _try_bind_transport_signals() -> void:
	if _transport != null and is_instance_valid(_transport):
		return
	var transport := adapter_getter.get_transport()
	if transport == null:
		return
	_transport = transport
	_mqtt_connected = transport.is_broker_connected()
	if not transport.connected.is_connected(_on_transport_connected):
		transport.connected.connect(_on_transport_connected)
	if not transport.disconnected.is_connected(_on_transport_disconnected):
		transport.disconnected.connect(_on_transport_disconnected)
	if not transport.connection_failed.is_connected(_on_transport_failed):
		transport.connection_failed.connect(_on_transport_failed)
	_push_link_status()

func _on_transport_connected() -> void:
	_mqtt_connected = true
	_push_link_status()

func _on_transport_disconnected(_reason = "") -> void:
	_mqtt_connected = false
	_push_link_status()

func _on_transport_failed(_reason = "") -> void:
	_mqtt_connected = false
	_push_link_status()

func _push_link_status() -> void:
	if not page_ready:
		return
	var now := Time.get_ticks_msec()
	var has_data := _last_data_update_msec > 0
	var data_outdated := has_data and now - _last_data_update_msec > 1500
	var data_status := "ok" if has_data else "warning"
	push_payload({
		"links": [
			{"name": "MQTT", "status": "ok" if _mqtt_connected else "warning", "outdated": false},
			{"name": "VIDEO", "status": "warning", "outdated": false},
			{"name": "DATA", "status": data_status, "outdated": data_outdated}
		]
	})

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

func _send_map_click(operation: Dictionary) -> void:
	var adapter = adapter_getter.get_adapter_silent()
	if adapter == null:
		_on_operation_status({
			"state": "failed",
			"label": "地图标点",
			"operationType": "mapClick",
			"requestId": 0,
			"code": -1,
			"timestamp": Time.get_ticks_msec()
		})
		return
	var data = AdapterTypes.MapClickInfoNotifyData.new()
	var robot_id := str(operation.get("robotId", "")).strip_edges()
	data.is_send_all = 1 if robot_id.is_empty() else int(operation.get("isSendAll", 0))
	data.robot_id = _robot_id_to_bytes(robot_id)
	data.mode = int(operation.get("mode", 0))
	data.enemy_id = int(operation.get("enemyId", operation.get("enemy_id", 0)))
	data.ascii = int(operation.get("ascii", 0))
	data.type = int(operation.get("clickType", operation.get("typeValue", 0)))
	data.map_x = float(operation.get("mapX", 0.0))
	data.map_y = float(operation.get("mapY", 0.0))
	var result := int(adapter.send_map_click_info_notify(data))
	_on_operation_status({
		"state": "success" if result >= 0 else "failed",
		"label": "地图标点",
		"operationType": "mapClick",
		"requestId": 0,
		"code": result,
		"timestamp": Time.get_ticks_msec()
	})

func _robot_id_to_bytes(value: String) -> PackedByteArray:
	var out := PackedByteArray()
	var source := value.to_utf8_buffer()
	for i in range(min(source.size(), AdapterTypes.MapClickInfoNotifyData.ROBOT_ID_BYTES)):
		out.append(source[i])
	return out

func _input(input_event):
	if input_event is InputEventKey and input_event.keycode == KEY_TAB and input_event.pressed and not input_event.echo:
		_toggle_command_panel()
		get_viewport().set_input_as_handled()
		return

	if _is_map_toggle_event(input_event):
		_toggle_map_page()
		get_viewport().set_input_as_handled()
		return

	if input_event is InputEventKey and input_event.keycode == KEY_Q and input_event.pressed and not input_event.echo:
		_spawn_mock_message()

	if keyboard_mouse_transport_enabled and _control_focus_active:
		_capture_keyboard_mouse_input(input_event)

func _is_map_toggle_event(input_event) -> bool:
	if input_event.is_action_pressed("map"):
		return true
	if not (input_event is InputEventKey):
		return false
	if not input_event.pressed or input_event.echo:
		return false
	return input_event.keycode == KEY_M or input_event.physical_keycode == KEY_M

func _toggle_map_page() -> void:
	if map_web == null:
		return
	map_web.visible = not map_web.visible
	if map_web.visible:
		map_web.move_to_front()
		_push_map_snapshot()
		_flush_pending_map_payloads()
	_refresh_control_focus()
	print("Toggle map UI:", map_web.visible)

func _toggle_command_panel() -> void:
	_set_command_panel_open(not _command_panel_open)

func _set_command_panel_open(open: bool) -> void:
	_command_panel_open = open
	_refresh_control_focus()
	var payload := {
		"commandPanel": {
			"open": _command_panel_open
		}
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)

func _refresh_control_focus() -> void:
	var map_open: bool = map_web != null and map_web.visible
	_set_control_focus(not _command_panel_open and not map_open)

func _set_control_focus(active: bool) -> void:
	_control_focus_active = active
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE)
	if not active:
		_mouse_delta = Vector2.ZERO
		_mouse_wheel_delta = 0
		_left_button_down = false
		_right_button_down = false
		_mid_button_down = false
		_pressed_key_bits.clear()

func _capture_keyboard_mouse_input(input_event) -> void:
	if input_event is InputEventMouseMotion:
		_mouse_delta += input_event.relative
		return
	if input_event is InputEventMouseButton:
		match input_event.button_index:
			MOUSE_BUTTON_LEFT:
				_left_button_down = input_event.pressed
			MOUSE_BUTTON_RIGHT:
				_right_button_down = input_event.pressed
			MOUSE_BUTTON_MIDDLE:
				_mid_button_down = input_event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if input_event.pressed:
					_mouse_wheel_delta += 1
			MOUSE_BUTTON_WHEEL_DOWN:
				if input_event.pressed:
					_mouse_wheel_delta -= 1
		return
	if input_event is InputEventKey and not input_event.echo:
		var bit := _keyboard_bit_for_event(input_event)
		if bit >= 0:
			if input_event.pressed:
				_pressed_key_bits[bit] = true
			else:
				_pressed_key_bits.erase(bit)

func _keyboard_bit_for_event(input_event: InputEventKey) -> int:
	var physical := input_event.physical_keycode
	var key := input_event.keycode
	if KEYBOARD_BIT_BY_PHYSICAL_KEY.has(physical):
		return int(KEYBOARD_BIT_BY_PHYSICAL_KEY[physical])
	if KEYBOARD_BIT_BY_PHYSICAL_KEY.has(key):
		return int(KEYBOARD_BIT_BY_PHYSICAL_KEY[key])
	return -1

func _keyboard_value() -> int:
	var value := 0
	for bit in _pressed_key_bits.keys():
		value |= 1 << int(bit)
	return value

func _update_keyboard_mouse_sender() -> void:
	var data := AdapterTypes.KeyboardMouseControlData.new()
	if _control_focus_active:
		data.mouse_x = int(round(_mouse_delta.x))
		data.mouse_y = int(round(-_mouse_delta.y))
		data.mouse_z = _mouse_wheel_delta
		data.left_button_down = _left_button_down
		data.right_button_down = _right_button_down
		data.mid_button_down = _mid_button_down
		data.keyboard_value = _keyboard_value()
	keyboard_mouse_sender.update_data(data)
	_mouse_delta = Vector2.ZERO
	_mouse_wheel_delta = 0

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

func _flush_pending_map_payloads() -> void:
	if not _map_page_ready or map_web == null or not map_web.visible or _pending_map_payloads.is_empty():
		return
	var pending: Array[Dictionary] = _pending_map_payloads.duplicate(true)
	_pending_map_payloads.clear()
	for payload in pending:
		push_map_payload(payload)

func _push_map_snapshot() -> void:
	if not _map_page_ready or map_web == null or not map_web.visible:
		return
	_push_map_state("GlobalUnitStatus", hud_data_bridge.get_global_unit_status_state())
	_push_map_state("RobotPosition", hud_data_bridge.get_robot_position_state())
	_push_map_state("RobotPathPlanInfo", hud_data_bridge.get_robot_path_plan_info_state())
	_push_map_state("RadarInfoToClient", hud_data_bridge.get_radar_info_state())

func _push_map_state(proto_key: String, value) -> void:
	if not _should_push_to_map(proto_key):
		return
	push_map_payload({
		proto_key: _normalize_bridge_value(proto_key, value)
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

func push_map_payload(payload: Dictionary) -> void:
	if not _map_page_ready or map_web == null or not map_web.visible:
		return
	var json := JSON.stringify(payload)
	map_web.eval("if (window.godotMapPush) { window.godotMapPush(" + json + "); }")
