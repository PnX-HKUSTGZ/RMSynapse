# viewer：RoboMaster 2026 通信协议 V1.2.0 对照检查报告

## 1. 检查范围
- 协议来源：`references/RoboMaster 2026 机甲大师高校系列赛通信协议 V1.2.0（20260209）.pdf`
  - 重点核查章节：`2.1 指令概览`、`2.2 详细协议定义`、`附录二 ID 编号说明`
- 代码范围：
  - `rm_synapse/net/mqtt/proto/rm_custom.proto`
  - `rm_synapse/net/mqtt/adapter/protocol_adapter.gd`
  - `rm_synapse/net/mqtt/adapter/adapter_types.gd`
  - `rm_synapse/net/mqtt/services/event/event_service.gd`
  - `rm_synapse/net/mqtt/services/*.gd`（发送节流/约束）
  - `rm_synapse/utile/id_map.gd`
  - `rm_synapse/ui/Readme.md`
  - `rm_synapse/README.md`

## 2. 总结
- `message` 名称集合：本地 `35` 个，与协议 `35` 个完全一致。
- `Topic` 常量与 `message` 名称：一一对应，无缺失。
- `proto` 字段定义整体基本对齐协议；发现 1 处命名差异（字段名拼写差异，不影响 Protobuf 线协议）。
- 发现主要问题集中在：
  - 事件参数语义解释（`EventService`）存在协议语义错配。
  - 发送侧未对部分协议约束（长度/频率）做防护。
  - 项目文档中存在多处旧协议命名和频率定义偏差。

## 3. 发现清单（按严重度）

### [高] `Event` 的飞镖命中参数语义错误
- 协议依据：`2.2.7 Event` 中 `event_id=14` 参数定义为 `1~5` 的“命中目标类型”（前哨站/基地固定目标/基地随机固定目标/基地随机移动目标/基地末端移动目标）。
- 代码现状：`rm_synapse/net/mqtt/services/event/event_service.gd:51-75` 将其定义成机器人 ID 枚举（红/蓝英雄、工程、步兵等），并按机器人目标解析（`290-303`）。
- 影响：`event_id=14` 的业务显示/统计语义会错位，UI 或逻辑层可能把“命中部位类型”错误当作“命中机器人 ID”。

### [高] `Event` 中“己方/对方”被固定映射为“红/蓝”
- 协议依据：`2.2.7 Event` 的 `event_id=15/17/18` 参数定义为 `1=己方`、`2=对方`（相对阵营语义）。
- 代码现状：`rm_synapse/net/mqtt/services/event/event_service.gd:305-313` 将 `1/2` 固定解析为 `RED/BLUE`。
- 影响：蓝方客户端场景下会出现语义反转（己方事件被标记为红方/对方）。

### [中] 发送接口缺少协议约束防护（长度/频率）
- 协议依据：
  - `CustomControl`：最大 `30` 字节（2.2.2）
  - `MapClickInfoNotify`：`robot_id` 固定 `7` 字节，且频率限制遵循 1.3.1（2.2.17 + 2.1）
  - `CommonCommand`：触发式发送，最高 `10Hz`（2.1）
  - 多个控制指令最高 `1Hz`（2.1）
- 代码现状：
  - `rm_synapse/net/mqtt/adapter/protocol_adapter.gd:213-230,245-276` 直接发送，无长度/频率校验。
  - `rm_synapse/net/mqtt/adapter/adapter_types.gd:16,21` 仅类型定义，无约束。
- 影响：上层调用若失误，可能发出不合规消息（超长或超频）。

### [中] 文档中的通信定义与 V1.2.0 不一致
- `rm_synapse/ui/Readme.md`
  - `RobotDynamicStatus` 写为 `5Hz`（协议为 `10Hz`）
  - `RobotModuleStatus` 写为 `5Hz`（协议为 `1Hz`）
  - `RobotPosition` 写为 `5Hz`（协议为 `1Hz`）
  - `Event` 写为 `1Hz`（协议为触发式发送）
- `rm_synapse/README.md`
  - 存在旧命名/旧架构条目：如 `RemoteControl`、`GuardCtrlCommand/Result`、`SentinelStatusSync`、`RaderInfoToClient`，与当前 V1.2.0 + 现代码命名不一致（当前为 `KeyboardMouseControl + CustomControl`、`SentryCtrlCommand/Result`、`SentryStatusSync`、`RadarInfoToClient`）。

### [低] `RadarInfoToClient` 字段名拼写与协议文本不同
- 协议文本（2.2.18）提取为：`torward_angle = 4`
- 本地 `proto`：`toward_angle = 4`（`rm_synapse/net/mqtt/proto/rm_custom.proto:180`）
- 说明：字段号与类型一致，Protobuf 线协议兼容；主要是命名不一致，影响的是跨语言代码可读性/检索一致性。

### [低] `IdMap` 蓝方步兵选手端文案命名不统一
- 协议附录二：`0x0167/0x0168/0x0169` 对应机器人 ID `3~5`。
- 代码：`rm_synapse/utile/id_map.gd:85-87` 文案为“一号/二号/三号”，与同文件红方“三号/四号/五号”命名风格不一致。
- 说明：数值映射本身正确，问题是命名一致性与认知成本。

## 4. 已对齐项（通过）
- `rm_custom.proto` 与协议 2.2 的 `message` 名称集合完全一致（35/35）。
- `protocol_adapter.gd` 的 `TOPIC_*` 与 `message` 名称一一对应，无缺失。
- 下行订阅集合 `SUBSCRIBE_TOPICS` 覆盖协议中服务器→客户端消息。
- 上行接口已覆盖协议中客户端→服务器消息（键鼠、自定义、地图点击、装配、性能体系、通用指令、部署、符文、飞镖、哨兵控制、空中支援）。
- 附录二中的主要机器人 ID、选手端 ID 数值映射在 `id_map.gd` 中基本正确。

## 5. 备注
- 协议 PDF 文本提取中可见个别排版/OCR 异常（如 `unit32`、`bytes data=0`）。本次判定以“协议语义 + 可编译 Protobuf 合法性 + 当前线协议兼容性”综合判断，未将这类提取噪声直接判为代码问题。

## 6. viewer 修复记录（Round 1，2026-03-03）

### 6.1 事件语义修复（高优先级）
- 已修复 `rm_synapse/net/mqtt/services/event/event_service.gd`：
  - `event_id=14` 的 `param` 解析由“机器人 ID 语义”改为协议定义的“飞镖命中目标类型 1~5”。
  - `event_id=15/17/18` 的 `param` 解析改为相对阵营语义：`1=ALLY(己方)`、`2=ENEMY(对方)`、`3=BOTH(双方)`。
- 同步更新 `rm_synapse/net/mqtt/services/event/README.md` 的信号参数说明。
- 同步更新 `rm_synapse/net/mqtt/tests/event_service_test.gd`：
  - 改为断言协议值（`DART_HIT=4`、`side=1/2`）。
  - 修复 lambda 捕获写法，避免 `CONFUSABLE_CAPTURE_REASSIGNMENT`。

### 6.2 发送约束防护（中优先级）
- 已修复 `rm_synapse/net/mqtt/adapter/protocol_adapter.gd`：
  - `CustomControl` 增加最大 `30` 字节校验，超限直接拒发并告警。
  - `MapClickInfoNotify.robot_id` 增加固定 `7` 字节归一化（不足补零、超长截断）。
  - 增加发送限频（按 topic）：
    - `MapClickInfoNotify`：最小间隔 `500ms`（对应 1.3.1“间隔不低于 0.5s”）。
    - `CommonCommand`：最小间隔 `100ms`（最高 10Hz）。
    - `AssemblyCommand`、`RobotPerformanceSelectionCommand`、`HeroDeployModeEventCommand`、`RuneActivateCommand`、`DartCommand`、`SentryCtrlCommand`、`AirSupportCommand`：最小间隔 `1000ms`（最高 1Hz）。
- 已在 `rm_synapse/net/mqtt/adapter/adapter_types.gd` 补充约束常量：
  - `CustomControlData.MAX_DATA_BYTES = 30`
  - `MapClickInfoNotifyData.ROBOT_ID_BYTES = 7`

### 6.3 文档与命名一致性修复（中/低优先级）
- 已修复 `rm_synapse/ui/Readme.md`：
  - `RobotDynamicStatus` 改为 `10Hz`
  - `RobotModuleStatus` 改为 `1Hz`
  - `RobotPosition` 改为 `1Hz`
  - `Event` 改为“触发式发送”
- 已修复 `rm_synapse/README.md` 的旧命名：
  - `RemoteControl` -> `KeyboardMouseControl + CustomControl`
  - `GuardCtrlCommand/Result` -> `SentryCtrlCommand/Result`
  - `SentinelStatusSync` -> `SentryStatusSync`
  - `RaderInfoToClient` -> `RadarInfoToClient`
- 已修复 `rm_synapse/utile/id_map.gd`：蓝方 `0x0167/0x0168/0x0169` 文案改为“三号/四号/五号选手端”。

### 6.4 proto 字段命名一致性（低优先级）
- 已将 `rm_synapse/net/mqtt/proto/rm_custom.proto` 中 `RadarInfoToClient` 字段 `toward_angle` 更名为 `torward_angle`（字段号仍为 `4`，线协议字段号不变）。
- 按你的约束，`generated/` 目录未手改；已通过工具链再生成：
  - 命令：`/home/pnx/godot/bin/godot --headless -s addons/protobuf/protobuf_cmdln.gd --input=net/mqtt/proto/rm_custom.proto --output=net/mqtt/proto/generated/rm_custom_pb.gd`

### 6.5 本轮验证记录
- 已执行 Godot 语法检查（工程导入检查）：
  - 命令：`/home/pnx/godot/bin/godot --headless --import --quit`
  - 结果：无 `SCRIPT ERROR / Compile Error / Parse Error`。

### 6.6 追加 Review 记录（实现层）
- [中] `MQTTProtocolAdapterGetter` 的获取方式会先报错，和“可空返回”意图不一致
  - 代码位置：`rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter.gd:10,16`
  - 现象：使用 `get_node(...)` 获取 `adapter/transport`，但后续按 `null` 分支处理。
  - 风险：路径缺失时会先触发 Godot 节点查找报错（噪声/误导），而不是干净地走“未找到”逻辑。
- [中] `ProtocolAdapter.bind_transport` 重绑时缺少去重/解绑，可能重复连接信号
  - 代码位置：`rm_synapse/net/mqtt/adapter/protocol_adapter.gd:189-193`
  - 现象：每次调用都 `connect`，未检查是否已连接，也未断开旧 transport 的连接。
  - 风险：在重绑或切换 transport 后，可能出现重复回调（重复解码、重复发信号）。
- [中] 重连后订阅行为存在重复发送
  - 代码位置：`rm_synapse/net/mqtt/transport/network_transport.gd:125-130`，`rm_synapse/net/mqtt/adapter/protocol_adapter.gd:438-441`
  - 现象：`NetworkTransport` 连上后会重放订阅；`ProtocolAdapter` 在 connected 回调里又执行 `subscribe_all()`。
  - 风险：每次重连会出现额外重复订阅请求，增加无效控制流量与日志噪声。
- [低] `CustomControlSender` 首次缺失依赖时不会打印错误
  - 代码位置：`rm_synapse/net/mqtt/services/custom_control_sender.gd:13`
  - 现象：`_logged_missing` 初始值为 `true`，导致第一次依赖缺失时不触发日志输出。
  - 风险：联调初期定位依赖问题的可观测性下降。
- [低] `MOVEABLE_ROBOT_IDS` 列表疑似遗漏 `3`/`103`
  - 代码位置：`rm_synapse/utile/id_map.gd:57-59`
  - 现象：可移动机器人列表包含 `1,2,4,5,6,7,101,102,104,105,106,107`，未包含 `3,103`。
  - 风险：若该列表用于筛选“可移动单位”，会导致每方一台步兵被漏算。
- [观察项] `EventService` 目前仅在 `_ready()` 尝试一次绑定
  - 代码位置：`rm_synapse/net/mqtt/services/event/event_service.gd:123-125,321-337`
  - 说明：当前实现可工作于“adapter 已就绪”启动顺序；若节点装配/Autoload 顺序变化，需确认是否需要重试绑定机制。

## 7. viewer 修复记录（Round 2，2026-03-03）

### 7.1 `EventService` 协议收敛与健壮性
- 已修复 `rm_synapse/net/mqtt/services/event/event_service.gd`：
  - `_parse_side(param)` 改为严格协议值解析，仅接受 `1=ALLY`、`2=ENEMY`；其余返回 `UNKNOWN`。
  - 移除非协议文本兜底（`ally/enemy/both/己方/对方/双方`）与 `v==3` 分支，避免引入无依据语义。
  - 增加 adapter 延迟绑定重试：`_ready()` 后若未绑定成功，会按 `bind_retry_interval_sec` 周期重试 `_try_bind_adapter()`，绑定后自动停止重试。

### 7.2 `EventService` 测试补强
- 已更新 `rm_synapse/net/mqtt/tests/event_service_test.gd`：
  - 新增严格性断言：`event_id=18` 且 `param=3` 时，`side` 应为 `UNKNOWN(0)`。
  - 覆盖“非协议 side 值不应被识别”为有效阵营。

### 7.3 Getter/Adapter/发送服务实现修复
- 已修复 `rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter.gd`：
  - `get_node(...)` 改为 `get_node_or_null(...)`；在 `SceneTree/root` 不可用时安全返回 `null` 并告警，避免路径缺失时报错噪声。
- 已修复 `rm_synapse/net/mqtt/adapter/protocol_adapter.gd`：
  - `bind_transport()` 增加防重复连接与旧 transport 解绑，避免重复 signal 回调。
  - `_on_transport_connected()` 移除重复 `subscribe_all()`，避免与 `NetworkTransport` 的重连重放订阅机制叠加。
- 已修复 `rm_synapse/net/mqtt/services/custom_control_sender.gd`：
  - `_logged_missing` 初始值改为 `false`，首次依赖缺失时可正常打印错误。

### 7.4 数据映射补漏
- 已修复 `rm_synapse/utile/id_map.gd`：
  - `MOVEABLE_ROBOT_IDS` 补入 `3` 与 `103`，避免步兵三号遗漏。

### 7.5 本轮验证
- 已执行工程级 Godot 语法检查：
  - 命令：`/home/pnx/godot/bin/godot --headless --import --quit`
  - 结果：`SYNTAX_CHECK_OK`（未出现 `SCRIPT ERROR / Compile Error / Parse Error`）。

### 7.6 继续 Review 记录（实现层，2026-03-03）
- [中] `MQTTProtocolAdapterGetter` 失败告警会在高频调用场景下刷屏
  - 代码位置：`rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter.gd:15-17,25-27`
  - 触发链路：`KeyboardMouseControlSender` / `CustomControlSender` 以 `75Hz` 轮询适配器（`.../keyboard_mouse_control_sender.gd:48-52`，`.../custom_control_sender.gd:47-51`）。
  - 风险：当 `/root/Mqtt/Adapter` 暂不可用时，每 tick 都会打 warn，日志吞吐和可观测性会显著下降（上层 `_logged_missing` 抑制不了 getter 内部告警）。

- [中] 两个 Sender 在 `_ready()` 无条件覆盖外部注入的 `adapter_getter`
  - 代码位置：`rm_synapse/net/mqtt/services/keyboard_mouse_control_sender.gd:15`，`rm_synapse/net/mqtt/services/custom_control_sender.gd:16`
  - 现象：即使运行前已设置自定义 getter（例如测试桩或自定义路径），进入 `_ready()` 后都会被 `MQTTProtocolAdapterGetter.new()` 覆盖。
  - 风险：降低可测试性与可配置性，非默认节点路径场景下难以复用 sender。

- [中] 测试入口在 CLI 下不稳定，存在“通过+编译错误并存”的假阳性风险
  - 复现命令：`/home/pnx/godot/bin/godot --headless --path rm_synapse --script net/mqtt/tests/event_service_test.gd`
  - 现象：先输出 `EVENT_SERVICE_TEST_OK`，随后出现 `Identifier not found: Log`（涉及 `protocol_adapter.gd`、`network_transport.gd` 等）与 `Failed to load script ... Compilation failed`。
  - 影响：CI 或脚本化测试很难据此判断真实通过状态；当前测试运行方式依赖完整项目上下文（Autoload `Log`）。

- [低] `self_test.gd` 不能直接作为 `--script` 入口执行
  - 代码位置：`rm_synapse/net/mqtt/tests/self_test.gd:1`
  - 现象：该脚本继承 `Node`，Godot `--script` 要求继承 `SceneTree/MainLoop`；直接执行会报错。
  - 说明：当前更适合作为 `mqtt_debug.tscn` 子节点场景测试，而非独立脚本测试入口。

- [低] `EventService.Side.BOTH` 当前不可达（语义悬空）
  - 代码位置：`rm_synapse/net/mqtt/services/event/event_service.gd:44-49,286-295`
  - 现象：枚举保留 `BOTH=3`，但 `_parse_side()` 仅返回 `ALLY/ENEMY/UNKNOWN`；测试也将 `param=3` 断言为 `UNKNOWN`。
  - 风险：对外接口语义不自洽，调用方可能误以为会收到 `BOTH`。

### 7.7 继续 Review 记录（补充，2026-03-03）
- [中] `GlobalSpecialMechanismService` 缺少自动重试绑定，存在“启动时机依赖”
  - 代码位置：`rm_synapse/net/mqtt/services/global_special_mechanism_service.gd:33-35,73-89`
  - 现象：仅在 `_ready()` 与 `get_active_effects()` 调用时尝试绑定 adapter；若节点启动早于 `/root/Mqtt/Adapter` 且上层不主动轮询 `get_active_effects()`，将长期未绑定。
  - 风险：服务可能静默失效（无法接收 `GlobalSpecialMechanism` 更新），问题依赖时序，现场复现不稳定。

- [低] `IdMap` 的机器人类型文案与协议语义不完全一致
  - 代码位置：`rm_synapse/utile/id_map.gd:61-73`
  - 现象：`ROBOT_TYPE_NAME[9] = "雷达/前哨"`，但协议附录二中 `9` 为雷达、`10` 为前哨站。
  - 风险：UI 文案和日志解释可能产生歧义（尤其在按 `type_id` 显示时）。

- [低] 场景资源 UID 出现漂移告警（运行可回退到 path，但会污染日志）
  - 复现命令：`/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
  - 告警涉及：`rm_synapse/net/mqtt/mqtt.tscn`、`rm_synapse/utile/log/log.tscn`、`rm_synapse/net/mqtt/tests/mqtt_debug.tscn`
  - 现象：`ext_resource, invalid UID ... using text path instead`
  - 风险：短期不影响加载，但会增加噪声并降低资源引用一致性（跨分支/跨机器合并更易出现误差）。

### 7.8 viewer 修复记录（Round 3，2026-03-03）
- 已修复 `rm_synapse/ui/hud.gd` 的 GameStatus 接入问题：
  - 将错误信号连接 `game_status_changed` 改为真实存在的 `game_status_updated`。
  - 回调函数统一为 `_on_game_status_updated(new_status)`。
  - 在 `_ready()` 中补充 `add_child(game_status_service)`（仅当尚未入树），确保 `GameStatusService` 的 `_ready/_process` 自动绑定逻辑会执行。

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --quit --scene Main.tscn`
    - 未再出现 `Attempt to connect nonexistent signal 'game_status_changed'`。
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有资源 UID 警告）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.9 viewer 修复记录（Round 4，2026-03-03）
- 已修复 `GameStatusService` 的运行期 adapter 替换风险：
  - 文件：`rm_synapse/net/mqtt/services/game_status/game_status_service.gd`
  - 变更点：
    - 增加 `_bound_adapter` 跟踪当前连接对象。
    - `_process()` 按 `bind_retry_interval_sec` 持续执行绑定探测，不再在首次成功后停止。
    - 检测到 adapter 变化时，自动断开旧 adapter 的 `game_status` 连接并重连新 adapter。
    - getter 返回 `null`/非对象/缺失 `game_status` 信号时，服务会回退未绑定状态并保留节流日志。
    - `GameStatusService` 退出树时新增解绑，避免悬挂连接。

- 已补齐“运行时绑定路径”自动化覆盖：
  - 更新：`rm_synapse/net/mqtt/tests/game_status_service_test.gd`
    - 新增 FakeAdapter/FakeAdapterGetter 路径，覆盖“延迟绑定 + adapter 替换重绑”。
  - 新增稳定测试入口（场景模式）：
    - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.tscn`
    - 目的：规避 `-s` 脚本模式下已知的 `Log` 编译噪声假阳性。

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/game_status_service_scene_test.tscn`
    - 输出：`GAME_STATUS_SERVICE_SCENE_TEST_OK`。
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID 警告）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.10 viewer 修复记录（Round 4 补充，2026-03-03）
- 测试噪声优化：
  - 在以下测试中预置 `delayed_service._logged_missing = true`，避免“故意延迟注入 adapter”时打印一次预期内错误日志：
    - `rm_synapse/net/mqtt/tests/game_status_service_test.gd`
    - `rm_synapse/net/mqtt/tests/game_status_service_scene_test.gd`
- 复验：`/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/game_status_service_scene_test.tscn`
  - 输出 `GAME_STATUS_SERVICE_SCENE_TEST_OK`，无该项干扰性错误日志。

### 7.11 viewer 实现记录（Round 5，2026-03-03）
- 按以下文档实现 getter 服务：
  - `rm_synapse/net/mqtt/services/global_logistics_status/README.md`
  - `rm_synapse/net/mqtt/services/global_unit_status/README.md`
  - `rm_synapse/net/mqtt/services/GETTER_REQUIREMENTS.md`

- 新增 `GlobalLogisticsStatusService`：
  - 文件：`rm_synapse/net/mqtt/services/global_logistics_status/global_logistics_status_service.gd`
  - 关键实现：
    - 强类型状态类 `GlobalLogisticsStatusState`（含 `clone()/to_dict()`）
    - 信号：`global_logistics_status_updated/economy_changed/tech_level_changed/encryption_level_changed`
    - getter：`get_state/get_remaining_economy/get_total_economy_obtained/get_tech_level/get_encryption_level`
    - 生命周期：`_ready/_process/_exit_tree` + `clear_cache`
    - adapter 延迟绑定 + 运行时替换重绑 + 解绑清理
    - `null` 消息与缺依赖日志节流、负值一次性告警并 clamp 到 0

- 新增 `GlobalUnitStatusService`：
  - 文件：`rm_synapse/net/mqtt/services/global_unit_status/global_unit_status_service.gd`
  - 关键实现：
    - 强类型状态模型：`BaseState/OutpostState/GlobalUnitStatusState`（深拷贝 `clone()`）
    - 信号：`global_unit_status_updated/base_state_changed/outpost_state_changed/robot_status_changed/total_damage_changed`
    - getter：基地/前哨/机器人数组/总伤害 + 状态名映射 `get_base_status_name/get_outpost_status_name`
    - 生命周期：`_ready/_process/_exit_tree` + `clear_cache`
    - adapter 延迟绑定 + 运行时替换重绑 + 解绑清理

- 新增场景化测试（覆盖默认值/ingest/信号/clear_cache/延迟绑定/替换重绑）：
  - `rm_synapse/net/mqtt/tests/global_logistics_status_service_scene_test.gd`
  - `rm_synapse/net/mqtt/tests/global_logistics_status_service_scene_test.tscn`
  - `rm_synapse/net/mqtt/tests/global_unit_status_service_scene_test.gd`
  - `rm_synapse/net/mqtt/tests/global_unit_status_service_scene_test.tscn`

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/global_logistics_status_service_scene_test.tscn`
    - 输出：`GLOBAL_LOGISTICS_STATUS_SERVICE_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/global_unit_status_service_scene_test.tscn`
    - 输出：`GLOBAL_UNIT_STATUS_SERVICE_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID warning）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何文件。

### 7.12 viewer 实现记录（Round 6，2026-03-03）
- 按要求完成“每一个 service 一个文件夹，并且补齐 README”：
  - 已将 `global_special_mechanism_service.gd` 从 `services/` 根目录迁移到：
    - `rm_synapse/net/mqtt/services/global_special_mechanism/global_special_mechanism_service.gd`
  - 并补充 `rm_synapse/net/mqtt/services/global_special_mechanism/README.md`。

- 新增并规范化以下 service 目录（每个目录含 `*_service.gd + README.md`）：
  - `robot_injury_stat/`
  - `robot_respawn_status/`
  - `robot_static_status/`
  - `robot_dynamic_status/`
  - `robot_module_status/`
  - `robot_position/`
  - `buff/`
  - `robot_path_plan_info/`
  - `radar_info_to_client/`
  - `tech_core_motion_state_sync/`
  - `robot_performance_selection_sync/`
  - `deploy_mode_status_sync/`
  - `rune_status_sync/`
  - `sentry_status_sync/`
  - `dart_select_target_status_sync/`
  - `air_support_status_sync/`

- 新增 service 均按 getter 统一规范实现：
  - 强类型状态类 + `clone()/to_dict()`
  - `get_state()` 返回拷贝
  - `_ready/_process` 重试绑定
  - `_exit_tree` 解绑
  - `clear_cache()` 重置并发出 updated 信号
  - adapter 延迟可用与替换重绑处理
  - 空消息/依赖缺失日志节流

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
  - 结果：新增 17 个 service 类成功注册，未出现 `SCRIPT ERROR / Compile Error / Parse Error`（仅保留既有 UID warning）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.13 viewer 实现记录（Round 7，2026-03-03）
- 按“每一个 service 一个文件夹，并且把 README 写好”的要求，继续完成 `services/` 根目录遗留脚本整理：
  - `rm_synapse/net/mqtt/services/custom_control_sender.gd`
    - 迁移到：`rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd`
  - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender.gd`
    - 迁移到：`rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd`
  - `rm_synapse/net/mqtt/services/mqtt_client_setter.gd`
    - 迁移到：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd`
  - `rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter.gd`
    - 迁移到：`rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter/mqtt_protocol_adapter_getter.gd`
  - 对应 `.gd.uid` 文件均已同步迁移。

- 为以上 4 个 service 目录新增 README：
  - `rm_synapse/net/mqtt/services/custom_control_sender/README.md`
  - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/README.md`
  - `rm_synapse/net/mqtt/services/mqtt_client_setter/README.md`
  - `rm_synapse/net/mqtt/services/mqtt_protocol_adapter_getter/README.md`

- 结果：`rm_synapse/net/mqtt/services/` 根目录已无遗留 service 脚本（仅保留规范文档 `GETTER_REQUIREMENTS.md`）。

- 本轮验证：
  - 命令：`/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
  - 结果：
    - 全局类注册通过（`CustomControlSender / KeyboardMouseControlSender / MQTTClientSetter / MQTTProtocolAdapterGetter`）
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`
    - 仅保留既有 UID warning（`log.tscn`、`mqtt_debug.tscn`）

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.14 viewer 修复记录（Round 8，2026-03-03）
- 按 `rm_synapse/net/mqtt/services/REVIEW_ROUND8.md` 完成修复与补测。

- [中] `EventService` 运行期 adapter 替换自动恢复：
  - 文件：`rm_synapse/net/mqtt/services/event/event_service.gd`
  - 变更：
    - 新增 `_bound_adapter` 跟踪当前绑定实例。
    - `_process()` 改为持续周期探测（不再首次成功后 `set_process(false)` 停止）。
    - `_try_bind_adapter()` 支持 `get_adapter_silent()`，并在 adapter 变更时先断开旧连接再连接新 adapter。
    - 新增 `_exit_tree()` / `_disconnect_bound_adapter()`，退出时清理连接。
    - 对 getter 返回 `null`、非对象、缺失 `event_message` 信号场景做失败回退并节流日志。

- [中] 两个 Sender 保留外部注入 getter，避免 `_ready()` 覆盖：
  - 文件：
    - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd`
    - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd`
  - 变更：
    - `_ready()` 仅在 `adapter_getter == null` 时创建默认 getter。

- [中] 缺失 adapter 高频告警刷屏路径收敛：
  - 文件：
    - `rm_synapse/net/mqtt/services/custom_control_sender/custom_control_sender.gd`
    - `rm_synapse/net/mqtt/services/keyboard_mouse_control_sender/keyboard_mouse_control_sender.gd`
  - 变更：
    - 轮询路径 `_get_adapter()` 优先走 `get_adapter_silent()`，避免 75Hz 下 getter 层重复 warn。

- [低] `MQTTClientSetter` 去除对 `ProtocolAdapter` 私有实现耦合：
  - 文件：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd`
  - 变更：
    - `_bind_adapter_transport()` 不再访问 `adapter._transport` 和私有方法 `_on_transport_message`。
    - 改为仅使用公开字段/接口：`adapter.transport_path` + `bind_transport(transport)`。

- 补齐 Round8 自动化测试：
  - 新增 `EventService` 场景测试（含延迟绑定 + 替换重绑）：
    - `rm_synapse/net/mqtt/tests/event_service_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/event_service_scene_test.tscn`
  - 新增 Sender 场景测试（外部注入不覆盖 + silent getter 调用路径）：
    - `rm_synapse/net/mqtt/tests/control_sender_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/control_sender_scene_test.tscn`
  - 新增 17 个 getter 批量场景最小回归（默认值/ingest/clear_cache/延迟绑定/替换重绑）：
    - `rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.tscn`

- 本轮测试过程中额外发现并修复 2 个真实运行期问题（非 review 原文，但会导致脚本错误）：
  - `GlobalSpecialMechanismState.clone()` 对 `Array[MechanismState]` 赋值时使用了未类型化 `[]`。
    - 修复文件：`rm_synapse/net/mqtt/services/global_special_mechanism/global_special_mechanism_service.gd`
  - `RobotPathPlanInfoState.clone()` 对 `Array[PathPointOffset]` 赋值时使用了未类型化 `[]`。
    - 修复文件：`rm_synapse/net/mqtt/services/robot_path_plan_info/robot_path_plan_info_service.gd`
  - 修复方式：改为先构造类型化数组，再整体赋值，避免 `Invalid assignment ... Array[...]` 运行时错误。

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/event_service_scene_test.tscn`
    - 输出：`EVENT_SERVICE_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/control_sender_scene_test.tscn`
    - 输出：`CONTROL_SENDER_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
    - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID warning）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.15 viewer 修复记录（Round 9 补充，2026-03-03）
- 根据 `rm_synapse/net/mqtt/services/REVIEW_ROUND8.md` Round9 “仍需处理”继续修复。

- [中] `MQTTClientSetter` 误判“已绑定”导致可能跳过真实绑定：
  - 修复文件：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd`
  - 修复点：
    - `_bind_adapter_transport()` 去掉 `adapter.transport_path == transport.get_path()` 的提前返回。
    - 统一走公开 API：`adapter.bind_transport(transport)`。
  - 目的：避免“路径一致但未真实绑定/实例替换同路径”时漏绑。

- [低] Round8 汇总测试补充关键信号断言：
  - 修复文件：`rm_synapse/net/mqtt/tests/getter_services_round8_scene_test.gd`
  - 新增断言覆盖：
    - `RobotDynamicStatusService`
      - `health_changed`
      - `energy_changed`
      - `combat_state_changed`
      - `robot_dynamic_status_updated`
    - `RobotRespawnStatusService`
      - `respawn_pending_changed`
      - `respawn_progress_changed`
      - `robot_respawn_status_updated`
    - `BuffService`
      - `buff_target_changed`
      - `buff_timer_changed`
      - `buff_updated`

- 补充 `MQTTClientSetter` 独立场景测试：
  - 新增文件：
    - `rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.gd`
    - `rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
  - 断言点：
    - 即使 `adapter.transport_path` 与 `transport.get_path()` 已一致，也会调用 `bind_transport`。

- 文档同步：
  - 更新 `rm_synapse/net/mqtt/services/mqtt_client_setter/README.md`，明确绑定路径走公开 `bind_transport`。

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
    - 输出：`MQTT_CLIENT_SETTER_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
    - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID warning）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。

### 7.16 viewer 修复记录（Round 11，2026-03-03）
- 根据 `rm_synapse/net/mqtt/services/REVIEW_ROUND8.md` Round 11 新发现继续修复：

- [低] `force_rebind` 配置项恢复有效语义：
  - 修复文件：`rm_synapse/net/mqtt/adapter/protocol_adapter.gd`
    - 新增公开方法：`is_transport_bound(node: Node) -> bool`（不暴露私有字段，仅提供绑定状态查询）。
  - 修复文件：`rm_synapse/net/mqtt/services/mqtt_client_setter/mqtt_client_setter.gd`
    - `_bind_adapter_transport()` 逻辑更新：
      - 当 `force_rebind == false` 且 `adapter.is_transport_bound(transport)` 为真时跳过重绑。
      - 否则调用公开 API `adapter.bind_transport(transport)`。
    - 结果：`force_rebind` 在 Inspector 中重新影响行为，不再是“导出但无效”。

- 文档同步：
  - 更新 `rm_synapse/net/mqtt/services/mqtt_client_setter/README.md`：补充 `force_rebind` 的行为定义。

- 测试更新：
  - 更新 `rm_synapse/net/mqtt/tests/mqtt_client_setter_scene_test.gd`：
    - 验证 `force_rebind=false` 时已绑定目标 transport 会跳过。
    - 验证目标 transport 实例变化时仍会绑定。
    - 验证 `force_rebind=true` 时会强制触发绑定。

- 本轮验证：
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/mqtt_client_setter_scene_test.tscn`
    - 输出：`MQTT_CLIENT_SETTER_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --scene net/mqtt/tests/getter_services_round8_scene_test.tscn`
    - 输出：`GETTER_SERVICES_ROUND8_SCENE_TEST_OK`
  - `/home/pnx/godot/bin/godot --headless --path rm_synapse --import --quit`
    - 未出现 `SCRIPT ERROR / Compile Error / Parse Error`（保留既有 UID warning）。

- 约束确认：
  - 未直接修改 `rm_synapse/net/mqtt/proto/generated/` 下任何生成文件。
