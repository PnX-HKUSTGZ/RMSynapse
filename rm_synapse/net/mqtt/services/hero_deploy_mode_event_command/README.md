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
- 按 1Hz 重发，直到 `status == mode` 或超时。
