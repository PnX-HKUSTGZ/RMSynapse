extends RichTextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "disconnected"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mqtt_client_mqtt_disconnected() -> void:
	text = "disconnected"


func _on_mqtt_client_mqtt_connection_failed() -> void:
	text = "connection failed"


func _on_mqtt_client_mqtt_connected() -> void:
		text = "connected"


func _on_mqtt_client_robot_dynamic_status_updated(value: Variant) -> void:
	text =  str(value.get_current_health())
