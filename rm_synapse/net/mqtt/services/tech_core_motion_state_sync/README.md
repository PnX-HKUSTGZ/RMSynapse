# TechCoreMotionStateSync Service

## 作用
缓存并分发 `TechCoreMotionStateSync` 消息，提供科技核心运动状态与剩余时间。

## 监听信号
- `ProtocolAdapter.tech_core_motion_state_sync(message)`

## 状态模型
- `TechCoreMotionStateSyncState { maximum_difficulty_level, status, enemy_core_status, remain_time_all, remain_time_step, last_update_msec }`

## 对外信号
- `tech_core_motion_state_sync_updated(state)`
- `tech_core_status_changed(status, enemy_core_status)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`
