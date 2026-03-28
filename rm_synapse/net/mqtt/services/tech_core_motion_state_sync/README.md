# TechCoreMotionStateSync Service

## 作用
缓存并分发 `TechCoreMotionStateSync`，对齐 RM2026 V1.3 的五段状态字段。

## 状态模型
- `TechCoreMotionStateSyncState { maximum_difficulty_level, basic_state, putin_state, move_state, rotate_state, enemy_core_status, remain_time_all, remain_time_step, last_update_msec }`

## 对外信号
- `tech_core_motion_state_sync_updated(state)`
- `tech_core_state_changed(basic_state, putin_state, move_state, rotate_state, enemy_core_status)`

## 主要接口
- `get_state()`
- `get_maximum_difficulty_level()`
- `get_basic_state()`
- `get_putin_state()`
- `get_move_state()`
- `get_rotate_state()`
- `get_enemy_core_status()`
- `get_remain_time_all()`
- `get_remain_time_step()`
- `clear_cache()`

## 说明
- 旧 `status` 字段布局已移除。
- 计时字段保持协议原始秒值，不在服务层推进倒计时。
