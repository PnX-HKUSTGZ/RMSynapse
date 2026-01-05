extends Node2D

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
var _gs : Node = null



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_gs = get_node(game_state_path)
	if _gs == null:
		push_error("Global Logistics Status: Game State node not found at path: " + str(game_state_path))

	_gs.connect("global_logistics_status_updated", Callable(self, "update_logistics_status"), CONNECT_REFERENCE_COUNTED )
	
func update_logistics_status(value) -> void:
	var current_economics = get_node("CurrentEconomics") as RichTextLabel
	var technology_level = get_node("TechnologyLevel") as RichTextLabel
	var encryption_level = get_node("EncryptionLevel") as RichTextLabel

	if current_economics == null:
		push_error("Global Logistics Status: CurrentEconomics node not found.")
	else:
		current_economics.text = "当前经济：" + str(value.get_remaining_economy())

	if technology_level == null:
		push_error("Global Logistics Status: TechnologyLevel node not found.")
	else:
		technology_level.text = "科技等级：" + str(value.get_tech_level())

	if encryption_level == null:
		push_error("Global Logistics Status: EncryptionLevel node not found.")
	else:
		encryption_level.text = "加密等级：" + str(value.get_encryption_level())
