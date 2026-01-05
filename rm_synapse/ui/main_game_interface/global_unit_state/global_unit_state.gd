extends Node2D

# 未完成，因为官方没有提供完整的信号数据

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
# 当前操作手的游戏方
@export_enum("blue", "red") var current_player_side: String = "blue"
@export_enum("Regional Contest", "Final") var competition_stage: String = "Regional Contest"

var _gs: Node = null
var _red_unit_hp_order: Array = []
var _blue_unit_hp_order: Array = []
var _own_side_unit_hp_order: Array = []
var _enemy_side_unit_hp_order: Array = []
var _own_prefix: String = ""
var _enemy_prefix: String = ""
var _own_base_name : String = ""
var _enemy_base_name : String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_gs = get_node(game_state_path)
	if _gs:
		print("[GlobalUnitState] GameState resolved: ", _gs)
	else:
		push_warning("[GlobalUnitState] GameState node NOT found.")
	
	# 连接信号
	_gs.connect("global_unit_status_updated", Callable(self, "_signal_callback"), CONNECT_REFERENCE_COUNTED)

	if competition_stage == "Final":
		_red_unit_hp_order = ["UnitRed1", "UnitRed2", "UnitRed3", "UnitRed4", "UnitRed6", "UnitRed7", "UnitRed8"]
		_blue_unit_hp_order = ["UnitBlue1", "UnitBlue2", "UnitBlue3", "UnitBlue4", "UnitBlue6", "UnitBlue7", "UnitBlue8"]
	else:
		_red_unit_hp_order = ["UnitRed1", "UnitRed2", "UnitRed3", "UnitRed6", "UnitRed7", "UnitRed8"]
		_blue_unit_hp_order = ["UnitBlue1", "UnitBlue2", "UnitBlue3", "UnitBlue6", "UnitBlue7", "UnitBlue8"]

	if current_player_side == "blue":
		_own_side_unit_hp_order = _blue_unit_hp_order
		_enemy_side_unit_hp_order = _red_unit_hp_order
		_own_prefix = "BlueUnitState"
		_enemy_prefix = "RedUnitState"
		_own_base_name = "BaseBlue"
		_enemy_base_name = "BaseRed"
	else:
		_own_side_unit_hp_order = _red_unit_hp_order
		_enemy_side_unit_hp_order = _blue_unit_hp_order
		_own_prefix = "RedUnitState"
		_enemy_prefix = "BlueUnitState"
		_own_base_name = "BaseRed"
		_enemy_base_name = "BaseBlue"

func _signal_callback(value) -> void:
	var all_unit_hp : Array = value.get_robot_health()
	var own_hp_arr : Array = []
	var enemy_hp_arr : Array = []

	# 检查大小
	if all_unit_hp.size() != (_own_side_unit_hp_order.size() + _enemy_side_unit_hp_order.size()):
		push_warning("[GlobalUnitState] Total unit HP array size mismatch!")
		return

	for i in _own_side_unit_hp_order.size():
		own_hp_arr.append(all_unit_hp[i])
	for i in _enemy_side_unit_hp_order.size():
		enemy_hp_arr.append(all_unit_hp[i + _own_side_unit_hp_order.size()])
	
	_update_unit_states(own_hp_arr, enemy_hp_arr)

	_update_base_shield(
		value.get_base_health(),
		value.get_base_status(),
		value.get_base_shield(),
		value.get_base_health(),
		value.get_base_status(),
		value.get_base_shield(),
	)
	
func _update_unit_states(own_hp_arr : Array, enemy_hp_arr : Array) -> void:
	# 检查血量
	if own_hp_arr.size() != _own_side_unit_hp_order.size():
		push_warning("[GlobalUnitState] Own side unit HP array size mismatch!")
		return
	if enemy_hp_arr.size() != _enemy_side_unit_hp_order.size():
		push_warning("[GlobalUnitState] Enemy side unit HP array size mismatch!")
		return
	
	# 更新我方单位血量显示
	for i in own_hp_arr.size():
		var unit_node = get_node(_own_prefix + "/" + _own_side_unit_hp_order[i]) as RM_Unit_Node
		unit_node.set_current_hp(own_hp_arr[i])
	
	# 更新敌方单位血量显示
	for i in enemy_hp_arr.size():
		var unit_node = get_node(_enemy_prefix + "/" + _enemy_side_unit_hp_order[i]) as RM_Unit_Node
		unit_node.set_current_hp(enemy_hp_arr[i])

func _update_base_shield(own_base_hp: float, own_shield_hp: float, own_base_status: int, enemy_base_hp: float, enemy_shield_hp: float, enemy_base_status: int) -> void:
	var base_node = get_node(_own_prefix + "/" + _own_base_name) as RM_Base_Node
	base_node.set_base_current_hp(own_base_hp)
	base_node.set_shield_hp(own_shield_hp)
	base_node.set_base_status(own_base_status)
	
	var enemy_base_node = get_node(_enemy_prefix + "/" + _enemy_base_name) as RM_Base_Node
	enemy_base_node.set_base_current_hp(enemy_base_hp)
	enemy_base_node.set_shield_hp(enemy_shield_hp)
	enemy_base_node.set_base_status(enemy_base_status)
