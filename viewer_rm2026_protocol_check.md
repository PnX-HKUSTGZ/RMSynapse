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
