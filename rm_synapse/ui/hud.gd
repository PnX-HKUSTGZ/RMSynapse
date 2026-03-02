extends CanvasLayer

@onready var web = $CefTexture
var page_ready := false

var update_rate := 0.0
var acc := 0.0

var event = EventService.new()

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

	add_child(event)
	event.connect("kill_event", self._on_kill_event)

func _on_kill_event(killer_id, victim_id):
	print("Kill event: killer_id=", killer_id, " victim_id=", victim_id)

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
		push_random_hp()


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
