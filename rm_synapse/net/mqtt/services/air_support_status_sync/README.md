# AirSupportStatusSync Service

## 作用
缓存并分发 `AirSupportStatusSync` 消息，提供空中支援状态、剩余时间与被瞄准标记。

## 监听信号
- `ProtocolAdapter.air_support_status_sync(message)`

## 状态模型
- `AirSupportStatusSyncState { airsupport_status, left_time, cost_coins, is_being_targeted, shooter_status, last_update_msec }`

## 对外信号
- `air_support_status_sync_updated(state)`
- `air_support_state_changed(airsupport_status, left_time)`
- `air_support_targeted_changed(is_being_targeted)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`
