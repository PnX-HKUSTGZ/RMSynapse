# Generated Protobuf Organization

## Overview

`rm_proto.gd` 已拆分为多文件结构，便于维护和定位：

- `protocol/generated/rm_proto.gd`
  - 兼容入口（facade）。
  - 对外导出与旧版本相同的类型访问方式。
- `protocol/generated/split/rm_proto_state.gd`
  - 下行状态类（GameStatus、RobotDynamicStatus 等）。
- `protocol/generated/split/rm_proto_control.gd`
  - 高频控制与触发类（RemoteControl、MapClickInfoNotify）。
- `protocol/generated/split/rm_proto_command.gd`
  - 低频命令/同步类（AssemblyCommand、RuneStatusSync 等）。

## Compatibility

现有业务代码无需修改，仍然可用：

```gdscript
const Proto = preload("res://protocol/generated/rm_proto.gd")
var msg = Proto.GameStatus.new()
```

`Proto.PB_ERR`、`Proto.PBPacker` 等公共符号也保持可访问。

## Message Grouping

- `state`:
  - `GameStatus`
  - `GlobalUnitStatus`
  - `GlobalLogisticsStatus`
  - `GlobalSpecialMechanism`
  - `Event`
  - `RobotInjuryStat`
  - `RobotRespawnStatus`
  - `RobotStaticStatus`
  - `RobotDynamicStatus`
  - `RobotModuleStatus`
  - `RobotPosition`
  - `Buff`
  - `PenaltyInfo`
  - `RobotPathPlanInfo`
  - `RaderInfoToClient`
  - `CustomByteBlock`
- `control`:
  - `RemoteControl`
  - `MapClickInfoNotify`
- `command`:
  - `AssemblyCommand`
  - `TechCoreMotionStateSync`
  - `RobotPerformanceSelectionCommand`
  - `RobotPerformanceSelectionSync`
  - `HeroDeployModeEventCommand`
  - `DeployModeStatusSync`
  - `RuneActivateCommand`
  - `RuneStatusSync`
  - `SentinelStatusSync`
  - `DartCommand`
  - `DartSelectTargetStatusSync`
  - `GuardCtrlCommand`
  - `GuardCtrlResult`
  - `AirSupportCommand`
  - `AirSupportStatusSync`

## Notes

- `split/*.gd` 为生成后组织文件，不建议手改消息字段。
- 当 `protocol/rm_custom.proto` 变化时，建议重新生成 protobuf 代码，再同步更新拆分文件与 facade 导出映射。
