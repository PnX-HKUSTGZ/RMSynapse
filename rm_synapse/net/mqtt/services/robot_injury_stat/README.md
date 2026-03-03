# RobotInjuryStat Service

## 作用
缓存并分发 `RobotInjuryStat` 消息，提供伤害分项与击杀来源（killer_id）。

## 监听信号
- `ProtocolAdapter.robot_injury_stat(message)`

## 状态模型
- `RobotInjuryStatState`
  - `total_damage`
  - `collision_damage`
  - `small_projectile_damage`
  - `large_projectile_damage`
  - `dart_splash_damage`
  - `module_offline_damage`
  - `offline_damage`
  - `penalty_damage`
  - `server_kill_damage`
  - `killer_id`

## 对外信号
- `robot_injury_stat_updated(state)`
- `injury_total_changed(total_damage)`
- `killer_changed(killer_id)`

## 主要接口
- `get_state()`
- 各字段 getter（`get_total_damage()` 等）
- `clear_cache()`
