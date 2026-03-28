# RadarInfoToClient Service

## 作用
缓存并分发 `RadarInfoToClient`，按协议顺序暴露整组雷达目标信息。

## 状态模型
- `RadarRobotInfo { target_pos_x_cm, target_pos_y_cm, is_high_light }`
- `RadarInfoToClientState { entries, last_update_msec }`

## 对外信号
- `radar_info_updated(state)`
- `radar_entries_changed(entries)`

## 主要接口
- `get_state()`
- `get_entries()`
- `get_entry(index)`
- `get_entry_count()`
- `clear_cache()`

## entries 顺序
固定 12 项：
1. `enemy 1`
2. `enemy 2`
3. `enemy 3`
4. `enemy 4`
5. `enemy 6`
6. `enemy 7`
7. `ally 1`
8. `ally 2`
9. `ally 3`
10. `ally 4`
11. `ally 6`
12. `ally 7`

## 说明
- 坐标保持原始厘米单位，不做米制转换。
- 超出 12 项的协议数据会被截断；不足 12 项时剩余位置补零。
- PDF 中 `RadarInfoToClient` 的 proto 示例不是合法 proto；仓库采用合法化后的 `repeated RadarSingleRobotInfo radar_single_robot_info = 1` 作为固定实现。
