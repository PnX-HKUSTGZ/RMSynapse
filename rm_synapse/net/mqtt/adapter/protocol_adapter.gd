extends Node
class_name ProtocolAdapter

signal decoded_message(topic, message)
signal decode_failed(topic, error_code)
signal unmapped_message(topic, payload)
signal keyboard_mouse_control(message)
signal custom_control(message)
signal game_status(message)
signal global_unit_status(message)
signal global_logistics_status(message)
signal global_special_mechanism(message)
signal event_message(message)
signal robot_injury_stat(message)
signal robot_respawn_status(message)
signal robot_static_status(message)
signal robot_dynamic_status(message)
signal robot_module_status(message)
signal robot_position(message)
signal buff(message)
signal penalty_info(message)
signal robot_path_plan_info(message)
signal map_click_info_notify(message)
signal radar_info_to_client(message)
signal custom_byte_block(message)
signal assembly_command(message)
signal tech_core_motion_state_sync(message)
signal robot_performance_selection_command(message)
signal robot_performance_selection_sync(message)
signal common_command(message)
signal hero_deploy_mode_event_command(message)
signal deploy_mode_status_sync(message)
signal rune_activate_command(message)
signal rune_status_sync(message)
signal sentry_status_sync(message)
signal dart_command(message)
signal dart_select_target_status_sync(message)
signal sentry_ctrl_command(message)
signal sentry_ctrl_result(message)
signal air_support_command(message)
signal air_support_status_sync(message)

@export var transport_path: NodePath = NodePath("../Transport")
@export var auto_subscribe: bool = true
enum Qos {
	QOS0 = 0,
	QOS1 = 1,
	QOS2 = 2
}

@export var publish_qos_default: Qos = Qos.QOS0
@export var subscribe_qos_default: Qos = Qos.QOS0
@export var publish_qos_by_topic: Dictionary = {}
@export var subscribe_qos_by_topic: Dictionary = {}

var RMProto: Variant = preload("res://net/mqtt/proto/generated/rm_custom_pb.gd")

const TOPIC_KEYBOARD_MOUSE_CONTROL = "KeyboardMouseControl"
const TOPIC_CUSTOM_CONTROL = "CustomControl"
const TOPIC_GAME_STATUS = "GameStatus"
const TOPIC_GLOBAL_UNIT_STATUS = "GlobalUnitStatus"
const TOPIC_GLOBAL_LOGISTICS_STATUS = "GlobalLogisticsStatus"
const TOPIC_GLOBAL_SPECIAL_MECHANISM = "GlobalSpecialMechanism"
const TOPIC_EVENT = "Event"
const TOPIC_ROBOT_INJURY_STAT = "RobotInjuryStat"
const TOPIC_ROBOT_RESPAWN_STATUS = "RobotRespawnStatus"
const TOPIC_ROBOT_STATIC_STATUS = "RobotStaticStatus"
const TOPIC_ROBOT_DYNAMIC_STATUS = "RobotDynamicStatus"
const TOPIC_ROBOT_MODULE_STATUS = "RobotModuleStatus"
const TOPIC_ROBOT_POSITION = "RobotPosition"
const TOPIC_BUFF = "Buff"
const TOPIC_PENALTY_INFO = "PenaltyInfo"
const TOPIC_ROBOT_PATH_PLAN_INFO = "RobotPathPlanInfo"
const TOPIC_MAP_CLICK_INFO_NOTIFY = "MapClickInfoNotify"
const TOPIC_RADAR_INFO_TO_CLIENT = "RadarInfoToClient"
const TOPIC_CUSTOM_BYTE_BLOCK = "CustomByteBlock"
const TOPIC_ASSEMBLY_COMMAND = "AssemblyCommand"
const TOPIC_TECH_CORE_MOTION_STATE_SYNC = "TechCoreMotionStateSync"
const TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND = "RobotPerformanceSelectionCommand"
const TOPIC_ROBOT_PERFORMANCE_SELECTION_SYNC = "RobotPerformanceSelectionSync"
const TOPIC_COMMON_COMMAND = "CommonCommand"
const TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND = "HeroDeployModeEventCommand"
const TOPIC_DEPLOY_MODE_STATUS_SYNC = "DeployModeStatusSync"
const TOPIC_RUNE_ACTIVATE_COMMAND = "RuneActivateCommand"
const TOPIC_RUNE_STATUS_SYNC = "RuneStatusSync"
const TOPIC_SENTRY_STATUS_SYNC = "SentryStatusSync"
const TOPIC_DART_COMMAND = "DartCommand"
const TOPIC_DART_SELECT_TARGET_STATUS_SYNC = "DartSelectTargetStatusSync"
const TOPIC_SENTRY_CTRL_COMMAND = "SentryCtrlCommand"
const TOPIC_SENTRY_CTRL_RESULT = "SentryCtrlResult"
const TOPIC_AIR_SUPPORT_COMMAND = "AirSupportCommand"
const TOPIC_AIR_SUPPORT_STATUS_SYNC = "AirSupportStatusSync"

const TOPIC_SIGNAL_MAP := {
	TOPIC_KEYBOARD_MOUSE_CONTROL: "keyboard_mouse_control",
	TOPIC_CUSTOM_CONTROL: "custom_control",
	TOPIC_GAME_STATUS: "game_status",
	TOPIC_GLOBAL_UNIT_STATUS: "global_unit_status",
	TOPIC_GLOBAL_LOGISTICS_STATUS: "global_logistics_status",
	TOPIC_GLOBAL_SPECIAL_MECHANISM: "global_special_mechanism",
	TOPIC_EVENT: "event_message",
	TOPIC_ROBOT_INJURY_STAT: "robot_injury_stat",
	TOPIC_ROBOT_RESPAWN_STATUS: "robot_respawn_status",
	TOPIC_ROBOT_STATIC_STATUS: "robot_static_status",
	TOPIC_ROBOT_DYNAMIC_STATUS: "robot_dynamic_status",
	TOPIC_ROBOT_MODULE_STATUS: "robot_module_status",
	TOPIC_ROBOT_POSITION: "robot_position",
	TOPIC_BUFF: "buff",
	TOPIC_PENALTY_INFO: "penalty_info",
	TOPIC_ROBOT_PATH_PLAN_INFO: "robot_path_plan_info",
	TOPIC_MAP_CLICK_INFO_NOTIFY: "map_click_info_notify",
	TOPIC_RADAR_INFO_TO_CLIENT: "radar_info_to_client",
	TOPIC_CUSTOM_BYTE_BLOCK: "custom_byte_block",
	TOPIC_ASSEMBLY_COMMAND: "assembly_command",
	TOPIC_TECH_CORE_MOTION_STATE_SYNC: "tech_core_motion_state_sync",
	TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND: "robot_performance_selection_command",
	TOPIC_ROBOT_PERFORMANCE_SELECTION_SYNC: "robot_performance_selection_sync",
	TOPIC_COMMON_COMMAND: "common_command",
	TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND: "hero_deploy_mode_event_command",
	TOPIC_DEPLOY_MODE_STATUS_SYNC: "deploy_mode_status_sync",
	TOPIC_RUNE_ACTIVATE_COMMAND: "rune_activate_command",
	TOPIC_RUNE_STATUS_SYNC: "rune_status_sync",
	TOPIC_SENTRY_STATUS_SYNC: "sentry_status_sync",
	TOPIC_DART_COMMAND: "dart_command",
	TOPIC_DART_SELECT_TARGET_STATUS_SYNC: "dart_select_target_status_sync",
	TOPIC_SENTRY_CTRL_COMMAND: "sentry_ctrl_command",
	TOPIC_SENTRY_CTRL_RESULT: "sentry_ctrl_result",
	TOPIC_AIR_SUPPORT_COMMAND: "air_support_command",
	TOPIC_AIR_SUPPORT_STATUS_SYNC: "air_support_status_sync",
}

const SUBSCRIBE_TOPICS: PackedStringArray = [
	TOPIC_GAME_STATUS,
	TOPIC_GLOBAL_UNIT_STATUS,
	TOPIC_GLOBAL_LOGISTICS_STATUS,
	TOPIC_GLOBAL_SPECIAL_MECHANISM,
	TOPIC_EVENT,
	TOPIC_ROBOT_INJURY_STAT,
	TOPIC_ROBOT_RESPAWN_STATUS,
	TOPIC_ROBOT_STATIC_STATUS,
	TOPIC_ROBOT_DYNAMIC_STATUS,
	TOPIC_ROBOT_MODULE_STATUS,
	TOPIC_ROBOT_POSITION,
	TOPIC_BUFF,
	TOPIC_PENALTY_INFO,
	TOPIC_ROBOT_PATH_PLAN_INFO,
	TOPIC_MAP_CLICK_INFO_NOTIFY,
	TOPIC_RADAR_INFO_TO_CLIENT,
	TOPIC_CUSTOM_BYTE_BLOCK,
	TOPIC_TECH_CORE_MOTION_STATE_SYNC,
	TOPIC_ROBOT_PERFORMANCE_SELECTION_SYNC,
	TOPIC_DEPLOY_MODE_STATUS_SYNC,
	TOPIC_RUNE_STATUS_SYNC,
	TOPIC_SENTRY_STATUS_SYNC,
	TOPIC_DART_SELECT_TARGET_STATUS_SYNC,
	TOPIC_SENTRY_CTRL_RESULT,
	TOPIC_AIR_SUPPORT_STATUS_SYNC,
]

const CUSTOM_CONTROL_MAX_BYTES := 30
const MAP_CLICK_ROBOT_ID_BYTES := 7
const MAP_CLICK_MIN_INTERVAL_MSEC := 500
const MAP_CLICK_SEMI_AUTO_MIN_INTERVAL_MSEC := 3000
const COMMON_COMMAND_MIN_INTERVAL_MSEC := 100
const COMMAND_10HZ_MIN_INTERVAL_MSEC := 100

const SEND_RATE_LIMIT_MSEC_BY_TOPIC := {
	TOPIC_COMMON_COMMAND: COMMON_COMMAND_MIN_INTERVAL_MSEC,
	TOPIC_ASSEMBLY_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
	TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
	TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
	TOPIC_RUNE_ACTIVATE_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
	TOPIC_DART_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
	TOPIC_SENTRY_CTRL_COMMAND: COMMAND_10HZ_MIN_INTERVAL_MSEC,
}

const RESTRICTED_SEND_METHOD_BY_TOPIC := {
	TOPIC_KEYBOARD_MOUSE_CONTROL: "send_keyboard_mouse_control()",
	TOPIC_CUSTOM_CONTROL: "send_custom_control()",
	TOPIC_MAP_CLICK_INFO_NOTIFY: "send_map_click_info_notify()",
	TOPIC_ASSEMBLY_COMMAND: "send_assembly_command()",
	TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND: "send_robot_performance_selection_command()",
	TOPIC_COMMON_COMMAND: "send_common_command()",
	TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND: "send_hero_deploy_mode_event_command()",
	TOPIC_RUNE_ACTIVATE_COMMAND: "send_rune_activate_command()",
	TOPIC_DART_COMMAND: "send_dart_command()",
	TOPIC_SENTRY_CTRL_COMMAND: "send_sentry_ctrl_command()",
	TOPIC_AIR_SUPPORT_COMMAND: "send_air_support_command()",
}

var _transport: Node
var _topic_to_class: Dictionary = {}
var _last_sent_msec_by_topic: Dictionary = {}

func _ready() -> void:
	_ensure_qos_maps()
	_register_default_mappings()
	if transport_path != NodePath(""):
		var node = get_node_or_null(transport_path)
		if node != null:
			bind_transport(node)

func bind_transport(node: Node) -> void:
	if node == null:
		Log.error("[ProtocolAdapter] Cannot bind null transport.")
		return
	if _transport != null and _transport != node:
		if _transport.raw_message.is_connected(_on_transport_message):
			_transport.raw_message.disconnect(_on_transport_message)
		if _transport.connected.is_connected(_on_transport_connected):
			_transport.connected.disconnect(_on_transport_connected)
	_transport = node
	if not _transport.raw_message.is_connected(_on_transport_message):
		_transport.raw_message.connect(_on_transport_message)
	if not _transport.connected.is_connected(_on_transport_connected):
		_transport.connected.connect(_on_transport_connected)
	Log.info("[ProtocolAdapter] Bound transport: %s" % str(node))
	if auto_subscribe:
		subscribe_all()

func is_transport_bound(node: Node) -> bool:
	if node == null:
		return false
	return _transport == node

func register_mapping(topic: String, message_class) -> void:
	_topic_to_class[topic] = message_class
	Log.debug("[ProtocolAdapter] Register mapping: %s" % topic)

func clear_mappings() -> void:
	_topic_to_class.clear()

func subscribe_all() -> void:
	if _transport == null:
		Log.error("[ProtocolAdapter] Cannot subscribe topics because transport is not bound.")
		return
	Log.info("[ProtocolAdapter] Subscribing to %d topics" % SUBSCRIBE_TOPICS.size())
	for topic in SUBSCRIBE_TOPICS:
		_transport.subscribe(topic, _get_subscribe_qos(topic))

func send_message(topic: String, message) -> int:
	var required_method = str(RESTRICTED_SEND_METHOD_BY_TOPIC.get(topic, ""))
	if required_method != "":
		Log.error("[ProtocolAdapter] Use %s for %s." % [required_method, topic])
		return -1
	return _send_topic_message(topic, message)

func _send_topic_message(topic: String, message) -> int:
	var min_interval_msec = _get_send_rate_limit_msec(topic)
	if _is_rate_limited(topic, min_interval_msec):
		return -1
	return _publish_message(topic, message)

func send_keyboard_mouse_control(data: AdapterTypes.KeyboardMouseControlData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_keyboard_mouse_control got null data.")
		return -1
	var message = RMProto.KeyboardMouseControl.new()
	message.set_mouse_x(data.mouse_x)
	message.set_mouse_y(data.mouse_y)
	message.set_mouse_z(data.mouse_z)
	message.set_left_button_down(data.left_button_down)
	message.set_right_button_down(data.right_button_down)
	message.set_keyboard_value(data.keyboard_value)
	message.set_mid_button_down(data.mid_button_down)
	return _send_topic_message(TOPIC_KEYBOARD_MOUSE_CONTROL, message)

func send_custom_control(data: AdapterTypes.CustomControlData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_custom_control got null data.")
		return -1
	var raw_data = data.data
	if raw_data == null:
		raw_data = PackedByteArray()
	if raw_data.size() > CUSTOM_CONTROL_MAX_BYTES:
		Log.warn("[ProtocolAdapter] CustomControl size=%d exceeds max=%d, drop message." % [raw_data.size(), CUSTOM_CONTROL_MAX_BYTES])
		return -1
	var message = RMProto.CustomControl.new()
	message.set_data(raw_data)
	return _send_topic_message(TOPIC_CUSTOM_CONTROL, message)

func send_map_click_info_notify(data: AdapterTypes.MapClickInfoNotifyData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_map_click_info_notify got null data.")
		return -1
	if not _validate_map_click_info_notify(data):
		return -1
	var min_interval_msec = _get_map_click_rate_limit_msec(data)
	var rate_limit_key = _get_map_click_rate_limit_key(data)
	if _is_rate_limited(rate_limit_key, min_interval_msec):
		return -1
	var message = RMProto.MapClickInfoNotify.new()
	message.set_is_send_all(data.is_send_all)
	message.set_robot_id(_normalize_map_click_robot_id(data.robot_id))
	message.set_mode(data.mode)
	message.set_enemy_id(data.enemy_id)
	message.set_ascii(data.ascii)
	message.set_type(data.type)
	message.set_map_x(data.map_x)
	message.set_map_y(data.map_y)
	return _publish_map_click_message(message, rate_limit_key)

func send_assembly_command(data: AdapterTypes.AssemblyCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_assembly_command got null data.")
		return -1
	if not _validate_assembly_command(data):
		return -1
	var message = RMProto.AssemblyCommand.new()
	message.set_operation(data.operation)
	message.set_difficulty(data.difficulty)
	return _send_topic_message(TOPIC_ASSEMBLY_COMMAND, message)

func send_robot_performance_selection_command(data: AdapterTypes.RobotPerformanceSelectionCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_robot_performance_selection_command got null data.")
		return -1
	if not _validate_robot_performance_selection_command(data):
		return -1
	var message = RMProto.RobotPerformanceSelectionCommand.new()
	message.set_shooter(data.shooter)
	message.set_chassis(data.chassis)
	message.set_sentry_control(data.sentry_control)
	return _send_topic_message(TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND, message)

func send_common_command(data: AdapterTypes.CommonCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_common_command got null data.")
		return -1
	if not _validate_common_command(data):
		return -1
	var message = RMProto.CommonCommand.new()
	message.set_cmd_type(data.cmd_type)
	message.set_param(data.param)
	return _send_topic_message(TOPIC_COMMON_COMMAND, message)

func send_hero_deploy_mode_event_command(data: AdapterTypes.HeroDeployModeEventCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_hero_deploy_mode_event_command got null data.")
		return -1
	if not _validate_hero_deploy_mode_event_command(data):
		return -1
	var message = RMProto.HeroDeployModeEventCommand.new()
	message.set_mode(data.mode)
	return _send_topic_message(TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND, message)

func send_rune_activate_command(data: AdapterTypes.RuneActivateCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_rune_activate_command got null data.")
		return -1
	if not _validate_rune_activate_command(data):
		return -1
	var message = RMProto.RuneActivateCommand.new()
	message.set_activate(data.activate)
	return _send_topic_message(TOPIC_RUNE_ACTIVATE_COMMAND, message)

func send_dart_command(data: AdapterTypes.DartCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_dart_command got null data.")
		return -1
	if not _validate_dart_command(data):
		return -1
	var message = RMProto.DartCommand.new()
	message.set_target_id(data.target_id)
	message.set_open(data.open)
	message.set_launch_confirm(data.launch_confirm)
	return _send_topic_message(TOPIC_DART_COMMAND, message)

func send_sentry_ctrl_command(data: AdapterTypes.SentryCtrlCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_sentry_ctrl_command got null data.")
		return -1
	if not _validate_sentry_ctrl_command(data):
		return -1
	var message = RMProto.SentryCtrlCommand.new()
	message.set_command_id(data.command_id)
	return _send_topic_message(TOPIC_SENTRY_CTRL_COMMAND, message)

func send_air_support_command(data: AdapterTypes.AirSupportCommandData) -> int:
	if data == null:
		Log.warn("[ProtocolAdapter] send_air_support_command got null data.")
		return -1
	if not _validate_air_support_command(data):
		return -1
	var message = RMProto.AirSupportCommand.new()
	message.set_command_id(data.command_id)
	return _send_topic_message(TOPIC_AIR_SUPPORT_COMMAND, message)

func set_publish_qos(topic: String, qos: Qos) -> void:
	publish_qos_by_topic[topic] = _normalize_qos(qos)

func set_subscribe_qos(topic: String, qos: Qos) -> void:
	subscribe_qos_by_topic[topic] = _normalize_qos(qos)

func _get_publish_qos(topic: String) -> int:
	return _normalize_qos(int(publish_qos_by_topic.get(topic, publish_qos_default)))

func _get_subscribe_qos(topic: String) -> int:
	return _normalize_qos(int(subscribe_qos_by_topic.get(topic, subscribe_qos_default)))

func _normalize_qos(qos: int) -> int:
	if qos < 0:
		Log.warn("[ProtocolAdapter] QoS %d is less than 0, normalized to 0" % qos)
		return 0
	if qos > 2:
		Log.warn("[ProtocolAdapter] QoS %d is greater than 2, normalized to 2" % qos)
		return 2
	return qos

func _normalize_map_click_robot_id(robot_id: PackedByteArray) -> PackedByteArray:
	var source = PackedByteArray()
	if robot_id != null:
		source = robot_id
	if source.size() == MAP_CLICK_ROBOT_ID_BYTES:
		return source
	var normalized = PackedByteArray()
	normalized.resize(MAP_CLICK_ROBOT_ID_BYTES)
	var copy_count = mini(source.size(), MAP_CLICK_ROBOT_ID_BYTES)
	for i in range(copy_count):
		normalized[i] = source[i]
	if source.size() < MAP_CLICK_ROBOT_ID_BYTES:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify robot_id size=%d, pad to %d bytes." % [source.size(), MAP_CLICK_ROBOT_ID_BYTES])
	elif source.size() > MAP_CLICK_ROBOT_ID_BYTES:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify robot_id size=%d, truncate to %d bytes." % [source.size(), MAP_CLICK_ROBOT_ID_BYTES])
	return normalized

func _publish_message(topic: String, message) -> int:
	if topic == TOPIC_MAP_CLICK_INFO_NOTIFY:
		Log.error("[ProtocolAdapter] MapClickInfoNotify must be sent through send_map_click_info_notify().")
		return -1
	if _transport == null:
		Log.error("[ProtocolAdapter] Cannot send message because transport is not bound.")
		return -1
	var payload = message.to_bytes()
	var qos = _get_publish_qos(topic)
	Log.debug("[ProtocolAdapter] Send message topic=%s size=%d qos=%d" % [topic, payload.size(), qos])
	var publish_result = _transport.publish_bytes(topic, payload, false, qos)
	if publish_result >= 0:
		_last_sent_msec_by_topic[topic] = Time.get_ticks_msec()
	return publish_result

func _publish_map_click_message(message, rate_limit_key: String) -> int:
	if _transport == null:
		Log.error("[ProtocolAdapter] Cannot send message because transport is not bound.")
		return -1
	var payload = message.to_bytes()
	var qos = _get_publish_qos(TOPIC_MAP_CLICK_INFO_NOTIFY)
	Log.debug("[ProtocolAdapter] Send message topic=%s size=%d qos=%d" % [TOPIC_MAP_CLICK_INFO_NOTIFY, payload.size(), qos])
	var publish_result = _transport.publish_bytes(TOPIC_MAP_CLICK_INFO_NOTIFY, payload, false, qos)
	if publish_result >= 0:
		_last_sent_msec_by_topic[rate_limit_key] = Time.get_ticks_msec()
	return publish_result

func _get_map_click_rate_limit_msec(data: AdapterTypes.MapClickInfoNotifyData) -> int:
	if _get_map_click_sender_context(data) == AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_SEMI_AUTO_OPERATOR:
		return MAP_CLICK_SEMI_AUTO_MIN_INTERVAL_MSEC
	return MAP_CLICK_MIN_INTERVAL_MSEC

func _get_map_click_rate_limit_key(data: AdapterTypes.MapClickInfoNotifyData) -> String:
	return "%s:%d" % [TOPIC_MAP_CLICK_INFO_NOTIFY, _get_map_click_sender_context(data)]

func _get_map_click_sender_context(data: AdapterTypes.MapClickInfoNotifyData) -> int:
	return data.sender_context

func _is_valid_map_click_sender_context(data: AdapterTypes.MapClickInfoNotifyData) -> bool:
	if data.sender_context == AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_GUNNER:
		return true
	if data.sender_context == AdapterTypes.MapClickInfoNotifyData.SENDER_CONTEXT_SEMI_AUTO_OPERATOR:
		return true
	Log.warn("[ProtocolAdapter] MapClickInfoNotify sender_context=%d is invalid." % data.sender_context)
	return false

func _validate_map_click_info_notify(data: AdapterTypes.MapClickInfoNotifyData) -> bool:
	if not _is_valid_map_click_sender_context(data):
		return false
	if data.is_send_all < 0 or data.is_send_all > 2:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify is_send_all=%d is invalid." % data.is_send_all)
		return false
	if data.mode < 1 or data.mode > 4:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify mode=%d is invalid." % data.mode)
		return false
	if data.type < 1 or data.type > 2:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify type=%d is invalid." % data.type)
		return false
	if data.mode == 4:
		if not _is_valid_map_click_ascii(data.ascii):
			Log.warn("[ProtocolAdapter] MapClickInfoNotify ascii=%d is invalid for custom marker." % data.ascii)
			return false
	elif data.ascii != 0:
		Log.warn("[ProtocolAdapter] MapClickInfoNotify ascii=%d must be 0 when mode=%d." % [data.ascii, data.mode])
		return false
	return true

func _is_valid_map_click_ascii(ascii: int) -> bool:
	return (ascii >= 67 and ascii <= 76) or ascii == 78 or ascii == 79 or (ascii >= 81 and ascii <= 90)

func _validate_assembly_command(data: AdapterTypes.AssemblyCommandData) -> bool:
	if data.operation < 0 or data.operation > 2:
		Log.warn("[ProtocolAdapter] AssemblyCommand operation=%d is invalid." % data.operation)
		return false
	return true

func _validate_robot_performance_selection_command(data: AdapterTypes.RobotPerformanceSelectionCommandData) -> bool:
	if data.shooter < 1 or data.shooter > 4:
		Log.warn("[ProtocolAdapter] RobotPerformanceSelectionCommand shooter=%d is invalid." % data.shooter)
		return false
	if data.chassis < 1 or data.chassis > 4:
		Log.warn("[ProtocolAdapter] RobotPerformanceSelectionCommand chassis=%d is invalid." % data.chassis)
		return false
	if data.sentry_control < 0 or data.sentry_control > 1:
		Log.warn("[ProtocolAdapter] RobotPerformanceSelectionCommand sentry_control=%d is invalid." % data.sentry_control)
		return false
	return true

func _validate_common_command(data: AdapterTypes.CommonCommandData) -> bool:
	if data.cmd_type < 1 or data.cmd_type > 6:
		Log.warn("[ProtocolAdapter] CommonCommand cmd_type=%d is invalid." % data.cmd_type)
		return false
	if data.cmd_type == 1 and data.param % 10 != 0:
		Log.warn("[ProtocolAdapter] CommonCommand param=%d must be a multiple of 10 for cmd_type=1." % data.param)
		return false
	return true

func _validate_hero_deploy_mode_event_command(data: AdapterTypes.HeroDeployModeEventCommandData) -> bool:
	if data.mode < 0 or data.mode > 1:
		Log.warn("[ProtocolAdapter] HeroDeployModeEventCommand mode=%d is invalid." % data.mode)
		return false
	return true

func _validate_rune_activate_command(data: AdapterTypes.RuneActivateCommandData) -> bool:
	if data.activate != 1:
		Log.warn("[ProtocolAdapter] RuneActivateCommand activate=%d is invalid." % data.activate)
		return false
	return true

func _validate_dart_command(data: AdapterTypes.DartCommandData) -> bool:
	if data.target_id < 1 or data.target_id > 5:
		Log.warn("[ProtocolAdapter] DartCommand target_id=%d is invalid." % data.target_id)
		return false
	return true

func _validate_sentry_ctrl_command(data: AdapterTypes.SentryCtrlCommandData) -> bool:
	if data.command_id < 1 or data.command_id > 9:
		Log.warn("[ProtocolAdapter] SentryCtrlCommand command_id=%d is invalid." % data.command_id)
		return false
	return true

func _validate_air_support_command(data: AdapterTypes.AirSupportCommandData) -> bool:
	if data.command_id < 0 or data.command_id > 2:
		Log.warn("[ProtocolAdapter] AirSupportCommand command_id=%d is invalid." % data.command_id)
		return false
	return true

func _get_send_rate_limit_msec(topic: String) -> int:
	return int(SEND_RATE_LIMIT_MSEC_BY_TOPIC.get(topic, 0))

func _is_rate_limited(topic: String, min_interval_msec: int) -> bool:
	if min_interval_msec <= 0:
		return false
	var now = Time.get_ticks_msec()
	var last_sent = int(_last_sent_msec_by_topic.get(topic, -1))
	if last_sent < 0:
		return false
	var elapsed = now - last_sent
	if elapsed >= min_interval_msec:
		return false
	var remaining = min_interval_msec - elapsed
	Log.warn("[ProtocolAdapter] Skip topic=%s, send interval too short (remaining=%dms)." % [topic, remaining])
	return true

func _ensure_qos_maps() -> void:
	for topic in TOPIC_SIGNAL_MAP.keys():
		if not publish_qos_by_topic.has(topic):
			publish_qos_by_topic[topic] = publish_qos_default
		if not subscribe_qos_by_topic.has(topic):
			subscribe_qos_by_topic[topic] = subscribe_qos_default

func _register_default_mappings() -> void:
	register_mapping(TOPIC_KEYBOARD_MOUSE_CONTROL, RMProto.KeyboardMouseControl)
	register_mapping(TOPIC_CUSTOM_CONTROL, RMProto.CustomControl)
	register_mapping(TOPIC_GAME_STATUS, RMProto.GameStatus)
	register_mapping(TOPIC_GLOBAL_UNIT_STATUS, RMProto.GlobalUnitStatus)
	register_mapping(TOPIC_GLOBAL_LOGISTICS_STATUS, RMProto.GlobalLogisticsStatus)
	register_mapping(TOPIC_GLOBAL_SPECIAL_MECHANISM, RMProto.GlobalSpecialMechanism)
	register_mapping(TOPIC_EVENT, RMProto.Event)
	register_mapping(TOPIC_ROBOT_INJURY_STAT, RMProto.RobotInjuryStat)
	register_mapping(TOPIC_ROBOT_RESPAWN_STATUS, RMProto.RobotRespawnStatus)
	register_mapping(TOPIC_ROBOT_STATIC_STATUS, RMProto.RobotStaticStatus)
	register_mapping(TOPIC_ROBOT_DYNAMIC_STATUS, RMProto.RobotDynamicStatus)
	register_mapping(TOPIC_ROBOT_MODULE_STATUS, RMProto.RobotModuleStatus)
	register_mapping(TOPIC_ROBOT_POSITION, RMProto.RobotPosition)
	register_mapping(TOPIC_BUFF, RMProto.Buff)
	register_mapping(TOPIC_PENALTY_INFO, RMProto.PenaltyInfo)
	register_mapping(TOPIC_ROBOT_PATH_PLAN_INFO, RMProto.RobotPathPlanInfo)
	register_mapping(TOPIC_MAP_CLICK_INFO_NOTIFY, RMProto.MapClickInfoNotify)
	register_mapping(TOPIC_RADAR_INFO_TO_CLIENT, RMProto.RadarInfoToClient)
	register_mapping(TOPIC_CUSTOM_BYTE_BLOCK, RMProto.CustomByteBlock)
	register_mapping(TOPIC_ASSEMBLY_COMMAND, RMProto.AssemblyCommand)
	register_mapping(TOPIC_TECH_CORE_MOTION_STATE_SYNC, RMProto.TechCoreMotionStateSync)
	register_mapping(TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND, RMProto.RobotPerformanceSelectionCommand)
	register_mapping(TOPIC_ROBOT_PERFORMANCE_SELECTION_SYNC, RMProto.RobotPerformanceSelectionSync)
	register_mapping(TOPIC_COMMON_COMMAND, RMProto.CommonCommand)
	register_mapping(TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND, RMProto.HeroDeployModeEventCommand)
	register_mapping(TOPIC_DEPLOY_MODE_STATUS_SYNC, RMProto.DeployModeStatusSync)
	register_mapping(TOPIC_RUNE_ACTIVATE_COMMAND, RMProto.RuneActivateCommand)
	register_mapping(TOPIC_RUNE_STATUS_SYNC, RMProto.RuneStatusSync)
	register_mapping(TOPIC_SENTRY_STATUS_SYNC, RMProto.SentryStatusSync)
	register_mapping(TOPIC_DART_COMMAND, RMProto.DartCommand)
	register_mapping(TOPIC_DART_SELECT_TARGET_STATUS_SYNC, RMProto.DartSelectTargetStatusSync)
	register_mapping(TOPIC_SENTRY_CTRL_COMMAND, RMProto.SentryCtrlCommand)
	register_mapping(TOPIC_SENTRY_CTRL_RESULT, RMProto.SentryCtrlResult)
	register_mapping(TOPIC_AIR_SUPPORT_COMMAND, RMProto.AirSupportCommand)
	register_mapping(TOPIC_AIR_SUPPORT_STATUS_SYNC, RMProto.AirSupportStatusSync)

func _on_transport_connected() -> void:
	Log.info("[ProtocolAdapter] mqtt broker connected.")

func _on_transport_message(topic, payload) -> void:
	var topic_str := String(topic)
	var bytes: PackedByteArray = payload
	if not (payload is PackedByteArray):
		bytes = str(payload).to_utf8_buffer()
	var message_class = _topic_to_class.get(topic_str, null)
	if message_class == null:
		Log.warn("[ProtocolAdapter] Unmapped topic: %s (size=%d)" % [topic_str, bytes.size()])
		emit_signal("unmapped_message", topic_str, bytes)
		return
	var message = message_class.new()
	if bytes.size() == 0:
		_fill_default_values(message)
		Log.info("[ProtocolAdapter] Empty payload topic=%s, use default message" % topic_str)
	else:
		var res = message.from_bytes(bytes)
		if res != RMProto.PB_ERR.NO_ERRORS:
			Log.warn("[ProtocolAdapter] Decode failed topic=%s err=%d" % [topic_str, res])
			emit_signal("decode_failed", topic_str, res)
			return
		_fill_default_values(message)
	Log.debug("[ProtocolAdapter] Decoded topic=%s" % topic_str)
	emit_signal("decoded_message", topic_str, message)
	_emit_topic_signal(topic_str, message)

func _fill_default_values(message) -> void:
	var defaults = RMProto.DEFAULT_VALUES_3
	if RMProto.PROTO_VERSION == 2:
		defaults = RMProto.DEFAULT_VALUES_2
	var data = message.data
	for key in data.keys():
		var service = data[key]
		if service == null or service.field == null:
			continue
		if service.state != RMProto.PB_SERVICE_STATE.UNFILLED:
			continue
		var field = service.field
		if field.value == null:
			field.value = _default_value_for(field.type, defaults)
		elif field.type == RMProto.PB_DATA_TYPE.BYTES \
		&& field.rule != RMProto.PB_RULE.REPEATED \
		&& typeof(field.value) != TYPE_PACKED_BYTE_ARRAY:
			field.value = PackedByteArray(field.value)
		service.state = RMProto.PB_SERVICE_STATE.FILLED

func _default_value_for(data_type: int, defaults: Dictionary):
	if data_type == RMProto.PB_DATA_TYPE.BYTES:
		return PackedByteArray()
	return defaults.get(data_type, null)

func _emit_topic_signal(topic: String, message) -> void:
	var signal_name = TOPIC_SIGNAL_MAP.get(topic, "")
	if signal_name == "":
		Log.warn("[ProtocolAdapter] topic " + topic + " dosen't have corresponding signal.")
		return
	Log.debug("[ProtocolAdapter] topic %s emit signal %s with content %s" % [topic, signal_name, str(message)])
	emit_signal(signal_name, message)
