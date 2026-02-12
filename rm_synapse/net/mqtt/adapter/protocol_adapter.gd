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

var _transport: Node
var _topic_to_class: Dictionary = {}

func _ready() -> void:
	_register_default_mappings()
	if transport_path != NodePath(""):
		var node = get_node_or_null(transport_path)
		if node != null:
			bind_transport(node)

func bind_transport(node: Node) -> void:
	_transport = node
	_transport.raw_message.connect(_on_transport_message)
	_transport.connected.connect(_on_transport_connected)
	Log.info("[ProtocolAdapter] Bound transport: %s" % str(node))
	if auto_subscribe:
		subscribe_all()

func register_mapping(topic: String, message_class) -> void:
	_topic_to_class[topic] = message_class
	Log.debug("[ProtocolAdapter] Register mapping: %s" % topic)

func clear_mappings() -> void:
	_topic_to_class.clear()

func subscribe_all() -> void:
	if _transport == null:
		return
	Log.info("[ProtocolAdapter] Subscribing to %d topics" % SUBSCRIBE_TOPICS.size())
	for topic in SUBSCRIBE_TOPICS:
		_transport.subscribe(topic)

func send_message(topic: String, message) -> int:
	if _transport == null:
		return -1
	var payload = message.to_bytes()
	Log.debug("[ProtocolAdapter] Send message topic=%s size=%d" % [topic, payload.size()])
	return _transport.publish_bytes(topic, payload)

func send_keyboard_mouse_control(message) -> int:
	return send_message(TOPIC_KEYBOARD_MOUSE_CONTROL, message)

func send_custom_control(message) -> int:
	return send_message(TOPIC_CUSTOM_CONTROL, message)

func send_map_click_info_notify(message) -> int:
	return send_message(TOPIC_MAP_CLICK_INFO_NOTIFY, message)

func send_assembly_command(message) -> int:
	return send_message(TOPIC_ASSEMBLY_COMMAND, message)

func send_robot_performance_selection_command(message) -> int:
	return send_message(TOPIC_ROBOT_PERFORMANCE_SELECTION_COMMAND, message)

func send_common_command(message) -> int:
	return send_message(TOPIC_COMMON_COMMAND, message)

func send_hero_deploy_mode_event_command(message) -> int:
	return send_message(TOPIC_HERO_DEPLOY_MODE_EVENT_COMMAND, message)

func send_rune_activate_command(message) -> int:
	return send_message(TOPIC_RUNE_ACTIVATE_COMMAND, message)

func send_dart_command(message) -> int:
	return send_message(TOPIC_DART_COMMAND, message)

func send_sentry_ctrl_command(message) -> int:
	return send_message(TOPIC_SENTRY_CTRL_COMMAND, message)

func send_air_support_command(message) -> int:
	return send_message(TOPIC_AIR_SUPPORT_COMMAND, message)

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
	Log.info("[ProtocolAdapter] mqtt broker connected! try to subscribe topic.")
	if auto_subscribe:
		subscribe_all()

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
	var res = message.from_bytes(bytes)
	if res != RMProto.PB_ERR.NO_ERRORS:
		Log.warn("[ProtocolAdapter] Decode failed topic=%s err=%d" % [topic_str, res])
		emit_signal("decode_failed", topic_str, res)
		return
	Log.debug("[ProtocolAdapter] Decoded topic=%s" % topic_str)
	emit_signal("decoded_message", topic_str, message)
	_emit_topic_signal(topic_str, message)

func _emit_topic_signal(topic: String, message) -> void:
	var signal_name = TOPIC_SIGNAL_MAP.get(topic, "")
	if signal_name == "":
		Log.warn("[ProtocolAdapter] topic " + topic + " dosen't have corresponding signal.")
		return
	Log.debug("[ProtocolAdapter] topic " + topic + " emit signal " + " signal_name with content " + message)
	emit_signal(signal_name, message)

# func _mark_signals_used() -> void:
# 	if false:
# 		keyboard_mouse_control.emit(null)
# 		custom_control.emit(null)
# 		game_status.emit(null)
# 		global_unit_status.emit(null)
# 		global_logistics_status.emit(null)
# 		global_special_mechanism.emit(null)
# 		event_message.emit(null)
# 		robot_injury_stat.emit(null)
# 		robot_respawn_status.emit(null)
# 		robot_static_status.emit(null)
# 		robot_dynamic_status.emit(null)
# 		robot_module_status.emit(null)
# 		robot_position.emit(null)
# 		buff.emit(null)
# 		penalty_info.emit(null)
# 		robot_path_plan_info.emit(null)
# 		map_click_info_notify.emit(null)
# 		radar_info_to_client.emit(null)
# 		custom_byte_block.emit(null)
# 		assembly_command.emit(null)
# 		tech_core_motion_state_sync.emit(null)
# 		robot_performance_selection_command.emit(null)
# 		robot_performance_selection_sync.emit(null)
# 		common_command.emit(null)
# 		hero_deploy_mode_event_command.emit(null)
# 		deploy_mode_status_sync.emit(null)
# 		rune_activate_command.emit(null)
# 		rune_status_sync.emit(null)
# 		sentry_status_sync.emit(null)
# 		dart_command.emit(null)
# 		dart_select_target_status_sync.emit(null)
# 		sentry_ctrl_command.emit(null)
# 		sentry_ctrl_result.emit(null)
# 		air_support_command.emit(null)
# 		air_support_status_sync.emit(null)
