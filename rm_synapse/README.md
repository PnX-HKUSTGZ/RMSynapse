# rm_synapse

本仓库现已拆分为“网络/数据后端”与“待重建前端 UI”两部分：
- 后端（已保留）：`net/` + `protocol/` + `addons/mqtt/`
- 前端（你将重写）：`ui/`
- 旧 UI 已删除（不再被主场景引用）

## 1. 当前运行形态

- 主场景：`test_video.tscn`
- 当前只保留基础壳（`Control`）和 `RMVideoCanvas`，不再加载旧 `ui/main_game_interface/*`。
- 网络层仍通过 AutoLoad 运行，UI 可以随时接入。

## 2. 后端组件总览（你要连接的对象）

AutoLoad 定义见 `project.godot`：
- `MQTT` -> `res://addons/mqtt/mqtt.tscn`
- `MqttNet` -> `res://net/mqtt_net.tscn`
- `IDMap` -> `res://utile/id_map.gd`

`MqttNet` 内部节点（见 `net/mqtt_net.tscn`）：
- `GameState`（脚本：`net/mqtt_game_state.gd`）
  - 下行 MQTT 订阅 + Protobuf 解码 + 状态分发
- `MQTTSender`（脚本：`net/mqtt_sender.gd`）
  - 统一发送队列（高频 latest / 触发 event / 直接发送）
- `RemoteControlSender`（脚本：`net/remote_control_service.gd`）
  - 高频上行 `RemoteControl`（默认 75Hz）
- `LowRateSender`（脚本：`net/low_rate_sender.gd`）
  - 固定低频上行（定时）
- `TriggerSender`（脚本：`net/trigger_service.gd`）
  - 触发式上行（当前封装 `MapClickInfoNotify`）

## 3. 前后端连接方式（新 UI 必看）

### 3.1 在 UI 脚本里拿到后端节点

```gdscript
var net_root := get_node("/root/MqttNet")
var game_state := net_root.get_node("GameState")
var rc_sender := net_root.get_node("RemoteControlSender")
var low_rate_sender := net_root.get_node("LowRateSender")
var trigger_sender := net_root.get_node("TriggerSender")
```

### 3.2 订阅下行数据（推荐优先用专用信号）

`GameState` 提供两类信号：
- 通用：`state_changed(key, value)`
- 专用：每个 topic 对应一个 `*_updated(...)`

主要 topic -> 专用信号映射：
- `GameStatus` -> `game_status_updated`
- `GlobalUnitStatus` -> `global_unit_status_updated`
- `GlobalLogisticsStatus` -> `global_logistics_status_updated`
- `GlobalSpecialMechanism` -> `global_special_mechanism_updated`
- `Event` -> `event_received`
- `RobotInjuryStat` -> `robot_injury_stat_updated`
- `RobotRespawnStatus` -> `robot_respawn_status_updated`
- `RobotStaticStatus` -> `robot_static_status_updated`
- `RobotDynamicStatus` -> `robot_dynamic_status_updated`
- `RobotModuleStatus` -> `robot_module_status_updated`
- `RobotPosition` -> `robot_position_updated`
- `Buff` -> `buff_updated`
- `PenaltyInfo` -> `penalty_info_updated`
- `RobotPathPlanInfo` -> `robot_path_plan_info_updated`
- `RaderInfoToClient` -> `rader_info_updated`
- `RobotPerformanceSelectionSync` -> `robot_performance_selection_sync_updated`
- `DeployModeStatusSync` -> `deploy_mode_status_sync_updated`
- `TechCoreMotionStateSync` -> `tech_core_motion_state_sync_updated`
- `RuneStatusSync` -> `rune_status_sync_updated`
- `SentinelStatusSync` -> `sentinel_status_sync_updated`
- `DartSelectTargetStatusSync` -> `dart_select_target_status_sync_updated`
- `GuardCtrlResult` -> `guard_ctrl_result_updated`
- `AirSupportStatusSync` -> `air_support_status_sync_updated`
- `CustomByteBlock` -> `custom_byte_block_received`

示例（UI 监听）：

```gdscript
func _ready() -> void:
	var game_state := get_node("/root/MqttNet/GameState")
	game_state.robot_dynamic_status_updated.connect(_on_robot_dynamic)
	game_state.robot_static_status_updated.connect(_on_robot_static)
	game_state.mqtt_connected.connect(_on_mqtt_connected)
	game_state.mqtt_disconnected.connect(_on_mqtt_disconnected)

func _on_robot_dynamic(msg) -> void:
	# msg 是 protocol/generated/rm_proto.gd 的对应对象
	# 例如：msg.get_current_health(), msg.get_remaining_ammo()
	pass
```

### 3.3 拉取快照（用于 UI 初始化）

```gdscript
var gs := get_node("/root/MqttNet/GameState")
var snapshot: Dictionary = gs.snapshot()
```

`snapshot()` 返回内部状态深拷贝，适合首帧渲染或页面切换恢复。

### 3.4 上行控制接口

`RemoteControlSender`（高频）：
- `update_mouse(dx, dy, dz)`
- `set_buttons(l, r, m)`
- `set_keyboard_mask(mask)`
- `set_custom_data(bytes, clear_after_send=true)`

默认按键位映射（你可自行改）：
- `w/a/s/d -> bit 0/1/2/3`
- `shift/ctrl/space -> bit 4/5/6`
- `q/e/r/f -> bit 7/8/9/10`
- `1..7 -> bit 11..17`
- `z/x/c -> bit 18/19/20`

`LowRateSender`（低频命令）：
- `set_guard_ctrl_command(command_id)` -> `GuardCtrlCommand`
- `set_hero_deploy_mode(mode)` -> `HeroDeployModeEventCommand`
- `set_rune_activate(activate)` -> `RuneActivateCommand`
- `set_robot_performance_selection(shooter, chassis)` -> `RobotPerformanceSelectionCommand`
- `set_assembly_command(operation, difficulty)` -> `AssemblyCommand`
- `set_air_support_command(command_id)` -> `AirSupportCommand`
- `set_dart_command(target_id, open)` -> `DartCommand`

`TriggerSender`（触发式）：
- `fire_map_click(...)` -> `MapClickInfoNotify`

## 4. 推荐的新 UI 接入步骤

1. 在 `ui/` 下创建你的新场景与脚本。
2. 先做一个最小状态面板：监听 `mqtt_connected/mqtt_disconnected`。
3. 再接 `robot_static_status_updated` + `robot_dynamic_status_updated`，验证基础数据链路。
4. 再接入输入上行（`RemoteControlSender`）。
5. 最后按业务分模块接入低频命令与触发命令。

## 5. 协议定义位置

- Protobuf 源文件：`protocol/rm_custom.proto`
- Godot 生成文件：`protocol/generated/rm_proto.gd`

UI 侧收到的 `msg` 对象来自 `rm_proto.gd`，字段访问使用对应 `get_*` 方法。

## 6. 常见排查

- 没有下行数据：检查 `net/mqtt_net.tscn` 里 `GameState.broker_url`。
- 有连接但无信号：确认你连接的是 `/root/MqttNet/GameState`，不是旧 UI 节点路径。
- 上行无效：确认发送调用的是 `/root/MqttNet/RemoteControlSender` / `LowRateSender` / `TriggerSender`。
- Protobuf 解码异常：检查 topic 与消息类型是否匹配（`net/mqtt_game_state.gd::_decode`）。
