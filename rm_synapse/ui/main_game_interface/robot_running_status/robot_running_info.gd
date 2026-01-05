extends Node2D

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var target_robot_id: int = -1

@onready var _heal_label: RichTextLabel = $RemoteHealShow
@onready var _ammo_label: RichTextLabel = $RemoteAmmoShow
@onready var _ooc_label: RichTextLabel = $OutOfCombat
@onready var _ooc_cnt_label: RichTextLabel = $OutOfCombatCnt

var _gs: Node = null
var _can_heal: bool = false
var _can_ammo: bool = false
var _ooc: bool = false
var _ooc_cnt: int = 0

func _ready() -> void:
	_reset()
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_dynamic_status_updated"):
			_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic"))
	else:
		push_warning("[RobotRunningInfo] GameState not found at %s" % str(game_state_path))

func _reset() -> void:
	_can_heal = false
	_can_ammo = false
	_ooc = false
	_ooc_cnt = 0
	_apply()

func _on_dynamic(value) -> void:
	var entry = _pick_entry(value)
	if entry == null:
		return
	_can_heal = _get_val(entry, "can_remote_heal", _can_heal)
	_can_ammo = _get_val(entry, "can_remote_ammo", _can_ammo)
	_ooc = _get_val(entry, "is_out_of_combat", _ooc)
	_ooc_cnt = int(_get_val(entry, "out_of_combat_countdown", _ooc_cnt))
	_apply()

func _apply() -> void:
	if _heal_label:
		if _can_heal:
			_heal_label.text = "是"
		else:
			_heal_label.text = "否"
	if _ammo_label:
		if _can_ammo:
			_ammo_label.text = "是"
		else:
			_ammo_label.text = "否"
	if _ooc_label:
		if _ooc:
			_ooc_label.text = "脱战"
		else:
			_ooc_label.text = "战斗中"
	if _ooc_cnt_label:
		_ooc_cnt_label.visible = not _ooc
		if not _ooc:
			_ooc_cnt_label.text = "脱战倒计时：%ds" % _ooc_cnt
		else:
			_ooc_cnt_label.text = ""

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _pick_entry(data):
	if data == null:
		return null
	if typeof(data) == TYPE_DICTIONARY:
		if target_robot_id != -1 and data.has(target_robot_id):
			return data[target_robot_id]
		if _maybe_match(data):
			return data
		for v in data.values():
			if _maybe_match(v):
				return v
		return null
	if typeof(data) == TYPE_ARRAY:
		for v in data:
			if _maybe_match(v):
				return v
		return null
	if _maybe_match(data):
		return data
	return null

func _maybe_match(entry) -> bool:
	if target_robot_id == -1:
		return true
	var rid = _get_val(entry, "robot_id", -1)
	return rid == target_robot_id

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		if src.has(key_name):
			return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	push_warning("[RobotRunningInfo] missing key %s on %s, default %s" % [key_name, str(src), str(default_val)])
	return default_val
