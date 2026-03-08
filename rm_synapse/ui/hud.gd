extends CanvasLayer

# HUD 层职责：
# 1. 连接嵌入式 CEF Web UI
# 2. 定时向前端推送游戏状态数据（如血量、基地信息等）
# 3. 监听游戏事件（例如 kill_event）

# CEF 纹理节点引用（通过 eval 执行前端 JS）
# HUD 层职责：
# 1. 连接嵌入式 CEF Web UI
# 2. 定时向前端推送游戏状态数据（如血量、基地信息等）
# 3. 监听游戏事件（例如 kill_event）

# CEF 纹理节点引用（通过 eval 执行前端 JS）
@onready var web = $CefTexture
@onready var map_web = $CefMap
@onready var message_container = $MessageContainer

enum MessagePriority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CRITICAL = 3
}

const PRIORITY_STYLES := {
	MessagePriority.LOW: {
		"bg": Color(0.07, 0.10, 0.14, 0.92),
		"border": Color(0.43, 0.51, 0.62, 0.95),
		"font": Color(0.86, 0.90, 0.95, 1.0),
		"time": Color(0.78, 0.83, 0.90, 1.0)
	},
	MessagePriority.MEDIUM: {
		"bg": Color(0.08, 0.11, 0.14, 0.94),
		"border": Color(0.15, 0.78, 1.0, 0.95),
		"font": Color(0.81, 0.95, 1.0, 1.0),
		"time": Color(0.57, 0.88, 1.0, 1.0)
	},
	MessagePriority.HIGH: {
		"bg": Color(0.15, 0.09, 0.05, 0.95),
		"border": Color(1.0, 0.60, 0.15, 1.0),
		"font": Color(1.0, 0.92, 0.70, 1.0),
		"time": Color(1.0, 0.72, 0.34, 1.0)
	},
	MessagePriority.CRITICAL: {
		"bg": Color(0.22, 0.05, 0.06, 0.96),
		"border": Color(1.0, 0.28, 0.31, 1.0),
		"font": Color(1.0, 0.82, 0.84, 1.0),
		"time": Color(1.0, 0.42, 0.45, 1.0)
	}
}

@export var message_default_duration := 3.5
@export var message_max_count := 6
@export var message_font_size := 22
@export var message_item_min_height := 36.0
@export var message_panel_width := 460.0
@export var message_panel_height := 260.0
@export var message_left_offset := 30.0
@export var message_center_y_offset := -36.0
@export var message_ui_scale := 1.0

var _active_messages: Array[Dictionary] = []

# 页面是否成功加载（HTTP 状态码 2xx 视为成功）

# 页面是否成功加载（HTTP 状态码 2xx 视为成功）
var page_ready := false

# 数据推送间隔（秒），例如 0.02 表示 50Hz
# 数据推送间隔（秒），例如 0.02 表示 50Hz
var update_rate := 0.0

# 时间累加器，用于控制固定频率推送

# 时间累加器，用于控制固定频率推送
var acc := 0.0

# 本地事件服务实例（用于接收游戏内事件）
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
	_configure_message_container()
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
func _input(input_event):
	if input_event.is_action_pressed("test_10hz"):
		push_default_ui_state()
		print("Send DEFAULT_UI_STATE")

	if input_event.is_action_pressed("test_20hz"):
		update_rate = 0.01 # 100Hz
		print("Start 100Hz update")

	if input_event.is_action_pressed("test_stop"):
		update_rate = 0.0
		print("Stop update")

	if input_event.is_action_pressed("map"):
		if map_web:
			map_web.visible = !map_web.visible
			if map_web.visible:
				map_web.move_to_front()
			print("Toggle map UI:", map_web.visible)

	if input_event is InputEventKey and input_event.keycode == KEY_Q and input_event.pressed and not input_event.echo:
			if message_container:
				# 切换容器的显示状态
				message_container.visible = !message_container.visible
				print("Toggle message feed:", message_container.visible)
				
				# 如果开启，则自动生成一条测试消息
				if message_container.visible:
					_spawn_mock_message()

func _configure_message_container() -> void:
	if not message_container:
		return
	message_container.anchor_top = 0.5
	message_container.anchor_bottom = 0.5
	message_container.offset_left = message_left_offset
	message_container.offset_top = -message_panel_height * 0.5 + message_center_y_offset
	message_container.offset_right = message_left_offset + message_panel_width
	message_container.offset_bottom = message_panel_height * 0.5 + message_center_y_offset
	message_container.scale = Vector2.ONE * max(message_ui_scale, 0.1)
	message_container.alignment = BoxContainer.ALIGNMENT_END
	message_container.add_theme_constant_override("separation", 10)

func _priority_style(priority: int) -> Dictionary:
	return PRIORITY_STYLES.get(priority, PRIORITY_STYLES[MessagePriority.MEDIUM])

func add_message(text: String, duration := -1.0, priority := MessagePriority.MEDIUM) -> void:
	if not message_container:
		return
	var ttl := duration if duration > 0.0 else message_default_duration
	ttl = max(ttl, 0.2)
	var style_cfg := _priority_style(priority)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, message_item_min_height)

	var style := StyleBoxFlat.new()
	style.bg_color = style_cfg["bg"]
	style.border_color = style_cfg["border"]
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_label := Label.new()
	text_label.text = text
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", message_font_size)
	text_label.add_theme_color_override("font_color", style_cfg["font"])
	text_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	row.add_child(text_label)

	var timer_label := Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", max(14, int(message_font_size * 0.68)))
	timer_label.add_theme_color_override("font_color", style_cfg["time"])
	row.add_child(timer_label)

	message_container.add_child(panel)

	_active_messages.append({
		"id": Time.get_ticks_usec(),
		"priority": priority,
		"duration": ttl,
		"remaining": ttl,
		"panel": panel,
		"text_label": text_label,
		"timer_label": timer_label
	})
	_refresh_message_item(_active_messages[_active_messages.size() - 1])

	_sort_messages()
	_trim_messages()

# 生成测试消息
func _spawn_mock_message():
	var msgs := [
		{ "text": "🔥 英雄 [狂战士] 击杀了 [突击手]", "duration": 4.0, "priority": MessagePriority.HIGH },
		{ "text": "⚠️ 全局播报：左侧基地正在遭受攻击！", "duration": 6.0, "priority": MessagePriority.CRITICAL },
		{ "text": "🛡️ 团队护甲升级完毕", "duration": 3.5, "priority": MessagePriority.MEDIUM },
		{ "text": "💠 队友占领了前哨站", "duration": 3.0, "priority": MessagePriority.LOW }
	]
	var sample: Dictionary = msgs[randi() % msgs.size()]
	add_message(sample["text"], sample["duration"], sample["priority"])

func _trim_messages() -> void:
	while _active_messages.size() > max(message_max_count, 1):
		var last: Dictionary = _active_messages[_active_messages.size() - 1]
		if is_instance_valid(last.get("panel")):
			last["panel"].queue_free()
		_active_messages.pop_back()

func _sort_messages() -> void:
	_active_messages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) == int(b["priority"]):
			return float(a["remaining"]) > float(b["remaining"])
		return int(a["priority"]) > int(b["priority"])
	)
	for i in range(_active_messages.size()):
		var panel: PanelContainer = _active_messages[i]["panel"]
		if is_instance_valid(panel) and panel.get_parent() == message_container:
			message_container.move_child(panel, i)

func _refresh_message_item(entry: Dictionary) -> void:
	var timer_label: Label = entry.get("timer_label")
	if is_instance_valid(timer_label):
		timer_label.text = "[%.1fs]" % max(float(entry["remaining"]), 0.0)
		var blink_window: float = minf(1.5, float(entry["duration"]) * 0.35)
		if float(entry["remaining"]) <= blink_window:
			var blink_phase: int = int(Time.get_ticks_msec() / 150.0) % 2
			timer_label.visible = blink_phase == 0
		else:
			timer_label.visible = true

	var panel: PanelContainer = entry.get("panel")
	if is_instance_valid(panel):
		if int(entry["priority"]) >= MessagePriority.HIGH:
			var pulse := 0.82 + 0.18 * (sin(float(Time.get_ticks_msec()) / 120.0) * 0.5 + 0.5)
			panel.modulate.a = pulse
		else:
			panel.modulate.a = 1.0

func _update_message_feed(delta: float) -> void:
	var removed := false
	for i in range(_active_messages.size() - 1, -1, -1):
		var entry := _active_messages[i]
		var panel: PanelContainer = entry.get("panel")
		if not is_instance_valid(panel):
			_active_messages.remove_at(i)
			removed = true
			continue
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			panel.queue_free()
			_active_messages.remove_at(i)
			removed = true
			continue
		_active_messages[i] = entry
		_refresh_message_item(entry)
	if removed:
		_sort_messages()

func _on_game_status_updated(new_status):
	print("Game status changed: ", new_status)

# 每帧调用
# 使用累加器模式按固定频率推送数据
# 若页面未就绪或未开启推送则直接返回
func _process(delta):
	_update_message_feed(delta)
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
	"uiSizing": {
		"topCoreScale": 2,
		"centerHudScale": 2
	},
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
