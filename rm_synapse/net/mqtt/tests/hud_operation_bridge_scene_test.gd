extends Node

class FakeAdapter:
	extends Node
	signal tech_core_motion_state_sync(message)
	signal robot_performance_selection_sync(message)
	signal deploy_mode_status_sync(message)
	signal rune_status_sync(message)
	signal dart_select_target_status_sync(message)
	signal sentry_ctrl_result(message)
	signal air_support_status_sync(message)

	var last_payload: Dictionary = {}
	var send_calls: Dictionary = {}

	func _record(key: String, payload: Dictionary) -> int:
		send_calls[key] = int(send_calls.get(key, 0)) + 1
		last_payload[key] = payload
		return 0

	func send_assembly_command(data) -> int:
		return _record("assembly", {"operation": int(data.operation), "difficulty": int(data.difficulty)})

	func send_robot_performance_selection_command(data) -> int:
		return _record("perf", {"shooter": int(data.shooter), "chassis": int(data.chassis), "sentry_control": int(data.sentry_control)})

	func send_common_command(data) -> int:
		return _record("common", {"cmd_type": int(data.cmd_type), "param": int(data.param)})

	func send_hero_deploy_mode_event_command(data) -> int:
		return _record("hero", {"mode": int(data.mode)})

	func send_rune_activate_command(data) -> int:
		return _record("rune", {"activate": int(data.activate)})

	func send_dart_command(data) -> int:
		return _record("dart", {"target_id": int(data.target_id), "open": bool(data.open), "launch_confirm": bool(data.launch_confirm)})

	func send_sentry_ctrl_command(data) -> int:
		return _record("sentry", {"command_id": int(data.command_id)})

	func send_air_support_command(data) -> int:
		return _record("air", {"command_id": int(data.command_id)})

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _assert_payload_value(payload: Dictionary, key: String, expected, errors: Array[String], label: String) -> void:
	if payload.get(key) != expected:
		errors.append("%s %s expected=%s got=%s" % [label, key, str(expected), str(payload.get(key))])

func _ready() -> void:
	var errors: Array[String] = []
	var adapter = FakeAdapter.new()
	var getter = FakeAdapterGetter.new()
	getter.adapter_ref = adapter

	var bridge = HudOperationBridge.new()
	bridge.adapter_getter = getter
	add_child(bridge)

	bridge.handle_operation({"type": "performanceSelection", "role": "infantry", "firing": "cooldown", "chassis": "power"})
	_assert_payload_value(adapter.last_payload.get("perf", {}), "shooter", 1, errors, "infantry perf")
	_assert_payload_value(adapter.last_payload.get("perf", {}), "chassis", 2, errors, "infantry perf")

	bridge.handle_operation({"type": "performanceSelection", "role": "hero", "firing": "ranged", "chassis": "hp"})
	_assert_payload_value(adapter.last_payload.get("perf", {}), "shooter", 4, errors, "hero perf")
	_assert_payload_value(adapter.last_payload.get("perf", {}), "chassis", 1, errors, "hero perf")

	bridge.handle_operation({"type": "performanceSelection", "role": "sentry", "sentryMode": "semi"})
	_assert_payload_value(adapter.last_payload.get("perf", {}), "sentry_control", 1, errors, "sentry perf")

	bridge.handle_operation({"type": "commonCommand", "command": "exchange17mm", "param": 20})
	_assert_payload_value(adapter.last_payload.get("common", {}), "cmd_type", 1, errors, "common 17mm")
	_assert_payload_value(adapter.last_payload.get("common", {}), "param", 20, errors, "common 17mm")

	bridge.handle_operation({"type": "commonCommand", "command": "remoteBuyHp", "param": 0})
	_assert_payload_value(adapter.last_payload.get("common", {}), "cmd_type", 6, errors, "common hp")

	bridge.handle_operation({"type": "heroDeploy", "mode": 1})
	_assert_payload_value(adapter.last_payload.get("hero", {}), "mode", 1, errors, "hero deploy")

	bridge.handle_operation({"type": "runeActivate"})
	_assert_payload_value(adapter.last_payload.get("rune", {}), "activate", 1, errors, "rune")

	bridge.handle_operation({"type": "dart", "targetId": 3, "open": true, "launchConfirm": false})
	_assert_payload_value(adapter.last_payload.get("dart", {}), "target_id", 3, errors, "dart")
	_assert_payload_value(adapter.last_payload.get("dart", {}), "open", true, errors, "dart")

	bridge.handle_operation({"type": "sentryCommand", "commandId": 8})
	_assert_payload_value(adapter.last_payload.get("sentry", {}), "command_id", 8, errors, "sentry")

	bridge.handle_operation({"type": "airSupport", "commandId": 2})
	_assert_payload_value(adapter.last_payload.get("air", {}), "command_id", 2, errors, "air")

	bridge.handle_operation({"type": "assembly", "operation": 2, "difficulty": 3})
	_assert_payload_value(adapter.last_payload.get("assembly", {}), "operation", 2, errors, "assembly")
	_assert_payload_value(adapter.last_payload.get("assembly", {}), "difficulty", 3, errors, "assembly")

	if errors.is_empty():
		print("HUD_OPERATION_BRIDGE_SCENE_TEST_OK")
	else:
		print("HUD_OPERATION_BRIDGE_SCENE_TEST_FAIL")
		for error in errors:
			print("FAIL:", error)
	get_tree().quit()
