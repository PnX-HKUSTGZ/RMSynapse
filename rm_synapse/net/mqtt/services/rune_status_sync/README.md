# RuneStatusSync Service

## 作用
缓存并分发 `RuneStatusSync` 消息，提供符文状态与环臂参数。

## 监听信号
- `ProtocolAdapter.rune_status_sync(message)`

## 状态模型
- `RuneStatusSyncState { rune_status, activated_arms, average_rings, last_update_msec }`

## 对外信号
- `rune_status_sync_updated(state)`
- `rune_status_changed(rune_status)`
- `rune_arms_changed(activated_arms, average_rings)`

## 主要接口
- `get_state()`
- 各字段 getter
- `get_rune_status_name(status)`（占位）
- `clear_cache()`
