# RobotPerformanceSelectionSync Service

## 作用
缓存并分发 `RobotPerformanceSelectionSync` 消息，提供性能系统选择同步状态。

## 监听信号
- `ProtocolAdapter.robot_performance_selection_sync(message)`

## 状态模型
- `RobotPerformanceSelectionSyncState { shooter, chassis, sentry_control, last_update_msec }`

## 对外信号
- `robot_performance_selection_sync_updated(state)`
- `performance_selection_changed(shooter, chassis, sentry_control)`

## 主要接口
- `get_state()`
- `get_shooter()/get_chassis()/get_sentry_control()`
- `clear_cache()`
