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

## 说明
- 协议语义按 V1.3：`0=取消`、`1=免费呼叫`、`2=付费呼叫`。
- `command_id` 仅允许 `0/1/2`。
- 服务默认按 1Hz 重发，直到验证成功或超时。
- `ProtocolAdapter` 不对该 topic 施加统一 topic 限频。
