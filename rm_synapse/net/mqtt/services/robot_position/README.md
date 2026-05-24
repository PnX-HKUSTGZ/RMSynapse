# RobotPosition Service

## 作用
缓存并分发 `RobotPosition` 消息，提供机器人三维位置与朝向。

## 监听信号
- `ProtocolAdapter.robot_position(message)`

## 状态模型
- `RobotPositionState { x, y, z, yaw, robot_id, last_update_msec }`

## 对外信号
- `robot_position_updated(state)`
- `position_changed(x, y, z, yaw)`
- `robot_id_changed(robot_id)`

## 主要接口
- `get_state()`
- `get_x()/get_y()/get_z()/get_yaw()/get_robot_id()`
- `get_planar_position()`
- `clear_cache()`
