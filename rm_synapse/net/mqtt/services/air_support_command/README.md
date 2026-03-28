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
- `command_id=0`：`airsupport_status == 0`
- 其他 `command_id` 不做额外校验，超时归类为 `VERIFY_TIMEOUT`

## 说明
- 协议语义按 V1.3：`0=取消`、`1=免费呼叫`、`2=付费呼叫`。
- 服务层不做枚举范围校验，`command_id` 按 raw 值透传。
