extends CanvasLayer

@onready var web = $CefTexture
var page_ready := false

var update_rate := 0.0
var acc := 0.0

@export var event_service: EventService

var _current_payload := {
	"events": [],
	"robots": {"left": [], "right": []},
	"bases": {"left": {"hp": 1500, "max": 1500}, "right": {"hp": 1500, "max": 1500}}
}

func _ready():
	randomize()
	print("HUD ready. Press A for 10Hz, B for 20Hz, C to stop.")
	set_process(true)
	set_process_input(true)
	if web and web.has_signal("load_finished"):
		web.load_finished.connect(func(_url: String, status: int) -> void:
			page_ready = (status >= 200 and status < 300)
			print("CEF load_finished status=", status, " page_ready=", page_ready)
		)

	if event_service:
		event_service.event_received.connect(_on_event_received)


func _on_event_received(event_data: Dictionary) -> void:
	var event_id = event_data.get("event_id", -1)
	var event_name = event_service.get_event_name(event_id)
	
	_current_payload["events"].append(event_name)
	
	if _current_payload["events"].size() > 10:
		_current_payload["events"].pop_front()


func _input(event):
	if event.is_action_pressed("test_10hz"):
		update_rate = 0.02 # 50Hz
		print("Start 50Hz update")

	if event.is_action_pressed("test_20hz"):
		update_rate = 0.01 # 100Hz
		print("Start 100Hz update")

	if event.is_action_pressed("test_stop"):
		update_rate = 0.0
		print("Stop update")


func _process(delta):
	if update_rate <= 0 or not page_ready:
		return

	acc += delta
	if acc >= update_rate:
		acc = 0.0
		# TODO: Temporarily mixing mock data and real event data.
		# Replace push_random_hp() with push_real_data() once robots/bases are fully hooked up.
		push_combined_data()


func push_combined_data():
	# Generate mock robot data
	var new_robots = {
		"left": [],
		"right": []
	}

	for id in [7, 6, 4, 3, 2, 1]:
		new_robots["left"].append({
			"id": id,
			"hp": randi() % 600,
			"max": 600
		})

	for id in [1, 2, 3, 4, 6, 7]:
		new_robots["right"].append({
			"id": id,
			"hp": randi() % 600,
			"max": 600
		})

	# Merge with the real events we got from MQTT
	_current_payload["robots"] = new_robots
	
	var json = JSON.stringify(_current_payload)
	if web:
		web.eval("if (window.godotPush) { window.godotPush(" + json + "); }")


func push_random_hp():
	var new_robots = {
		"left": [],
		"right": []
	}

	for id in [7, 6, 4, 3, 2, 1]:
		new_robots["left"].append({
			"id": id,
			"hp": randi() % 600,
			"max": 600
		})

	for id in [1, 2, 3, 4, 6, 7]:
		new_robots["right"].append({
			"id": id,
			"hp": randi() % 600,
			"max": 600
		})

	var payload = {
		"robots": new_robots,
		"bases": {
			"left": { "hp": randi() % 1500, "max": 1500 },
			"right": { "hp": randi() % 1500, "max": 1500 }
		}
	}

	var json = JSON.stringify(payload)
	print("Pushing HUD payload bytes=", json.length())

	if web:
		# Godot CEF uses `eval()` to execute JavaScript on the page
		web.eval("if (window.godotPush) { window.godotPush(" + json + "); } else { console.error('godotPush is not defined'); }")
