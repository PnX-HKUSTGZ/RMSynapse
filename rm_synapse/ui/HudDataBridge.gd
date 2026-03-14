extends Node
class_name HudDataBridge

# Bridge 输出说明（signal 与 getter 对应）：
# - game_status_updated / get_game_status_state -> GameStatusState
#   fields: current_round,total_rounds,red_score,blue_score,current_stage,current_stage_name,
#           stage_countdown_sec,stage_elapsed_sec,is_paused,last_update_msec
# - global_unit_status_updated / get_global_unit_status_state -> GlobalUnitStatusState
#   fields: ally_base{health,status,shield},enemy_base{health,status,shield},
#           ally_outpost{health,status},enemy_outpost{health,status},
#           robot_health(Array[int]),robot_bullets(Array[int]),total_damage_ally,total_damage_enemy,last_update_msec
# - global_logistics_status_updated / get_global_logistics_status_state -> GlobalLogisticsStatusState
#   fields: remaining_economy,total_economy_obtained,tech_level,encryption_level,last_update_msec
# - global_special_mechanism_updated / get_global_special_mechanism_state -> GlobalSpecialMechanismState
#   fields: effects(Array[MechanismState{id,remaining_sec}]),last_update_msec
# - event_received / get_last_event_message -> Event(proto message)
#   proto fields: event_id(int32), param(String)
# - robot_injury_stat_updated / get_robot_injury_stat_state -> RobotInjuryStatState
#   fields: total_damage,collision_damage,small_projectile_damage,large_projectile_damage,
#           dart_splash_damage,module_offline_damage,offline_damage,penalty_damage,server_kill_damage,killer_id,last_update_msec
# - robot_respawn_status_updated / get_robot_respawn_status_state -> RobotRespawnStatusState
#   fields: is_pending_respawn,total_respawn_progress,current_respawn_progress,
#           can_free_respawn,gold_cost_for_respawn,can_pay_for_respawn,last_update_msec
# - robot_static_status_updated / get_robot_static_status_state -> RobotStaticStatusState
#   fields: connection_state,field_state,alive_state,robot_id,robot_type,performance_system_shooter,performance_system_chassis,
#           level,max_health,max_heat,heat_cooldown_rate,max_power,max_buffer_energy,max_chassis_energy,last_update_msec
# - robot_dynamic_status_updated / get_robot_dynamic_status_state -> RobotDynamicStatusState
#   fields: current_health,current_heat,last_projectile_fire_rate,current_chassis_energy,current_buffer_energy,current_experience,
#           experience_for_upgrade,total_projectiles_fired,remaining_ammo,is_out_of_combat,out_of_combat_countdown,
#           can_remote_heal,can_remote_ammo,last_update_msec
# - robot_module_status_updated / get_robot_module_status_state -> RobotModuleStatusState
#   fields: power_manager,rfid,light_strip,small_shooter,big_shooter,uwb,armor,video_transmission,capacitor,
#           main_controller,laser_detection_module,last_update_msec
# - robot_position_updated / get_robot_position_state -> RobotPositionState
#   fields: x,y,z,yaw,last_update_msec
# - buff_updated / get_buff_state -> BuffState
#   fields: robot_id,buff_type,buff_level,buff_max_time,buff_left_time,last_update_msec
# - penalty_info_updated / get_penalty_info_state -> PenaltyInfoState
#   fields: penalty_type,penalty_effect_sec,total_penalty_num,last_update_msec
# - robot_path_plan_info_updated / get_robot_path_plan_info_state -> RobotPathPlanInfoState
#   fields: intention,start_pos_x,start_pos_y,offsets(Array[PathPointOffset{dx,dy}]),sender_id,last_update_msec
# - radar_info_updated / get_radar_info_state -> RadarInfoToClientState
#   fields: target_robot_id,target_pos_x,target_pos_y,torward_angle,is_high_light,last_update_msec
# - robot_performance_selection_sync_updated / get_robot_performance_selection_sync_state -> RobotPerformanceSelectionSyncState
#   fields: shooter,chassis,sentry_control,last_update_msec
# - deploy_mode_status_sync_updated / get_deploy_mode_status_sync_state -> DeployModeStatusSyncState
#   fields: status,last_update_msec
# - tech_core_motion_state_sync_updated / get_tech_core_motion_state_sync_state -> TechCoreMotionStateSyncState
#   fields: maximum_difficulty_level,status,enemy_core_status,remain_time_all,remain_time_step,last_update_msec
# - rune_status_sync_updated / get_rune_status_sync_state -> RuneStatusSyncState
#   fields: rune_status,activated_arms,average_rings,last_update_msec
# - sentry_status_sync_updated / get_sentry_status_sync_state -> SentryStatusSyncState
#   fields: posture_id,is_weakened,last_update_msec
# - dart_select_target_status_sync_updated / get_dart_select_target_status_sync_state -> DartSelectTargetStatusSyncState
#   fields: target_id,open,last_update_msec
# - sentry_ctrl_result_updated / get_sentry_ctrl_result_state -> SentryCtrlResultState
#   fields: command_id,result_code,last_update_msec
# - air_support_status_sync_updated / get_air_support_status_sync_state -> AirSupportStatusSyncState
#   fields: airsupport_status,left_time,cost_coins,is_being_targeted,shooter_status,last_update_msec
# - custom_byte_block_received / get_last_custom_byte_block_message -> CustomByteBlock(proto message)
#   proto fields: data(PackedByteArray)

signal game_status_updated(state)
signal global_unit_status_updated(state)
signal global_logistics_status_updated(state)
signal global_special_mechanism_updated(state)
signal event_received(message)
signal robot_injury_stat_updated(state)
signal robot_respawn_status_updated(state)
signal robot_static_status_updated(state)
signal robot_dynamic_status_updated(state)
signal robot_module_status_updated(state)
signal robot_position_updated(state)
signal buff_updated(state)
signal penalty_info_updated(state)
signal robot_path_plan_info_updated(state)
signal radar_info_updated(state)
signal robot_performance_selection_sync_updated(state)
signal deploy_mode_status_sync_updated(state)
signal tech_core_motion_state_sync_updated(state)
signal rune_status_sync_updated(state)
signal sentry_status_sync_updated(state)
signal dart_select_target_status_sync_updated(state)
signal sentry_ctrl_result_updated(state)
signal air_support_status_sync_updated(state)
signal custom_byte_block_received(message)

var game_status_service = GameStatusService.new()
var global_unit_status_service = GlobalUnitStatusService.new()
var global_logistics_status_service = GlobalLogisticsStatusService.new()
var global_special_mechanism_service = GlobalSpecialMechanismService.new()
var robot_injury_stat_service = RobotInjuryStatService.new()
var robot_respawn_status_service = RobotRespawnStatusService.new()
var robot_static_status_service = RobotStaticStatusService.new()
var robot_dynamic_status_service = RobotDynamicStatusService.new()
var robot_module_status_service = RobotModuleStatusService.new()
var robot_position_service = RobotPositionService.new()
var buff_service = BuffService.new()
var penalty_info_service = PenaltyInfoService.new()
var robot_path_plan_info_service = RobotPathPlanInfoService.new()
var radar_info_service = RadarInfoToClientService.new()
var robot_performance_selection_sync_service = RobotPerformanceSelectionSyncService.new()
var deploy_mode_status_sync_service = DeployModeStatusSyncService.new()
var tech_core_motion_state_sync_service = TechCoreMotionStateSyncService.new()
var rune_status_sync_service = RuneStatusSyncService.new()
var sentry_status_sync_service = SentryStatusSyncService.new()
var dart_select_target_status_sync_service = DartSelectTargetStatusSyncService.new()
var sentry_ctrl_result_service = SentryCtrlResultService.new()
var air_support_status_sync_service = AirSupportStatusSyncService.new()

var adapter_getter = MQTTProtocolAdapterGetter.new()
@export var adapter_bind_retry_interval_sec: float = 1.0
var _bound_adapter: ProtocolAdapter = null
var _adapter_bind_retry_elapsed: float = 0.0
var _last_event_message = null
var _last_custom_byte_block_message = null

func _ready() -> void:
	_attach_services()
	_bind_service_signals()
	_try_bind_adapter_signals()
	set_process(true)

func _process(delta: float) -> void:
	if _bound_adapter != null:
		return
	_adapter_bind_retry_elapsed += delta
	if _adapter_bind_retry_elapsed < maxf(adapter_bind_retry_interval_sec, 0.1):
		return
	_adapter_bind_retry_elapsed = 0.0
	_try_bind_adapter_signals()

func _exit_tree() -> void:
	_disconnect_adapter_signals()

func _attach_services() -> void:
	for service in _get_state_services():
		_attach_service(service)

func _get_state_services() -> Array[Node]:
	return [
		game_status_service,
		global_unit_status_service,
		global_logistics_status_service,
		global_special_mechanism_service,
		robot_injury_stat_service,
		robot_respawn_status_service,
		robot_static_status_service,
		robot_dynamic_status_service,
		robot_module_status_service,
		robot_position_service,
		buff_service,
		penalty_info_service,
		robot_path_plan_info_service,
		radar_info_service,
		robot_performance_selection_sync_service,
		deploy_mode_status_sync_service,
		tech_core_motion_state_sync_service,
		rune_status_sync_service,
		sentry_status_sync_service,
		dart_select_target_status_sync_service,
		sentry_ctrl_result_service,
		air_support_status_sync_service
	]

func _attach_service(service: Node) -> void:
	if service.get_parent() == null:
		add_child(service)

func _bind_service_signals() -> void:
	_connect_state_service_signal(game_status_service, "game_status_updated", "game_status_updated")
	_connect_state_service_signal(global_unit_status_service, "global_unit_status_updated", "global_unit_status_updated")
	_connect_state_service_signal(global_logistics_status_service, "global_logistics_status_updated", "global_logistics_status_updated")
	_connect_state_service_signal(global_special_mechanism_service, "global_special_mechanism_updated", "global_special_mechanism_updated")
	_connect_state_service_signal(robot_injury_stat_service, "robot_injury_stat_updated", "robot_injury_stat_updated")
	_connect_state_service_signal(robot_respawn_status_service, "robot_respawn_status_updated", "robot_respawn_status_updated")
	_connect_state_service_signal(robot_static_status_service, "robot_static_status_updated", "robot_static_status_updated")
	_connect_state_service_signal(robot_dynamic_status_service, "robot_dynamic_status_updated", "robot_dynamic_status_updated")
	_connect_state_service_signal(robot_module_status_service, "robot_module_status_updated", "robot_module_status_updated")
	_connect_state_service_signal(robot_position_service, "robot_position_updated", "robot_position_updated")
	_connect_state_service_signal(buff_service, "buff_updated", "buff_updated")
	_connect_state_service_signal(penalty_info_service, "penalty_info_updated", "penalty_info_updated")
	_connect_state_service_signal(robot_path_plan_info_service, "robot_path_plan_info_updated", "robot_path_plan_info_updated")
	_connect_state_service_signal(radar_info_service, "radar_info_updated", "radar_info_updated")
	_connect_state_service_signal(robot_performance_selection_sync_service, "robot_performance_selection_sync_updated", "robot_performance_selection_sync_updated")
	_connect_state_service_signal(deploy_mode_status_sync_service, "deploy_mode_status_sync_updated", "deploy_mode_status_sync_updated")
	_connect_state_service_signal(tech_core_motion_state_sync_service, "tech_core_motion_state_sync_updated", "tech_core_motion_state_sync_updated")
	_connect_state_service_signal(rune_status_sync_service, "rune_status_sync_updated", "rune_status_sync_updated")
	_connect_state_service_signal(sentry_status_sync_service, "sentry_status_sync_updated", "sentry_status_sync_updated")
	_connect_state_service_signal(dart_select_target_status_sync_service, "dart_select_target_status_sync_updated", "dart_select_target_status_sync_updated")
	_connect_state_service_signal(sentry_ctrl_result_service, "sentry_ctrl_result_updated", "sentry_ctrl_result_updated")
	_connect_state_service_signal(air_support_status_sync_service, "air_support_status_sync_updated", "air_support_status_sync_updated")

func _connect_state_service_signal(service: Object, service_signal: StringName, bridge_signal: StringName) -> void:
	if service == null or not service.has_signal(service_signal):
		return
	var relay := Callable(self , "_relay_state_signal").bind(String(bridge_signal))
	if not service.is_connected(service_signal, relay):
		service.connect(service_signal, relay)

func _relay_state_signal(state, bridge_signal: String) -> void:
	emit_signal(bridge_signal, state)

func _try_bind_adapter_signals() -> void:
	var adapter = adapter_getter.get_adapter_silent()
	if adapter == null:
		return
	if _bound_adapter != null and _bound_adapter != adapter:
		_disconnect_adapter_signals()
	if _bound_adapter == adapter:
		return
	_bound_adapter = adapter
	_connect_adapter_signal("event_message", "event_received")
	_connect_adapter_signal("custom_byte_block", "custom_byte_block_received")

func _disconnect_adapter_signals() -> void:
	if _bound_adapter == null:
		return
	_disconnect_adapter_signal("event_message", "event_received")
	_disconnect_adapter_signal("custom_byte_block", "custom_byte_block_received")
	_bound_adapter = null

func _connect_adapter_signal(adapter_signal: StringName, bridge_signal: StringName) -> void:
	if _bound_adapter == null or not _bound_adapter.has_signal(adapter_signal):
		return
	var relay := Callable(self , "_relay_adapter_signal").bind(String(bridge_signal))
	if not _bound_adapter.is_connected(adapter_signal, relay):
		_bound_adapter.connect(adapter_signal, relay)

func _disconnect_adapter_signal(adapter_signal: StringName, bridge_signal: StringName) -> void:
	if _bound_adapter == null or not _bound_adapter.has_signal(adapter_signal):
		return
	var relay := Callable(self , "_relay_adapter_signal").bind(String(bridge_signal))
	if _bound_adapter.is_connected(adapter_signal, relay):
		_bound_adapter.disconnect(adapter_signal, relay)

func _relay_adapter_signal(message, bridge_signal: String) -> void:
	if bridge_signal == "event_received":
		_last_event_message = message
	elif bridge_signal == "custom_byte_block_received":
		_last_custom_byte_block_message = message
	emit_signal(bridge_signal, message)

func _get_service_state(service):
	if service != null and service.has_method("get_state"):
		return service.get_state()
	return null

func get_game_status_state():
	return _get_service_state(game_status_service)

func get_global_unit_status_state():
	return _get_service_state(global_unit_status_service)

func get_global_logistics_status_state():
	return _get_service_state(global_logistics_status_service)

func get_global_special_mechanism_state():
	return _get_service_state(global_special_mechanism_service)

func get_robot_injury_stat_state():
	return _get_service_state(robot_injury_stat_service)

func get_robot_respawn_status_state():
	return _get_service_state(robot_respawn_status_service)

func get_robot_static_status_state():
	return _get_service_state(robot_static_status_service)

func get_robot_dynamic_status_state():
	return _get_service_state(robot_dynamic_status_service)

func get_robot_module_status_state():
	return _get_service_state(robot_module_status_service)

func get_robot_position_state():
	return _get_service_state(robot_position_service)

func get_buff_state():
	return _get_service_state(buff_service)

func get_penalty_info_state():
	return _get_service_state(penalty_info_service)

func get_robot_path_plan_info_state():
	return _get_service_state(robot_path_plan_info_service)

func get_radar_info_state():
	return _get_service_state(radar_info_service)

func get_robot_performance_selection_sync_state():
	return _get_service_state(robot_performance_selection_sync_service)

func get_deploy_mode_status_sync_state():
	return _get_service_state(deploy_mode_status_sync_service)

func get_tech_core_motion_state_sync_state():
	return _get_service_state(tech_core_motion_state_sync_service)

func get_rune_status_sync_state():
	return _get_service_state(rune_status_sync_service)

func get_sentry_status_sync_state():
	return _get_service_state(sentry_status_sync_service)

func get_dart_select_target_status_sync_state():
	return _get_service_state(dart_select_target_status_sync_service)

func get_sentry_ctrl_result_state():
	return _get_service_state(sentry_ctrl_result_service)

func get_air_support_status_sync_state():
	return _get_service_state(air_support_status_sync_service)

func get_last_event_message():
	return _last_event_message

func get_last_custom_byte_block_message():
	return _last_custom_byte_block_message


const DEFAULT_MINI_MAP_PLAYERS = [
	{"id": "red-1", "team": "red", "number": 1, "x": 12, "y": 15, "rotation": 90},
	{"id": "red-2", "team": "red", "number": 2, "x": 12, "y": 29, "rotation": 90},
	{"id": "red-3", "team": "red", "number": 3, "x": 12, "y": 43, "rotation": 90},
	{"id": "red-4", "team": "red", "number": 4, "x": 12, "y": 57, "rotation": 90},
	{"id": "red-6", "team": "red", "number": 6, "x": 12, "y": 71, "rotation": 90},
	{"id": "red-7", "team": "red", "number": 7, "x": 12, "y": 85, "rotation": 90},
	{"id": "blue-1", "team": "blue", "number": 1, "x": 88, "y": 15, "rotation": 270},
	{"id": "blue-2", "team": "blue", "number": 2, "x": 88, "y": 29, "rotation": 270},
	{"id": "blue-3", "team": "blue", "number": 3, "x": 88, "y": 43, "rotation": 270},
	{"id": "blue-4", "team": "blue", "number": 4, "x": 88, "y": 57, "rotation": 270},
	{"id": "blue-6", "team": "blue", "number": 6, "x": 88, "y": 71, "rotation": 270},
	{"id": "blue-7", "team": "blue", "number": 7, "x": 88, "y": 85, "rotation": 270}
]

const DEFAULT_UI_STATE = {
	"forceBlackBg": false,
	"uiSizing": {
		"topCoreScale": 1,
		"centerHudScale": 1,
		"mechaHudScale": 1,
		"miniMapScale": 0.75,
		"miniMapWidth": 420,
		"miniMapHeight": 236,
		"miniMapMarkerSize": 24,
		"miniMapBottom": 16,
		"miniMapRight": 16
	},
	"roundLabel": "Round 2/5",
	"labels": {
		"outpost": "前哨站",
		"eco": "ECO",
		"tech": "TECH",
		"radar": "RADAR"
	},
	"baseStateMeta": {
		0: {"icon": "🛡️", "label": "无敌"},
		1: {"icon": "⚠️", "label": "接敌"},
		2: {"icon": "💠", "label": "护甲"}
	},
	"outpostStateMeta": {
		0: {"icon": "🔒", "spin": false},
		1: {"icon": "🔄", "spin": true},
		2: {"icon": "⏸️", "spin": false},
		3: {"icon": "❌", "spin": false},
		4: {"icon": "🔧", "spin": false},
		5: {"icon": "⏳", "spin": true},
		"default": {"icon": "❓", "spin": false}
	},
	"maxValues": {
		"baseHp": 5000,
		"baseShield": 1500,
		"outpostHp": 750,
		"mechaHp": 2000,
		"mechaBoost": 500,
		"mechaPower": 3500,
		"techLevel": 4,
		"radarLevel": 5
	},
	"timeLeft": 420,
	"scores": {"left": 0, "right": 0},
	"bases": {
		"left": {"hp": 4200, "shield": 800, "state": 0},
		"right": {"hp": 5000, "shield": 1500, "state": 0}
	},
	"outposts": {
		"left": {"hp": 530, "state": 1},
		"right": {"hp": 0, "state": 3}
	},
	"stats": {
		"eco": 0,
		"totalEco": 450,
		"tech": 4,
		"radar": 5
	},
	"messageCenter": {
		"enabled": true,
		"topPercent": 25,
		"scale": 0.7,
		"minScale": 0.5,
		"maxScale": 2,
		"maxVisible": 8,
		"defaultDurationMs": 5000,
		"leaveAnimationMs": 300,
		"priorityMap": {
			"critical": 1,
			"important": 2,
			"normal": 3
		},
		"levels": {
			"critical": {
				"title": "CRITICAL ALERT",
				"colorClass": "text-red-500",
				"borderClass": "border-red-600",
				"bgClass": "bg-red-950/40",
				"iconBg": "bg-red-900/60",
				"glowClass": "shadow-[0_0_25px_rgba(220,38,38,0.7)] ring-1 ring-red-500/50",
				"icon": "⚠️",
				"extraAnim": "animate-pulse"
			},
			"important": {
				"title": "TACTICAL EVENT",
				"colorClass": "text-amber-400",
				"borderClass": "border-amber-500",
				"bgClass": "bg-amber-950/28",
				"iconBg": "bg-amber-900/38",
				"glowClass": "shadow-[0_0_15px_rgba(245,158,11,0.5)]",
				"icon": "⚔️",
				"extraAnim": ""
			},
			"normal": {
				"title": "SYSTEM LOG",
				"colorClass": "text-emerald-400",
				"borderClass": "border-emerald-500",
				"bgClass": "bg-emerald-950/20",
				"iconBg": "bg-emerald-900/28",
				"glowClass": "shadow-[0_0_10px_rgba(16,185,129,0.3)]",
				"icon": "⚡",
				"extraAnim": ""
			}
		},
		"items": [
			{
				"id": "msg-test-critical-1",
				"tag": "base-shield-broken",
				"level": "critical",
				"text": "测试：基地护盾崩溃，进入高危状态",
				"duration": 8000,
				"timestamp": 1
			},
			{
				"id": "msg-test-important-1",
				"tag": "kill-streak",
				"level": "important",
				"text": "测试：我方完成关键击杀，获得战术优势",
				"duration": 6000,
				"timestamp": 2
			},
			{
				"id": "msg-test-normal-1",
				"tag": "buff-activated",
				"level": "normal",
				"text": "测试：系统提示，增益模块已激活",
				"duration": 4500,
				"timestamp": 3
			}
		]
	},
	"controls": {
		"activeRole": "infantry",
		"isLocked": false,
		"infantrySettings": {"chassis": "hp", "firing": "burst"},
		"heroSettings": {"chassis": "hp", "firing": "melee"},
		"sentrySettings": {"mode": "auto"},
		"dartTarget": "1",
		"gateOpen": false,
		"toastDurationMs": 2500,
		"costs": {
			"remoteHeal": 200
		},
		"ammoStore": {
			"infantry": {
				"normal": {"title": "步兵弹药", "unitPrice": 1, "step": 10, "desc": "10金币/10发"},
				"airdrop": {"title": "步兵弹药(空投)", "unitPrice": 1.5, "step": 10, "desc": "15金币/10发"}
			},
			"hero": {
				"normal": {"title": "英雄弹药", "unitPrice": 10, "step": 1, "desc": "10金币/1发"},
				"airdrop": {"title": "英雄弹药(空投)", "unitPrice": 15, "step": 1, "desc": "15金币/1发"}
			}
		}
	},
	"robots": {
		"left": [
			{"id": 7, "hp": 600, "max": 600},
			{"id": 6, "hp": 500, "max": 500},
			{"id": 4, "hp": 200, "max": 400},
			{"id": 3, "hp": 400, "max": 400},
			{"id": 2, "hp": 150, "max": 400},
			{"id": 1, "hp": 2000, "max": 2000}
		],
		"right": [
			{"id": 1, "hp": 1800, "max": 2000},
			{"id": 2, "hp": 400, "max": 400},
			{"id": 3, "hp": 0, "max": 400},
			{"id": 4, "hp": 400, "max": 400},
			{"id": 6, "hp": 500, "max": 500},
			{"id": 7, "hp": 600, "max": 600}
		]
	},
	"mecha": {
		"pilotId": "HERO",
		"pilotLevel": "LV.6",
		"linkState": "LINKED",
		"hpLabel": "CORE HP",
		"powerLabel": "ENG PWR",
		"boostLabel": "BOOST",
		"currentMaxLabel": "CUR MAX",
		"ammoLabel": "AMMO",
		"cooldownPrefix": "[CD: ",
		"cooldownSuffix": "s]",
		"statusEngaged": "[ENGAGED]",
		"statusSafe": "[SAFE]",
		"hp": 1650,
		"boost": 400,
		"energy": 2850,
		"ammo": 12450,
		"inCombat": false,
		"combatTimer": 5.0,
		"remoteHealReady": true,
		"remoteAmmoReady": false
	},
	"respawn": {
		"isDead": true,
		"countdown": 10,
		"reviveCost": 500,
		"scale": 0.8,
		"minScale": 0.4,
		"maxScale": 3,
		"texts": {
			"rebootTitle": "SYSTEM REBOOT IN",
			"ready": "READY",
			"ecoLabel": "当前金币(ECO)",
			"normalReviveTitle": "普通复活",
			"normalReviveReadyHint": "点击左键复活",
			"normalReviveCoolingPrefix": "冷却中",
			"buyReviveTitle": "立刻复活",
			"noEcoTitle": "金币不足",
			"buyTriggerHint": "右键触发",
			"confirmBuyTitle": "确认购买？",
			"confirmHint": "左键 确认",
			"cancelHint": "右键 取消"
		}
	},
	"centerHud": {
		"ammo": 300,
		"maxAmmo": 300,
		"heat": 0,
		"maxHeat": 100,
		"isOverheated": false,
		"attackBuffTime": 10,
		"defenseBuffTime": 10,
		"isShooting": false,
		"overheatLabel": "OVERHEAT"
	},
	"boostBuffs": [
		{"id": 1, "type": "attack", "name": "攻击", "time": 15, "icon": "sword", "color": "rose"},
		{"id": 2, "type": "defense", "name": "防御", "time": 8, "icon": "shield", "color": "blue"},
		{"id": 3, "type": "cooling", "name": "冷却", "time": 22, "icon": "snowflake", "color": "cyan"},
		{"id": 4, "type": "power", "name": "功率", "time": 5, "icon": "zap", "color": "amber"},
		{"id": 5, "type": "regen", "name": "回血", "time": 12, "icon": "heartPlus", "color": "emerald"},
		{"id": 6, "type": "ammo", "name": "弹量", "time": 30, "icon": "crosshair", "color": "violet"},
		{"id": 7, "type": "terrain", "name": "跨越", "time": 0, "icon": "mountain", "color": "stone"}
	],
	"miniMap": {
		"title": "小地图",
		"imageSrc": "./map.png",
		"imageAlt": "RoboMaster Map",
		"interactive": true,
		"currentPlayerId": "red-1",
		"players": DEFAULT_MINI_MAP_PLAYERS
	},
	"mapDebug": {
		"updateIntervalMs": 33,
		"miniMapTitle": "地图",
		"uiSizing": {
			"miniMapScale": 1,
			"miniMapWidth": 560,
			"miniMapHeight": 315,
			"miniMapMarkerSize": 28,
			"miniMapBottom": 20,
			"miniMapRight": 20
		}
	}
}
