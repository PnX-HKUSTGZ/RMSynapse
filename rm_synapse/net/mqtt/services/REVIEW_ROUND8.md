# MQTT Services Review（Round 8）

日期：2026-03-03  
范围：
- `rm_synapse/net/mqtt/services/**/*.gd`
- `rm_synapse/net/mqtt/tests/*.gd`
- 对照：`rm_synapse/net/mqtt/services/GETTER_REQUIREMENTS.md`

## 发现清单（按严重度）

### [中] `EventService` 仅在首次绑定成功后停止探测，运行期替换 Adapter 会静默失效
- 位置：`rm_synapse/net/mqtt/services/event/event_service.gd:126-139,322-339`
- 现象：绑定成功后 `_adapter_bound=true` 且 `set_process(false)`，后续不再检测 `/root/Mqtt/Adapter` 是否被替换。
- 风险：运行期若 `ProtocolAdapter` 被重建/替换，`EventService` 仍连在旧实例上，事件流中断但无自动恢复。
- 建议：与 `GameStatus/GlobalUnit/GlobalLogistics` 一致，增加 `_bound_adapter` 跟踪和“adapter 变化后断开旧连接并重连”的逻辑。

### [中] 两个 Sender 在 `_ready()` 无条件覆盖外部注入的 `adapter_getter`
- 位置：
  - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd:15-17`
  - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd:14-16`
- 现象：无论调用方是否预先注入自定义 getter，进入 `_ready()` 都会被 `MQTTProtocolAdapterGetter.new()` 覆盖。
- 风险：测试桩注入、非默认路径部署、运行时替换 getter 都会失效。
- 建议：仅在 `adapter_getter == null` 时再创建默认 getter。

### [中] 缺失 Adapter 时存在高频重复告警（日志刷屏风险）
- 位置：
  - `rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter/mqtt_protocol_adapter_getter.gd:10-13`
  - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd:47-52`
  - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd:48-53`
- 现象：getter 的 `get_adapter()` 每次 miss 都会 warn；两个 sender 以 `75Hz` 轮询调用。
- 风险：Adapter 暂不可用时日志被大量重复 warn 淹没，影响排障和性能。
- 建议：sender 轮询路径统一改用 `get_adapter_silent()`，或在 getter 内做节流（按时间窗口/状态变更输出）。

### [中] 新增 17 个 getter 服务未配套自动化测试，未满足当前验收标准
- 依据：`rm_synapse/net/mqtt/services/GETTER_REQUIREMENTS.md:25-30,264-270`
- 现状：仅有 `Event/GameStatus/GlobalUnitStatus/GlobalLogisticsStatus` 相关测试；以下新增服务暂无独立测试：
  - `global_special_mechanism`
  - `robot_injury_stat`
  - `robot_respawn_status`
  - `robot_static_status`
  - `robot_dynamic_status`
  - `robot_module_status`
  - `robot_position`
  - `buff`
  - `robot_path_plan_info`
  - `radar_info_to_client`
  - `tech_core_motion_state_sync`
  - `robot_performance_selection_sync`
  - `deploy_mode_status_sync`
  - `rune_status_sync`
  - `sentry_status_sync`
  - `dart_select_target_status_sync`
  - `air_support_status_sync`
- 风险：目前大部分 getter 的“默认值/ingest/clear_cache/延迟绑定/替换重绑”仍缺回归保护。
- 建议：先补齐 scene 测试模板，再按服务批量复制改造。

### [低] `MQTTClientSetter` 依赖 `ProtocolAdapter` 私有成员，耦合较脆弱
- 位置：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:81-85`
- 现象：直接读取 `adapter._transport` 并构造 `Callable(adapter, "_on_transport_message")`。
- 风险：若 `ProtocolAdapter` 私有字段/方法重命名，`MQTTClientSetter` 运行时会失效。
- 建议：优先只调用公开 API（`bind_transport`），去掉对私有实现细节的判断分支。

## 通过项
- `services/` 目录迁移完成，`class_name` 注册和脚本编译通过。
- 新增 getter 基本遵循统一模式：强类型状态、`clone()`、`clear_cache()`、延迟绑定/重绑、解绑清理。
- 当前字段名与生成代码 getter（`rm_custom_pb.gd`）对照未发现明显拼写缺失。

## 本地验证记录
- `godot --headless --path rm_synapse --import --quit`：通过（仅既有 UID warning）。
- `game_status_service_scene_test.tscn`：`GAME_STATUS_SERVICE_SCENE_TEST_OK`
- `global_unit_status_service_scene_test.tscn`：`GLOBAL_UNIT_STATUS_SERVICE_SCENE_TEST_OK`
- `global_logistics_status_service_scene_test.tscn`：`GLOBAL_LOGISTICS_STATUS_SERVICE_SCENE_TEST_OK`

## Round 9 复审（2026-03-03）

### 已关闭项
- [已修复] `EventService` 运行期 adapter 替换重绑
  - 复核位置：`rm_synapse/net/mqtt/services/event/event_service.gd:121-140,323-371`
  - 结果：已引入 `_bound_adapter` 与 `_disconnect_bound_adapter()`，并在 `_process` 周期重试，旧 adapter 会断开。

- [已修复] 两个 Sender 覆盖外部注入 getter
  - 复核位置：
    - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd:15-18`
    - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd:14-17`
  - 结果：改为仅在 `adapter_getter == null` 时创建默认 getter。

- [已修复] Sender 轮询路径不再触发 getter 高频 warn
  - 复核位置：
    - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd:60-65`
    - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd:61-66`
  - 结果：优先使用 `get_adapter_silent()`，缺失 adapter 时日志已做 sender 侧节流。

- [已修复] 新增 getter 无自动化测试
  - 新增测试：
    - `rm_synapse/net/mqtt/tests/event_service_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/control_sender_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.gd`
  - 运行结果：
    - `EVENT_SERVICE_SCENE_TEST_OK`
    - `CONTROL_SENDER_SCENE_TEST_OK`
    - `GETTER_SERVICES_ROUND8_SCENE_TEST_OK`

### 仍需处理

#### [中] `MQTTClientSetter` 的“是否已绑定”判定可能误跳过真正需要的 `bind_transport`
- 位置：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:79-83`
- 现象：当前仅按 `adapter.transport_path == transport.get_path()` 提前 return。
- 风险：
  - 若 `adapter._transport` 尚未真正绑定（但 `transport_path` 已一致），会被误判为“已绑定”；
  - 若 transport 对象被替换但路径不变，也可能跳过重绑。
- 建议：直接调用 `adapter.bind_transport(transport)`，或在 `ProtocolAdapter` 增加公开 `is_transport_bound(transport)` 再判断。

#### [低] Round8 汇总测试对“关键变更信号”仍未做断言
- 位置：`rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.gd:264-317`
- 现状：测试覆盖了默认值/ingest/clear/rebind，但未逐项断言 `*_changed` 信号触发。
- 风险：字段更新逻辑正确但信号回归时，现有测试可能漏检。
- 建议：至少给高价值服务（`robot_dynamic_status`、`robot_respawn_status`、`buff`）补充信号断言。

### 本轮复测记录
- `godot --headless --path rm_synapse --import --quit`：通过（仅既有 UID warning）
- `godot --headless --path rm_synapse --scene net/mqtt/tests/event_service_scene_test.tscn`：`EVENT_SERVICE_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/control_sender_scene_test.tscn`：`CONTROL_SENDER_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`

## Round 10 复审（2026-03-03）

### 已关闭项

- [已修复] `MQTTClientSetter` 绑定判定误跳过
  - 修复位置：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:79-81`
  - 变更：移除 `adapter.transport_path == transport.get_path()` 的提前返回，统一走公开 API：`adapter.bind_transport(transport)`。
  - 验证：新增 `rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.gd`，断言“路径一致时仍触发 bind_transport”。

- [已修复] Round8 汇总测试缺少关键信号断言
  - 修复位置：`rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.gd`
  - 新增断言：
    - `RobotDynamicStatusService`：`health_changed`、`energy_changed`、`combat_state_changed`、`robot_dynamic_status_updated`
    - `RobotRespawnStatusService`：`respawn_pending_changed`、`respawn_progress_changed`、`robot_respawn_status_updated`
    - `BuffService`：`buff_target_changed`、`buff_timer_changed`、`buff_updated`

### 本轮新增验证
- `godot --headless --path rm_synapse --scene net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
  - 输出：`MQTT_CLIENT_SETTER_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
  - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --import --quit`
  - 结果：通过（仅既有 UID warning）

### 当前结论
- Round9 标注的“仍需处理”项已全部关闭。

## Round 11 复审（2026-03-03）

### 新发现

#### [低] `force_rebind` 当前成为无效配置项（导出但未参与逻辑）
- 位置：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:15,79-81`
- 现象：`_bind_adapter_transport()` 现在无条件调用 `adapter.bind_transport(transport)`，不再读取 `force_rebind`。
- 风险：Inspector 中该选项对行为没有影响，容易误导使用方；文档与实际行为可能逐步偏离。
- 建议：二选一
  - 删除 `force_rebind` 导出字段；
  - 或恢复其语义（`false` 时仅在确有必要时重绑）。

### 复核通过
- `MQTTClientSetter` 已不再依赖 `ProtocolAdapter` 私有字段/方法。
- `EventService` 运行期替换 adapter 可自动重绑。
- Sender 注入 getter + silent 获取路径保持正确。
- Round10 新增测试均通过：
  - `MQTT_CLIENT_SETTER_SCENE_TEST_OK`
  - `GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
  - `EVENT_SERVICE_SCENE_TEST_OK`
  - `CONTROL_SENDER_SCENE_TEST_OK`

## Round 12 复审（2026-03-03）

### 已关闭项

- [已修复] `force_rebind` 导出项恢复有效语义
  - 修复位置：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:15,79-83`
  - 实现方式：
    - 在 `ProtocolAdapter` 增加公开方法 `is_transport_bound(node)`：`rm_synapse/net/mqtt/adapter/protocol_adapter.gd:207-210`
    - `MQTTClientSetter._bind_adapter_transport()` 在 `force_rebind=false` 且已绑定时跳过；否则调用 `bind_transport(transport)`。
  - 结果：
    - 不依赖私有字段/方法；
    - `force_rebind` 对行为重新生效，避免 Inspector 语义失真。

- [已补充] `MQTTClientSetter` 行为与文档一致
  - 更新文档：`rm_synapse/net/mqtt/services/mqtt_client_setter/README.md:20-24`
  - 说明已明确：`force_rebind=false` 跳过已绑定重绑，`force_rebind=true` 强制重绑。

- [已补充] 对应自动化测试覆盖
  - 更新测试：`rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.gd:37-61`
  - 覆盖点：
    - 首次绑定会调用 `bind_transport`
    - 已绑定 + `force_rebind=false` 会跳过
    - transport 实例变化会重新绑定
    - `force_rebind=true` 会强制绑定

### 复测结果
- `godot --headless --path rm_synapse --scene net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
  - 输出：`MQTT_CLIENT_SETTER_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
  - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --import --quit`
  - 结果：通过（仅既有 UID warning）

### 当前结论
- Round 11 新发现项已关闭。

## Round 13 复审（2026-03-03）

### 结论
- 本轮未发现新的服务层缺陷。
- `MQTTClientSetter.force_rebind` 已恢复有效语义，且保持对 `ProtocolAdapter` 公开 API 的依赖边界。

### 复核点
- `rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd:79-83`
  - `force_rebind=false` + `adapter.is_transport_bound(transport)` 时跳过重绑；
  - 其他情况调用 `adapter.bind_transport(transport)`。
- `rm_synapse/net/mqtt/adapter/protocol_adapter.gd:207-210`
  - 新增公开方法 `is_transport_bound(node)`，避免 Setter 读取私有字段。
- `rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.gd:37-61`
  - 覆盖首次绑定、已绑定跳过、transport 变化重绑、`force_rebind=true` 强制重绑。

### 本轮验证
- `godot --headless --path rm_synapse --scene net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
  - 输出：`MQTT_CLIENT_SETTER_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
  - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/event_service_scene_test.tscn`
  - 输出：`EVENT_SERVICE_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --scene net/mqtt/tests/control_sender_scene_test.tscn`
  - 输出：`CONTROL_SENDER_SCENE_TEST_OK`
- `godot --headless --path rm_synapse --import --quit`
  - 结果：通过（仅既有 UID warning）。
