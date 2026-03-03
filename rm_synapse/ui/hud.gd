extends CanvasLayer

# HUD 层职责：
# 1. 连接嵌入式 CEF Web UI
# 2. 定时向前端推送游戏状态数据（如血量、基地信息等）
# 3. 监听游戏事件（例如 kill_event）

# CEF 纹理节点引用（通过 eval 执行前端 JS）
@onready var web = $CefTexture

# 页面是否成功加载（HTTP 状态码 2xx 视为成功）
var page_ready := false

# 数据推送间隔（秒），例如 0.02 表示 50Hz
var update_rate := 0.0

# 时间累加器，用于控制固定频率推送
var acc := 0.0

# 本地事件服务实例（用于接收游戏内事件）
var event = EventService.new()

# GameStatusService
var game_status_service = GameStatusService.new()

var robot_static_status_service = RobotStaticStatusService.new()

# 当 HUD 节点进入场景树时调用
# 负责初始化 CEF 连接、事件绑定和输入处理
func _ready():
	randomize()
	print("HUD ready. Press A to send DEFAULT_UI_STATE, B for 100Hz test, C to stop.")
	set_process(true)
	set_process_input(true)
	if web and web.has_signal("load_finished"):
		# 监听 CEF 页面加载完成信号
		# 仅当 HTTP 状态码为 2xx 时才允许开始推送数据
		web.load_finished.connect(func(_url: String, status: int) -> void:
			page_ready = (status >= 200 and status < 300)
			print("CEF load_finished status=", status, " page_ready=", page_ready)
		)

	if game_status_service.get_parent() == null:
		add_child(game_status_service)
	if not game_status_service.game_status_updated.is_connected(_on_game_status_updated):
		game_status_service.game_status_updated.connect(_on_game_status_updated)

	add_child(robot_static_status_service)
	robot_static_status_service.connect("robot_static_status_updated", self._on_robot_static_status_updated)

func _on_robot_static_status_updated(new_status):
	print("Robot static status updated: ", new_status)

# 调试用输入处理：
# - test_20hz：开启 100Hz 推送
# - test_stop：停止推送
func _input(event):
	if event.is_action_pressed("test_10hz"):
		push_default_ui_state()
		print("Send DEFAULT_UI_STATE")

	if event.is_action_pressed("test_20hz"):
		update_rate = 0.01 # 100Hz
		print("Start 100Hz update")

	if event.is_action_pressed("test_stop"):
		update_rate = 0.0
		print("Stop update")

func _on_game_status_updated(new_status):
	print("Game status changed: ", new_status)

# 每帧调用
# 使用累加器模式按固定频率推送数据
# 若页面未就绪或未开启推送则直接返回
func _process(delta):
	if update_rate <= 0 or not page_ready:
		return
	acc += delta
	if acc >= update_rate:
		acc = 0.0
		push_random_hp()


# 生成模拟的机器人与基地血量数据并推送到前端
# 用于模拟真实对局中的状态同步
func push_random_hp():
	# 构造左右双方机器人血量列表
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

	# 构造前端 window.godotPush() 期望的数据结构
	# 包含机器人和基地血量信息
	var payload = {
		"robots": new_robots,
		"bases": {
			"left": { "hp": randi() % 1500, "max": 1500 },
			"right": { "hp": randi() % 1500, "max": 1500 }
		}
	}

	push_payload(payload)


# 将任意 payload 推送到前端（调用 window.godotPush）
func push_payload(payload: Dictionary) -> void:
	if not page_ready:
		print("CEF page not ready, skip push")
		return
	var json = JSON.stringify(payload)
	print("Pushing HUD payload bytes=", json.length())
	# 在 CEF 页面上下文中执行 JavaScript
	# 若页面定义了 window.godotPush，则调用并传入数据
	if web:
		web.eval("if (window.godotPush) { window.godotPush(" + json + "); } else { console.error('godotPush is not defined'); }")

# 按前端默认结构推送一份完整的 UI 初始状态
func push_default_ui_state() -> void:
	push_payload(DEFAULT_UI_STATE)


# 前端 UI 默认状态（用于一键初始化/联调）
const DEFAULT_UI_STATE := {
	"roundLabel": "Round 2/5",
	"baseStateMeta": {
		0: { "icon": "🛡️", "label": "无敌" },
		1: { "icon": "⚠️", "label": "接敌" },
		2: { "icon": "💠", "label": "护甲" }
	},
	"outpostStateMeta": {
		0: { "icon": "🔒", "spin": false },
		1: { "icon": "🔄", "spin": true },
		2: { "icon": "⏸️", "spin": false },
		3: { "icon": "❌", "spin": false },
		4: { "icon": "🔧", "spin": false },
		5: { "icon": "⏳", "spin": true },
		"default": { "icon": "❓", "spin": false }
	},
	"maxValues": {
		"mechaHp": 2000,
		"mechaBoost": 500,
		"mechaPower": 3500,
		"techLevel": 4,
		"radarLevel": 5
	},
	"timeLeft": 420, # gamestatus属性
	"scores": { "left": 0, "right": 0 },
	"bases": {
		"left": { "hp": 4200, "shield": 800, "state": 0 },
		"right": { "hp": 5000, "shield": 1500, "state": 0 }
	},
	"outposts": {
		"left": { "hp": 530, "state": 1 },
		"right": { "hp": 0, "state": 3 }
	},
	"stats": {
		"left": { "eco": 50, "totalEco": 300, "tech": 2, "radar": 3 },
		"right": { "eco": 120, "totalEco": 450, "tech": 4, "radar": 5 }
	},
	"robots": {
		"left": [
			{ "id": 7, "hp": 600, "max": 600 },
			{ "id": 6, "hp": 500, "max": 500 },
			{ "id": 4, "hp": 200, "max": 400 },
			{ "id": 3, "hp": 400, "max": 400 },
			{ "id": 2, "hp": 150, "max": 400 },
			{ "id": 1, "hp": 2000, "max": 2000 }
		],
		"right": [
			{ "id": 1, "hp": 1800, "max": 2000 },
			{ "id": 2, "hp": 400, "max": 400 },
			{ "id": 3, "hp": 0, "max": 400 },
			{ "id": 4, "hp": 400, "max": 400 },
			{ "id": 6, "hp": 500, "max": 500 },
			{ "id": 7, "hp": 600, "max": 600 }
		]
	},
	"mecha": {
		"pilotId": "HERO",
		"pilotLevel": "LV.6",
		"linkState": "LINKED",
		"hpLabel": "CORE HP",
		"hp": 1650,
		"boost": 400,
		"energy": 2850,
		"ammo": 12450,
		"inCombat": false,
		"combatTimer": 5.0,
		"remoteHealReady": true,
		"remoteAmmoReady": false
	},
	"centerHud": {
		"ammo": 300,
		"maxAmmo": 300,
		"heat": 0,
		"maxHeat": 100,
		"isOverheated": false,
		"attackBuffTime": 10,
		"defenseBuffTime": 10,
		"isShooting": false
	}
}
