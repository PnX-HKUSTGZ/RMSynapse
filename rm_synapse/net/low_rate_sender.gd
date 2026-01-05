extends Node
class_name LowRateSender

# 固定低频上行通道，内置所有低频 topic，定时发送最近一次设定的状态。
# 上层只调用类型化的 setter，不接触字节流。

@export var mqtt_sender_path: NodePath = NodePath("/root/MQTTSender")
@export_enum("off", "info", "debug") var verbose: String = "info"

@export var interval_sec: float = 1.0 # 默认 1Hz，适用于所有低频 topic

const Proto = preload("res://protocol/generated/rm_proto.gd")

const LVL_OFF := 0
const LVL_INFO := 1
const LVL_DEBUG := 2

var sender: MqttSender
var _timer: Timer

# 低频上行状态缓存（最新一次设定）
var _guard_ctrl: Dictionary = {"command_id": 0}                   # 0=无效
var _hero_deploy: Dictionary = {"mode": 0}                        # 0=退出
var _rune_activate: Dictionary = {"activate": 0}                  # 0=未激活
var _perf_select: Dictionary = {"shooter": 0, "chassis": 0}       # 未选择
var _assembly: Dictionary = {"operation": 0, "difficulty": 0}     # 未操作
var _assembly_pending: bool = false                               # 是否待发送
var _air_support: Dictionary = {"command_id": 0}                  # 未呼叫
var _dart_cmd: Dictionary = {"target_id": 0, "open": false}       # 默认不打开

func _ready() -> void:
	sender = _resolve_sender()
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = interval_sec
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(func(): _tick(), CONNECT_DEFERRED)
	_log(LVL_INFO, "LowRateSender started interval=%.2fs" % interval_sec)

func set_guard_ctrl_command(command_id: int) -> void:
	_guard_ctrl = {"command_id": command_id}

func set_hero_deploy_mode(mode: int) -> void:
	_hero_deploy = {"mode": mode}

func set_rune_activate(activate: int) -> void:
	_rune_activate = {"activate": activate}

func set_robot_performance_selection(shooter: int, chassis: int) -> void:
	_perf_select = {"shooter": shooter, "chassis": chassis}

func set_assembly_command(operation: int, difficulty: int) -> void:
	_assembly = {"operation": operation, "difficulty": difficulty}
	_assembly_pending = true

func set_air_support_command(command_id: int) -> void:
	_air_support = {"command_id": command_id}

func set_dart_command(target_id: int, open: bool) -> void:
	_dart_cmd = {"target_id": target_id, "open": open}

func _tick() -> void:
	if sender == null:
		_log(LVL_DEBUG, "No sender; skip tick")
		return
	_send_guard_ctrl()
	_send_hero_deploy()
	_send_rune_activate()
	_send_perf_select()
	_send_assembly()
	_send_air_support()
	_send_dart()

func _send_guard_ctrl():
	if _guard_ctrl == null:
		return
	var msg = Proto.GuardCtrlCommand.new()
	msg.set_command_id(_guard_ctrl.get("command_id", 0))
	sender.publish_now("GuardCtrlCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent GuardCtrlCommand id=%d" % _guard_ctrl.get("command_id", 0))

func _send_hero_deploy():
	if _hero_deploy == null:
		return
	var msg = Proto.HeroDeployModeEventCommand.new()
	msg.set_mode(_hero_deploy.get("mode", 0))
	sender.publish_now("HeroDeployModeEventCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent HeroDeployModeEvent mode=%d" % _hero_deploy.get("mode", 0))

func _send_rune_activate():
	if _rune_activate == null:
		return
	var msg = Proto.RuneActivateCommand.new()
	msg.set_activate(_rune_activate.get("activate", 0))
	sender.publish_now("RuneActivateCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent RuneActivate activate=%d" % _rune_activate.get("activate", 0))

func _send_perf_select():
	if _perf_select == null:
		return
	var msg = Proto.RobotPerformanceSelectionCommand.new()
	msg.set_shooter(_perf_select.get("shooter", 0))
	msg.set_chassis(_perf_select.get("chassis", 0))
	sender.publish_now("RobotPerformanceSelectionCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent PerfSelection shooter=%d chassis=%d" % [_perf_select.get("shooter", 0), _perf_select.get("chassis", 0)])

func _send_assembly():
	if _assembly == null or not _assembly_pending:
		return
	var msg = Proto.AssemblyCommand.new()
	msg.set_operation(_assembly.get("operation", 0))
	msg.set_difficulty(_assembly.get("difficulty", 0))
	sender.publish_now("AssemblyCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent Assembly op=%d diff=%d" % [_assembly.get("operation", 0), _assembly.get("difficulty", 0)])
	# 发送完成后置零，避免持续重复下发
	_assembly = {"operation": 0, "difficulty": 0}
	_assembly_pending = false

func _send_air_support():
	if _air_support == null:
		return
	var msg = Proto.AirSupportCommand.new()
	msg.set_command_id(_air_support.get("command_id", 0))
	sender.publish_now("AirSupportCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent AirSupport cmd=%d" % _air_support.get("command_id", 0))

func _send_dart():
	if _dart_cmd == null:
		return
	var msg = Proto.DartCommand.new()
	msg.set_target_id(_dart_cmd.get("target_id", 0))
	msg.set_open(_dart_cmd.get("open", false))
	sender.publish_now("DartCommand", msg.to_bytes(), 1, false)
	_log(LVL_DEBUG, "Sent DartCommand target_id=%d open=%s" % [_dart_cmd.get("target_id", 0), str(_dart_cmd.get("open", false))])

func _resolve_sender() -> MqttSender:
	if Engine.has_singleton("MQTTSender"):
		_log(LVL_INFO, "Using AutoLoad MQTTSender instance")
		return Engine.get_singleton("MQTTSender")
	if mqtt_sender_path != NodePath("") and has_node(mqtt_sender_path):
		_log(LVL_INFO, "Using MQTTSender instance at %s" % str(mqtt_sender_path))
		return get_node(mqtt_sender_path) as MqttSender
	push_error("MQTTSender not found; set mqtt_sender_path.")
	return null

func _log(level:int, msg:String) -> void:
	var v:int
	match verbose:
		"debug": v = LVL_DEBUG
		"info": v = LVL_INFO
		_: v = LVL_OFF
	if level <= v and level > LVL_OFF:
		print("%s [LowRateSender][%s] %s" % [Time.get_datetime_string_from_system(), ("DEBUG" if level==LVL_DEBUG else "INFO"), msg])
