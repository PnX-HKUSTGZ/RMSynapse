# GameStatusService Code Review

日期：2026-03-03  
范围：
- `rm_synapse/net/mqtt/services/game_status/game_status_service.gd`
- `rm_synapse/net/mqtt/tests/game_status_service_test.gd`
- 对照：`references/RoboMaster 2026 机甲大师高校系列赛通信协议 V1.2.0（20260209）.pdf` 2.2.3 `GameStatus`

## 结论
- 协议字段与阶段枚举映射整体正确，核心 ingest/cache/signal 逻辑可用。
- `rm_synapse/ui` 目录实现按当前约束不纳入缺陷判定（仅作测试使用）。
- 当前有效关注点仅保留在服务层与测试层；UI 相关记录保留为历史背景，不计入结论。

## 发现清单（按严重度）

### [中][历史已修复] `clear_cache()` 仅重置缓存，不向订阅方广播状态已清空
- 位置：`game_status_service.gd:84-85`
- 现象：调用 `clear_cache()` 后没有发出 `game_status_updated` / `stage_changed` / `score_changed` / `pause_state_changed`。
- 风险：若 UI 侧是事件驱动刷新，调用清空后可能仍显示旧比分/旧阶段，直到下一条 MQTT 消息到达。
- 建议：清空后至少补发一次 `game_status_updated(_state.clone())`，或新增 `cache_cleared` 信号并在 UI 侧订阅。

### [中][历史已修复] 适配器未就绪时存在持续日志噪声
- 位置：
  - 重试循环：`game_status_service.gd:73-83`
  - getter 告警：`../mqtt_protocol_adapter_getter.gd:15-17`
- 现象：`GameStatusService` 会按间隔重试绑定；`MQTTProtocolAdapterGetter.get_adapter()` 在每次未命中时都会 `warn`。
- 风险：服务启动早于 `/root/Mqtt/Adapter` 时，会持续输出重复告警，影响日志可读性与排障效率。
- 建议：在 getter 层增加节流/去重告警，或提供无日志的 `try_get_adapter_silent()` 给轮询重试路径使用。

### [低][历史已修复] 默认阶段值与默认阶段名语义不一致
- 位置：`game_status_service.gd:28-30,120-123`
- 现象：默认 `current_stage = 0`，但 `current_stage_name = "Unknown"`；而 `get_stage_name(0)` 返回 `"未开始比赛"`。
- 风险：UI 首帧若读取缓存，可能出现“阶段=0但名称Unknown”的不一致展示。
- 建议：统一默认语义（例如初始化为 `"未开始比赛"`，或把 `current_stage` 设为 `-1` 代表未知）。

### [低] 测试覆盖尚未验证运行时绑定路径
- 位置：`game_status_service_test.gd:38-198`
- 现象：测试直接 `new()` 服务并手动 `ingest`，未覆盖 `_ready/_process` 的 adapter 延迟绑定与重试行为。
- 风险：未来若绑定逻辑回归，当前测试集不能第一时间发现。
- 建议：增加集成级测试，覆盖“adapter 晚启动 -> 服务自动绑定成功”的路径。

### [中] 服务绑定后不再重新探测 adapter，存在“适配器被替换后静默失效”风险
- 位置：`game_status_service.gd:154-176`
- 现象：`_adapter_bound` 置 `true` 后即停止重试；若运行期 `ProtocolAdapter` 节点被销毁/替换，服务不会自动重绑。
- 风险：服务表面正常但不再收到 `game_status`，问题仅在运行时序变化或热重载场景出现，排查成本高。

## 通过项
- 协议 `GameStatus` 字段编号/类型对齐（`current_round/total_rounds/red_score/blue_score/current_stage/stage_countdown_sec/stage_elapsed_sec/is_paused`）。
- `current_stage` 的 0~5 枚举映射与协议文本一致。
- `get_state()` 返回 `clone()`，避免外部直接污染内部缓存。
- 变更信号拆分合理（阶段/比分/暂停）且保留总线信号 `game_status_updated`。

## 本地验证记录
- 执行：`/home/pnx/godot/bin/godot --headless --path rm_synapse -s net/mqtt/tests/game_status_service_test.gd`
- 结果：测试脚本输出 `GAME_STATUS_SERVICE_TEST_OK`。  
  备注：命令尾部出现与项目全局脚本加载相关的既有编译报错日志（`Log` 标识符），不属于本服务逻辑本身。

## Round 2 追加审阅（2026-03-03）

### [范围外记录] HUD 连接了不存在的信号名，导致 GameStatus UI 回调不会被触发
- 位置：
  - `ui/hud.gd:41`：`game_status_service.connect("game_status_changed", game_status_changed)`
  - `net/mqtt/services/game_status/game_status_service.gd:4-7`：实际仅定义 `game_status_updated/stage_changed/score_changed/pause_state_changed`
- 现象：运行主场景时 Godot 报错 `Attempt to connect nonexistent signal 'game_status_changed'`。
- 风险：HUD 无法接收 GameStatus 更新回调，后续 UI 渲染链路断开。
- 复现：`/home/pnx/godot/bin/godot --headless --path rm_synapse --quit --scene Main.tscn`

### [范围外记录] HUD 中 `GameStatusService.new()` 后未进树，自动绑定逻辑不会执行
- 位置：
  - `ui/hud.gd:24`：创建 `GameStatusService` 实例
  - `ui/hud.gd:28-42`：`_ready()` 中未 `add_child(game_status_service)`，也未挂载场景节点
  - `net/mqtt/services/game_status/game_status_service.gd:69-83`：adapter 绑定依赖 `_ready/_process`
- 现象：服务实例未进入 SceneTree 时，其 `_ready/_process` 不会运行，`_try_bind_adapter()` 不会被周期触发。
- 风险：即使 MQTT 正常，HUD 侧该服务实例也不会自动订阅 `ProtocolAdapter.game_status`，表现为长期无数据更新。

### [低] 前一轮部分问题已被修复（复核关闭）
- `clear_cache()` 不发信号问题已修复：见 `game_status_service.gd:84-90`。
- 默认阶段名不一致问题已修复：默认 `current_stage_name` 现为 `"未开始比赛"`（`game_status_service.gd:29`）。

## Round 3 修复结果（2026-03-03）

### [范围外记录][已修复] HUD 信号名错误导致回调不触发
- 修复位置：`rm_synapse/ui/hud.gd:41-44`
- 变更：改为连接 `GameStatusService.game_status_updated`，并绑定到 `_on_game_status_updated`。
- 复核：运行主场景后未再出现 `Attempt to connect nonexistent signal 'game_status_changed'`。

### [范围外记录][已修复] HUD 创建的 GameStatusService 未入树导致不自动绑定 adapter
- 修复位置：`rm_synapse/ui/hud.gd:41-42`
- 变更：在 HUD `_ready()` 中对 `game_status_service` 执行 `add_child(...)`（仅在无父节点时）。
- 复核：服务实例进入 SceneTree 后，可执行自身 `_ready/_process` 绑定逻辑。

### [中][复核关闭] adapter 未就绪日志噪声
- 复核位置：`rm_synapse/net/mqtt/services/game_status/game_status_service.gd:163-167`
- 结论：重试路径优先走 `get_adapter_silent()`，未命中时不再每周期触发 getter warn。

### 仍待后续处理
- [低] 运行时绑定路径的自动化测试覆盖仍偏弱（`_ready/_process` 延迟绑定场景尚未形成稳定集成测试）。

### 本轮验证
- `/home/pnx/godot/bin/godot --headless --path rm_synapse --quit --scene Main.tscn`
  - 结果：未出现 `game_status_changed` 不存在的连接错误。
- `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
  - 结果：未出现 `SCRIPT ERROR / Compile Error / Parse Error`（仅保留既有 UID 警告）。

## Round 4 继续审阅（2026-03-03）

### [范围外记录] UI 拿到 GameStatus 后的消费方式不纳入本轮缺陷
- 位置：
  - `rm_synapse/ui/hud.gd:62-63`：`_on_game_status_updated(new_status)` 仅 `print`，未组装并推送 payload。
  - `rm_synapse/ui/hud.gd:68-75,78-109`：当前 `_process()` 驱动的是 `push_random_hp()` 随机数据路径。
  - 需求对照：`rm_synapse/ui/Readme.md:26,68-70` 要求 `GameStatus(5Hz)` 同步并通过 `push_payload/web.eval` 推给前端。
- 备注：按当前约束“UI 只是测试，不评估 UI 拿到数据后的使用方式”，该项仅保留为背景观察，不计入缺陷。

### [中] `game_status_service_test.gd` 的 CLI 执行结果仍存在“通过+编译错误并存”假阳性
- 复现命令：`/home/pnx/godot/bin/godot --headless --path rm_synapse -s net/mqtt/tests/game_status_service_test.gd`
- 现象：先输出 `GAME_STATUS_SERVICE_TEST_OK`，随后出现 `Identifier not found: Log` 与 `Failed to load script ... Compilation failed`。
- 风险：CI/脚本化验证难以基于该命令稳定判断真实状态，容易误判。

### [范围外记录] HUD 中 `EventService` 实例未接入且变量命名与输入事件参数冲突
- 位置：
  - `rm_synapse/ui/hud.gd:21`：`var event = EventService.new()` 仅实例化，未 `add_child`、未连接信号。
  - `rm_synapse/ui/hud.gd:49`：`func _input(event)` 参数名与上面的服务变量同名。
- 风险：后续若在 HUD 中接入事件流，容易产生维护混淆；当前 `EventService` 实例也不会运行其自动绑定逻辑。

## Round 5 范围更新（2026-03-03）
- 约束确认：`rm_synapse/ui` 下实现不纳入本轮缺陷判定，仅视作联调用测试代码。
- 生效后有效未关闭项（非 UI）：
  - [中] `game_status_service_test.gd` CLI 假阳性风险（通过+编译失败并存）。
  - [中] `GameStatusService` 运行期 adapter 替换后的自动重绑缺失风险。
  - [低] 运行时绑定路径的自动化测试覆盖仍偏弱。

## Round 6 修复结果（2026-03-03）

### [中][已修复] 运行期 adapter 替换后服务可自动重绑
- 修复位置：`rm_synapse/net/mqtt/services/game_status/game_status_service.gd:63-203`
- 变更：
  - 新增 `_bound_adapter` 跟踪当前已连接适配器。
  - `_process()` 改为持续按间隔执行 `_try_bind_adapter()`，不再在首次绑定成功后停掉探测。
  - 当 getter 返回 `null`/非对象/缺少 `game_status` 信号时，主动断开旧连接并回退到未绑定状态。
  - 当检测到 adapter 对象变化时，先断开旧 adapter，再连接新 adapter。
  - 新增 `_exit_tree()` 退出时解绑，避免悬挂连接。

### [低][已修复] 运行时绑定路径测试覆盖补齐
- 修复位置：
  - `rm_synapse/net/mqtt/tests/game_status_service_test.gd:38-311`
  - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.gd:1-309`
  - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.tscn`
- 变更：新增 FakeAdapter/FakeAdapterGetter 测试桩，覆盖：
  - “adapter 初始缺失 -> 延迟出现 -> 服务成功绑定并 ingest”
  - “adapter A -> adapter B 替换后，旧 adapter 数据不再生效，新 adapter 数据生效”

### [中][收敛] CLI 假阳性问题提供稳定替代入口
- 现象：`-s net/mqtt/tests/game_status_service_test.gd` 仍可能出现 `TEST_OK` 与 `Log` 相关编译噪声并存。
- 处理：新增场景化测试入口并建议改用：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/game_status_service_scene_test.tscn`
- 结果：该命令稳定输出 `GAME_STATUS_SERVICE_SCENE_TEST_OK`，未出现 `Identifier not found: Log` 的脚本模式假阳性。

### 本轮验证
- `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/game_status_service_scene_test.tscn`
  - 结果：`GAME_STATUS_SERVICE_SCENE_TEST_OK`
- `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
  - 结果：未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID 警告）。

### Round 6 补充（2026-03-03）
- 为降低测试日志噪声，在两份测试中将 `delayed_service._logged_missing` 预置为 `true`，避免“故意先不注入 adapter”的步骤触发一次预期内错误日志：
  - `rm_synapse/net/mqtt/tests/game_status_service_test.gd:222`
  - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.gd:222`

## Round 7 继续审阅（2026-03-03）

### [范围外记录] 场景化测试入口为“非隔离测试”（按当前约束不处理）
- 位置：
  - `rm_synapse/project.godot:18-21`（autoload `Mqtt`、`Log`）
  - `rm_synapse/net/mqtt/mqtt.tscn:13`（固定 `broker_url = "10.4.144.223:3333"`）
  - 复现命令：`/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/game_status_service_scene_test.tscn`
- 现象：测试执行时会初始化 `ProtocolAdapter/NetworkTransport` 并尝试连接真实 broker（日志可见 `Connecting to 10.4.144.223:3333`），退出时伴随 `ObjectDB instances leaked` / `resources still in use`。
- 备注：你已确认“这个不用管”，该项仅保留背景，不纳入待修。

### [状态更新]
- `GameStatusService` 的“adapter 替换后静默失效”问题已复核通过，当前未复现回归。
- `game_status_service_test.gd` 的 `-s` 假阳性问题仍存在；目前仅通过“推荐 scene 测试命令”绕开，尚未从根因上消除。
