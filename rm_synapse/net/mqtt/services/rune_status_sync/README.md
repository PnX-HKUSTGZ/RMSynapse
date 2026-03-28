# RuneStatusSync Service

## 作用
缓存并分发 `RuneStatusSync`，提供符文状态与环臂统计。

## 状态模型
- `RuneStatusSyncState { rune_status, activated_arms, average_rings, last_update_msec }`

## 对外信号
- `rune_status_sync_updated(state)`
- `rune_status_changed(rune_status)`
- `rune_arms_changed(activated_arms, average_rings)`

## 主要接口
- `get_state()`
- `get_rune_status()`
- `get_activated_arms()`
- `get_average_rings()`
- `get_rune_status_name(status)`
- `clear_cache()`

## 说明
- `average_rings` 在 V1.3 中为 `float`，对应 getter 与信号参数均保持浮点。
