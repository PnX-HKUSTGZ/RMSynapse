extends Node2D

# 官方未给出复活topic，此部分实现不完全

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _title: RichTextLabel = $Title
@onready var _progress: ProgressBar = $RespawnProgressBar
@onready var _btn_free: Button = $FreeReSpawn
@onready var _btn_pay: Button = $PayReSpawn

var _gs: Node = null

func _ready() -> void:
	_resolve_game_state()
	_reset_ui()
	if _gs:
		if _gs.has_signal("robot_respawn_status_updated"):
			_gs.connect("robot_respawn_status_updated", Callable(self, "_on_respawn_status"))
		else:
			push_warning("[RobotRespawn] GameState missing signal robot_respawn_status_updated")
	else:
		push_warning("[RobotRespawn] GameState not found at %s" % str(game_state_path))

func _reset_ui() -> void:
	visible = false
	if _progress:
		_progress.max_value = 1
		_progress.value = 0
	if _title:
		_title.text = "存活"
	if _btn_free:
		_btn_free.disabled = true
	if _btn_pay:
		_btn_pay.disabled = true

func _on_respawn_status(value) -> void:
	var pending: bool = _get_val(value, "is_pending_respawn", false)
	var total: int = int(_get_val(value, "total_respawn_progress", 0))
	var current: int = int(_get_val(value, "current_respawn_progress", 0))
	var can_free: bool = _get_val(value, "can_free_respawn", false)
	var can_pay: bool = _get_val(value, "can_pay_for_respawn", false)
	var gold_cost: int = int(_get_val(value, "gold_cost_for_respawn", 0))

	visible = pending
	if _title:
		if pending:
			_title.text = "待复活"
		else:
			_title.text = "存活"

	if _progress:
		_progress.max_value = max(1, total)
		_progress.value = clamp(current, 0, _progress.max_value)

	if _btn_free:
		_btn_free.disabled = not (pending and can_free)
	if _btn_pay:
		_btn_pay.disabled = not (pending and can_pay)
		if gold_cost > 0:
			_btn_pay.text = "付费复活(%d)" % gold_cost
		else:
			_btn_pay.text = "付费复活"

func _resolve_game_state() -> void:
	if game_state_path != NodePath("") and has_node(game_state_path):
		_gs = get_node(game_state_path)
	elif Engine.has_singleton("GameState"):
		_gs = Engine.get_singleton("GameState")

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val
