# Event / Operate 服务实现需求文档

## 1. 目的与范围
本文用于约束 `rm_synapse/ui/Readme.md` 中 `event` 与 `operate` 类服务的实现方式，供实现同学直接落代码，reviewer 按本文验收。

范围：
- `rm_synapse/net/mqtt/services/` 下新增或扩展的 event/operate 服务。
- 仅涉及 MQTT 通信与服务状态，不包含 `rm_synapse/ui/` 的展示逻辑。

## 2. 关键约束（已确认）
1. `CommonCommand` 必须严格“按一次发送一次”，不允许自动重发。
2. `CommonCommand` 每种命令类型单独暴露服务节点（不能合并为单一泛化服务）。
3. `CommonCommand` 仅对 `cmd_type=1` 做参数约束（必须为 10 的倍数）；其他类型不做额外校验。
4. 其余 operate 命令按“每种命令单独服务”实现。
5. `RuneActivateCommand` 成功判定按协议：`RuneStatusSync.rune_status == 3`（已激活）。
6. 失败原因统一使用固定枚举（见第 5 节）。
7. 除第 3 条外，不增加任何业务入参校验（范围/枚举/组合关系）；其余字段均透传发送，结果由协议回执或超时决定。

## 3. 协议依据（实现必须对齐）
1. `RuneStatusSync.rune_status` 枚举：
- `1` 未激活
- `2` 正在激活
- `3` 已激活

2. `SentryCtrlResult.result_code` 枚举：
- `0` 成功
- 其他值失败

3. `CommonCommand.cmd_type`（当前协议）：
- `1` 兑换 17mm 发弹量（参数需为 10 的倍数）
- `2` 兑换 42mm 发弹量
- `3` 确认复活
- `4` 兑换立即复活
- `5` 远程兑换允许发弹量
- `6` 远程兑换血量

4. 协议勘误（按仓库固定实现）：
- `MapClickInfoNotify` 的 PDF 字段表与 proto 示例冲突，仓库按 proto 示例实现：保留 `mode=3`、`type=6`，并使用 `map_x=7`、`map_y=8`。
- `RadarInfoToClient` 的 PDF proto 示例不是合法 proto，仓库采用 `repeated RadarSingleRobotInfo radar_single_robot_info = 1` 作为合法化写法。

## 4. Event 类实现分解

### 4.1 Event（已存在）
- 服务：`event/event_service.gd`
- 维持现有逻辑，重点保持：
  - adapter 延迟绑定 + 重绑
  - 严格按 RM2026 V1.3 事件集暴露信号与缓存
  - `event_id=3` 第二参数按 `float` 解析
  - `event_id=9` 第一参数按绝对阵营 `RED/BLUE` 解析
  - 缓存访问与信号分发

### 4.2 PenaltyInfo（新增）
- 目录：`services/penalty_info/`
- 脚本：`penalty_info_service.gd`
- README：`services/penalty_info/README.md`
- 状态模型：
  - `PenaltyInfoState { penalty_type:int, penalty_effect_sec:int, total_penalty_num:int, last_update_msec:int }`
- 信号：
  - `penalty_info_updated(state)`
  - `penalty_type_changed(penalty_type)`
  - `penalty_effect_changed(penalty_effect_sec)`
  - `penalty_count_changed(total_penalty_num)`
- 接口：
  - `get_state()`
  - `get_penalty_type()`
  - `get_penalty_effect_sec()`
  - `get_total_penalty_num()`
  - `clear_cache()`
  - `ingest_penalty_info(message)`（测试入口）

### 4.3 SentryCtrlResult（新增）
- 目录：`services/sentry_ctrl_result/`
- 脚本：`sentry_ctrl_result_service.gd`
- README：`services/sentry_ctrl_result/README.md`
- 状态模型：
  - `SentryCtrlResultState { command_id:int, result_code:int, last_update_msec:int }`
- 信号：
  - `sentry_ctrl_result_updated(state)`
  - `command_result_changed(command_id, result_code)`
- 接口：
  - `get_state()`
  - `get_command_id()`
  - `get_result_code()`
  - `clear_cache()`
  - `ingest_sentry_ctrl_result(message)`（测试入口）

## 5. Operate 类实现分解

## 5.1 统一失败原因枚举（operate 服务通用）
建议在各命令服务内统一定义：
- `OK = 0`
- `OVERRIDDEN = 1`（新请求覆盖旧请求）
- `SEND_REJECTED = 2`（adapter 发送失败）
- `PROTOCOL_REJECTED = 3`（协议结果明确失败）
- `VERIFY_TIMEOUT = 4`（验证超时）
- `CANCELED = 5`（主动取消）

## 5.2 KeyboardMouseControl（已有）
- 目录：`services/keyboard_mouse_control_sender/`
- 维持 `75Hz` 连续发送模式，不改成单次命令。

## 5.3 CommonCommand（新增 6 个独立服务）
每个命令一个目录，不合并：
1. `common_command_exchange_17mm/`
2. `common_command_exchange_42mm/`
3. `common_command_confirm_respawn/`
4. `common_command_buy_respawn/`
5. `common_command_remote_buy_ammo/`
6. `common_command_remote_buy_hp/`

每个目录包含：
- `*_service.gd`
- `README.md`

每个服务统一接口：
- `send_once(param: int = 0) -> int`
- `get_last_send_result() -> int`

每个服务统一行为：
1. 每次 `send_once` 只发送一次，不重试，不定时。
2. 仅创建并发送一次 `AdapterTypes.CommonCommandData`。
3. `cmd_type` 在服务内固定写死，不允许调用方覆盖。
4. `cmd_type=1` 时校验 `param % 10 == 0`；不满足则直接返回失败码并不发送。
5. `cmd_type=2~6` 不做额外参数校验，按透传发送。
6. 限频依赖 `ProtocolAdapter` 的 10Hz topic 限流。

## 5.4 其余 operate 命令（每种命令单独服务）
新增以下目录（每个目录 `*_service.gd + README.md`）：
1. `assembly_command/`
2. `robot_performance_selection_command/`
3. `hero_deploy_mode_event_command/`
4. `rune_activate_command/`
5. `dart_command/`
6. `sentry_ctrl_command/`
7. `air_support_command/`

对外接口建议：
- `request_xxx(...) -> int request_id`
- `is_running() -> bool`
- `cancel(request_id: int) -> bool`
- `get_last_error_code() -> int`

通用行为：
1. 同一服务同一时刻仅允许一个 in-flight 请求。
2. 新请求到来时覆盖旧请求，旧请求标记 `OVERRIDDEN`。
3. 请求发起后按命令频率重发（1Hz），直到满足成功条件或超时。
4. 不做额外业务入参校验（除 `CommonCommand cmd_type=1`）；命令参数按调用值直接透传。

成功判定：
1. `AssemblyCommand`：
- 以 `TechCoreMotionStateSync` 状态向量变化判定成功：
  `basic_state`, `putin_state`, `move_state`, `rotate_state`, `enemy_core_status`, `remain_time_all`, `remain_time_step`
- 请求发起后，若只收到与起点完全相同的状态直到超时，归类为 `VERIFY_TIMEOUT`

2. `RobotPerformanceSelectionCommand`：
- `RobotPerformanceSelectionSync` 三字段达到目标值即成功。

3. `HeroDeployModeEventCommand`：
- `DeployModeStatusSync.status` 达到目标值（0/1）即成功。

4. `RuneActivateCommand`：
- 发送值固定 `activate=1`。
- `RuneStatusSync.rune_status == 3` 判定成功。

5. `DartCommand`：
- `open` 指令可由 `DartSelectTargetStatusSync.open` 变化验证。
- `launch_confirm` 第一版按发送成功判定，后续可按比赛事件细化。

6. `SentryCtrlCommand`：
- 等待 `SentryCtrlResult.command_id` 匹配。
- `result_code == 0` 成功；`!= 0` 失败（`PROTOCOL_REJECTED`）。

7. `AirSupportCommand`：
- `command_id=1/2`：`AirSupportStatusSync.airsupport_status == 1` 成功。
- `command_id=0`：`AirSupportStatusSync.airsupport_status == 0` 成功。

## 6. 通用编码规范
1. 服务统一 `extends Node` + `class_name XxxService`。
2. 通过 `MQTTProtocolAdapterGetter` 获取 adapter（轮询路径优先 `get_adapter_silent()`）。
3. getter 服务状态模型使用强类型 `RefCounted`，`get_state()` 返回 `clone()`。
4. 生命周期统一包含 `_ready/_process/_exit_tree`（需要重绑的服务）。
5. `clear_cache()` 统一恢复默认并发出 `*_updated`。
6. 日志需节流：避免 adapter 缺失导致每帧刷屏。

## 7. 测试验收清单
新增场景测试建议：
1. `penalty_info_service_scene_test.gd/.tscn`
2. `sentry_ctrl_result_service_scene_test.gd/.tscn`
3. `common_command_services_scene_test.gd/.tscn`
4. `operate_command_services_scene_test.gd/.tscn`

必须覆盖：
1. 默认值与 clear_cache。
2. ingest 后字段一致性（event 类）。
3. 请求覆盖（`OVERRIDDEN`）行为。
4. 发送失败、协议失败、超时分类。
5. CommonCommand 单次触发语义（调用一次发送一次）。
6. adapter 延迟可用与替换重绑。

## 8. 实施顺序（建议）
1. `PenaltyInfoService`、`SentryCtrlResultService`（先打通 event 闭环）。
2. `CommonCommand` 六服务（独立、无重试，最先可交付给前端联调）。
3. `RuneActivateCommandService`（与 `RuneStatusSync` 闭环，作为命令状态机模板）。
4. `SentryCtrlCommandService`、`AirSupportCommandService`。
5. `RobotPerformanceSelectionCommandService`、`HeroDeployModeEventCommandService`、`AssemblyCommandService`、`DartCommandService`。
6. 完成汇总场景测试与 README。

## 9. 完成情况（2026-03-03）

### 9.1 已完成的服务实现

#### Event
1. `services/penalty_info/penalty_info_service.gd`
2. `services/sentry_ctrl_result/sentry_ctrl_result_service.gd`

上述两个服务均已实现：
- 强类型状态模型（`RefCounted` + `clone()/to_dict()`）
- `clear_cache()`
- `ingest_*()` 测试入口
- adapter 延迟绑定与替换重绑
- 缺失依赖日志节流

#### CommonCommand（6 个独立服务）
1. `services/common_command_exchange_17mm/common_command_exchange_17mm_service.gd`
2. `services/common_command_exchange_42mm/common_command_exchange_42mm_service.gd`
3. `services/common_command_confirm_respawn/common_command_confirm_respawn_service.gd`
4. `services/common_command_buy_respawn/common_command_buy_respawn_service.gd`
5. `services/common_command_remote_buy_ammo/common_command_remote_buy_ammo_service.gd`
6. `services/common_command_remote_buy_hp/common_command_remote_buy_hp_service.gd`

已满足：
- `send_once(param: int = 0) -> int`
- `get_last_send_result() -> int`
- 每次调用只发送一次，不自动重发
- `cmd_type` 固定在服务内
- 仅 `cmd_type=1` 执行 `param % 10 == 0` 校验

#### Operate（7 个独立服务）
1. `services/assembly_command/assembly_command_service.gd`
2. `services/robot_performance_selection_command/robot_performance_selection_command_service.gd`
3. `services/hero_deploy_mode_event_command/hero_deploy_mode_event_command_service.gd`
4. `services/rune_activate_command/rune_activate_command_service.gd`
5. `services/dart_command/dart_command_service.gd`
6. `services/sentry_ctrl_command/sentry_ctrl_command_service.gd`
7. `services/air_support_command/air_support_command_service.gd`

已统一实现：
- 失败码枚举：`OK/OVERRIDDEN/SEND_REJECTED/PROTOCOL_REJECTED/VERIFY_TIMEOUT/CANCELED`
- 单 in-flight 请求
- 新请求覆盖旧请求
- 1Hz 重发直到成功或超时
- `cancel()` / `is_running()` / `get_last_error_code()`
- adapter 延迟绑定 + 替换重绑

成功判定已按本文第 5.4 节落地。

### 9.2 README 补充
为每个新增服务目录补充了 `README.md`，包括：作用、接口、成功判定与行为约束。

### 9.3 测试实现
新增场景测试：
1. `tests/penalty_info_service_scene_test.gd/.tscn`
2. `tests/sentry_ctrl_result_service_scene_test.gd/.tscn`
3. `tests/common_command_services_scene_test.gd/.tscn`
4. `tests/operate_command_services_scene_test.gd/.tscn`

覆盖内容：
- 默认值与 `clear_cache`
- ingest 字段一致性（event）
- 覆盖请求（`OVERRIDDEN`）
- 发送失败 / 协议失败 / 超时分类
- CommonCommand 单次触发语义
- adapter 延迟可用与替换重绑

### 9.4 本地验证记录
执行命令：
1. `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
2. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/penalty_info_service_scene_test.tscn`
3. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/sentry_ctrl_result_service_scene_test.tscn`
4. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/common_command_services_scene_test.tscn`
5. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/operate_command_services_scene_test.tscn`

结果：
- `PENALTY_INFO_SERVICE_SCENE_TEST_OK`
- `SENTRY_CTRL_RESULT_SERVICE_SCENE_TEST_OK`
- `COMMON_COMMAND_SERVICES_SCENE_TEST_OK`
- `OPERATE_COMMAND_SERVICES_SCENE_TEST_OK`

备注：运行时仍有项目既有的 UID warning 与 Godot 退出时资源告警，不影响本轮新增测试结论。

## 10. 审阅建议（2026-03-03）

### 10.1 审阅结论
- 本轮未发现阻断级（会直接导致脚本加载失败或接口不可用）问题。
- 我本地复跑了 4 个新增场景测试，均通过。

### 10.2 发现与建议（按严重度）

1. 中：`operate` 服务“首发失败即结束”与“持续重发直到超时”语义存在偏差。  
   现状：请求刚创建后，若第一次 `_send_pending_once()` 返回失败会立即 `_finish_pending(SEND_REJECTED)`，不会继续进入后续重发窗口。  
   参考：
   - `rm_synapse/net/mqtt/services/assembly_command/assembly_command_service.gd:58`
   - `rm_synapse/net/mqtt/services/robot_performance_selection_command/robot_performance_selection_command_service.gd:57`
   - `rm_synapse/net/mqtt/services/hero_deploy_mode_event_command/hero_deploy_mode_event_command_service.gd:55`
   - `rm_synapse/net/mqtt/services/rune_activate_command/rune_activate_command_service.gd:56`
   - `rm_synapse/net/mqtt/services/dart_command/dart_command_service.gd:57`
   - `rm_synapse/net/mqtt/services/sentry_ctrl_command/sentry_ctrl_command_service.gd:55`
   - `rm_synapse/net/mqtt/services/air_support_command/air_support_command_service.gd:56`
   建议：若目标是“自动持续发送直到成功/超时”，可改为首发失败仅记录状态、不立即结束，让 `_process_request()` 在超时前继续尝试。

2. 中：`AssemblyCommand` 成功判定可能出现误判。  
   现状：`_on_tech_core_motion_state_sync` 只要收到任意新同步帧就判定成功（按序号增长），未校验是否与本次请求目标相关。  
   参考：
   - `rm_synapse/net/mqtt/services/assembly_command/assembly_command_service.gd:76`
   建议：若协议后续可提供更强关联字段（或可从状态中推导 operation/difficulty 落地），优先升级为“目标状态命中”判定，降低假阳性。

3. 低：`SentryCtrlCommand` 回执关联仅依赖 `command_id`，存在历史回执误命中的窗口。  
   现状：只要 `command_id` 相等即消费回执，不区分是否为当前请求触发。  
   参考：
   - `rm_synapse/net/mqtt/services/sentry_ctrl_command/sentry_ctrl_command_service.gd:73`
   建议：可增加“请求开始时间戳后到达”的过滤（或序号机制），减少同 `command_id` 连续请求时的串扰风险。

### 10.3 测试覆盖缺口（非阻断）
- 当前场景测试验证了成功路径、覆盖、超时、协议拒绝；但尚未覆盖“首发失败后是否继续重发”的行为一致性断言。  
  建议在 `operate_command_services_scene_test.gd` 增补该断言，避免后续语义漂移。

## 11. 审阅建议修复记录（2026-03-03）

### 11.1 已修复项

1. 已修复：operate 服务“首发失败即结束”问题。  
修复策略：统一改为“首发失败不立即结束，超时前继续按 1Hz 重发”；超时时按是否曾成功发送分类：
- 从未发送成功：`SEND_REJECTED`
- 发送成功但验证未通过：`VERIFY_TIMEOUT`

涉及文件：
- `services/assembly_command/assembly_command_service.gd`
- `services/robot_performance_selection_command/robot_performance_selection_command_service.gd`
- `services/hero_deploy_mode_event_command/hero_deploy_mode_event_command_service.gd`
- `services/rune_activate_command/rune_activate_command_service.gd`
- `services/dart_command/dart_command_service.gd`
- `services/sentry_ctrl_command/sentry_ctrl_command_service.gd`
- `services/air_support_command/air_support_command_service.gd`

2. 已修复：`AssemblyCommand` 成功判定过宽。  
修复策略：在保留“请求后同步更新”前提下，增加“相对请求起始 `status` 变化”过滤，减少任意同步帧导致的误判。

涉及文件：
- `services/assembly_command/assembly_command_service.gd`

3. 已修复：`SentryCtrlCommand` 历史回执误命中窗口。  
修复策略：新增请求起点序号/时间戳字段（`result_seq`/`start_msec`）并在回执处理时过滤请求前已观测结果，降低串扰风险。

涉及文件：
- `services/sentry_ctrl_command/sentry_ctrl_command_service.gd`

4. 已补充：测试覆盖“首发失败后继续重发”语义。  
修复策略：在 operate 场景测试中新增断言：
- 首发失败后服务应保持 running，恢复发送成功后可完成验证成功；
- 持续发送失败直到超时时应归类为 `SEND_REJECTED`。

涉及文件：
- `tests/operate_command_services_scene_test.gd`

### 11.2 本轮复测记录
执行命令：
1. `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
2. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/operate_command_services_scene_test.tscn`
3. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/common_command_services_scene_test.tscn`
4. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/penalty_info_service_scene_test.tscn`
5. `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/sentry_ctrl_result_service_scene_test.tscn`

结果：
- `OPERATE_COMMAND_SERVICES_SCENE_TEST_OK`
- `COMMON_COMMAND_SERVICES_SCENE_TEST_OK`
- `PENALTY_INFO_SERVICE_SCENE_TEST_OK`
- `SENTRY_CTRL_RESULT_SERVICE_SCENE_TEST_OK`

备注：仍存在项目既有 UID warning 与 Godot 退出时资源告警，不影响本轮修复结论。
