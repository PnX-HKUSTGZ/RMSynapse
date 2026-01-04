extends Node2D

@export var unit_id: int = -1
@export var unit_image: Texture2D = null
@export var unit_max_hp: float = 100.0
@export var unit_current_hp: float = 100.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var id = get_node("ID") as RichTextLabel
	var image = get_node("Icon") as TextureRect
	var hp_bar = get_node("HPBar") as ProgressBar
	hp_bar.max_value = unit_max_hp
	hp_bar.value = unit_current_hp
	id.text = str(unit_id)
	if unit_image != null:
		image.texture = unit_image

func set_max_hp(hp: float) -> void:
	var hp_bar = get_node("HPBar") as ProgressBar
	hp_bar.max_value = hp

func set_current_hp(hp: float) -> void:
	var hp_bar = get_node("HPBar") as ProgressBar
	hp_bar.value = hp
