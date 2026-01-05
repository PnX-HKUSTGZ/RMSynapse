extends Node2D
@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

const OWN_OVER_ENEMY : int = 1
const ENEMY_OVER_OWN : int = 2

const ID_MAP := {
	OWN_OVER_ENEMY : "OwnOverEnemyFortress",
	ENEMY_OVER_OWN : "EnemyOverOwnFortress"
}

var _gs : Node = null

func _ready() -> void:
	_gs = get_node(game_state_path)
	if _gs == null:
		push_error("Global Special Mechanism: Game State node not found at path: " + str(game_state_path))

	if _gs.has_signal("global_special_mechanism_updated"):
		_gs.connect("global_special_mechanism_updated", Callable(self, "update_special_mechanism"), CONNECT_REFERENCE_COUNTED )
	else:
		push_error("Global Special Mechanism: Game State node does not have signal 'global_special_mechanism_updated'")

	

func update_special_mechanism(value) -> void:
	var special_id : Array[int] = value.get_mechanism_id()
	var special_value : Array[int] = value.get_mechanism_time_sec()

	if special_id.size() != special_value.size():
		push_error("Global Special Mechanism: Mismatched sizes for mechanism IDs and values.")
		return
	
	# 首先将全部置为 not visible
	for id in ID_MAP.values():
		var node : Node = get_node(id)
		if node:
			node.visible = false
		else:
			push_error("Global Special Mechanism: Node not found for ID: " + (id))
	
	# 然后根据传入的值设置对应的 visible 和 time
	for i in special_id.size():
		var id = special_id[i]
		var time_sec = special_value[i]

		if id == OWN_OVER_ENEMY:
			var node : RichTextLabel = get_node(ID_MAP[OWN_OVER_ENEMY])
			if node:
				node.visible = true
				node.text = "对方堡垒被己方占领计时: " + str(time_sec) + " sec"
			else:
				push_error("Global Special Mechanism: Node not found for ID: " + str(ID_MAP[OWN_OVER_ENEMY]))
		elif id == ENEMY_OVER_OWN:
			var node : RichTextLabel = get_node(ID_MAP[ENEMY_OVER_OWN])
			if node:
				node.visible = true
				node.text = "己方堡垒被对方占领计时: " + str(time_sec) + " sec"
			else:
				push_error("Global Special Mechanism: Node not found for ID: " + str(ID_MAP[ENEMY_OVER_OWN]))
		else:
			push_warning("Global Special Mechanism: Unknown mechanism ID: " + str(id))
