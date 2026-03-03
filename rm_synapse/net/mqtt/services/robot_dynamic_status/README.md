# RobotDynamicStatus Service

## 作用
缓存并分发 `RobotDynamicStatus` 高频消息（10Hz），提供生命值、能量、热量与战斗态。

## 监听信号
- `ProtocolAdapter.robot_dynamic_status(message)`

## 状态模型
- `RobotDynamicStatusState`
  - 血量/热量/射速
  - 底盘与缓冲能量
  - 经验与升级需求
  - 发弹累计与剩余弹药
  - 脱战状态与倒计时
  - 远程补给能力

## 对外信号
- `robot_dynamic_status_updated(state)`
- `health_changed(current_health)`
- `energy_changed(chassis_energy, buffer_energy)`
- `combat_state_changed(is_out_of_combat, out_of_combat_countdown)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`
