# rm_synapse

本工程当前由 Godot 壳层、MQTT 数据层和 CEF React UI 组成：
- MQTT 后端：`net/mqtt/` + `addons/mqtt/`
- 前端页面：`ui/` 与 `ui/web/`
- 调试日志：`utile/log/`

## 1. 当前运行形态

- 主场景：`Main.tscn`
- HUD 场景：`ui/HUD.tscn`
- 视频占位场景：`net/video_udp/transfer_image.tscn`
- 网络层和日志层通过 AutoLoad 运行。

## 2. 后端组件总览（你要连接的对象）

AutoLoad 定义见 `project.godot`：
- `Mqtt` -> `res://net/mqtt/mqtt.tscn`
- `Log` -> `res://utile/log/log.tscn`

`Mqtt` 内部节点（见 `net/mqtt/mqtt.tscn`）：
- `Adapter`（脚本：`net/mqtt/adapter/protocol_adapter.gd`）
  - Topic 与 Protobuf 消息互转，并分发 HUD 所需信号。
- `Transport`（脚本：`net/mqtt/transport/network_transport.gd`）
  - 基于 `addons/mqtt/mqtt.gd` 连接 Broker。
- `ClientSetter`（脚本：`net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd`）
  - 接收 UI 设置并更新 Broker、端口、Client ID。

## 3. 前后端连接方式（新 UI 必看）

### 3.1 在 UI 脚本里拿到后端节点

```gdscript
var mqtt_root := get_node("/root/Mqtt")
var adapter := mqtt_root.get_node("Adapter")
var transport := mqtt_root.get_node("Transport")
var client_setter := mqtt_root.get_node("ClientSetter")
```

### 3.2 订阅下行数据（推荐优先用专用信号）

`Adapter` 提供每个 topic 对应的专用信号。

主要 topic -> 专用信号映射：
- `GameStatus` -> `game_status`
- `GlobalUnitStatus` -> `global_unit_status`
- `GlobalLogisticsStatus` -> `global_logistics_status`
- `GlobalSpecialMechanism` -> `global_special_mechanism`
- `Event` -> `event_message`
- `RobotInjuryStat` -> `robot_injury_stat`
- `RobotRespawnStatus` -> `robot_respawn_status`
- `RobotStaticStatus` -> `robot_static_status`
- `RobotDynamicStatus` -> `robot_dynamic_status`
- `RobotModuleStatus` -> `robot_module_status`
- `RobotPosition` -> `robot_position`
- `Buff` -> `buff`
- `PenaltyInfo` -> `penalty_info`
- `RobotPathPlanInfo` -> `robot_path_plan_info`
- `RadarInfoToClient` -> `radar_info_to_client`
- `RobotPerformanceSelectionSync` -> `robot_performance_selection_sync`
- `DeployModeStatusSync` -> `deploy_mode_status_sync`
- `TechCoreMotionStateSync` -> `tech_core_motion_state_sync`
- `RuneStatusSync` -> `rune_status_sync`
- `SentryStatusSync` -> `sentry_status_sync`
- `DartSelectTargetStatusSync` -> `dart_select_target_status_sync`
- `SentryCtrlResult` -> `sentry_ctrl_result`
- `AirSupportStatusSync` -> `air_support_status_sync`
- `CustomByteBlock` -> `custom_byte_block`

示例（UI 监听）：

```gdscript
func _ready() -> void:
	var adapter := get_node("/root/Mqtt/Adapter")
	adapter.robot_dynamic_status.connect(_on_robot_dynamic)
	adapter.robot_static_status.connect(_on_robot_static)
	adapter.decoded_message.connect(_on_decoded_message)

func _on_robot_dynamic(msg) -> void:
	# msg 是 net/mqtt/proto/generated/rm_custom_pb.gd 的对应对象
	# 例如：msg.get_current_health(), msg.get_remaining_ammo()
	pass
```

### 3.3 上行控制接口

`Adapter` 提供统一发送方法：
- `send_keyboard_mouse_control(data)` -> `KeyboardMouseControl`
- `send_custom_control(data)` -> `CustomControl`
- `send_map_click_cmd(data)` -> `MapClickCmd`
- `send_assembly_command(data)` -> `AssemblyCommand`
- `send_robot_performance_selection_command(data)` -> `RobotPerformanceSelectionCommand`
- `send_common_command(data)` -> 买血、买弹、复活等通用命令
- `send_hero_deploy_mode_event_command(data)` -> `HeroDeployModeEventCommand`
- `send_rune_activate_command(data)` -> `RuneActivateCommand`
- `send_dart_command(data)` -> `DartCommand`
- `send_sentry_ctrl_command(data)` -> `SentryCtrlCommand`
- `send_air_support_command(data)` -> `AirSupportCommand`

## 4. 推荐的新 UI 接入步骤

1. 在 `ui/` 下创建你的新场景与脚本。
2. 先做一个最小状态面板：监听 `decoded_message` 和 `decode_failed`。
3. 再接 `robot_static_status_updated` + `robot_dynamic_status_updated`，验证基础数据链路。
4. 再接入输入上行（`send_keyboard_mouse_control` / `send_custom_control`）。
5. 最后按业务分模块接入低频命令与触发命令。

## 5. 协议定义位置

- Protobuf 源文件：`net/mqtt/proto/rm_custom.proto`
- Godot 生成文件：`net/mqtt/proto/generated/rm_custom_pb.gd`

UI 侧收到的 `msg` 对象来自 `rm_custom_pb.gd`，字段访问使用对应 `get_*` 方法。

## 6. 常见排查

- 没有下行数据：检查 `net/mqtt/mqtt.tscn` 里的 `Transport.broker_url`，或 ESC 设置里的 Broker/Port/ClientID。
- 有连接但无信号：确认你连接的是 `/root/Mqtt/Adapter`。
- 上行无效：确认发送调用的是 `/root/Mqtt/Adapter`，并检查 `message_sent` 的返回值。
- Protobuf 解码异常：检查 topic 与消息类型是否匹配（`net/mqtt/adapter/protocol_adapter.gd`）。
