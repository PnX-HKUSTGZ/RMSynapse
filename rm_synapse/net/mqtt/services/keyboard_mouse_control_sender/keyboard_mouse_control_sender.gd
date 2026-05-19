extends Node
class_name KeyboardMouseControlSender

const SEND_HZ := 5.0
const SEND_INTERVAL_SEC := 1.0 / SEND_HZ

var adapter_getter: MQTTProtocolAdapterGetter
@export var auto_start: bool = true

var _data := AdapterTypes.KeyboardMouseControlData.new()
var _timer: Timer
var _logged_missing: bool = false

func _ready() -> void:
	if adapter_getter == null:
		adapter_getter = MQTTProtocolAdapterGetter.new()
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = SEND_INTERVAL_SEC
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	if auto_start:
		start_sending()

func update_data(data: AdapterTypes.KeyboardMouseControlData) -> void:
	if data == null:
		return
	_data.mouse_x = data.mouse_x
	_data.mouse_y = data.mouse_y
	_data.mouse_z = data.mouse_z
	_data.left_button_down = data.left_button_down
	_data.right_button_down = data.right_button_down
	_data.keyboard_value = data.keyboard_value
	_data.mid_button_down = data.mid_button_down

func start_sending() -> void:
	if _timer == null:
		return
	_timer.start()

func stop_sending() -> void:
	if _timer == null:
		return
	_timer.stop()

func is_sending() -> bool:
	return _timer != null and not _timer.is_stopped()

func _on_tick() -> void:
	var adapter = _get_adapter()
	if adapter == null:
		return
	adapter.send_keyboard_mouse_control(_data)
	_data.mouse_x = 0
	_data.mouse_y = 0
	_data.mouse_z = 0

func _get_adapter() -> ProtocolAdapter:
	if adapter_getter == null:
		if not _logged_missing:
			Log.error("[KeyboardMouseControlSender] adapter_getter is not set.")
			_logged_missing = true
		return null
	var adapter = null
	if adapter_getter.has_method("get_adapter_silent"):
		adapter = adapter_getter.get_adapter_silent()
	else:
		adapter = adapter_getter.get_adapter()
	if adapter == null:
		if not _logged_missing:
			Log.error("[KeyboardMouseControlSender] ProtocolAdapter not available.")
			_logged_missing = true
		return null
	_logged_missing = false
	return adapter
