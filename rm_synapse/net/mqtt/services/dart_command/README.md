# DartCommand Service

## 作用
发送 `DartCommand`，支持开闭挡板与发射确认两类操作。

## 接口
- `request_dart_command(target_id: int, open: bool = false, launch_confirm: bool = false, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 成功判定
- `launch_confirm=true`：发送成功即判定成功。
- 其余情况：`DartSelectTargetStatusSync.open` 达到目标值判定成功。

## 行为
- 单请求 in-flight，支持覆盖、取消和 1Hz 重发。
