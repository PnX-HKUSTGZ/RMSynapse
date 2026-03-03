# RuneActivateCommand Service

## 作用
发送 `RuneActivateCommand(activate=1)`，并通过 `RuneStatusSync.rune_status == 3` 判定成功。

## 接口
- `request_rune_activate(timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 行为
- 命令参数固定为 `activate=1`。
- 单请求 in-flight，支持覆盖、取消和 1Hz 重发。
- 未达到激活状态时按超时处理。
