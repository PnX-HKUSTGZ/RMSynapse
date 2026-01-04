extends Node2D

@export var shield_hp = 100.0
@export var base_max_hp = 5000.0
@export var base_current_hp = 1000.0

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
