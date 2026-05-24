# RadarInfoToClient Service

## 作用
缓存并分发 `RadarInfoToClient` 消息，提供按协议顺序排列的雷达目标位置信息。

## 监听信号
- `ProtocolAdapter.radar_info_to_client(message)`

## 状态模型
- `RadarInfoToClientState { targets, radar_single_robot_info, target_robot_id, target_pos_x, target_pos_y, torward_angle, is_high_light, last_update_msec }`
- `RadarTargetState { target_robot_id, target_pos_x, target_pos_y, is_high_light }`

## 对外信号
- `radar_info_updated(state)`
- `target_changed(target_robot_id)`

## 主要接口
- `get_state()`
- `get_targets()`
- 兼容单目标字段 getter（含 `get_torward_angle()`）
- `clear_cache()`

## 说明
- V1.3.1 协议使用 `repeated RadarSingleRobotInfo radar_single_robot_info = 1`。
- 目标顺序按协议映射为：对方 1/2/3/4/6/7，己方 1/2/3/4/6/7。
- `torward_angle` 仅作为旧 UI 兼容字段保留，V1.3.1 雷达消息不再提供朝向。
