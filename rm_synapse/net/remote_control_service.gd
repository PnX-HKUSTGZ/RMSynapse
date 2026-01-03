extends Node
class_name RemoteControlService

# High-rate RemoteControl sender (e.g., 75Hz), latest-only.

@export var mqtt_sender_path: NodePath = NodePath("/root/MQTTSender")
@export var rate_hz: float = 75.0
@export var qos: int = 0
@export var clear_custom_after_send: bool = true
@export_enum("off", "info", "debug") var verbose: String = "info"

const Proto = preload("res://protocol/generated/rm_proto.gd")

var sender: MqttSender
var _accum: float = 0.0
var _state := {
	"mouse_x": 0,
	"mouse_y": 0,
	"mouse_z": 0,
	"l": false,
	"r": false,
	"m": false,
	"mask": 0,
	"custom": PackedByteArray()
}

func _ready() -> void:
	sender = _resolve_sender()

func _physics_process(delta: float) -> void:
	if sender == null:
		return
	_accum += delta
	var period = 1.0 / max(rate_hz, 1.0)
	if _accum >= period:
		_accum = 0.0
		_send_remote_control()

func update_mouse(dx:int, dy:int, dz:int) -> void:
	_state.mouse_x = dx
	_state.mouse_y = dy
	_state.mouse_z = dz

func set_buttons(l:bool, r:bool, m:bool) -> void:
	_state.l = l
	_state.r = r
	_state.m = m

func set_keyboard_mask(mask: int) -> void:
	_state.mask = mask

func set_custom_data(data: PackedByteArray, clear_after_send: bool = true) -> void:
	_state.custom = data
	clear_custom_after_send = clear_after_send

func _send_remote_control() -> void:
	var msg = Proto.RemoteControl.new()
	msg.set_mouse_x(_state.mouse_x)
	msg.set_mouse_y(_state.mouse_y)
	msg.set_mouse_z(_state.mouse_z)
	msg.set_left_button_down(_state.l)
	msg.set_right_button_down(_state.r)
	msg.set_keyboard_value(_state.mask)
	msg.set_mid_button_down(_state.m)
	# custom bytes length <=30
	var custom = _state.custom
	if custom.size() > 30:
		custom = custom.slice(0, 30)
	msg.set_data(custom)
	var payload = msg.to_bytes()
	sender.enqueue_latest("RemoteControl", payload, qos, false)
	_log("DEBUG", "len=%d data=%s mask=%d l=%s r=%s m=%s" % [
		payload.size(),
		str(custom),
		_state.mask,
		str(_state.l),
		str(_state.r),
		str(_state.m)
	])
	if clear_custom_after_send:
		_state.custom = PackedByteArray()

func _log(level:String, msg:String) -> void:
	var v
	match verbose:
		"debug": v = "DEBUG"
		"info": v = "INFO"
		_: v = "OFF"
	if level == "DEBUG" and v != "DEBUG":
		return
	if level == "INFO" and v == "OFF":
		return
	if level == "OFF":
		return
	print("%s [RemoteCtrl][%s] %s" % [Time.get_datetime_string_from_system(), level, msg])

func _resolve_sender() -> MqttSender:
	if Engine.has_singleton("MqttSender"):
		return Engine.get_singleton("MqttSender")
	if mqtt_sender_path != NodePath("") and has_node(mqtt_sender_path):
		return get_node(mqtt_sender_path) as MqttSender
	push_error("MqttSender not found; set mqtt_sender_path.")
	return null
