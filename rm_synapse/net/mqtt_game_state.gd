extends Node
class_name MQTTGameState

# 单节点整合：
# - MQTT 连接/订阅/重连/解码（原 mqtt_receiver 功能）
# - 状态存储、按 topic 发专用信号、线程安全 inbox（原 GameState 功能）
#
# 用法：
# 1) 在场景中添加本脚本节点（建议 AutoLoad 名称 GameState 以兼容原调用）。
# 2) 作为子节点放置 addons/mqtt/mqtt.tscn 并命名为 "MQTT"；如果缺少，会在运行时自动实例化。
# 3) 订阅 GameState 信号或各 topic 专用信号获取最新状态；消息会自动从 MQTT 解码并入库。

@export var subscribe_topics: Array[String] = [
	"GameStatus", "GlobalUnitStatus", "GlobalLogisticsStatus", "GlobalSpecialMechanism",
	"Event", "RobotInjuryStat", "RobotRespawnStatus", "RobotStaticStatus", "RobotDynamicStatus",
	"RobotModuleStatus", "RobotPosition", "Buff", "PenaltyInfo", "RobotPathPlanInfo",
	"RaderInfoToClient", "RobotPerformanceSelectionSync", "DeployModeStatusSync",
	"TechCoreMotionStateSync", "RuneStatusSync", "SentinelStatusSync",
	"DartSelectTargetStatusSync", "GuardCtrlResult", "AirSupportStatusSync", "CustomByteBlock"
]
@export var broker_url: String = "tcp://192.168.12.1:3333"
@export var client_id: String = ""
@export var username: String = ""
@export var password: String = ""
@export_enum("off", "info", "debug", "trace") var verbose: String = "info"
@export var reconnect_delay_sec: float = 2.0
@export var reconnect_max_sec: float = 30.0
@export var dump_payload_hex_len: int = 32      # 解码失败时输出的十六进制预览长度
@export var log_decode_errors_only: bool = false # 为 true 时，仅在解码失败时打印收包摘要

# MQTT 连接信号
signal mqtt_connected
signal mqtt_connection_failed
signal mqtt_disconnected

# 状态信号（原 GameState）
signal state_changed(key, value)
signal batch_applied(count)
signal game_status_updated(value)
signal global_unit_status_updated(value)
signal global_logistics_status_updated(value)
signal global_special_mechanism_updated(value)
signal event_received(value)
signal robot_injury_stat_updated(value)
signal robot_respawn_status_updated(value)
signal robot_static_status_updated(value)
signal robot_dynamic_status_updated(value)
signal robot_module_status_updated(value)
signal robot_position_updated(value)
signal buff_updated(value)
signal penalty_info_updated(value)
signal robot_path_plan_info_updated(value)
signal rader_info_updated(value)
signal robot_performance_selection_sync_updated(value)
signal deploy_mode_status_sync_updated(value)
signal tech_core_motion_state_sync_updated(value)
signal rune_status_sync_updated(value)
signal sentinel_status_sync_updated(value)
signal dart_select_target_status_sync_updated(value)
signal guard_ctrl_result_updated(value)
signal air_support_status_sync_updated(value)
signal custom_byte_block_received(value)
signal unknown_message_received(msg)

const Proto = preload("res://protocol/generated/rm_proto.gd")

# MQTT 节点引用；统一复用外部实例（建议 AutoLoad 名为 MQTT，或场景节点名为 MQTT）
@export var mqtt_path: NodePath = NodePath("MQTT")
@onready var mqtt: Node = _resolve_mqtt()
var _next_delay := reconnect_delay_sec

# 状态存储
var _data: Dictionary = {}
var game_status := {}
var global_unit_status := {}
var global_logistics_status := {}
var global_special_mechanism := {}
var event_data := {}
var robot_injury_stat := {}
var robot_respawn_status := {}
var robot_static_status := {}
var robot_dynamic_status := {}
var robot_module_status := {}
var robot_position := {}
var buff := {}
var penalty_info := {}
var robot_path_plan_info := {}
var rader_info := {}
var robot_performance_selection_sync := {}
var deploy_mode_status_sync := {}
var tech_core_motion_state_sync := {}
var rune_status_sync := {}
var sentinel_status_sync := {}
var dart_select_target_status_sync := {}
var guard_ctrl_result := {}
var air_support_status_sync := {}
var custom_byte_block := {}

# inbox 用于跨线程安全写入
var _inbox: Array = []          # 解码成功的数据
var _inbox_raw: Array = []      # 解码失败或未解码的原始数据
var _inbox_mutex := Mutex.new()

func _ready() -> void:
	_connect_mqtt_signals()
	_start()

func _process(_delta: float) -> void:
	_drain_inbox()
	_drain_inbox_raw()

#================ MQTT 部分 =================

func _resolve_mqtt() -> Node:
	# 优先使用 AutoLoad 单例 “MQTT”
	if Engine.has_singleton("MQTT"):
		_log_info("Using MQTT singleton instance")
		return Engine.get_singleton("MQTT")
	# 其次尝试 /root/MQTT
	var root_mqtt = get_node_or_null("/root/MQTT")
	if root_mqtt != null:
		_log_info("Using /root/MQTT instance")
		return root_mqtt
	# 再尝试导出的路径（场景内节点）
	if mqtt_path != NodePath("") and has_node(mqtt_path):
		return get_node(mqtt_path)
	push_error("MQTT instance not found. Ensure AutoLoad MQTT or set mqtt_path to existing node.")
	return null

func _connect_mqtt_signals() -> void:
	if mqtt == null:
		push_error("MQTT node missing; please set mqtt_path to shared MQTT instance.")
		return
	mqtt.binarymessages = true
	mqtt.verbose_level = _mqtt_verbose_level()
	if client_id != "": mqtt.client_id = client_id
	if username != "": mqtt.user = username
	if password != "": mqtt.pswd = password
	mqtt.connect("received_message", Callable(self, "_on_received_message"))
	mqtt.connect("broker_connected", Callable(self, "_on_connected"))
	mqtt.connect("broker_connection_failed", Callable(self, "_on_failed"))
	mqtt.connect("broker_disconnected", Callable(self, "_on_disconnected"))
	_log_info("Signals connected; client_id=%s" % client_id)

func _start() -> void:
	if mqtt == null:
		push_error("MQTT node missing; cannot start connection.")
		return
	_log_info("Connecting to %s" % broker_url)
	mqtt.connect_to_broker(broker_url)

func _on_connected() -> void:
	_log_info("Connected, subscribing %d topics" % subscribe_topics.size())
	for t in subscribe_topics:
		mqtt.subscribe(t, 1)
	_next_delay = reconnect_delay_sec
	mqtt_connected.emit()

func _on_failed() -> void:
	_log_warn("Connection failed; scheduling reconnect in %.2fs" % _next_delay)
	mqtt_connection_failed.emit()
	_schedule_reconnect()

func _on_disconnected() -> void:
	_log_warn("Disconnected; scheduling reconnect in %.2fs" % _next_delay)
	mqtt_disconnected.emit()
	_schedule_reconnect()

func _schedule_reconnect() -> void:
	if mqtt == null:
		return
	var delay = _next_delay
	_next_delay = min(_next_delay * 2.0, reconnect_max_sec)
	get_tree().create_timer(delay).timeout.connect(func():
		_log_info("Reconnecting...")
		_start()
	, CONNECT_DEFERRED)

func _on_received_message(topic: String, payload) -> void:
	# payload 是二进制 PackedByteArray
	if payload.size() == 0:
		_log_warn("Recv %s empty payload, dropped" % topic)
		return
	var decoded = _decode(topic, payload)
	if decoded == null:
		if not log_decode_errors_only:
			_log_debug("Recv %s len=%d (raw)" % [topic, payload.size()])
		enqueue_raw_message({"topic": topic, "data": payload})
	else:
		_log_debug("Recv %s len=%d decoded=%s" % [topic, payload.size(), decoded])
		enqueue_message({"topic": topic, "data": decoded})

func _decode(topic: String, payload: PackedByteArray):
	var msg
	match topic:
		"GameStatus":
			msg = Proto.GameStatus.new()
		"GlobalUnitStatus":
			msg = Proto.GlobalUnitStatus.new()
		"GlobalLogisticsStatus":
			msg = Proto.GlobalLogisticsStatus.new()
		"GlobalSpecialMechanism":
			msg = Proto.GlobalSpecialMechanism.new()
		"Event":
			msg = Proto.Event.new()
		"RobotInjuryStat":
			msg = Proto.RobotInjuryStat.new()
		"RobotRespawnStatus":
			msg = Proto.RobotRespawnStatus.new()
		"RobotStaticStatus":
			msg = Proto.RobotStaticStatus.new()
		"RobotDynamicStatus":
			msg = Proto.RobotDynamicStatus.new()
		"RobotModuleStatus":
			msg = Proto.RobotModuleStatus.new()
		"RobotPosition":
			msg = Proto.RobotPosition.new()
		"Buff":
			msg = Proto.Buff.new()
		"PenaltyInfo":
			msg = Proto.PenaltyInfo.new()
		"RobotPathPlanInfo":
			msg = Proto.RobotPathPlanInfo.new()
		"RaderInfoToClient":
			msg = Proto.RaderInfoToClient.new()
		"RobotPerformanceSelectionSync":
			msg = Proto.RobotPerformanceSelectionSync.new()
		"DeployModeStatusSync":
			msg = Proto.DeployModeStatusSync.new()
		"TechCoreMotionStateSync":
			msg = Proto.TechCoreMotionStateSync.new()
		"RuneStatusSync":
			msg = Proto.RuneStatusSync.new()
		"SentinelStatusSync":
			msg = Proto.SentinelStatusSync.new()
		"DartSelectTargetStatusSync":
			msg = Proto.DartSelectTargetStatusSync.new()
		"GuardCtrlResult":
			msg = Proto.GuardCtrlResult.new()
		"AirSupportStatusSync":
			msg = Proto.AirSupportStatusSync.new()
		"CustomByteBlock":
			msg = Proto.CustomByteBlock.new()
		_:
			return null
	var err = msg.from_bytes(payload)
	if err != Proto.PB_ERR.NO_ERRORS and err != 0:
		_log_warn("Decode failed for %s err=%s hex=%s" % [topic, err, _hex_preview(payload)])
		return null
	return msg

#================ 状态存储 / 信号部分 =================

func enqueue_message(msg) -> void:
	# 线程安全入队；msg 结构 {"topic": topic, "data": decoded_object}
	_inbox_mutex.lock()
	_inbox.append(msg)
	_inbox_mutex.unlock()

func enqueue_raw_message(msg) -> void:
	# 线程安全入队原始二进制；msg 结构 {"topic": topic, "data": PackedByteArray}
	_inbox_mutex.lock()
	_inbox_raw.append(msg)
	_inbox_mutex.unlock()

func _drain_inbox() -> void:
	_inbox_mutex.lock()
	var batch := _inbox
	_inbox = []
	_inbox_mutex.unlock()
	if batch.is_empty():
		return
	for msg in batch:
		_handle_incoming(msg)

func _drain_inbox_raw() -> void:
	_inbox_mutex.lock()
	var batch := _inbox_raw
	_inbox_raw = []
	_inbox_mutex.unlock()
	if batch.is_empty():
		return
	for msg in batch:
		_emit_unknown(msg) # 原始数据不做存储和相等比较

func _handle_incoming(msg) -> void:
	if typeof(msg) == TYPE_DICTIONARY and msg.has("topic") and msg.has("data"):
		_apply_topic(msg["topic"], msg["data"])
	else:
		_log_warn("Malformed inbox message: %s" % msg)

func _apply_topic(topic: String, data) -> void:
	match topic:
		"GameStatus":
			_store_and_emit("game_status", data, game_status_updated)
		"GlobalUnitStatus":
			_store_and_emit("global_unit_status", data, global_unit_status_updated)
		"GlobalLogisticsStatus":
			_store_and_emit("global_logistics_status", data, global_logistics_status_updated)
		"GlobalSpecialMechanism":
			_store_and_emit("global_special_mechanism", data, global_special_mechanism_updated)
		"Event":
			_store_and_emit("event_data", data, event_received)
		"RobotInjuryStat":
			_store_and_emit("robot_injury_stat", data, robot_injury_stat_updated)
		"RobotRespawnStatus":
			_store_and_emit("robot_respawn_status", data, robot_respawn_status_updated)
		"RobotStaticStatus":
			_store_and_emit("robot_static_status", data, robot_static_status_updated)
		"RobotDynamicStatus":
			_store_and_emit("robot_dynamic_status", data, robot_dynamic_status_updated)
		"RobotModuleStatus":
			_store_and_emit("robot_module_status", data, robot_module_status_updated)
		"RobotPosition":
			_store_and_emit("robot_position", data, robot_position_updated)
		"Buff":
			_store_and_emit("buff", data, buff_updated)
		"PenaltyInfo":
			_store_and_emit("penalty_info", data, penalty_info_updated)
		"RobotPathPlanInfo":
			_store_and_emit("robot_path_plan_info", data, robot_path_plan_info_updated)
		"RaderInfoToClient":
			_store_and_emit("rader_info", data, rader_info_updated)
		"RobotPerformanceSelectionSync":
			_store_and_emit("robot_performance_selection_sync", data, robot_performance_selection_sync_updated)
		"DeployModeStatusSync":
			_store_and_emit("deploy_mode_status_sync", data, deploy_mode_status_sync_updated)
		"TechCoreMotionStateSync":
			_store_and_emit("tech_core_motion_state_sync", data, tech_core_motion_state_sync_updated)
		"RuneStatusSync":
			_store_and_emit("rune_status_sync", data, rune_status_sync_updated)
		"SentinelStatusSync":
			_store_and_emit("sentinel_status_sync", data, sentinel_status_sync_updated)
		"DartSelectTargetStatusSync":
			_store_and_emit("dart_select_target_status_sync", data, dart_select_target_status_sync_updated)
		"GuardCtrlResult":
			_store_and_emit("guard_ctrl_result", data, guard_ctrl_result_updated)
		"AirSupportStatusSync":
			_store_and_emit("air_support_status_sync", data, air_support_status_sync_updated)
		"CustomByteBlock":
			_store_and_emit("custom_byte_block", data, custom_byte_block_received)
		_:
			_emit_unknown({"topic": topic, "data": data})

func _store_and_emit(field_name: String, value, sig: Signal) -> void:
	self.set(field_name, value)
	_data[field_name] = value
	sig.emit(value)
	state_changed.emit(field_name, value)

func _emit_unknown(payload) -> void:
	_log_warn("Unknown topic payload: %s" % payload)
	unknown_message_received.emit(payload)

func set_value(key: String, value) -> void:
	if _data.get(key) == value:
		return
	_data[key] = value
	state_changed.emit(key, value)

func set_many(pairs: Dictionary) -> void:
	var changed := 0
	for k in pairs.keys():
		if _data.get(k) != pairs[k]:
			_data[k] = pairs[k]
			state_changed.emit(k, pairs[k])
			changed += 1
	if changed > 0:
		batch_applied.emit(changed)

func get_value(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)

func snapshot() -> Dictionary:
	return _data.duplicate(true) # 深拷贝防修改

func clear() -> void:
	_data.clear()

#================ 日志辅助 =================

const LVL_OFF := 0
const LVL_INFO := 1
const LVL_DEBUG := 2
const LVL_TRACE := 3

func _vlevel() -> int:
	match verbose:
		"off": return LVL_OFF
		"debug": return LVL_DEBUG
		"trace": return LVL_TRACE
		_: return LVL_INFO

func _mqtt_verbose_level() -> int:
	# map string level to plugin int level (0 quiet,1 basic,2 verbose)
	var v = _vlevel()
	if v <= LVL_OFF:
		return 0
	elif v == LVL_INFO:
		return 1
	else:
		return 2

func _lvl_name(level:int) -> String:
	match level:
		LVL_INFO: return "INFO"
		LVL_DEBUG: return "DEBUG"
		LVL_TRACE: return "TRACE"
		_: return "OFF"

func _log(level:int, msg:String) -> void:
	if level <= _vlevel() and level > LVL_OFF:
		print("%s [MQTTState][%s] %s" % [Time.get_datetime_string_from_system(), _lvl_name(level), msg])

func _log_info(msg:String) -> void:
	_log(LVL_INFO, msg)

func _log_debug(msg:String) -> void:
	_log(LVL_DEBUG, msg)

func _log_trace(msg:String) -> void:
	_log(LVL_TRACE, msg)

func _log_warn(msg:String) -> void:
	print("%s [MQTTState][WARN] %s" % [Time.get_datetime_string_from_system(), msg])

func _hex_preview(payload: PackedByteArray) -> String:
	var n = min(payload.size(), dump_payload_hex_len)
	var hex := PackedStringArray()
	for i in range(n):
		hex.append("%02X" % payload[i])
	return "".join(hex)
