extends Node

class DummyRadarSingleRobotInfo:
    extends RefCounted

    var target_pos_x: float = 0.0
    var target_pos_y: float = 0.0
    var is_high_light: int = 0

    func get_target_pos_x() -> float: return target_pos_x
    func get_target_pos_y() -> float: return target_pos_y
    func get_is_high_light() -> int: return is_high_light

class DummyMessage:
    extends RefCounted

    var mechanism_id: Array = []
    var mechanism_time_sec: Array = []

    var total_damage: int = 0
    var collision_damage: int = 0
    var small_projectile_damage: int = 0
    var large_projectile_damage: int = 0
    var dart_splash_damage: int = 0
    var module_offline_damage: int = 0
    var offline_damage: int = 0
    var penalty_damage: int = 0
    var server_kill_damage: int = 0
    var killer_id: int = 0

    var is_pending_respawn: bool = false
    var total_respawn_progress: int = 0
    var current_respawn_progress: int = 0
    var can_free_respawn: bool = false
    var gold_cost_for_respawn: int = 0
    var can_pay_for_respawn: bool = false

    var connection_state: int = 0
    var field_state: int = 0
    var alive_state: int = 0
    var robot_id: int = 0
    var robot_type: int = 0
    var performance_system_shooter: int = 0
    var performance_system_chassis: int = 0
    var level: int = 0
    var max_health: int = 0
    var max_heat: int = 0
    var heat_cooldown_rate: float = 0.0
    var max_power: int = 0
    var max_buffer_energy: int = 0
    var max_chassis_energy: int = 0

    var current_health: int = 0
    var current_heat: float = 0.0
    var last_projectile_fire_rate: float = 0.0
    var current_chassis_energy: int = 0
    var current_buffer_energy: int = 0
    var current_experience: int = 0
    var experience_for_upgrade: int = 0
    var total_projectiles_fired: int = 0
    var remaining_ammo: int = 0
    var is_out_of_combat: bool = false
    var out_of_combat_countdown: int = 0
    var can_remote_heal: bool = false
    var can_remote_ammo: bool = false

    var power_manager: int = 0
    var rfid: int = 0
    var light_strip: int = 0
    var small_shooter: int = 0
    var big_shooter: int = 0
    var uwb: int = 0
    var armor: int = 0
    var video_transmission: int = 0
    var capacitor: int = 0
    var main_controller: int = 0
    var laser_detection_module: int = 0

    var x: float = 0.0
    var y: float = 0.0
    var z: float = 0.0
    var yaw: float = 0.0

    var buff_type: int = 0
    var buff_level: int = 0
    var buff_max_time: int = 0
    var buff_left_time: int = 0

    var intention: int = 0
    var start_pos_x: int = 0
    var start_pos_y: int = 0
    var offset_x: Array = []
    var offset_y: Array = []
    var sender_id: int = 0

    var target_robot_id: int = 0
    var target_pos_x: float = 0.0
    var target_pos_y: float = 0.0
    var torward_angle: float = 0.0
    var is_high_light: int = 0
    var radar_single_robot_info: Array = []

    var maximum_difficulty_level: int = 0
    var status: int = 0
    var enemy_core_status: int = 0
    var remain_time_all: int = 0
    var remain_time_step: int = 0

    var shooter: int = 0
    var chassis: int = 0
    var sentry_control: int = 0

    var rune_status: int = 0
    var activated_arms: int = 0
    var average_rings: float = 0.0

    var posture_id: int = 0
    var is_weakened: bool = false

    var target_id: int = 0
    var open: int = 0

    var airsupport_status: int = 0
    var left_time: int = 0
    var cost_coins: int = 0
    var is_being_targeted: int = 0
    var shooter_status: int = 0

    func get_mechanism_id() -> Array: return mechanism_id
    func get_mechanism_time_sec() -> Array: return mechanism_time_sec

    func get_total_damage() -> int: return total_damage
    func get_collision_damage() -> int: return collision_damage
    func get_small_projectile_damage() -> int: return small_projectile_damage
    func get_large_projectile_damage() -> int: return large_projectile_damage
    func get_dart_splash_damage() -> int: return dart_splash_damage
    func get_module_offline_damage() -> int: return module_offline_damage
    func get_offline_damage() -> int: return offline_damage
    func get_penalty_damage() -> int: return penalty_damage
    func get_server_kill_damage() -> int: return server_kill_damage
    func get_killer_id() -> int: return killer_id

    func get_is_pending_respawn() -> bool: return is_pending_respawn
    func get_total_respawn_progress() -> int: return total_respawn_progress
    func get_current_respawn_progress() -> int: return current_respawn_progress
    func get_can_free_respawn() -> bool: return can_free_respawn
    func get_gold_cost_for_respawn() -> int: return gold_cost_for_respawn
    func get_can_pay_for_respawn() -> bool: return can_pay_for_respawn

    func get_connection_state() -> int: return connection_state
    func get_field_state() -> int: return field_state
    func get_alive_state() -> int: return alive_state
    func get_robot_id() -> int: return robot_id
    func get_robot_type() -> int: return robot_type
    func get_performance_system_shooter() -> int: return performance_system_shooter
    func get_performance_system_chassis() -> int: return performance_system_chassis
    func get_level() -> int: return level
    func get_max_health() -> int: return max_health
    func get_max_heat() -> int: return max_heat
    func get_heat_cooldown_rate() -> float: return heat_cooldown_rate
    func get_max_power() -> int: return max_power
    func get_max_buffer_energy() -> int: return max_buffer_energy
    func get_max_chassis_energy() -> int: return max_chassis_energy

    func get_current_health() -> int: return current_health
    func get_current_heat() -> float: return current_heat
    func get_last_projectile_fire_rate() -> float: return last_projectile_fire_rate
    func get_current_chassis_energy() -> int: return current_chassis_energy
    func get_current_buffer_energy() -> int: return current_buffer_energy
    func get_current_experience() -> int: return current_experience
    func get_experience_for_upgrade() -> int: return experience_for_upgrade
    func get_total_projectiles_fired() -> int: return total_projectiles_fired
    func get_remaining_ammo() -> int: return remaining_ammo
    func get_is_out_of_combat() -> bool: return is_out_of_combat
    func get_out_of_combat_countdown() -> int: return out_of_combat_countdown
    func get_can_remote_heal() -> bool: return can_remote_heal
    func get_can_remote_ammo() -> bool: return can_remote_ammo

    func get_power_manager() -> int: return power_manager
    func get_rfid() -> int: return rfid
    func get_light_strip() -> int: return light_strip
    func get_small_shooter() -> int: return small_shooter
    func get_big_shooter() -> int: return big_shooter
    func get_uwb() -> int: return uwb
    func get_armor() -> int: return armor
    func get_video_transmission() -> int: return video_transmission
    func get_capacitor() -> int: return capacitor
    func get_main_controller() -> int: return main_controller
    func get_laser_detection_module() -> int: return laser_detection_module

    func get_x() -> float: return x
    func get_y() -> float: return y
    func get_z() -> float: return z
    func get_yaw() -> float: return yaw

    func get_buff_type() -> int: return buff_type
    func get_buff_level() -> int: return buff_level
    func get_buff_max_time() -> int: return buff_max_time
    func get_buff_left_time() -> int: return buff_left_time

    func get_intention() -> int: return intention
    func get_start_pos_x() -> int: return start_pos_x
    func get_start_pos_y() -> int: return start_pos_y
    func get_offset_x() -> Array: return offset_x
    func get_offset_y() -> Array: return offset_y
    func get_sender_id() -> int: return sender_id

    func get_target_robot_id() -> int: return target_robot_id
    func get_target_pos_x() -> float: return target_pos_x
    func get_target_pos_y() -> float: return target_pos_y
    func get_torward_angle() -> float: return torward_angle
    func get_is_high_light() -> int: return is_high_light
    func get_radar_single_robot_info() -> Array: return radar_single_robot_info

    func get_maximum_difficulty_level() -> int: return maximum_difficulty_level
    func get_status() -> int: return status
    func get_enemy_core_status() -> int: return enemy_core_status
    func get_remain_time_all() -> int: return remain_time_all
    func get_remain_time_step() -> int: return remain_time_step

    func get_shooter() -> int: return shooter
    func get_chassis() -> int: return chassis
    func get_sentry_control() -> int: return sentry_control

    func get_rune_status() -> int: return rune_status
    func get_activated_arms() -> int: return activated_arms
    func get_average_rings() -> float: return average_rings

    func get_posture_id() -> int: return posture_id
    func get_is_weakened() -> bool: return is_weakened

    func get_target_id() -> int: return target_id
    func get_open() -> int: return open

    func get_airsupport_status() -> int: return airsupport_status
    func get_left_time() -> int: return left_time
    func get_cost_coins() -> int: return cost_coins
    func get_is_being_targeted() -> int: return is_being_targeted
    func get_shooter_status() -> int: return shooter_status

class FakeAdapter:
    extends Node
    signal global_special_mechanism(message)
    signal robot_injury_stat(message)
    signal robot_respawn_status(message)
    signal robot_static_status(message)
    signal robot_dynamic_status(message)
    signal robot_module_status(message)
    signal robot_position(message)
    signal buff(message)
    signal robot_path_plan_info(message)
    signal radar_info_to_client(message)
    signal tech_core_motion_state_sync(message)
    signal robot_performance_selection_sync(message)
    signal deploy_mode_status_sync(message)
    signal rune_status_sync(message)
    signal sentry_status_sync(message)
    signal dart_select_target_status_sync(message)
    signal air_support_status_sync(message)

class FakeAdapterGetter:
    extends MQTTProtocolAdapterGetter
    var adapter_ref = null

    func get_adapter_silent():
        return adapter_ref

    func get_adapter():
        return adapter_ref

func _make_message(fields: Dictionary) -> DummyMessage:
    var m = DummyMessage.new()
    for k in fields.keys():
        m.set(str(k), fields[k])
    return m

func _make_radar_targets(items: Array) -> Array:
    var targets := []
    for item in items:
        var target = DummyRadarSingleRobotInfo.new()
        if item is Dictionary:
            target.target_pos_x = float(item.get("target_pos_x", 0.0))
            target.target_pos_y = float(item.get("target_pos_y", 0.0))
            target.is_high_light = int(item.get("is_high_light", 0))
        targets.append(target)
    return targets

func _run_case(
    name: String,
    service: Node,
    ingest_method: String,
    signal_name: String,
    read_value: Callable,
    default_val: int,
    val_a: int,
    val_b: int,
    fields_a: Dictionary,
    fields_b: Dictionary,
    errors: Array[String]
) -> void:
    service.clear_cache()
    if int(read_value.call(service)) != default_val:
        errors.append("%s default" % name)

    var msg_a = _make_message(fields_a)
    service.call(ingest_method, msg_a)
    if int(read_value.call(service)) != val_a:
        errors.append("%s ingest" % name)

    service.clear_cache()
    if int(read_value.call(service)) != default_val:
        errors.append("%s clear_cache" % name)

    var getter = FakeAdapterGetter.new()
    var delayed_service = service.get_script().new()
    delayed_service.adapter_getter = getter
    delayed_service.bind_retry_interval_sec = 0.01

    var adapter_a = FakeAdapter.new()
    adapter_a.emit_signal(signal_name, msg_a)
    if int(read_value.call(delayed_service)) != default_val:
        errors.append("%s delayed prebind" % name)

    getter.adapter_ref = adapter_a
    delayed_service._process(0.2)
    adapter_a.emit_signal(signal_name, msg_a)
    if int(read_value.call(delayed_service)) != val_a:
        errors.append("%s delayed bind ingest" % name)

    var msg_b = _make_message(fields_b)
    var adapter_b = FakeAdapter.new()
    getter.adapter_ref = adapter_b
    delayed_service._process(0.2)

    adapter_a.emit_signal(signal_name, msg_b)
    if int(read_value.call(delayed_service)) != val_a:
        errors.append("%s rebind stale old adapter" % name)

    adapter_b.emit_signal(signal_name, msg_b)
    if int(read_value.call(delayed_service)) != val_b:
        errors.append("%s rebind new adapter" % name)

func _assert_robot_dynamic_signals(errors: Array[String]) -> void:
    var svc = RobotDynamicStatusService.new()
    var health_changed_count := [0]
    var energy_changed_count := [0]
    var combat_changed_count := [0]
    var updated_count := [0]

    svc.health_changed.connect(func(_current_health):
        health_changed_count[0] += 1
    )
    svc.energy_changed.connect(func(_chassis_energy, _buffer_energy):
        energy_changed_count[0] += 1
    )
    svc.combat_state_changed.connect(func(_is_out_of_combat, _countdown):
        combat_changed_count[0] += 1
    )
    svc.robot_dynamic_status_updated.connect(func(_state):
        updated_count[0] += 1
    )

    svc.ingest_robot_dynamic_status(_make_message({
        "current_health": 100,
        "current_chassis_energy": 20,
        "current_buffer_energy": 30,
        "is_out_of_combat": false,
        "out_of_combat_countdown": 0
    }))
    svc.ingest_robot_dynamic_status(_make_message({
        "current_health": 100,
        "current_chassis_energy": 20,
        "current_buffer_energy": 30,
        "is_out_of_combat": true,
        "out_of_combat_countdown": 5
    }))
    svc.ingest_robot_dynamic_status(_make_message({
        "current_health": 100,
        "current_chassis_energy": 20,
        "current_buffer_energy": 30,
        "is_out_of_combat": true,
        "out_of_combat_countdown": 5,
        "current_heat": 99.0
    }))

    if health_changed_count[0] != 1:
        errors.append("robot_dynamic_status signal health_changed count")
    if energy_changed_count[0] != 1:
        errors.append("robot_dynamic_status signal energy_changed count")
    if combat_changed_count[0] != 1:
        errors.append("robot_dynamic_status signal combat_state_changed count")
    if updated_count[0] != 3:
        errors.append("robot_dynamic_status signal updated count")

func _assert_robot_respawn_signals(errors: Array[String]) -> void:
    var svc = RobotRespawnStatusService.new()
    var pending_changed_count := [0]
    var progress_changed_count := [0]
    var updated_count := [0]

    svc.respawn_pending_changed.connect(func(_is_pending_respawn):
        pending_changed_count[0] += 1
    )
    svc.respawn_progress_changed.connect(func(_current, _total):
        progress_changed_count[0] += 1
    )
    svc.robot_respawn_status_updated.connect(func(_state):
        updated_count[0] += 1
    )

    svc.ingest_robot_respawn_status(_make_message({
        "is_pending_respawn": true,
        "total_respawn_progress": 100,
        "current_respawn_progress": 10,
        "gold_cost_for_respawn": 20
    }))
    svc.ingest_robot_respawn_status(_make_message({
        "is_pending_respawn": true,
        "total_respawn_progress": 100,
        "current_respawn_progress": 10,
        "gold_cost_for_respawn": 30
    }))
    svc.ingest_robot_respawn_status(_make_message({
        "is_pending_respawn": false,
        "total_respawn_progress": 100,
        "current_respawn_progress": 15,
        "gold_cost_for_respawn": 30
    }))

    if pending_changed_count[0] != 2:
        errors.append("robot_respawn_status signal respawn_pending_changed count")
    if progress_changed_count[0] != 2:
        errors.append("robot_respawn_status signal respawn_progress_changed count")
    if updated_count[0] != 3:
        errors.append("robot_respawn_status signal updated count")

func _assert_buff_signals(errors: Array[String]) -> void:
    var svc = BuffService.new()
    var target_changed_count := [0]
    var timer_changed_count := [0]
    var updated_count := [0]

    svc.buff_target_changed.connect(func(_robot_id):
        target_changed_count[0] += 1
    )
    svc.buff_timer_changed.connect(func(_left_time, _max_time):
        timer_changed_count[0] += 1
    )
    svc.buff_updated.connect(func(_state):
        updated_count[0] += 1
    )

    svc.ingest_buff(_make_message({
        "robot_id": 3,
        "buff_max_time": 30,
        "buff_left_time": 20,
        "buff_level": 1
    }))
    svc.ingest_buff(_make_message({
        "robot_id": 3,
        "buff_max_time": 30,
        "buff_left_time": 20,
        "buff_level": 2
    }))
    svc.ingest_buff(_make_message({
        "robot_id": 3,
        "buff_max_time": 30,
        "buff_left_time": 10,
        "buff_level": 2
    }))

    if target_changed_count[0] != 1:
        errors.append("buff signal buff_target_changed count")
    if timer_changed_count[0] != 2:
        errors.append("buff signal buff_timer_changed count")
    if updated_count[0] != 3:
        errors.append("buff signal updated count")

func _ready() -> void:
    var errors: Array[String] = []

    _run_case(
        "global_special_mechanism",
        GlobalSpecialMechanismService.new(),
        "ingest_global_special_mechanism",
        "global_special_mechanism",
        func(s): return s.get_active_effects().size(),
        0,
        1,
        2,
        {"mechanism_id": [1], "mechanism_time_sec": [120]},
        {"mechanism_id": [1, 2], "mechanism_time_sec": [120, 90]},
        errors
    )

    _run_case(
        "robot_injury_stat",
        RobotInjuryStatService.new(),
        "ingest_robot_injury_stat",
        "robot_injury_stat",
        func(s): return s.get_total_damage(),
        0,
        11,
        22,
        {"total_damage": 11, "killer_id": 2},
        {"total_damage": 22, "killer_id": 3},
        errors
    )

    _run_case(
        "robot_respawn_status",
        RobotRespawnStatusService.new(),
        "ingest_robot_respawn_status",
        "robot_respawn_status",
        func(s): return s.get_current_respawn_progress(),
        0,
        33,
        55,
        {"current_respawn_progress": 33, "total_respawn_progress": 100},
        {"current_respawn_progress": 55, "total_respawn_progress": 120},
        errors
    )

    _run_case(
        "robot_static_status",
        RobotStaticStatusService.new(),
        "ingest_robot_static_status",
        "robot_static_status",
        func(s): return s.get_robot_id(),
        0,
        101,
        102,
        {"robot_id": 101, "robot_type": 1},
        {"robot_id": 102, "robot_type": 2},
        errors
    )

    _run_case(
        "robot_dynamic_status",
        RobotDynamicStatusService.new(),
        "ingest_robot_dynamic_status",
        "robot_dynamic_status",
        func(s): return s.get_current_health(),
        0,
        150,
        120,
        {"current_health": 150},
        {"current_health": 120},
        errors
    )

    _run_case(
        "robot_module_status",
        RobotModuleStatusService.new(),
        "ingest_robot_module_status",
        "robot_module_status",
        func(s): return s.get_main_controller(),
        0,
        1,
        2,
        {"main_controller": 1},
        {"main_controller": 2},
        errors
    )

    _run_case(
        "robot_position",
        RobotPositionService.new(),
        "ingest_robot_position",
        "robot_position",
        func(s): return s.get_robot_id(),
        0,
        7,
        107,
        {"x": 1.23, "robot_id": 7},
        {"x": 4.56, "robot_id": 107},
        errors
    )

    _run_case(
        "buff",
        BuffService.new(),
        "ingest_buff",
        "buff",
        func(s): return s.get_robot_id(),
        0,
        3,
        5,
        {"robot_id": 3, "buff_type": 1},
        {"robot_id": 5, "buff_type": 2},
        errors
    )

    _run_case(
        "robot_path_plan_info",
        RobotPathPlanInfoService.new(),
        "ingest_robot_path_plan_info",
        "robot_path_plan_info",
        func(s): return s.get_sender_id(),
        0,
        11,
        12,
        {"sender_id": 11, "offset_x": [1, 2], "offset_y": [3, 4]},
        {"sender_id": 12, "offset_x": [5], "offset_y": [6]},
        errors
    )

    _run_case(
        "radar_info_to_client",
        RadarInfoToClientService.new(),
        "ingest_radar_info_to_client",
        "radar_info_to_client",
        func(s): return s.get_targets().size(),
        0,
        1,
        2,
        {"radar_single_robot_info": _make_radar_targets([
            {"target_pos_x": 850, "target_pos_y": 625, "is_high_light": 1}
        ])},
        {"radar_single_robot_info": _make_radar_targets([
            {"target_pos_x": 850, "target_pos_y": 625, "is_high_light": 1},
            {"target_pos_x": 410, "target_pos_y": 320, "is_high_light": 0}
        ])},
        errors
    )

    var radar_mapping_service = RadarInfoToClientService.new()
    radar_mapping_service.ingest_radar_info_to_client(_make_message({
        "radar_single_robot_info": _make_radar_targets([
            {"target_pos_x": 850, "target_pos_y": 625, "is_high_light": 1},
            {"target_pos_x": 410, "target_pos_y": 320, "is_high_light": 0}
        ])
    }))
    var radar_targets = radar_mapping_service.get_targets()
    if radar_mapping_service.get_target_robot_id() != 101:
        errors.append("radar_info_to_client first target id")
    if radar_targets.size() < 2 or radar_targets[1].target_robot_id != 102:
        errors.append("radar_info_to_client second target id")

    _run_case(
        "tech_core_motion_state_sync",
        TechCoreMotionStateSyncService.new(),
        "ingest_tech_core_motion_state_sync",
        "tech_core_motion_state_sync",
        func(s): return s.get_status(),
        0,
        2,
        3,
        {"status": 2},
        {"status": 3},
        errors
    )

    _run_case(
        "robot_performance_selection_sync",
        RobotPerformanceSelectionSyncService.new(),
        "ingest_robot_performance_selection_sync",
        "robot_performance_selection_sync",
        func(s): return s.get_shooter(),
        0,
        4,
        5,
        {"shooter": 4},
        {"shooter": 5},
        errors
    )

    _run_case(
        "deploy_mode_status_sync",
        DeployModeStatusSyncService.new(),
        "ingest_deploy_mode_status_sync",
        "deploy_mode_status_sync",
        func(s): return s.get_status(),
        0,
        1,
        2,
        {"status": 1},
        {"status": 2},
        errors
    )

    _run_case(
        "rune_status_sync",
        RuneStatusSyncService.new(),
        "ingest_rune_status_sync",
        "rune_status_sync",
        func(s): return int(round(s.get_average_rings() * 10.0)),
        0,
        86,
        92,
        {"rune_status": 6, "average_rings": 8.6},
        {"rune_status": 7, "average_rings": 9.2},
        errors
    )

    _run_case(
        "sentry_status_sync",
        SentryStatusSyncService.new(),
        "ingest_sentry_status_sync",
        "sentry_status_sync",
        func(s): return s.get_posture_id(),
        0,
        8,
        9,
        {"posture_id": 8},
        {"posture_id": 9},
        errors
    )

    _run_case(
        "dart_select_target_status_sync",
        DartSelectTargetStatusSyncService.new(),
        "ingest_dart_select_target_status_sync",
        "dart_select_target_status_sync",
        func(s): return s.get_target_id(),
        0,
        301,
        302,
        {"target_id": 301},
        {"target_id": 302},
        errors
    )

    _run_case(
        "air_support_status_sync",
        AirSupportStatusSyncService.new(),
        "ingest_air_support_status_sync",
        "air_support_status_sync",
        func(s): return s.get_airsupport_status(),
        0,
        2,
        4,
        {"airsupport_status": 2},
        {"airsupport_status": 4},
        errors
    )

    _assert_robot_dynamic_signals(errors)
    _assert_robot_respawn_signals(errors)
    _assert_buff_signals(errors)

    if errors.is_empty():
        print("GETTER_SERVICES_ROUND8_SCENE_TEST_OK")
    else:
        print("GETTER_SERVICES_ROUND8_SCENE_TEST_FAIL")
        for e in errors:
            print("FAIL:", e)
    get_tree().quit()
