extends Node

@export var unit_max_hp: float = 1500.0
@export var unit_current_hp: float = 100.0
@export var state_string: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var hp_bar = get_node("HPBar") as ProgressBar
	var state_label = get_node("State") as RichTextLabel
	hp_bar.max_value = unit_max_hp
	hp_bar.value = unit_current_hp
	state_label.text = state_string

func set_max_hp(hp: float) -> void:
	var hp_bar = get_node("HPBar") as ProgressBar
	hp_bar.max_value = hp

func set_current_hp(hp: float) -> void:
	var hp_bar = get_node("HPBar") as ProgressBar
	hp_bar.value = hp

func set_state(state: String) -> void:
	var state_label = get_node("State") as RichTextLabel
	state_label.text = state
	state_string = state
