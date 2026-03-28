# Event Service

## 作用
接收 `Event` 消息并按 RM2026 V1.3 事件集解析，向上层暴露信号与只读缓存。

## 对外接口
- `clear_cache()`
- `ingest_event(event_id: int, param: String = "")`
- `get_kill_events()`
- `get_destroy_events()`
- `get_dart_hit_events()`
- `get_big_rune_active_arms_count()`
- `get_big_rune_average_rings()`
- `get_ally_sniper_damage_total()`
- `get_enemy_sniper_damage_total()`
- `get_ally_air_support_counter_left()`
- `get_last_assembly_result()`
- `get_event_name(event_id: int)`

## 缓存模型
- `KillEventInfo { victim_id, killer_id }`
- `DestroyEventInfo { target_id }`
- `DartHitEventInfo { hit_team, target }`
- 最近一次大能量机关状态：`arms_count`、`average_rings`
- 己方/敌方英雄累计狙击伤害
- 己方剩余反制空中支援次数
- 最近一次装配结算结果

## 信号
- `kill_event(victim_id, killer_id)`
- `outpost_destroyed(target_id)`
- `big_rune_active_arms_changed(arms_count, avg_rings)`
- `energy_mech_activated(activate_type)`
- `ally_hero_sniper_damage(total_damage)`
- `enemy_hero_sniper_damage(total_damage)`
- `enemy_air_support_called()`
- `enemy_air_support_countered(remaining)`
- `dart_hit(hit_team, target)`
- `enemy_dart_gate_opened()`
- `base_under_attack()`
- `enemy_outpost_stopped()`
- `enemy_base_armor_deployed()`
- `enemy_requested_level4_assembly()`
- `assembly_result(result_code)`

## 枚举
- `EventId = 1..15`
- `HitTeam { UNKNOWN=0, RED=1, BLUE=2 }`
- `DartHitTarget { UNKNOWN=0, OUTPOST=1, BASE_FIXED_TARGET=2, BASE_RANDOM_FIXED_TARGET=3, BASE_RANDOM_MOVING_TARGET=4, BASE_TERMINAL_MOVING_TARGET=5 }`
- `AssemblyResult { SUCCESS=0, PULLED_OUT=1, TIMEOUT=2, LEFT_ASSEMBLY_AREA_TOO_LONG=3, ENGINEER_DESTROYED=4, LEVEL4_COLLAB_TIMEOUT=5, ABORTED=6, NO_ENERGY_UNIT_ON_SETTLEMENT=7, BUFFER_TIMEOUT_FORCED_END=8 }`

## 解析规则
- `event_id=3` 的第二参数按 `float` 解析，对应平均环数。
- `event_id=9` 的第一参数是绝对阵营：`1=RED`、`2=BLUE`，不再做相对阵营换算。
- 未识别事件保留忽略，不抛异常。
