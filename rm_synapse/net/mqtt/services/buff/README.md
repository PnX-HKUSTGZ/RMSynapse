# Buff Service

## 作用
缓存并分发 `Buff` 消息，提供目标机器人 Buff 类型、等级与计时。

## 监听信号
- `ProtocolAdapter.buff(message)`

## 状态模型
- `BuffState { robot_id, buff_type, buff_level, buff_max_time, buff_left_time, last_update_msec }`

## 对外信号
- `buff_updated(state)`
- `buff_target_changed(robot_id)`
- `buff_timer_changed(left_time, max_time)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`

## 说明
- 计时字段按非负语义缓存。
- `buff_level` 保留协议有符号整型语义。
