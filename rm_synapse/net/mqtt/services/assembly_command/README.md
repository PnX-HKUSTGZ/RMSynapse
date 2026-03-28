# AssemblyCommand Service

## 作用
发送 `AssemblyCommand`，并通过 `TechCoreMotionStateSync` 更新确认命令生效。

## 接口
- `request_assembly_command(operation: int, difficulty: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 失败码
- `OK=0`
- `OVERRIDDEN=1`
- `SEND_REJECTED=2`
- `PROTOCOL_REJECTED=3`
- `VERIFY_TIMEOUT=4`
- `CANCELED=5`

## 行为
- 同时仅允许一个 in-flight 请求。
- 新请求覆盖旧请求（旧请求回调 `OVERRIDDEN`）。
- `operation` 仅允许 `0/1/2`，`difficulty` 由调用方按协议语义提供。
- 服务默认按 1Hz 重发，直到收到状态更新或超时。
- `ProtocolAdapter` 对该 topic 采用 `100ms` 上限限频。
