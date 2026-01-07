extends Node2D

@export var change_map_key : Key = Key.KEY_M

@onready var small_map = $SmallMapLayer
@onready var big_map = $BigMapLayer
@onready var big_map_root = $BigMapLayer/MapWindow

var _pre_key_state : bool = false

func _ready() -> void:
	big_map.visible = false
	small_map.visible = true


func _process(_delta: float) -> void:
	if _pre_key_state == false and Input.is_key_pressed(change_map_key):
		big_map.visible = not big_map.visible
		small_map.visible = not small_map.visible

		if big_map.visible:
			big_map_root._reset_map()

	_pre_key_state = Input.is_key_pressed(change_map_key)
