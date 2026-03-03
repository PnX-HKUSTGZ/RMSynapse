# RobotPathPlanInfo Service

## 作用
缓存并分发 `RobotPathPlanInfo` 消息，提供路径规划意图与偏移点序列。

## 监听信号
- `ProtocolAdapter.robot_path_plan_info(message)`

## 状态模型
- `PathPointOffset { dx, dy }`
- `RobotPathPlanInfoState { intention, start_pos_x, start_pos_y, offsets, sender_id, last_update_msec }`

## 对外信号
- `robot_path_plan_info_updated(state)`
- `path_plan_changed(intention, point_count)`

## 主要接口
- `get_state()`
- `get_offsets()`
- `get_sender_id()`
- `get_absolute_points()`
- `clear_cache()`

## 说明
- `offset_x/offset_y` 长度不一致时按最短长度处理并告警一次。
