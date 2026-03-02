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

# const DEFAULT_UI_STATE = {
#   roundLabel: 'Round 2/5',
#   baseStateMeta: {
#     0: { icon: '🛡️', label: '无敌' },
#     1: { icon: '⚠️', label: '接敌' },
#     2: { icon: '💠', label: '护甲' }
#   },
#   outpostStateMeta: {
#     0: { icon: '🔒', spin: false },
#     1: { icon: '🔄', spin: true },
#     2: { icon: '⏸️', spin: false },
#     3: { icon: '❌', spin: false },
#     4: { icon: '🔧', spin: false },
#     5: { icon: '⏳', spin: true },
#     default: { icon: '❓', spin: false }
#   },
#   maxValues: {
#     mechaHp: 2000,
#     mechaBoost: 500,
#     mechaPower: 3500,
#     techLevel: 4,
#     radarLevel: 5
#   },
#   timeLeft: 420,
#   scores: { left: 0, right: 0 },
#   bases: {
#     left: { hp: 4200, shield: 800, state: 0 },
#     right: { hp: 5000, shield: 1500, state: 0 }
#   },
#   outposts: {
#     left: { hp: 530, state: 1 },
#     right: { hp: 0, state: 3 }
#   },
#   stats: {
#     left: { eco: 50, totalEco: 300, tech: 2, radar: 3 },
#     right: { eco: 120, totalEco: 450, tech: 4, radar: 5 }
#   },
#   robots: {
#     left: [
#       { id: 7, hp: 600, max: 600 },
#       { id: 6, hp: 500, max: 500 },
#       { id: 4, hp: 200, max: 400 },
#       { id: 3, hp: 400, max: 400 },
#       { id: 2, hp: 150, max: 400 },
#       { id: 1, hp: 2000, max: 2000 }
#     ],
#     right: [
#       { id: 1, hp: 1800, max: 2000 },
#       { id: 2, hp: 400, max: 400 },
#       { id: 3, hp: 0, max: 400 },
#       { id: 4, hp: 400, max: 400 },
#       { id: 6, hp: 500, max: 500 },
#       { id: 7, hp: 600, max: 600 }
#     ]
#   },
#   mecha: {
#     pilotId: 'HERO',
#     pilotLevel: 'LV.6',
#     linkState: 'LINKED',
#     hpLabel: 'CORE HP',
#     hp: 1650,
#     boost: 400,
#     energy: 2850,
#     ammo: 12450,
#     inCombat: false,
#     combatTimer: 5.0,
#     remoteHealReady: true,
#     remoteAmmoReady: false
#   },
#   centerHud: {
#     ammo: 300,
#     maxAmmo: 300,
#     heat: 0,
#     maxHeat: 100,
#     isOverheated: false,
#     attackBuffTime: 10,
#     defenseBuffTime: 10,
#     isShooting: false,
#   }
# };