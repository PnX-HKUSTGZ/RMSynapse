# Event Service 事件服务

本服务用于处理 MQTT `Event` 消息，提供对上层 UI 友好的接口与状态缓存。

## 协议字段
- `event_id`: int32
- `param`: string

## 依赖
- 通过 `MQTTProtocolAdapterGetter` 获取 `ProtocolAdapter`，不直接使用路径。
- `IdMap` 位于 `rm_synapse/utile/id_map.gd`，可用于将机器人 ID 转为名称。

## 使用方式
1. 在场景中创建 `EventService` 节点。
2. 通过 Inspector 绑定 `adapter_getter`。
3. 监听本服务的信号或调用 getter 获取状态。

## 说明
- 本服务不做时间处理，只在收到 `event_message` 时更新缓存。
- 事件列表为从开局至今的累计记录，支持清空。
- 所有名称映射使用 enum + 数组，不使用 Dictionary。

## 对外接口
- `clear_cache()` 清空所有缓存并重置默认值。
- `get_kill_events()` 获取击杀事件列表。
- `get_destroy_events()` 获取基地/前哨站被摧毁事件列表。
- `get_dart_hit_events()` 获取飞镖命中事件列表。
- `get_energy_activation_count()` 获取能量机关可激活次数，默认 0。
- `get_ally_sniper_damage_total()` 获取己方英雄累计狙击伤害，默认 0。
- `get_enemy_sniper_damage_total()` 获取对方英雄累计狙击伤害，默认 0。
- `get_ally_air_support_interrupts_left()` 获取己方空中支援可被打断次数，默认 3。
- `get_enemy_air_support_interrupts_left()` 获取对方空中支援可被打断次数，默认 3。
- `get_event_name(event_id)` 获取事件名称。

## 信号
- `kill_event(killer_id, victim_id)`
- `base_or_outpost_destroyed(target_id)`
- `energy_activation_count_changed(count)`
- `energy_mech_entered_active_state()`
- `energy_mech_active_arms_changed(arms_count, avg_rings)`
- `energy_mech_activated(activate_type)`
- `ally_hero_deploy_mode()`
- `ally_hero_sniper_damage(total_damage)`
- `enemy_hero_sniper_damage(total_damage)`
- `ally_air_support_called()`
- `enemy_air_support_called()`
- `ally_air_support_interrupted(remaining)`
- `enemy_air_support_interrupted(remaining)`
- `dart_hit(target)` 目标为 `DartHitTarget` enum
- `dart_gate_opened(side)` side 为 `Side` enum
- `ally_base_under_attack()`
- `outpost_stopped(side)` side 为 `Side` enum
- `base_armor_deployed(side)` side 为 `Side` enum

## 事件 ID 枚举
`EventId` 枚举名称使用事件英文翻译大写，值等于 `event_id`。
