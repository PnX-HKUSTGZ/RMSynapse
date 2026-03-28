extends Node

class DummySyncMessage:
	extends RefCounted
	var status: int = 0
	var basic_state: int = 0
	var putin_state: int = 0
	var move_state: int = 0
	var rotate_state: int = 0
	var enemy_core_status: int = 0
	var remain_time_all: int = 0
	var remain_time_step: int = 0
	var shooter: int = 0
	var chassis: int = 0
	var sentry_control: int = 0
	var rune_status: int = 0
	var open: int = 0
	var command_id: int = 0
	var result_code: int = 0
	var airsupport_status: int = 0

	func get_status() -> int:
		return status

	func get_basic_state() -> int:
		return basic_state

	func get_putin_state() -> int:
		return putin_state

	func get_move_state() -> int:
		return move_state

	func get_rotate_state() -> int:
		return rotate_state

	func get_enemy_core_status() -> int:
		return enemy_core_status

	func get_remain_time_all() -> int:
		return remain_time_all

	func get_remain_time_step() -> int:
		return remain_time_step

	func get_shooter() -> int:
		return shooter

	func get_chassis() -> int:
		return chassis

	func get_sentry_control() -> int:
		return sentry_control

	func get_rune_status() -> int:
		return rune_status

	func get_open() -> int:
		return open

	func get_command_id() -> int:
		return command_id

	func get_result_code() -> int:
		return result_code

	func get_airsupport_status() -> int:
		return airsupport_status

class FakeAdapter:
	extends Node
	signal tech_core_motion_state_sync(message)
	signal robot_performance_selection_sync(message)
	signal deploy_mode_status_sync(message)
	signal rune_status_sync(message)
	signal dart_select_target_status_sync(message)
	signal sentry_ctrl_result(message)
	signal air_support_status_sync(message)

	var send_results: Dictionary = {
		"assembly": 0,
		"perf": 0,
		"hero": 0,
		"rune": 0,
		"dart": 0,
		"sentry": 0,
		"air": 0,
	}
	var send_calls: Dictionary = {}
	var last_payload: Dictionary = {}

	func _record_call(key: String) -> void:
		send_calls[key] = int(send_calls.get(key, 0)) + 1

	func send_assembly_command(data) -> int:
		_record_call("assembly")
		last_payload["assembly"] = {
			"operation": int(data.operation),
			"difficulty": int(data.difficulty),
		}
		return int(send_results.get("assembly", 0))

	func send_robot_performance_selection_command(data) -> int:
		_record_call("perf")
		last_payload["perf"] = {
			"shooter": int(data.shooter),
			"chassis": int(data.chassis),
			"sentry_control": int(data.sentry_control),
		}
		return int(send_results.get("perf", 0))

	func send_hero_deploy_mode_event_command(data) -> int:
		_record_call("hero")
		last_payload["hero"] = {
			"mode": int(data.mode),
		}
		return int(send_results.get("hero", 0))

	func send_rune_activate_command(data) -> int:
		_record_call("rune")
		last_payload["rune"] = {
			"activate": int(data.activate),
		}
		return int(send_results.get("rune", 0))

	func send_dart_command(data) -> int:
		_record_call("dart")
		last_payload["dart"] = {
			"target_id": int(data.target_id),
			"open": bool(data.open),
			"launch_confirm": bool(data.launch_confirm),
		}
		return int(send_results.get("dart", 0))

	func send_sentry_ctrl_command(data) -> int:
		_record_call("sentry")
		last_payload["sentry"] = {
			"command_id": int(data.command_id),
		}
		return int(send_results.get("sentry", 0))

	func send_air_support_command(data) -> int:
		_record_call("air")
		last_payload["air"] = {
			"command_id": int(data.command_id),
		}
		return int(send_results.get("air", 0))

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _find_code(records: Array[Dictionary], request_id: int) -> int:
	for item in records:
		if int(item.get("id", -1)) == request_id:
			return int(item.get("code", -999))
	return -999

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var adapter = FakeAdapter.new()
	var getter = FakeAdapterGetter.new()
	getter.adapter_ref = adapter

	var assembly = AssemblyCommandService.new()
	var perf = RobotPerformanceSelectionCommandService.new()
	var hero = HeroDeployModeEventCommandService.new()
	var rune = RuneActivateCommandService.new()
	var dart = DartCommandService.new()
	var sentry = SentryCtrlCommandService.new()
	var air = AirSupportCommandService.new()

	for svc in [assembly, perf, hero, rune, dart, sentry, air]:
		svc.adapter_getter = getter
		svc.bind_retry_interval_sec = 0.01
		svc.default_timeout_sec = 0.5
		add_child(svc)

	var assembly_finished: Array[Dictionary] = []
	var perf_finished: Array[Dictionary] = []
	var hero_finished: Array[Dictionary] = []
	var rune_finished: Array[Dictionary] = []
	var dart_finished: Array[Dictionary] = []
	var sentry_finished: Array[Dictionary] = []
	var air_finished: Array[Dictionary] = []

	assembly.request_finished.connect(func(id, code):
		assembly_finished.append({"id": int(id), "code": int(code)})
	)
	perf.request_finished.connect(func(id, code):
		perf_finished.append({"id": int(id), "code": int(code)})
	)
	hero.request_finished.connect(func(id, code):
		hero_finished.append({"id": int(id), "code": int(code)})
	)
	rune.request_finished.connect(func(id, code):
		rune_finished.append({"id": int(id), "code": int(code)})
	)
	dart.request_finished.connect(func(id, code):
		dart_finished.append({"id": int(id), "code": int(code)})
	)
	sentry.request_finished.connect(func(id, code):
		sentry_finished.append({"id": int(id), "code": int(code)})
	)
	air.request_finished.connect(func(id, code):
		air_finished.append({"id": int(id), "code": int(code)})
	)

	var rune_req_1 = rune.request_rune_activate(0.5)
	var rune_req_2 = rune.request_rune_activate(0.5)
	if _find_code(rune_finished, rune_req_1) != RuneActivateCommandService.ErrorCode.OVERRIDDEN:
		ok = false
		errors.append("override should mark old request as OVERRIDDEN")
	var rune_msg = DummySyncMessage.new()
	rune_msg.rune_status = 3
	adapter.rune_status_sync.emit(rune_msg)
	if _find_code(rune_finished, rune_req_2) != RuneActivateCommandService.ErrorCode.OK:
		ok = false
		errors.append("rune success verify")

	adapter.send_results["hero"] = -1
	var hero_retry_req = hero.request_hero_deploy_mode(1, 0.5)
	if _find_code(hero_finished, hero_retry_req) != -999:
		ok = false
		errors.append("hero first send fail should keep running")
	adapter.send_results["hero"] = 0
	hero._process(1.1)
	var hero_retry_msg = DummySyncMessage.new()
	hero_retry_msg.status = 1
	adapter.deploy_mode_status_sync.emit(hero_retry_msg)
	if _find_code(hero_finished, hero_retry_req) != HeroDeployModeEventCommandService.ErrorCode.OK:
		ok = false
		errors.append("hero retry after first send fail should succeed")

	adapter.send_results["hero"] = -1
	var hero_fail_req = hero.request_hero_deploy_mode(1, 0.2)
	OS.delay_msec(250)
	hero._process(0.25)
	if _find_code(hero_finished, hero_fail_req) != HeroDeployModeEventCommandService.ErrorCode.SEND_REJECTED:
		ok = false
		errors.append("hero send failure classify")
	adapter.send_results["hero"] = 0

	var sentry_fail_req = sentry.request_sentry_ctrl_command(9, 0.5)
	var sentry_fail_msg = DummySyncMessage.new()
	sentry_fail_msg.command_id = 9
	sentry_fail_msg.result_code = 2
	adapter.sentry_ctrl_result.emit(sentry_fail_msg)
	if _find_code(sentry_finished, sentry_fail_req) != SentryCtrlCommandService.ErrorCode.PROTOCOL_REJECTED:
		ok = false
		errors.append("sentry protocol reject classify")

	var air_timeout_req = air.request_air_support_command(1, 0.2)
	var air_timeout_payload = adapter.last_payload.get("air", {})
	if int(air_timeout_payload.get("command_id", -1)) != 1:
		ok = false
		errors.append("air timeout payload should use legal command_id")
	OS.delay_msec(250)
	air._process(0.25)
	if _find_code(air_finished, air_timeout_req) != AirSupportCommandService.ErrorCode.VERIFY_TIMEOUT:
		ok = false
		errors.append("air timeout classify")

	var baseline_motion_msg = DummySyncMessage.new()
	adapter.tech_core_motion_state_sync.emit(baseline_motion_msg)
	var assembly_req = assembly.request_assembly_command(2, 3, 0.5)
	var unchanged_motion_msg = DummySyncMessage.new()
	adapter.tech_core_motion_state_sync.emit(unchanged_motion_msg)
	if _find_code(assembly_finished, assembly_req) != -999:
		ok = false
		errors.append("assembly should ignore unchanged vector")
	var motion_msg = DummySyncMessage.new()
	motion_msg.basic_state = 1
	adapter.tech_core_motion_state_sync.emit(motion_msg)
	if _find_code(assembly_finished, assembly_req) != AssemblyCommandService.ErrorCode.OK:
		ok = false
		errors.append("assembly success")
	var assembly_payload = adapter.last_payload.get("assembly", {})
	if int(assembly_payload.get("operation", -1)) != 2 or int(assembly_payload.get("difficulty", -1)) != 3:
		ok = false
		errors.append("assembly payload")

	var assembly_timeout_req = assembly.request_assembly_command(2, 1, 0.2)
	var assembly_timeout_payload = adapter.last_payload.get("assembly", {})
	if int(assembly_timeout_payload.get("operation", -1)) != 2 or int(assembly_timeout_payload.get("difficulty", -1)) != 1:
		ok = false
		errors.append("assembly timeout payload should use legal values")
	var unchanged_timeout_msg = DummySyncMessage.new()
	unchanged_timeout_msg.basic_state = 1
	adapter.tech_core_motion_state_sync.emit(unchanged_timeout_msg)
	OS.delay_msec(250)
	assembly._process(0.25)
	if _find_code(assembly_finished, assembly_timeout_req) != AssemblyCommandService.ErrorCode.VERIFY_TIMEOUT:
		ok = false
		errors.append("assembly timeout on unchanged vector")

	var perf_req = perf.request_robot_performance_selection(4, 4, 1, 0.5)
	var perf_payload = adapter.last_payload.get("perf", {})
	if int(perf_payload.get("shooter", -1)) != 4 or int(perf_payload.get("chassis", -1)) != 4 or int(perf_payload.get("sentry_control", -1)) != 1:
		ok = false
		errors.append("perf payload should use legal values")
	var perf_msg = DummySyncMessage.new()
	perf_msg.shooter = 4
	perf_msg.chassis = 4
	perf_msg.sentry_control = 1
	adapter.robot_performance_selection_sync.emit(perf_msg)
	if _find_code(perf_finished, perf_req) != RobotPerformanceSelectionCommandService.ErrorCode.OK:
		ok = false
		errors.append("perf success")

	var hero_req = hero.request_hero_deploy_mode(0, 0.5)
	var hero_msg = DummySyncMessage.new()
	hero_msg.status = 0
	adapter.deploy_mode_status_sync.emit(hero_msg)
	if _find_code(hero_finished, hero_req) != HeroDeployModeEventCommandService.ErrorCode.OK:
		ok = false
		errors.append("hero success")

	var dart_open_req = dart.request_dart_command(4, true, false, 0.5)
	var dart_open_payload = adapter.last_payload.get("dart", {})
	if int(dart_open_payload.get("target_id", -1)) != 4 or not bool(dart_open_payload.get("open", false)) or bool(dart_open_payload.get("launch_confirm", false)):
		ok = false
		errors.append("dart open payload should use legal target")
	var dart_msg = DummySyncMessage.new()
	dart_msg.open = 1
	adapter.dart_select_target_status_sync.emit(dart_msg)
	if _find_code(dart_finished, dart_open_req) != DartCommandService.ErrorCode.OK:
		ok = false
		errors.append("dart open success")

	var dart_launch_req = dart.request_dart_command(5, false, true, 0.5)
	if _find_code(dart_finished, dart_launch_req) != DartCommandService.ErrorCode.OK:
		ok = false
		errors.append("dart launch_confirm success")
	var dart_payload = adapter.last_payload.get("dart", {})
	if int(dart_payload.get("target_id", -1)) != 5 or not bool(dart_payload.get("launch_confirm", false)):
		ok = false
		errors.append("dart launch payload")

	var sentry_ok_req = sentry.request_sentry_ctrl_command(5, 0.5)
	var sentry_ok_msg = DummySyncMessage.new()
	sentry_ok_msg.command_id = 5
	sentry_ok_msg.result_code = 0
	adapter.sentry_ctrl_result.emit(sentry_ok_msg)
	if _find_code(sentry_finished, sentry_ok_req) != SentryCtrlCommandService.ErrorCode.OK:
		ok = false
		errors.append("sentry success")

	var air_open_req = air.request_air_support_command(1, 0.5)
	var air_open_msg = DummySyncMessage.new()
	air_open_msg.airsupport_status = 1
	adapter.air_support_status_sync.emit(air_open_msg)
	if _find_code(air_finished, air_open_req) != AirSupportCommandService.ErrorCode.OK:
		ok = false
		errors.append("air command 1 success")

	var air_paid_req = air.request_air_support_command(2, 0.5)
	var air_paid_msg = DummySyncMessage.new()
	air_paid_msg.airsupport_status = 1
	adapter.air_support_status_sync.emit(air_paid_msg)
	if _find_code(air_finished, air_paid_req) != AirSupportCommandService.ErrorCode.OK:
		ok = false
		errors.append("air command 2 success")

	var air_stop_req = air.request_air_support_command(0, 0.5)
	var air_stop_msg = DummySyncMessage.new()
	air_stop_msg.airsupport_status = 0
	adapter.air_support_status_sync.emit(air_stop_msg)
	if _find_code(air_finished, air_stop_req) != AirSupportCommandService.ErrorCode.OK:
		ok = false
		errors.append("air command 0 success")

	var delayed_getter = FakeAdapterGetter.new()
	var delayed_service = AssemblyCommandService.new()
	delayed_service.adapter_getter = delayed_getter
	delayed_service.bind_retry_interval_sec = 0.01
	delayed_service.default_timeout_sec = 0.5
	delayed_service._logged_missing = true
	add_child(delayed_service)
	var delayed_finished: Array[Dictionary] = []
	delayed_service.request_finished.connect(func(id, code):
		delayed_finished.append({"id": int(id), "code": int(code)})
	)

	var delayed_adapter_a = FakeAdapter.new()
	delayed_getter.adapter_ref = delayed_adapter_a
	delayed_service._process(0.2)
	delayed_adapter_a.tech_core_motion_state_sync.emit(DummySyncMessage.new())
	var delayed_req_1 = delayed_service.request_assembly_command(1, 1, 0.5)
	var delayed_changed_msg = DummySyncMessage.new()
	delayed_changed_msg.basic_state = 1
	delayed_adapter_a.tech_core_motion_state_sync.emit(delayed_changed_msg)
	if _find_code(delayed_finished, delayed_req_1) != AssemblyCommandService.ErrorCode.OK:
		ok = false
		errors.append("delayed adapter bind success")

	var delayed_adapter_b = FakeAdapter.new()
	delayed_getter.adapter_ref = delayed_adapter_b
	delayed_service._process(0.2)
	var delayed_req_2 = delayed_service.request_assembly_command(2, 2, 0.5)
	var delayed_stale_msg = DummySyncMessage.new()
	delayed_stale_msg.basic_state = 2
	delayed_adapter_a.tech_core_motion_state_sync.emit(delayed_stale_msg)
	if not delayed_service.is_running():
		ok = false
		errors.append("adapter replace should disconnect old adapter")
	var delayed_new_msg = DummySyncMessage.new()
	delayed_new_msg.basic_state = 2
	delayed_adapter_b.tech_core_motion_state_sync.emit(delayed_new_msg)
	if _find_code(delayed_finished, delayed_req_2) != AssemblyCommandService.ErrorCode.OK:
		ok = false
		errors.append("adapter replace should bind new adapter")

	if ok:
		print("OPERATE_COMMAND_SERVICES_SCENE_TEST_OK")
	else:
		print("OPERATE_COMMAND_SERVICES_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
