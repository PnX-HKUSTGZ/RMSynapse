# AirSupportCommand Service

## 作用
发送 `AirSupportCommand`，并通过 `AirSupportStatusSync.airsupport_status` 验证状态切换。

## 接口
- `request_air_support_command(command_id: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 成功判定
- `command_id=1/2`：`airsupport_status == 1`
- `command_id=3`：`airsupport_status == 0`
- 其他 `command_id` 不做额外校验，超时归类为 `VERIFY_TIMEOUT`

## 行为
- 单请求 in-flight，支持覆盖、取消和 1Hz 重发。
