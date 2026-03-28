extends Node

const RMProto = preload("res://net/mqtt/proto/generated/rm_custom_pb.gd")
const EXPECTED_MAP_CLICK_GUNNER_INTERVAL_MSEC := 500
const EXPECTED_MAP_CLICK_SEMI_AUTO_INTERVAL_MSEC := 3000
const EXPECTED_COMMAND_INTERVAL_MSEC := 100

class FakeTransport:
	extends Node
	signal raw_message(topic, payload)
	signal connected()

	var publishes: Array[Dictionary] = []
	var subscriptions: Array[Dictionary] = []

	func publish_bytes(topic: String, payload: PackedByteArray, retain: bool = false, qos: int = 0) -> int:
		publishes.append({
			"topic": topic,
			"payload": payload.duplicate(),
			"retain": retain,
			"qos": qos,
		})
		return 0

	func subscribe(topic: String, qos: int = 0) -> void:
		subscriptions.append({
			"topic": topic,
			"qos": qos,
		})

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var auto_transport = FakeTransport.new()
	var auto_adapter = ProtocolAdapter.new()
	auto_adapter.auto_subscribe = true
	add_child(auto_transport)
	add_child(auto_adapter)
	auto_adapter.bind_transport(auto_transport)
	if not _has_subscription(auto_transport, ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY):
		ok = false
		errors.append("auto_subscribe should include MapClickInfoNotify")

	var transport = FakeTransport.new()
	var adapter = ProtocolAdapter.new()
	adapter.auto_subscribe = false
	add_child(transport)
	add_child(adapter)
	adapter.bind_transport(transport)
	if ProtocolAdapter.MAP_CLICK_MIN_INTERVAL_MSEC != EXPECTED_MAP_CLICK_GUNNER_INTERVAL_MSEC:
		ok = false
		errors.append("map_click gunner interval constant should be 500ms")
	if ProtocolAdapter.MAP_CLICK_SEMI_AUTO_MIN_INTERVAL_MSEC != EXPECTED_MAP_CLICK_SEMI_AUTO_INTERVAL_MSEC:
		ok = false
		errors.append("map_click semi-auto interval constant should be 3000ms")
	if ProtocolAdapter.COMMAND_10HZ_MIN_INTERVAL_MSEC != EXPECTED_COMMAND_INTERVAL_MSEC:
		ok = false
		errors.append("10hz command interval constant should be 100ms")
	if ProtocolAdapter.COMMON_COMMAND_MIN_INTERVAL_MSEC != EXPECTED_COMMAND_INTERVAL_MSEC:
		ok = false
		errors.append("common command interval constant should be 100ms")

	var custom_ok = AdapterTypes.CustomControlData.new()
	custom_ok.data = _make_bytes(30)
	if adapter.send_custom_control(custom_ok) != 0:
		ok = false
		errors.append("custom_control 30 bytes should send")
	var custom_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_CUSTOM_CONTROL)
	if custom_publish.is_empty():
		ok = false
		errors.append("custom_control publish missing")
	else:
		var custom_msg = RMProto.CustomControl.new()
		if custom_msg.from_bytes(custom_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("custom_control decode")
		elif custom_msg.get_data().size() != 30:
			ok = false
			errors.append("custom_control data size")

	var keyboard_null_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_keyboard_mouse_control(null),
		transport,
		keyboard_null_publish_count,
		errors,
		"keyboard_mouse_control null data"
	)

	var publish_count_before_oversize = transport.publishes.size()
	var custom_oversize = AdapterTypes.CustomControlData.new()
	custom_oversize.data = _make_bytes(31)
	_expect_rejected(
		adapter.send_custom_control(custom_oversize),
		transport,
		publish_count_before_oversize,
		errors,
		"custom_control >30 bytes"
	)

	var map_click = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	if adapter.send_map_click_info_notify(map_click) != 0:
		ok = false
		errors.append("map_click gunner send")
	var map_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY)
	if map_publish.is_empty():
		ok = false
		errors.append("map_click publish missing")
	else:
		var map_msg = RMProto.MapClickInfoNotify.new()
		if map_msg.from_bytes(map_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("map_click decode")
		else:
			if map_msg.get_is_send_all() != 1 or map_msg.get_mode() != 4 or map_msg.get_enemy_id() != 3:
				ok = false
				errors.append("map_click scalar values")
			if map_msg.get_ascii() != 67 or map_msg.get_type() != 2:
				ok = false
				errors.append("map_click mode/type values")
			if not is_equal_approx(map_msg.get_map_x(), 12.5) or not is_equal_approx(map_msg.get_map_y(), 34.75):
				ok = false
				errors.append("map_click map coordinates")
			if map_msg.get_robot_id() != PackedByteArray([1, 2, 3, 4, 5, 6, 7]):
				ok = false
				errors.append("map_click robot_id")
		var field_numbers = _parse_field_numbers(map_publish["payload"], errors, "map_click")
		if field_numbers != [1, 2, 3, 4, 5, 6, 7, 8]:
			ok = false
			errors.append("map_click field numbers")
		if field_numbers.has(9) or field_numbers.has(10):
			ok = false
			errors.append("map_click should not encode legacy screen fields")

	var gunner_rate_key = _map_click_rate_key(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	var publish_count_before_map_rate_limit = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(map_click),
		transport,
		publish_count_before_map_rate_limit,
		errors,
		"map_click gunner rate limit"
	)
	adapter._last_sent_msec_by_topic[gunner_rate_key] = Time.get_ticks_msec() - EXPECTED_MAP_CLICK_GUNNER_INTERVAL_MSEC
	if adapter.send_map_click_info_notify(map_click) != 0:
		ok = false
		errors.append("map_click gunner resend after 500ms")

	var semi_map_click = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_SEMI_AUTO_OPERATOR)
	if adapter.send_map_click_info_notify(semi_map_click) != 0:
		ok = false
		errors.append("map_click semi-auto send")
	var semi_rate_key = _map_click_rate_key(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_SEMI_AUTO_OPERATOR)
	var publish_count_before_semi_rate_limit = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(semi_map_click),
		transport,
		publish_count_before_semi_rate_limit,
		errors,
		"map_click semi-auto rate limit"
	)
	adapter._last_sent_msec_by_topic[semi_rate_key] = Time.get_ticks_msec() - EXPECTED_MAP_CLICK_SEMI_AUTO_INTERVAL_MSEC
	if adapter.send_map_click_info_notify(semi_map_click) != 0:
		ok = false
		errors.append("map_click semi-auto resend after 3000ms")

	adapter._last_sent_msec_by_topic.clear()
	var non_custom_map_click = AdapterTypes.MapClickInfoNotifyData.new()
	non_custom_map_click.is_send_all = 2
	non_custom_map_click.robot_id = PackedByteArray([7, 6, 5, 4, 3, 2, 1])
	non_custom_map_click.mode = 2
	non_custom_map_click.enemy_id = 6
	non_custom_map_click.ascii = 0
	non_custom_map_click.type = 1
	non_custom_map_click.map_x = 1.25
	non_custom_map_click.map_y = 9.5
	non_custom_map_click.sender_context = AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER
	if adapter.send_map_click_info_notify(non_custom_map_click) != 0:
		ok = false
		errors.append("map_click non-custom send")
	else:
		var non_custom_map_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY)
		var non_custom_map_msg = RMProto.MapClickInfoNotify.new()
		if non_custom_map_publish.is_empty() or non_custom_map_msg.from_bytes(non_custom_map_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("map_click non-custom decode")
		elif non_custom_map_msg.get_is_send_all() != 2 or non_custom_map_msg.get_mode() != 2 or non_custom_map_msg.get_type() != 1 or non_custom_map_msg.get_ascii() != 0:
			ok = false
			errors.append("map_click non-custom values")

	var map_click_bypass_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_message(ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY, RMProto.MapClickInfoNotify.new()),
		transport,
		map_click_bypass_publish_count,
		errors,
		"map_click send_message bypass"
	)
	var assembly_bypass_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_message(ProtocolAdapter.TOPIC_ASSEMBLY_COMMAND, RMProto.AssemblyCommand.new()),
		transport,
		assembly_bypass_publish_count,
		errors,
		"assembly send_message bypass"
	)

	adapter._last_sent_msec_by_topic.clear()

	var invalid_map_click_sender = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_sender.sender_context = 9
	var invalid_map_click_sender_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_sender),
		transport,
		invalid_map_click_sender_publish_count,
		errors,
		"map_click invalid sender_context"
	)

	var invalid_map_click_type = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_type.type = 3
	var invalid_map_click_type_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_type),
		transport,
		invalid_map_click_type_publish_count,
		errors,
		"map_click invalid type"
	)

	var invalid_map_click_mode = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_mode.mode = 0
	var invalid_map_click_mode_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_mode),
		transport,
		invalid_map_click_mode_publish_count,
		errors,
		"map_click invalid mode"
	)

	var invalid_map_click_send_all = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_send_all.is_send_all = 3
	var invalid_map_click_send_all_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_send_all),
		transport,
		invalid_map_click_send_all_publish_count,
		errors,
		"map_click invalid is_send_all"
	)

	var invalid_map_click_ascii = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_ascii.mode = 2
	invalid_map_click_ascii.ascii = 67
	var invalid_map_click_ascii_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_ascii),
		transport,
		invalid_map_click_ascii_publish_count,
		errors,
		"map_click invalid ascii"
	)
	var invalid_map_click_custom_ascii = _make_valid_map_click(AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER)
	invalid_map_click_custom_ascii.ascii = 65
	var invalid_map_click_custom_ascii_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_map_click_info_notify(invalid_map_click_custom_ascii),
		transport,
		invalid_map_click_custom_ascii_publish_count,
		errors,
		"map_click invalid custom ascii whitelist"
	)

	var invalid_assembly = AdapterTypes.AssemblyCommandData.new()
	invalid_assembly.operation = 3
	invalid_assembly.difficulty = 1
	var invalid_assembly_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_assembly_command(invalid_assembly),
		transport,
		invalid_assembly_publish_count,
		errors,
		"assembly invalid operation"
	)

	var invalid_perf = AdapterTypes.RobotPerformanceSelectionCommandData.new()
	invalid_perf.shooter = 5
	invalid_perf.chassis = 4
	invalid_perf.sentry_control = 1
	var invalid_perf_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_robot_performance_selection_command(invalid_perf),
		transport,
		invalid_perf_publish_count,
		errors,
		"robot_performance invalid shooter"
	)

	var invalid_perf_chassis = AdapterTypes.RobotPerformanceSelectionCommandData.new()
	invalid_perf_chassis.shooter = 4
	invalid_perf_chassis.chassis = 0
	invalid_perf_chassis.sentry_control = 1
	var invalid_perf_chassis_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_robot_performance_selection_command(invalid_perf_chassis),
		transport,
		invalid_perf_chassis_publish_count,
		errors,
		"robot_performance invalid chassis"
	)

	var invalid_perf_sentry = AdapterTypes.RobotPerformanceSelectionCommandData.new()
	invalid_perf_sentry.shooter = 4
	invalid_perf_sentry.chassis = 4
	invalid_perf_sentry.sentry_control = 2
	var invalid_perf_sentry_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_robot_performance_selection_command(invalid_perf_sentry),
		transport,
		invalid_perf_sentry_publish_count,
		errors,
		"robot_performance invalid sentry_control"
	)

	var invalid_common_type = AdapterTypes.CommonCommandData.new()
	invalid_common_type.cmd_type = 7
	invalid_common_type.param = 0
	var invalid_common_type_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_common_command(invalid_common_type),
		transport,
		invalid_common_type_publish_count,
		errors,
		"common_command invalid cmd_type"
	)

	var invalid_common_param = AdapterTypes.CommonCommandData.new()
	invalid_common_param.cmd_type = 1
	invalid_common_param.param = 15
	var invalid_common_param_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_common_command(invalid_common_param),
		transport,
		invalid_common_param_publish_count,
		errors,
		"common_command invalid param"
	)

	var invalid_hero = AdapterTypes.HeroDeployModeEventCommandData.new()
	invalid_hero.mode = 2
	var invalid_hero_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_hero_deploy_mode_event_command(invalid_hero),
		transport,
		invalid_hero_publish_count,
		errors,
		"hero_deploy invalid mode"
	)

	var invalid_rune = AdapterTypes.RuneActivateCommandData.new()
	invalid_rune.activate = 0
	var invalid_rune_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_rune_activate_command(invalid_rune),
		transport,
		invalid_rune_publish_count,
		errors,
		"rune_activate invalid activate"
	)

	var invalid_dart = AdapterTypes.DartCommandData.new()
	invalid_dart.target_id = 6
	var invalid_dart_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_dart_command(invalid_dart),
		transport,
		invalid_dart_publish_count,
		errors,
		"dart invalid target_id"
	)

	var invalid_sentry = AdapterTypes.SentryCtrlCommandData.new()
	invalid_sentry.command_id = 0
	var invalid_sentry_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_sentry_ctrl_command(invalid_sentry),
		transport,
		invalid_sentry_publish_count,
		errors,
		"sentry_ctrl invalid command_id"
	)

	var invalid_air = AdapterTypes.AirSupportCommandData.new()
	invalid_air.command_id = 3
	var invalid_air_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_air_support_command(invalid_air),
		transport,
		invalid_air_publish_count,
		errors,
		"air_support invalid command_id"
	)

	adapter._last_sent_msec_by_topic.clear()

	var perf_ok = AdapterTypes.RobotPerformanceSelectionCommandData.new()
	perf_ok.shooter = 4
	perf_ok.chassis = 4
	perf_ok.sentry_control = 1
	if adapter.send_robot_performance_selection_command(perf_ok) != 0:
		ok = false
		errors.append("robot_performance first send")
	else:
		var perf_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND)
		var perf_msg = RMProto.RobotPerformanceSelectionCommand.new()
		if perf_publish.is_empty() or perf_msg.from_bytes(perf_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("robot_performance decode")
		elif perf_msg.get_shooter() != 4 or perf_msg.get_chassis() != 4 or perf_msg.get_sentry_control() != 1:
			ok = false
			errors.append("robot_performance payload values")
	var perf_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_robot_performance_selection_command(perf_ok),
		transport,
		perf_rate_limit_publish_count,
		errors,
		"robot_performance 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_robot_performance_selection_command(perf_ok) != 0:
		ok = false
		errors.append("robot_performance resend after 100ms")

	var hero_ok = AdapterTypes.HeroDeployModeEventCommandData.new()
	hero_ok.mode = 1
	if adapter.send_hero_deploy_mode_event_command(hero_ok) != 0:
		ok = false
		errors.append("hero_deploy first send")
	else:
		var hero_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND)
		var hero_msg = RMProto.HeroDeployModeEventCommand.new()
		if hero_publish.is_empty() or hero_msg.from_bytes(hero_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("hero_deploy decode")
		elif hero_msg.get_mode() != 1:
			ok = false
			errors.append("hero_deploy payload values")
	var hero_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_hero_deploy_mode_event_command(hero_ok),
		transport,
		hero_rate_limit_publish_count,
		errors,
		"hero_deploy 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_hero_deploy_mode_event_command(hero_ok) != 0:
		ok = false
		errors.append("hero_deploy resend after 100ms")

	var rune_ok = AdapterTypes.RuneActivateCommandData.new()
	rune_ok.activate = 1
	if adapter.send_rune_activate_command(rune_ok) != 0:
		ok = false
		errors.append("rune_activate first send")
	else:
		var rune_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_RUNE_ACTIVATE_COMMAND)
		var rune_msg = RMProto.RuneActivateCommand.new()
		if rune_publish.is_empty() or rune_msg.from_bytes(rune_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("rune_activate decode")
		elif rune_msg.get_activate() != 1:
			ok = false
			errors.append("rune_activate payload values")
	var rune_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_rune_activate_command(rune_ok),
		transport,
		rune_rate_limit_publish_count,
		errors,
		"rune_activate 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_RUNE_ACTIVATE_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_rune_activate_command(rune_ok) != 0:
		ok = false
		errors.append("rune_activate resend after 100ms")

	var dart_ok = AdapterTypes.DartCommandData.new()
	dart_ok.target_id = 5
	dart_ok.open = true
	dart_ok.launch_confirm = false
	if adapter.send_dart_command(dart_ok) != 0:
		ok = false
		errors.append("dart first send")
	else:
		var dart_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_DART_COMMAND)
		var dart_msg = RMProto.DartCommand.new()
		if dart_publish.is_empty() or dart_msg.from_bytes(dart_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("dart decode")
		elif dart_msg.get_target_id() != 5 or not dart_msg.get_open() or dart_msg.get_launch_confirm():
			ok = false
			errors.append("dart payload values")
	var dart_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_dart_command(dart_ok),
		transport,
		dart_rate_limit_publish_count,
		errors,
		"dart 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_DART_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_dart_command(dart_ok) != 0:
		ok = false
		errors.append("dart resend after 100ms")

	var sentry_ok = AdapterTypes.SentryCtrlCommandData.new()
	sentry_ok.command_id = 9
	if adapter.send_sentry_ctrl_command(sentry_ok) != 0:
		ok = false
		errors.append("sentry_ctrl first send")
	else:
		var sentry_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_SENTRY_CTRL_COMMAND)
		var sentry_msg = RMProto.SentryCtrlCommand.new()
		if sentry_publish.is_empty() or sentry_msg.from_bytes(sentry_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("sentry_ctrl decode")
		elif sentry_msg.get_command_id() != 9:
			ok = false
			errors.append("sentry_ctrl payload values")
	var sentry_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_sentry_ctrl_command(sentry_ok),
		transport,
		sentry_rate_limit_publish_count,
		errors,
		"sentry_ctrl 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_SENTRY_CTRL_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_sentry_ctrl_command(sentry_ok) != 0:
		ok = false
		errors.append("sentry_ctrl resend after 100ms")

	var assembly_ok = AdapterTypes.AssemblyCommandData.new()
	assembly_ok.operation = 2
	assembly_ok.difficulty = 3
	if adapter.send_assembly_command(assembly_ok) != 0:
		ok = false
		errors.append("assembly command first send")
	var assembly_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_assembly_command(assembly_ok),
		transport,
		assembly_rate_limit_publish_count,
		errors,
		"assembly 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_ASSEMBLY_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_assembly_command(assembly_ok) != 0:
		ok = false
		errors.append("assembly resend after 100ms")

	var common_ok = AdapterTypes.CommonCommandData.new()
	common_ok.cmd_type = 2
	common_ok.param = 1
	if adapter.send_common_command(common_ok) != 0:
		ok = false
		errors.append("common_command first send")
	var common_rate_limit_publish_count = transport.publishes.size()
	_expect_rejected(
		adapter.send_common_command(common_ok),
		transport,
		common_rate_limit_publish_count,
		errors,
		"common_command 10hz rate limit"
	)
	adapter._last_sent_msec_by_topic[ProtocolAdapter.TOPIC_COMMON_COMMAND] = Time.get_ticks_msec() - EXPECTED_COMMAND_INTERVAL_MSEC
	if adapter.send_common_command(common_ok) != 0:
		ok = false
		errors.append("common_command resend after 100ms")

	var common_legal_cases: Array[Dictionary] = [
		{"cmd_type": 1, "param": 20, "label": "common_command type1 legal"},
		{"cmd_type": 3, "param": 0, "label": "common_command type3 legal"},
		{"cmd_type": 4, "param": 1, "label": "common_command type4 legal"},
		{"cmd_type": 5, "param": 33, "label": "common_command type5 legal"},
		{"cmd_type": 6, "param": 44, "label": "common_command type6 legal"},
	]
	for common_case in common_legal_cases:
		adapter._last_sent_msec_by_topic.erase(ProtocolAdapter.TOPIC_COMMON_COMMAND)
		var common_case_data = AdapterTypes.CommonCommandData.new()
		common_case_data.cmd_type = int(common_case["cmd_type"])
		common_case_data.param = int(common_case["param"])
		if adapter.send_common_command(common_case_data) != 0:
			ok = false
			errors.append("%s send" % String(common_case["label"]))
			continue
		var common_case_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_COMMON_COMMAND)
		var common_case_msg = RMProto.CommonCommand.new()
		if common_case_publish.is_empty() or common_case_msg.from_bytes(common_case_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("%s decode" % String(common_case["label"]))
		elif common_case_msg.get_cmd_type() != int(common_case["cmd_type"]) or common_case_msg.get_param() != int(common_case["param"]):
			ok = false
			errors.append("%s values" % String(common_case["label"]))

	var air_support = AdapterTypes.AirSupportCommandData.new()
	air_support.command_id = 0
	if adapter.send_air_support_command(air_support) != 0:
		ok = false
		errors.append("air_support command 0 send")
	var air_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_AIR_SUPPORT_COMMAND)
	if air_publish.is_empty():
		ok = false
		errors.append("air_support publish missing")
	else:
		var air_payload: PackedByteArray = air_publish["payload"]
		if air_payload.size() != 0:
			ok = false
			errors.append("air_support command_id 0 should serialize as default empty payload")
	if adapter.send_air_support_command(air_support) != 0:
		ok = false
		errors.append("air_support should not use old 1hz topic rate limit")

	var air_support_paid = AdapterTypes.AirSupportCommandData.new()
	air_support_paid.command_id = 2
	if adapter.send_air_support_command(air_support_paid) != 0:
		ok = false
		errors.append("air_support command 2 send")
	else:
		var air_paid_publish = _latest_publish(transport, ProtocolAdapter.TOPIC_AIR_SUPPORT_COMMAND)
		var air_paid_msg = RMProto.AirSupportCommand.new()
		if air_paid_publish.is_empty() or air_paid_msg.from_bytes(air_paid_publish["payload"]) != RMProto.PB_ERR.NO_ERRORS:
			ok = false
			errors.append("air_support command 2 decode")
		elif air_paid_msg.get_command_id() != 2:
			ok = false
			errors.append("air_support command 2 payload")

	if ok:
		print("PROTOCOL_ADAPTER_SCENE_TEST_OK")
	else:
		print("PROTOCOL_ADAPTER_SCENE_TEST_FAIL")
		for error in errors:
			print("FAIL:", error)
	get_tree().quit()

func _expect_rejected(result: int, transport: FakeTransport, publish_count_before: int, errors: Array[String], label: String) -> void:
	if result != -1:
		errors.append("%s should reject" % label)
	if transport.publishes.size() != publish_count_before:
		errors.append("%s should not publish" % label)

func _has_subscription(transport: FakeTransport, topic: String) -> bool:
	for subscription in transport.subscriptions:
		if String(subscription.get("topic", "")) == topic:
			return true
	return false

func _latest_publish(transport: FakeTransport, topic: String) -> Dictionary:
	for i in range(transport.publishes.size() - 1, -1, -1):
		var publish = transport.publishes[i]
		if String(publish.get("topic", "")) == topic:
			return publish
	return {}

func _make_valid_map_click(sender_context: int) -> AdapterTypes.MapClickInfoNotifyData:
	var data = AdapterTypes.MapClickInfoNotifyData.new()
	data.is_send_all = 1
	data.robot_id = PackedByteArray([1, 2, 3, 4, 5, 6, 7])
	data.mode = 4
	data.enemy_id = 3
	data.ascii = 67
	data.type = 2
	data.map_x = 12.5
	data.map_y = 34.75
	data.sender_context = sender_context
	return data

func _map_click_rate_key(sender_context: int) -> String:
	return "%s:%d" % [ProtocolAdapter.TOPIC_MAP_CLICK_INFO_NOTIFY, sender_context]

func _make_bytes(length: int) -> PackedByteArray:
	var data = PackedByteArray()
	data.resize(length)
	for i in range(length):
		data[i] = i % 256
	return data

func _parse_field_numbers(bytes: PackedByteArray, errors: Array[String], label: String) -> Array[int]:
	var fields: Array[int] = []
	var offset = 0
	while offset < bytes.size():
		var tag_result = _read_varint(bytes, offset)
		if not bool(tag_result.get("ok", false)):
			errors.append("%s invalid tag varint" % label)
			return []
		offset = int(tag_result.get("offset", offset))
		var tag = int(tag_result.get("value", 0))
		if tag == 0:
			errors.append("%s zero tag" % label)
			return []
		fields.append(tag >> 3)
		var wire_type = tag & 0x07
		match wire_type:
			0:
				var value_result = _read_varint(bytes, offset)
				if not bool(value_result.get("ok", false)):
					errors.append("%s invalid value varint" % label)
					return []
				offset = int(value_result.get("offset", offset))
			1:
				offset += 8
			2:
				var length_result = _read_varint(bytes, offset)
				if not bool(length_result.get("ok", false)):
					errors.append("%s invalid length varint" % label)
					return []
				var size = int(length_result.get("value", 0))
				offset = int(length_result.get("offset", offset)) + size
			5:
				offset += 4
			_:
				errors.append("%s unsupported wire type %d" % [label, wire_type])
				return []
		if offset > bytes.size():
			errors.append("%s field overrun" % label)
			return []
	return fields

func _read_varint(bytes: PackedByteArray, start_offset: int) -> Dictionary:
	var value: int = 0
	var shift: int = 0
	var offset = start_offset
	while offset < bytes.size() and shift < 64:
		var current = int(bytes[offset])
		value |= (current & 0x7F) << shift
		offset += 1
		if (current & 0x80) == 0:
			return {
				"ok": true,
				"value": value,
				"offset": offset,
			}
		shift += 7
	return {
		"ok": false,
		"value": 0,
		"offset": start_offset,
	}
