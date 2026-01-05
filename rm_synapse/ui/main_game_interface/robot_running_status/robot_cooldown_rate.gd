extends Node2D

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _rate_label: RichTextLabel = $CooldownRateShow

var _gs: Node = null
var _cool_rate: float = 0.0

func _ready() -> void:
	_reset()
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_static_status_updated"):
			_gs.connect("robot_static_status_updated", Callable(self, "_on_static"))
		else:
			push_warning("[CooldownRate] GameState missing signal robot_static_status_updated")
	else:
		push_warning("[CooldownRate] GameState not found at %s" % str(game_state_path))

func _reset() -> void:
	_cool_rate = 0.0
	_apply()

func _on_static(value) -> void:
	_cool_rate = value.get_heat_cooldown_rate()
	_apply()

func _apply() -> void:
	print(_cool_rate)
	if _rate_label:
		if _cool_rate <= 0.0:
			_rate_label.text = "--"
		else:
			_rate_label.text = "%.2f /s" % _cool_rate
	else:
		push_warning("[CooldownRate] _rate_label is null")

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

