# Getter 服务实现需求总文档

## 1. 目的与范围
本文用于统一约束 `rm_synapse/ui/Readme.md` 中 getter 类服务的实现方式，供实现同学直接按文档落代码，后续由 reviewer 按本文审阅。

覆盖范围：`rm_synapse/net/mqtt/services/` 下 getter/downlink 服务（仅接收 MQTT 下行，不负责上行发送）。

## 2. 已完成项（不重复写）
以下需求文档已经完成，直接沿用，不重复撰写：
- [GameStatus README](/home/pnx/code/RMSynapse/rm_synapse/net/mqtt/services/game_status/README.md)
- [GlobalUnitStatus README](/home/pnx/code/RMSynapse/rm_synapse/net/mqtt/services/global_unit_status/README.md)
- [GlobalLogisticsStatus README](/home/pnx/code/RMSynapse/rm_synapse/net/mqtt/services/global_logistics_status/README.md)

## 3. 通用实现规范（所有 getter）
1. 服务脚本统一 `extends Node`，使用 `class_name XxxService`。
2. 统一通过 `MQTTProtocolAdapterGetter` 获取 adapter，监听 `ProtocolAdapter` 对应 topic 信号。
3. 使用强类型状态类（`extends RefCounted`），避免以 `Dictionary` 作为主状态模型。
4. 必须提供 `get_state() -> XxxState`，且返回 `clone()`，避免外部修改内部缓存。
5. 生命周期统一包含：
   - `_ready()` 初次绑定
   - `_process(delta)` 重试绑定（adapter 延迟可用时）
   - `_exit_tree()` 解绑已连接 adapter
6. `clear_cache()` 需重置到默认状态，并发出统一 `*_updated` 信号。
7. 日志需节流（缺依赖/空消息/字段异常避免每帧刷屏）。
8. 测试至少覆盖：
   - 默认值
   - ingest 后字段一致性
   - 关键变更信号
   - clear_cache 恢复
   - adapter 延迟可用 + adapter 替换重绑

## 4. 剩余 getter 需求分解

### 4.1 GlobalSpecialMechanism（1Hz）
- 建议目录：`services/global_special_mechanism/`
- 建议脚本：`global_special_mechanism_service.gd`
- 协议字段：`mechanism_id[]`、`mechanism_time_sec[]`
- 状态模型：
  - `MechanismState { id:int, remaining_sec:int }`
  - `GlobalSpecialMechanismState { effects:Array[MechanismState], last_update_msec:int }`
- 建议信号：
  - `global_special_mechanism_updated(state)`
  - `active_effects_changed(effects)`
- getter：
  - `get_state()`, `get_active_effects()`, `get_effect_name(id)`
- 实现要点：
  - 两数组长度不一致取 `min(size_id, size_time)` 并 `warn once`
  - `remaining_sec < 0` 时 clamp 到 `0`

### 4.2 RobotInjuryStat（1Hz）
- 建议目录：`services/robot_injury_stat/`
- 协议字段：
  - `total_damage`, `collision_damage`, `small_projectile_damage`, `large_projectile_damage`
  - `dart_splash_damage`, `module_offline_damage`, `offline_damage`, `penalty_damage`
  - `server_kill_damage`, `killer_id`
- 状态模型：
  - `RobotInjuryStatState`（上述字段 + `last_update_msec`）
- 建议信号：
  - `robot_injury_stat_updated(state)`
  - `injury_total_changed(total_damage)`
  - `killer_changed(killer_id)`
- getter：每个字段 getter + `get_state()`
- 实现要点：全部转 `int`；`killer_id` 保留原值，不在服务层做 ID 语义推断

### 4.3 RobotRespawnStatus（1Hz）
- 建议目录：`services/robot_respawn_status/`
- 协议字段：
  - `is_pending_respawn`, `total_respawn_progress`, `current_respawn_progress`
  - `can_free_respawn`, `gold_cost_for_respawn`, `can_pay_for_respawn`
- 状态模型：`RobotRespawnStatusState`
- 建议信号：
  - `robot_respawn_status_updated(state)`
  - `respawn_pending_changed(is_pending_respawn)`
  - `respawn_progress_changed(current, total)`
- getter：字段 getter + `get_state()`
- 实现要点：
  - 进度字段保持无符号整型语义（非负）
  - 若 `current > total`，不改值，仅可记录一次 warn

### 4.4 RobotStaticStatus（1Hz）
- 建议目录：`services/robot_static_status/`
- 协议字段：
  - `connection_state`, `field_state`, `alive_state`, `robot_id`, `robot_type`
  - `performance_system_shooter`, `performance_system_chassis`
  - `level`, `max_health`, `max_heat`, `heat_cooldown_rate`
  - `max_power`, `max_buffer_energy`, `max_chassis_energy`
- 状态模型：`RobotStaticStatusState`
- 建议信号：
  - `robot_static_status_updated(state)`
  - `robot_identity_changed(robot_id, robot_type)`
  - `robot_capability_changed(level, max_health, max_power)`
- getter：字段 getter + `get_state()`
- 实现要点：
  - `heat_cooldown_rate` 使用 `float`
  - 可选接 `IdMap` 提供只读辅助 `get_robot_name()`（不改变主状态结构）

### 4.5 RobotDynamicStatus（10Hz）
- 建议目录：`services/robot_dynamic_status/`
- 协议字段：
  - `current_health`, `current_heat`, `last_projectile_fire_rate`
  - `current_chassis_energy`, `current_buffer_energy`
  - `current_experience`, `experience_for_upgrade`
  - `total_projectiles_fired`, `remaining_ammo`
  - `is_out_of_combat`, `out_of_combat_countdown`
  - `can_remote_heal`, `can_remote_ammo`
- 状态模型：`RobotDynamicStatusState`
- 建议信号：
  - `robot_dynamic_status_updated(state)`
  - `health_changed(current_health)`
  - `energy_changed(chassis_energy, buffer_energy)`
  - `combat_state_changed(is_out_of_combat, out_of_combat_countdown)`
- getter：字段 getter + `get_state()`
- 实现要点：
  - 高频更新，避免多余分配（仅在对外返回时 clone）
  - `float` 字段保留精度，不转 int

### 4.6 RobotModuleStatus（1Hz）
- 建议目录：`services/robot_module_status/`
- 协议字段：
  - `power_manager`, `rfid`, `light_strip`, `small_shooter`, `big_shooter`
  - `uwb`, `armor`, `video_transmission`, `capacitor`, `main_controller`, `laser_detection_module`
- 状态模型：`RobotModuleStatusState`
- 建议信号：
  - `robot_module_status_updated(state)`
  - `critical_module_changed(main_controller, power_manager, armor)`
- getter：字段 getter + `get_state()`
- 实现要点：状态值先按 raw int 缓存；枚举名称映射可后续补

### 4.7 RobotPosition（1Hz）
- 建议目录：`services/robot_position/`
- 协议字段：`x`, `y`, `z`, `yaw`, `robot_id`
- 状态模型：`RobotPositionState { x:float, y:float, z:float, yaw:float, robot_id:int, last_update_msec:int }`
- 建议信号：
  - `robot_position_updated(state)`
  - `position_changed(x, y, z, yaw)`
- getter：`get_state()`, `get_x()`, `get_y()`, `get_z()`, `get_yaw()`, `get_robot_id()`
- 实现要点：
  - 可选增加 `get_planar_position() -> Vector2`
  - 不在服务层做坐标系转换

### 4.8 Buff（1Hz）
- 建议目录：`services/buff/`
- 协议字段：`robot_id`, `buff_type`, `buff_level`, `buff_max_time`, `buff_left_time`
- 状态模型：`BuffState`
- 建议信号：
  - `buff_updated(state)`
  - `buff_target_changed(robot_id)`
  - `buff_timer_changed(left_time, max_time)`
- getter：字段 getter + `get_state()`
- 实现要点：
  - `buff_level` 为 `int32`，允许负值
  - 计时字段保持非负语义

### 4.9 RobotPathPlanInfo（1Hz）
- 建议目录：`services/robot_path_plan_info/`
- 协议字段：
  - `intention`, `start_pos_x`, `start_pos_y`
  - `offset_x[]`, `offset_y[]`, `sender_id`
- 状态模型：
  - `PathPointOffset { dx:int, dy:int }`
  - `RobotPathPlanInfoState { intention:int, start_pos_x:int, start_pos_y:int, offsets:Array[PathPointOffset], sender_id:int }`
- 建议信号：
  - `robot_path_plan_info_updated(state)`
  - `path_plan_changed(intention, point_count)`
- getter：`get_state()`, `get_offsets()`, `get_sender_id()`
- 实现要点：
  - `offset_x/y` 长度不一致取 `min` 并 `warn once`
  - 建议提供 `get_absolute_points()`（可选）

### 4.10 RadarInfoToClient（1Hz）
- 建议目录：`services/radar_info_to_client/`
- 协议字段：`repeated RadarSingleRobotInfo radar_single_robot_info`
- 状态模型：
  - `RadarRobotInfo { target_pos_x_cm:int, target_pos_y_cm:int, is_high_light:int }`
  - `RadarInfoToClientState { entries:Array[RadarRobotInfo], last_update_msec:int }`
- 建议信号：
  - `radar_info_updated(state)`
  - `radar_entries_changed(entries)`
- getter：`get_state()`, `get_entries()`, `get_entry(index)`, `get_entry_count()`
- 实现要点：
  - `entries` 固定保存 12 项，顺序为 `enemy 1/2/3/4/6/7` 后接 `ally 1/2/3/4/6/7`
  - 坐标保持厘米单位，不做转换
  - PDF proto 示例非法，仓库固定采用 `radar_single_robot_info = 1` 的最小合法化写法

### 4.11 TechCoreMotionStateSync（1Hz）
- 建议目录：`services/tech_core_motion_state_sync/`
- 协议字段：`maximum_difficulty_level`, `basic_state`, `putin_state`, `move_state`, `rotate_state`, `enemy_core_status`, `remain_time_all`, `remain_time_step`
- 状态模型：`TechCoreMotionStateSyncState`
- 建议信号：
  - `tech_core_motion_state_sync_updated(state)`
  - `tech_core_state_changed(basic_state, putin_state, move_state, rotate_state, enemy_core_status)`
- getter：字段 getter + `get_state()`
- 实现要点：计时字段按秒缓存，不在服务层做倒计时推进

### 4.12 RobotPerformanceSelectionSync（1Hz）
- 建议目录：`services/robot_performance_selection_sync/`
- 协议字段：`shooter`, `chassis`, `sentry_control`
- 状态模型：`RobotPerformanceSelectionSyncState`
- 建议信号：
  - `robot_performance_selection_sync_updated(state)`
  - `performance_selection_changed(shooter, chassis, sentry_control)`
- getter：字段 getter + `get_state()`
- 实现要点：raw int 缓存；枚举解释后续补充

### 4.13 DeployModeStatusSync（1Hz）
- 建议目录：`services/deploy_mode_status_sync/`
- 协议字段：`status`
- 状态模型：`DeployModeStatusSyncState`
- 建议信号：
  - `deploy_mode_status_sync_updated(state)`
  - `deploy_mode_changed(status)`
- getter：`get_state()`, `get_status()`
- 实现要点：保留 `get_status_name(status)` 占位接口（Unknown 默认）

### 4.14 RuneStatusSync（1Hz）
- 建议目录：`services/rune_status_sync/`
- 协议字段：`rune_status`, `activated_arms`, `average_rings`
- 状态模型：`RuneStatusSyncState`
- 建议信号：
  - `rune_status_sync_updated(state)`
  - `rune_status_changed(rune_status)`
  - `rune_arms_changed(activated_arms, average_rings)`
- getter：字段 getter + `get_state()`
- 实现要点：`average_rings` 保持 `float`；其余字段按 int 缓存；保留枚举名映射函数

### 4.15 SentryStatusSync（1Hz）
- 建议目录：`services/sentry_status_sync/`
- 协议字段：`posture_id`, `is_weakened`
- 状态模型：`SentryStatusSyncState`
- 建议信号：
  - `sentry_status_sync_updated(state)`
  - `sentry_posture_changed(posture_id)`
  - `sentry_weakened_changed(is_weakened)`
- getter：字段 getter + `get_state()`
- 实现要点：`is_weakened` 使用 `bool` 缓存

### 4.16 DartSelectTargetStatusSync（1Hz）
- 建议目录：`services/dart_select_target_status_sync/`
- 协议字段：`target_id`, `open`
- 状态模型：`DartSelectTargetStatusSyncState`
- 建议信号：
  - `dart_select_target_status_sync_updated(state)`
  - `dart_target_changed(target_id, open)`
- getter：字段 getter + `get_state()`
- 实现要点：`open` 当前协议为 `uint32`，先按 int 保存，不强转 bool

### 4.17 AirSupportStatusSync（1Hz）
- 建议目录：`services/air_support_status_sync/`
- 协议字段：`airsupport_status`, `left_time`, `cost_coins`, `is_being_targeted`, `shooter_status`
- 状态模型：`AirSupportStatusSyncState`
- 建议信号：
  - `air_support_status_sync_updated(state)`
  - `air_support_state_changed(airsupport_status, left_time)`
  - `air_support_targeted_changed(is_being_targeted)`
- getter：字段 getter + `get_state()`
- 实现要点：
  - `left_time`/`cost_coins` 为整型秒/资源值
  - `is_being_targeted` 先按 int 标志位保存

## 5. 实现顺序建议（交付节奏）
1. `GlobalSpecialMechanism`（已有基础代码，先补齐文档规范与测试）
2. `RobotDynamicStatus`、`RobotStaticStatus`、`RobotPosition`（UI最常用）
3. `RobotModuleStatus`、`RobotRespawnStatus`、`RobotInjuryStat`
4. `Buff`、`RobotPathPlanInfo`、`RadarInfoToClient`
5. 其余同步类（`TechCoreMotionStateSync` 等）

## 6. Reviewer 审阅清单（后续按此验收）
1. 是否使用强类型状态类而非 Dictionary 主模型。
2. `get_state()` 是否返回 clone，避免外部改写缓存。
3. 是否存在 adapter 延迟绑定 + 替换重绑逻辑。
4. `clear_cache()` 是否恢复默认并发出统一 updated 信号。
5. 是否覆盖“默认值 / ingest / clear / 延迟绑定 / adapter 替换”测试。
6. 是否避免日志刷屏（warn/error 节流）。
