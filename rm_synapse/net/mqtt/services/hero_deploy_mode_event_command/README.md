# HeroDeployModeEventCommand Service

## 作用
发送 `HeroDeployModeEventCommand`，并通过 `DeployModeStatusSync.status` 匹配确认成功。

## 接口
- `request_hero_deploy_mode(mode: int, timeout_sec: float = -1.0) -> int`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

## 行为
- 单请求 in-flight，支持覆盖与取消。
- `mode` 仅允许 `0/1`。
- 服务默认按 1Hz 重发，直到 `status == mode` 或超时。
- `ProtocolAdapter` 对该 topic 采用 `100ms` 上限限频。
