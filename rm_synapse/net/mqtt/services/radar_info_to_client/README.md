# RadarInfoToClient Service

## 作用
缓存并分发 `RadarInfoToClient` 消息，提供雷达目标位置与朝向信息。

## 监听信号
- `ProtocolAdapter.radar_info_to_client(message)`

## 状态模型
- `RadarInfoToClientState { target_robot_id, target_pos_x, target_pos_y, torward_angle, is_high_light, last_update_msec }`

## 对外信号
- `radar_info_updated(state)`
- `target_changed(target_robot_id)`

## 主要接口
- `get_state()`
- 各字段 getter（含 `get_torward_angle()`）
- `clear_cache()`

## 说明
- 字段名保持与 proto getter 对齐：`torward_angle`。
