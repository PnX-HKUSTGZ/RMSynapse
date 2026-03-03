extends Node
class_name RobotModuleStatusService

signal robot_module_status_updated(state)
signal critical_module_changed(main_controller, power_manager, armor)

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class RobotModuleStatusState:
	extends RefCounted
	var power_manager: int = 0
	var rfid: int = 0
	var light_strip: int = 0
	var small_shooter: int = 0
	var big_shooter: int = 0
	var uwb: int = 0
	var armor: int = 0
	var video_transmission: int = 0
	var capacitor: int = 0
	var main_controller: int = 0
	var laser_detection_module: int = 0
	var last_update_msec: int = 0

	func clone() -> RobotModuleStatusState:
		var c = RobotModuleStatusState.new()
		c.power_manager = power_manager
		c.rfid = rfid
		c.light_strip = light_strip
		c.small_shooter = small_shooter
		c.big_shooter = big_shooter
		c.uwb = uwb
		c.armor = armor
		c.video_transmission = video_transmission
		c.capacitor = capacitor
		c.main_controller = main_controller
		c.laser_detection_module = laser_detection_module
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"power_manager": power_manager,
			"rfid": rfid,
			"light_strip": light_strip,
			"small_shooter": small_shooter,
			"big_shooter": big_shooter,
			"uwb": uwb,
			"armor": armor,
			"video_transmission": video_transmission,
			"capacitor": capacitor,
			"main_controller": main_controller,
			"laser_detection_module": laser_detection_module,
			"last_update_msec": last_update_msec
		}

var _state: RobotModuleStatusState = RobotModuleStatusState.new()
var _bound_adapter = null
var _bind_retry_elapsed: float = 0.0
var _logged_missing: bool = false
var _logged_null_message: bool = false

func _ready() -> void:
	_try_bind_adapter()
	set_process(true)

func _process(delta: float) -> void:
	var interval = maxf(bind_retry_interval_sec, 0.1)
	_bind_retry_elapsed += delta
	if _bind_retry_elapsed < interval:
		return
	_bind_retry_elapsed = 0.0
	_try_bind_adapter()

func _exit_tree() -> void:
	_disconnect_bound_adapter()

func clear_cache() -> void:
	var old_state = _state.clone()
	_state = RobotModuleStatusState.new()
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_module_status_updated", _state.clone())

func ingest_robot_module_status(message) -> void:
	_on_robot_module_status(message)

func get_state() -> RobotModuleStatusState:
	return _state.clone()

func get_power_manager() -> int:
	return _state.power_manager

func get_rfid() -> int:
	return _state.rfid

func get_light_strip() -> int:
	return _state.light_strip

func get_small_shooter() -> int:
	return _state.small_shooter

func get_big_shooter() -> int:
	return _state.big_shooter

func get_uwb() -> int:
	return _state.uwb

func get_armor() -> int:
	return _state.armor

func get_video_transmission() -> int:
	return _state.video_transmission

func get_capacitor() -> int:
	return _state.capacitor

func get_main_controller() -> int:
	return _state.main_controller

func get_laser_detection_module() -> int:
	return _state.laser_detection_module

func _on_robot_module_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[RobotModuleStatusService] Received null robot_module_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()
	_state.power_manager = int(message.get_power_manager())
	_state.rfid = int(message.get_rfid())
	_state.light_strip = int(message.get_light_strip())
	_state.small_shooter = int(message.get_small_shooter())
	_state.big_shooter = int(message.get_big_shooter())
	_state.uwb = int(message.get_uwb())
	_state.armor = int(message.get_armor())
	_state.video_transmission = int(message.get_video_transmission())
	_state.capacitor = int(message.get_capacitor())
	_state.main_controller = int(message.get_main_controller())
	_state.laser_detection_module = int(message.get_laser_detection_module())
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("robot_module_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotModuleStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter_silent() if adapter_getter.has_method("get_adapter_silent") else adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotModuleStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object) or not adapter.has_signal("robot_module_status"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[RobotModuleStatusService] Adapter is invalid or missing signal: robot_module_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.robot_module_status.is_connected(_on_robot_module_status):
		adapter.robot_module_status.connect(_on_robot_module_status)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("robot_module_status") and _bound_adapter.robot_module_status.is_connected(_on_robot_module_status):
			_bound_adapter.robot_module_status.disconnect(_on_robot_module_status)
	_bound_adapter = null

func _emit_change_signals(old_state: RobotModuleStatusState) -> void:
	if _state.main_controller != old_state.main_controller or _state.power_manager != old_state.power_manager or _state.armor != old_state.armor:
		emit_signal("critical_module_changed", _state.main_controller, _state.power_manager, _state.armor)

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)

func _log_warn(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("warn"):
		logger.warn(message)
		return
	push_warning(message)
