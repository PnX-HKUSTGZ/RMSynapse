# SentryCtrlCommand Service

## 作用
发送 `SentryCtrlCommand`，并依据 `SentryCtrlResult` 判定成功或协议拒绝。

## 接口
- `request_sentry_ctrl_command(command_id: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 成功判定
- 回执 `command_id` 匹配且 `result_code == 0`。
- `result_code != 0` 归类为 `PROTOCOL_REJECTED`。

## 行为
- 单请求 in-flight，支持覆盖、取消和 1Hz 重发。
