# PenaltyInfo Service

## 作用
接收并缓存 `PenaltyInfo` 消息，向 UI 暴露判罚类型、持续秒数和累计判罚次数。

## 监听信号
- `ProtocolAdapter.penalty_info(message)`

## 状态模型
- `PenaltyInfoState { penalty_type, penalty_effect_sec, total_penalty_num, last_update_msec }`

## 对外信号
- `penalty_info_updated(state)`
- `penalty_type_changed(penalty_type)`
- `penalty_effect_changed(penalty_effect_sec)`
- `penalty_count_changed(total_penalty_num)`

## 主要接口
- `get_state()`
- `get_penalty_type()`
- `get_penalty_effect_sec()`
- `get_total_penalty_num()`
- `clear_cache()`
- `ingest_penalty_info(message)`
