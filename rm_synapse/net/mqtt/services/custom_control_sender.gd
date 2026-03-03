extends Node
class_name CustomControlSender

const SEND_HZ := 75.0
const SEND_INTERVAL_SEC := 1.0 / SEND_HZ

var adapter_getter: MQTTProtocolAdapterGetter

@export var auto_start: bool = true

var _data := AdapterTypes.CustomControlData.new()
var _timer: Timer
var _logged_missing: bool = false

func _ready() -> void:
	adapter_getter = MQTTProtocolAdapterGetter.new()
	
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = SEND_INTERVAL_SEC
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	if auto_start:
		start_sending()

func update_data(data: AdapterTypes.CustomControlData) -> void:
	if data == null:
		return
	if data.data is PackedByteArray:
		_data.data = data.data.duplicate()
	else:
		_data.data = PackedByteArray()

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
	adapter.send_custom_control(_data)

func _get_adapter() -> ProtocolAdapter:
	if adapter_getter == null:
		if not _logged_missing:
			Log.error("[CustomControlSender] adapter_getter is not set.")
			_logged_missing = true
		return null
	var adapter = adapter_getter.get_adapter()
	if adapter == null:
		if not _logged_missing:
			Log.error("[CustomControlSender] ProtocolAdapter not available.")
			_logged_missing = true
		return null
	_logged_missing = false
	return adapter
