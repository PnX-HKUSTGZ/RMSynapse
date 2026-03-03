# GlobalSpecialMechanism Service

## 作用
缓存并分发 `GlobalSpecialMechanism` 下行消息，提供全局特殊机制剩余时间列表。

## 监听信号
- `ProtocolAdapter.global_special_mechanism(message)`

## 状态模型
- `MechanismState { id, remaining_sec }`
- `GlobalSpecialMechanismState { effects, last_update_msec }`

## 对外信号
- `global_special_mechanism_updated(state)`
- `active_effects_changed(effects)`

## 主要接口
- `get_state()`
- `get_active_effects()`
- `get_effect_name(effect_id)`
- `clear_cache()`

## 说明
- `mechanism_id` 与 `mechanism_time_sec` 长度不一致时按最短长度处理。
- `remaining_sec < 0` 会被钳制为 `0`。
