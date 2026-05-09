extends Node

const EXPECTED_SIGNALS := {
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

@export var timeout_sec: float = 15.0

var hud_data_bridge := HudDataBridge.new()
var adapter_getter := MQTTProtocolAdapterGetter.new()
var _adapter: ProtocolAdapter = null
var _elapsed := 0.0
var _ready_printed := false
var _received := {}


func _ready() -> void:
	add_child(hud_data_bridge)
	for signal_name in EXPECTED_SIGNALS.keys():
		if not hud_data_bridge.has_signal(signal_name):
			push_error("HudDataBridge missing signal: %s" % signal_name)
			get_tree().quit(1)
			return
		var callback := Callable(self, "_on_bridge_signal").bind(String(signal_name), String(EXPECTED_SIGNALS[signal_name]))
		if not hud_data_bridge.is_connected(signal_name, callback):
			hud_data_bridge.connect(signal_name, callback)
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_try_bind_adapter()
	if not _ready_printed and _is_transport_connected():
		_ready_printed = true
		print("HUD_API_RECEIVE_READY")
	if _received.size() >= EXPECTED_SIGNALS.size():
		print("HUD_API_RECEIVE_OK %s" % JSON.stringify(_received))
		get_tree().quit(0)
		return
	if _elapsed >= timeout_sec:
		var missing := _get_missing_topics()
		push_error("HUD_API_RECEIVE_TIMEOUT missing=%s" % JSON.stringify(missing))
		print("HUD_API_RECEIVE_TIMEOUT %s" % JSON.stringify({
			"missing": missing,
			"received": _received.keys()
		}))
		get_tree().quit(1)


func _try_bind_adapter() -> void:
	if _adapter != null and is_instance_valid(_adapter):
		return
	var adapter = adapter_getter.get_adapter_silent()
	if adapter == null:
		return
	_adapter = adapter
	if not _adapter.decoded_message.is_connected(_on_decoded_message):
		_adapter.decoded_message.connect(_on_decoded_message)


func _is_transport_connected() -> bool:
	var transport = adapter_getter.get_transport()
	return transport != null and transport.has_method("is_broker_connected") and transport.is_broker_connected()


func _on_decoded_message(topic, _message) -> void:
	print("HUD_API_DECODED %s" % str(topic))


func _on_bridge_signal(value, signal_name: String, proto_key: String) -> void:
	var normalized = _normalize_value(proto_key, value)
	_received[proto_key] = normalized
	print("HUD_API_RECV %s" % JSON.stringify({
		"topic": proto_key,
		"signal": signal_name,
		"payload": normalized
	}))


func _normalize_value(proto_key: String, value):
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


func _get_missing_topics() -> Array[String]:
	var missing: Array[String] = []
	for topic in EXPECTED_SIGNALS.values():
		if not _received.has(topic):
			missing.append(String(topic))
	return missing
