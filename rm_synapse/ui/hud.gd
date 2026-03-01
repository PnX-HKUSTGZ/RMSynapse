extends CanvasLayer

@onready var web = $CefTexture
var page_ready := false

var update_rate := 0.0
var acc := 0.0

@export var event_service: EventService
var mechanism_service: GlobalSpecialMechanismService

var _current_payload := {
	"events": [],
	"mechanisms": [],
	"robots": {"left": [], "right": []},
	"bases": {"left": {"hp": 1500, "max": 1500}, "right": {"hp": 1500, "max": 1500}},
	"game_state": {
		"energy_activation_count": 0,
		"energy_mech_arms_count": 0,
		"energy_mech_avg_rings": 0,
		"ally_sniper_damage": 0,
		"enemy_sniper_damage": 0,
		"ally_air_support_interrupts_left": 3,
		"enemy_air_support_interrupts_left": 3
	}
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

	event_service = get_node_or_null("/root/Mqtt/EventService")

	if event_service:
		# event_service.event_received.connect(_on_event_received) # 已注释，改用下方更精细的信号
		event_service.kill_event.connect(_on_kill_event)
		event_service.base_or_outpost_destroyed.connect(_on_base_or_outpost_destroyed)
		event_service.energy_activation_count_changed.connect(_on_energy_activation_count_changed)
		event_service.energy_mech_entered_active_state.connect(_on_energy_mech_entered_active_state)
		event_service.energy_mech_active_arms_changed.connect(_on_energy_mech_active_arms_changed)
		event_service.energy_mech_activated.connect(_on_energy_mech_activated)
		event_service.ally_hero_deploy_mode.connect(_on_ally_hero_deploy_mode)
		event_service.ally_hero_sniper_damage.connect(_on_ally_hero_sniper_damage)
		event_service.enemy_hero_sniper_damage.connect(_on_enemy_hero_sniper_damage)
		event_service.ally_air_support_called.connect(_on_ally_air_support_called)
		event_service.enemy_air_support_called.connect(_on_enemy_air_support_called)
		event_service.ally_air_support_interrupted.connect(_on_ally_air_support_interrupted)
		event_service.enemy_air_support_interrupted.connect(_on_enemy_air_support_interrupted)
		event_service.dart_hit.connect(_on_dart_hit)
		event_service.dart_gate_opened.connect(_on_dart_gate_opened)
		event_service.ally_base_under_attack.connect(_on_ally_base_under_attack)
		event_service.outpost_stopped.connect(_on_outpost_stopped)
		event_service.base_armor_deployed.connect(_on_base_armor_deployed)
		print("[HUD] 成功连接到 EventService 的所有明细信号!")
	else:
		push_error("[HUD] 找不到 EventService! 请检查自动加载(Autoload)或节点路径是否为 /root/Mqtt/EventService。")

	mechanism_service = get_node_or_null("/root/Mqtt/MechanismService")
	if mechanism_service:
		mechanism_service.effects_updated.connect(_on_effects_updated)
		print("[HUD] 成功连接到 MechanismService!")
	else:
		push_error("[HUD] 找不到 MechanismService! 请检查自动加载(Autoload)或节点路径是否为 /root/Mqtt/MechanismService。")


func _add_event_log(msg: String) -> void:
	_current_payload["events"].append(msg)
	if _current_payload["events"].size() > 10:
		_current_payload["events"].pop_front()

# ========== 核心击杀机制事件 ==========
func _on_kill_event(killer_id: int, victim_id: int) -> void:
	_add_event_log("击杀! 击杀者: " + str(killer_id) + " 被击杀: " + str(victim_id))

func _on_base_or_outpost_destroyed(target_id: int) -> void:
	_add_event_log("被摧毁! 基地/前哨站: " + str(target_id))

# ========== 能量机关事件 ==========
func _on_energy_activation_count_changed(count: int) -> void:
	_current_payload["game_state"]["energy_activation_count"] = count

func _on_energy_mech_entered_active_state() -> void:
	_add_event_log("能量机关进入激活状态")

func _on_energy_mech_active_arms_changed(arms_count: int, avg_rings: int) -> void:
	_current_payload["game_state"]["energy_mech_arms_count"] = arms_count
	_current_payload["game_state"]["energy_mech_avg_rings"] = avg_rings

func _on_energy_mech_activated(activate_type: String) -> void:
	_add_event_log("能量机关成功激活! 类型: " + activate_type)

# ========== 英雄与狙击事件 ==========
func _on_ally_hero_deploy_mode() -> void:
	_add_event_log("己方英雄进入部署模式")

func _on_ally_hero_sniper_damage(total_damage: int) -> void:
	_current_payload["game_state"]["ally_sniper_damage"] = total_damage

func _on_enemy_hero_sniper_damage(total_damage: int) -> void:
	_current_payload["game_state"]["enemy_sniper_damage"] = total_damage

# ========== 空中支援事件 ==========
func _on_ally_air_support_called() -> void:
	_add_event_log("己方请求空中支援")

func _on_enemy_air_support_called() -> void:
	_add_event_log("对方请求空中支援")

func _on_ally_air_support_interrupted(remaining: int) -> void:
	_current_payload["game_state"]["ally_air_support_interrupts_left"] = remaining

func _on_enemy_air_support_interrupted(remaining: int) -> void:
	_current_payload["game_state"]["enemy_air_support_interrupts_left"] = remaining

# ========== 飞镖与阵营事件 ==========
func _on_dart_hit(target: int) -> void:
	_add_event_log("飞镖命中! 目标: " + str(target))

func _on_dart_gate_opened(side: int) -> void:
	var side_str = "红方" if side == 1 else ("蓝方" if side == 2 else ("双方" if side == 3 else "未知"))
	_add_event_log(side_str + "飞镖闸门已开启")

func _on_ally_base_under_attack() -> void:
	_add_event_log("🚨警告! 己方基地正在受到攻击")

func _on_outpost_stopped(side: int) -> void:
	var side_str = "红方" if side == 1 else ("蓝方" if side == 2 else ("双方" if side == 3 else "未知"))
	_add_event_log(side_str + "前哨站已停止运转")

func _on_base_armor_deployed(side: int) -> void:
	var side_str = "红方" if side == 1 else ("蓝方" if side == 2 else ("双方" if side == 3 else "未知"))
	_add_event_log(side_str + "基地虚拟护盾已展开")


func _on_effects_updated(effects: Array) -> void:
	# effects 的每个元素是 EffectInfo(id, name, remaining_sec)
	var mechanisms_list = []
	for effect in effects:
		mechanisms_list.append({
			"id": effect.id,
			"name": effect.name,
			"remaining_sec": effect.remaining_sec
		})
	_current_payload["mechanisms"] = mechanisms_list


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
