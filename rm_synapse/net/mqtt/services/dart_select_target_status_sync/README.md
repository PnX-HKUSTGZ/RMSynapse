# DartSelectTargetStatusSync Service

## 作用
缓存并分发 `DartSelectTargetStatusSync` 消息，提供镖弹目标选择与开关状态。

## 监听信号
- `ProtocolAdapter.dart_select_target_status_sync(message)`

## 状态模型
- `DartSelectTargetStatusSyncState { target_id, open, last_update_msec }`

## 对外信号
- `dart_select_target_status_sync_updated(state)`
- `dart_target_changed(target_id, open)`

## 主要接口
- `get_state()`
- `get_target_id()`
- `get_open()`
- `clear_cache()`

## 说明
- `open` 按 `int` 保存，不强转 `bool`。
