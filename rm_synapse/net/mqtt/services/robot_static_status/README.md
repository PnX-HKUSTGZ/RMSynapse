# RobotStaticStatus Service

## 作用
缓存并分发 `RobotStaticStatus` 消息，提供机器人静态能力参数与身份信息。

## 监听信号
- `ProtocolAdapter.robot_static_status(message)`

## 状态模型
- `RobotStaticStatusState`
  - 身份与连接：`connection_state/field_state/alive_state/robot_id/robot_type`
  - 性能选择：`performance_system_shooter/performance_system_chassis`
  - 上限能力：`level/max_health/max_heat/heat_cooldown_rate/max_power/max_buffer_energy/max_chassis_energy`

## 对外信号
- `robot_static_status_updated(state)`
- `robot_identity_changed(robot_id, robot_type)`
- `robot_capability_changed(level, max_health, max_power)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`
