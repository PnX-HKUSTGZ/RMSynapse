extends Node2D

class_name RobotMapIcon

@export var color : Color = Color(1, 1, 1, 1)
@export var angle : float = 0.0
@export var id : String = ""

@onready var circle : Sprite2D = $PlayerMinimapCircle
@onready var arrow : Sprite2D = $PlayerMinimapArrow
@onready var label : RichTextLabel = $Label

func _process(_delta: float) -> void:
	circle.modulate = color
	arrow.modulate = color
	arrow.rotation_degrees = -angle + 90.0
	label.text = id
