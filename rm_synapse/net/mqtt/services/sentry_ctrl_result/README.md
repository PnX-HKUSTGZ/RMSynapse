# SentryCtrlResult Service

## 作用
接收并缓存 `SentryCtrlResult`，用于给 operate 层提供哨兵控制指令执行回执。

## 监听信号
- `ProtocolAdapter.sentry_ctrl_result(message)`

## 状态模型
- `SentryCtrlResultState { command_id, result_code, last_update_msec }`

## 对外信号
- `sentry_ctrl_result_updated(state)`
- `command_result_changed(command_id, result_code)`

## 主要接口
- `get_state()`
- `get_command_id()`
- `get_result_code()`
- `clear_cache()`
- `ingest_sentry_ctrl_result(message)`
