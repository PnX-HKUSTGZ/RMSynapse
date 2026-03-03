# RobotRespawnStatus Service

## 作用
缓存并分发 `RobotRespawnStatus` 消息，提供复活状态、进度与资源代价。

## 监听信号
- `ProtocolAdapter.robot_respawn_status(message)`

## 状态模型
- `RobotRespawnStatusState`
  - `is_pending_respawn`
  - `total_respawn_progress`
  - `current_respawn_progress`
  - `can_free_respawn`
  - `gold_cost_for_respawn`
  - `can_pay_for_respawn`

## 对外信号
- `robot_respawn_status_updated(state)`
- `respawn_pending_changed(is_pending_respawn)`
- `respawn_progress_changed(current, total)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`

## 说明
- 进度字段按非负整数缓存。
- 当 `current > total` 时保留原值并输出一次告警。
