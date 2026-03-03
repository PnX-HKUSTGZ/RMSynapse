# DeployModeStatusSync Service

## 作用
缓存并分发 `DeployModeStatusSync` 消息，提供部署模式状态。

## 监听信号
- `ProtocolAdapter.deploy_mode_status_sync(message)`

## 状态模型
- `DeployModeStatusSyncState { status, last_update_msec }`

## 对外信号
- `deploy_mode_status_sync_updated(state)`
- `deploy_mode_changed(status)`

## 主要接口
- `get_state()`
- `get_status()`
- `get_status_name(status)`（占位，默认 Unknown）
- `clear_cache()`
