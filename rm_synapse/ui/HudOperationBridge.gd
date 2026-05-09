extends Node
class_name HudOperationBridge

signal operation_status(status)

const STATUS_IDLE := "idle"
const STATUS_PENDING := "pending"
const STATUS_SUCCESS := "success"
const STATUS_FAILED := "failed"

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

var assembly_command_service = AssemblyCommandService.new()
var performance_command_service = RobotPerformanceSelectionCommandService.new()
var exchange_17mm_service = CommonCommandExchange17mmService.new()
var exchange_42mm_service = CommonCommandExchange42mmService.new()
var confirm_respawn_service = CommonCommandConfirmRespawnService.new()
var buy_respawn_service = CommonCommandBuyRespawnService.new()
var remote_buy_ammo_service = CommonCommandRemoteBuyAmmoService.new()
var remote_buy_hp_service = CommonCommandRemoteBuyHpService.new()
var hero_deploy_service = HeroDeployModeEventCommandService.new()
var rune_activate_service = RuneActivateCommandService.new()
var dart_command_service = DartCommandService.new()
var sentry_ctrl_service = SentryCtrlCommandService.new()
var air_support_service = AirSupportCommandService.new()

var _pending_labels: Dictionary = {}

func _ready() -> void:
	_attach_services()
	_bind_status_signals()

func handle_operation(operation) -> void:
	if not (operation is Dictionary):
		_emit_immediate(STATUS_FAILED, "无效操作", "invalid", -1)
		return

	var operation_type := str(operation.get("type", ""))
	match operation_type:
		"performanceSelection":
			_handle_performance_selection(operation)
		"commonCommand":
			_handle_common_command(operation)
		"heroDeploy":
			_request_service("heroDeploy", "英雄部署", hero_deploy_service.request_hero_deploy_mode(int(operation.get("mode", 0))))
		"runeActivate":
			_request_service("runeActivate", "能量机关", rune_activate_service.request_rune_activate())
		"dart":
			_request_service(
				"dart",
				"飞镖指令",
				dart_command_service.request_dart_command(
					int(operation.get("targetId", 1)),
					bool(operation.get("open", false)),
					bool(operation.get("launchConfirm", false))
				)
			)
		"sentryCommand":
			_request_service("sentryCommand", "哨兵指令", sentry_ctrl_service.request_sentry_ctrl_command(int(operation.get("commandId", 0))))
		"airSupport":
			_request_service("airSupport", "空中支援", air_support_service.request_air_support_command(int(operation.get("commandId", 0))))
		"assembly":
			_request_service(
				"assembly",
				"工程装配",
				assembly_command_service.request_assembly_command(
					int(operation.get("operation", 0)),
					int(operation.get("difficulty", 0))
				)
			)
		_:
			_emit_immediate(STATUS_FAILED, "未知操作: %s" % operation_type, operation_type, -1)

func _attach_services() -> void:
	for service in _get_services():
		if service == null:
			continue
		if service.get("adapter_getter") != null:
			service.set("adapter_getter", adapter_getter)
		if service.get_parent() == null:
			add_child(service)

func _get_services() -> Array[Node]:
	return [
		assembly_command_service,
		performance_command_service,
		exchange_17mm_service,
		exchange_42mm_service,
		confirm_respawn_service,
		buy_respawn_service,
		remote_buy_ammo_service,
		remote_buy_hp_service,
		hero_deploy_service,
		rune_activate_service,
		dart_command_service,
		sentry_ctrl_service,
		air_support_service,
	]

func _bind_status_signals() -> void:
	_connect_request_service(assembly_command_service, "assembly", "工程装配")
	_connect_request_service(performance_command_service, "performanceSelection", "性能体系")
	_connect_request_service(hero_deploy_service, "heroDeploy", "英雄部署")
	_connect_request_service(rune_activate_service, "runeActivate", "能量机关")
	_connect_request_service(dart_command_service, "dart", "飞镖指令")
	_connect_request_service(sentry_ctrl_service, "sentryCommand", "哨兵指令")
	_connect_request_service(air_support_service, "airSupport", "空中支援")

func _connect_request_service(service: Object, operation_type: String, label: String) -> void:
	if service == null:
		return
	if service.has_signal("request_finished"):
		var finished := Callable(self, "_on_request_finished").bind(operation_type, label)
		if not service.is_connected("request_finished", finished):
			service.connect("request_finished", finished)

func _handle_performance_selection(operation: Dictionary) -> void:
	var role := str(operation.get("role", "infantry"))
	var shooter := 0
	var chassis := 0
	var sentry_control := 0

	if role == "sentry":
		sentry_control = 1 if str(operation.get("sentryMode", "auto")) == "semi" else 0
	else:
		chassis = 2 if str(operation.get("chassis", "hp")) == "power" else 1
		var firing := str(operation.get("firing", "burst"))
		if role == "hero":
			shooter = 4 if firing == "ranged" else 3
		else:
			shooter = 1 if firing == "cooldown" else 2

	_request_service(
		"performanceSelection",
		"性能体系",
		performance_command_service.request_robot_performance_selection(shooter, chassis, sentry_control)
	)

func _handle_common_command(operation: Dictionary) -> void:
	var command := str(operation.get("command", ""))
	var param := int(operation.get("param", 0))
	var result := -1
	var label := ""
	match command:
		"exchange17mm":
			label = "17mm兑换"
			result = exchange_17mm_service.send_once(param)
		"exchange42mm":
			label = "42mm兑换"
			result = exchange_42mm_service.send_once(param)
		"confirmRespawn":
			label = "确认复活"
			result = confirm_respawn_service.send_once(param)
		"buyRespawn":
			label = "立即复活"
			result = buy_respawn_service.send_once(param)
		"remoteBuyAmmo":
			label = "远程补弹"
			result = remote_buy_ammo_service.send_once(param)
		"remoteBuyHp":
			label = "远程回血"
			result = remote_buy_hp_service.send_once(param)
		_:
			_emit_immediate(STATUS_FAILED, "未知 CommonCommand: %s" % command, "commonCommand", -1)
			return

	_emit_immediate(STATUS_SUCCESS if result >= 0 else STATUS_FAILED, label, "commonCommand", result)

func _request_service(operation_type: String, label: String, request_id: int) -> void:
	if request_id <= 0:
		_emit_immediate(STATUS_FAILED, label, operation_type, -1)
		return
	_pending_labels[_make_pending_key(operation_type, request_id)] = label
	_emit_status(STATUS_PENDING, label, operation_type, request_id, 0)

func _on_request_finished(request_id, error_code, operation_type: String, label: String) -> void:
	var id := int(request_id)
	var code := int(error_code)
	var key := _make_pending_key(operation_type, id)
	var status_label := str(_pending_labels.get(key, label))
	_pending_labels.erase(key)
	var state := STATUS_SUCCESS if code == 0 else STATUS_FAILED
	_emit_status(state, status_label, operation_type, id, code)

func _emit_immediate(state: String, label: String, operation_type: String, code: int) -> void:
	_emit_status(state, label, operation_type, 0, code)

func _emit_status(state: String, label: String, operation_type: String, request_id: int, code: int) -> void:
	emit_signal("operation_status", {
		"state": state,
		"label": label,
		"operationType": operation_type,
		"requestId": request_id,
		"code": code,
		"timestamp": Time.get_ticks_msec(),
	})

func _make_pending_key(operation_type: String, request_id: int) -> String:
	return "%s:%d" % [operation_type, request_id]
