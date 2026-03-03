# SentryStatusSync Service

## 作用
缓存并分发 `SentryStatusSync` 消息，提供哨兵姿态与虚弱状态。

## 监听信号
- `ProtocolAdapter.sentry_status_sync(message)`

## 状态模型
- `SentryStatusSyncState { posture_id, is_weakened, last_update_msec }`

## 对外信号
- `sentry_status_sync_updated(state)`
- `sentry_posture_changed(posture_id)`
- `sentry_weakened_changed(is_weakened)`

## 主要接口
- `get_state()`
- `get_posture_id()`
- `get_is_weakened()`
- `clear_cache()`
