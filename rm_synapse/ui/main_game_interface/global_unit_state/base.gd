extends Node2D

class_name RM_Base_Node

@export var shield_hp : float = 100.0
@export var base_max_hp : float = 5000.0
@export var base_current_hp : float = 1000.0

# 无敌状态常量
const INVINCIBLE : int = 0
# 取消无敌但是基地装甲闭合
const SHIELD_ONLY : int = 1
# 取消无敌但是基地装甲开放
const SHIELD_OPEN : int = 2

func _base_status_to_string(status_id : int) -> String:
	match status_id:
		INVINCIBLE:
			return "无敌"
		SHIELD_ONLY:
			return "无敌失效，装甲闭合"
		SHIELD_OPEN:
			return "无敌失效，装甲开放"
		_:
			return "未知状态"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var base_hp_bar = get_node("PHBar") as ProgressBar
	var base_current_hp_label = get_node("BasePH") as RichTextLabel
	var shield_hp_label = get_node("ShieldPH") as RichTextLabel

	base_hp_bar.max_value = base_max_hp
	base_hp_bar.value = base_current_hp
	base_current_hp_label.text = str(base_current_hp)
	shield_hp_label.text = str(shield_hp)

func set_base_max_hp(hp: float) -> void:
	var base_hp_bar = get_node("PHBar") as ProgressBar
	base_hp_bar.max_value = hp

func set_base_current_hp(hp: float) -> void:
	var base_hp_bar = get_node("PHBar") as ProgressBar
	var base_current_hp_label = get_node("BasePH") as RichTextLabel
	base_hp_bar.value = hp
	base_current_hp_label.text = str(hp)

func set_shield_hp(hp: float) -> void:
	var shield_hp_label = get_node("ShieldPH") as RichTextLabel
	shield_hp_label.text = str(hp)
	
func set_base_status(status_id : int) -> void:
	var status_label = get_node("BaseStatus") as RichTextLabel
	status_label.text = _base_status_to_string(status_id)
