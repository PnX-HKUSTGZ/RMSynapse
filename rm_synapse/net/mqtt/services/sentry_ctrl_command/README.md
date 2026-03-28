# SentryCtrlCommand Service

## 作用
发送 `SentryCtrlCommand`，并依据 `SentryCtrlResult` 判定成功或协议拒绝。

## 接口
- `request_sentry_ctrl_command(command_id: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 成功判定
- 回执 `command_id` 匹配且 `result_code == 0`
- `result_code != 0` 归类为 `PROTOCOL_REJECTED`

## 说明
- `command_id` 仅允许 `1..9`。
- README 不保留旧版“`7=地图标点`”说明；具体含义以当期协议表为准。
- 服务默认按 1Hz 重发，直到收到 `SentryCtrlResult` 或超时。
- `ProtocolAdapter` 对该 topic 采用 `100ms` 上限限频。
