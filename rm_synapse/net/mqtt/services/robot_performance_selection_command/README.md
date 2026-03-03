# RobotPerformanceSelectionCommand Service

## 作用
发送 `RobotPerformanceSelectionCommand`，并通过 `RobotPerformanceSelectionSync` 三字段匹配确认成功。

## 接口
- `request_robot_performance_selection(shooter: int, chassis: int, sentry_control: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 行为
- 同时仅允许一个 in-flight 请求，新请求覆盖旧请求。
- 请求按 1Hz 重发，直到 `shooter/chassis/sentry_control` 与目标一致或超时。
- 统一失败码见 `ErrorCode`。
