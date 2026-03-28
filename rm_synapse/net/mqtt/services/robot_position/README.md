# RobotPosition Service

## 作用
缓存并分发 `RobotPosition` 消息，提供机器人位置、朝向和 `robot_id`。

## 状态模型
- `RobotPositionState { x, y, z, yaw, robot_id, last_update_msec }`

## 对外信号
- `robot_position_updated(state)`
- `position_changed(x, y, z, yaw)`

## 主要接口
- `get_state()`
- `get_x()`
- `get_y()`
- `get_z()`
- `get_yaw()`
- `get_robot_id()`
- `get_planar_position()`
- `clear_cache()`

## 说明
- `position_changed` 仍只在空间坐标或朝向变化时触发，不把 `robot_id` 变化混入该信号。
