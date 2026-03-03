# GameStatus Service 实现文档

## 1. 目标
为 UI 提供稳定、可直接消费的比赛全局状态服务（`GameStatus`），覆盖以下字段：
- 当前局号 `current_round`
- 总局数 `total_rounds`
- 红方得分 `red_score`
- 蓝方得分 `blue_score`
- 当前阶段 `current_stage`
- 当前阶段剩余时间（秒）`stage_countdown_sec`
- 当前阶段已过时间（秒）`stage_elapsed_sec`
- 暂停状态 `is_paused`

依据来源：
- 协议定义：`rm_synapse/net/mqtt/proto/rm_custom.proto` 的 `message GameStatus`
- UI 需求：`rm_synapse/ui/Readme.md`（GameStatus，5Hz）

## 2. 服务定位
- 类型：`getter` 类服务（只处理下行状态，不发上行指令）。
- 目录：`rm_synapse/net/mqtt/services/game_status/`
- 建议脚本名：`game_status_service.gd`
- 建议类名：`GameStatusService`

## 3. 依赖关系
- 依赖 `MQTTProtocolAdapterGetter` 获取 `ProtocolAdapter`。
- 监听 `ProtocolAdapter.game_status(message)` 信号。
- 不直接依赖 UI 节点；UI 通过信号或 getter 拉取数据。

## 4. 对外接口设计

### 4.1 信号（建议）
- `game_status_updated(state)`
- `stage_changed(stage, stage_name)`
- `score_changed(red_score, blue_score)`
- `pause_state_changed(is_paused)`

### 4.2 Getter（建议）
- `get_state() -> GameStatusState`
- `get_current_round() -> int`
- `get_total_rounds() -> int`
- `get_red_score() -> int`
- `get_blue_score() -> int`
- `get_current_stage() -> int`
- `get_current_stage_name() -> String`
- `get_stage_countdown_sec() -> int`
- `get_stage_elapsed_sec() -> int`
- `is_paused() -> bool`

### 4.3 生命周期接口（建议）
- `clear_cache()`
- 内部自动绑定：`_ready()` 调用 `_try_bind_adapter()`
- 绑定重试：若启动时 adapter 未就绪，定时重试绑定

## 5. 状态模型
不使用 `Dictionary` 作为主状态载体，改为强类型数据类：

`GameStatusState extends RefCounted`
- `current_round: int = 0`
- `total_rounds: int = 0`
- `red_score: int = 0`
- `blue_score: int = 0`
- `current_stage: int = 0`
- `current_stage_name: String = "未开始比赛"`
- `stage_countdown_sec: int = 0`
- `stage_elapsed_sec: int = 0`
- `is_paused: bool = false`
- `last_update_msec: int = 0`

建议在 `GameStatusState` 内提供：
- `clone() -> GameStatusState`（深拷贝给 UI，避免外部修改内部缓存）
- 可选 `to_dict() -> Dictionary`（仅用于最终 Web payload 组装，不作为服务内部主模型）

默认值建议：
- 数值字段默认 `0`
- 布尔字段默认 `false`
- 阶段名默认 `"未开始比赛"`（对应 `current_stage=0`）

## 6. 阶段枚举映射
按协议约定维护枚举映射：
- `0`: 未开始比赛
- `1`: 准备阶段
- `2`: 十五秒裁判系统自检阶段
- `3`: 五秒倒计时
- `4`: 比赛中
- `5`: 比赛结算中

建议提供 `get_stage_name(stage: int) -> String`，未知值返回 `"Unknown"`。

## 7. 实现步骤（详细分解）

### Step 1：创建服务骨架
- 新建 `game_status/game_status_service.gd`，`extends Node`，`class_name GameStatusService`。
- 在同文件或独立文件中定义 `class GameStatusState`（强类型状态类）。
- 定义依赖成员：`adapter_getter`、`_adapter_bound`、日志防抖字段。
- 定义 `_state: GameStatusState` 并初始化默认值。

### Step 2：定义协议字段读取逻辑
- 实现 `_on_game_status(message)`：
  - 读取 `message.get_current_round()` 等全部字段。
  - 同步更新 `_state` 的强类型字段。
  - 记录 `last_update_msec`。

### Step 3：定义变更检测与信号
- 在更新前保留旧值副本，更新后按需发信号：
  - 阶段变化 -> `stage_changed`
  - 比分变化 -> `score_changed`
  - 暂停状态变化 -> `pause_state_changed`
  - 每次更新 -> `game_status_updated(_state.clone())`

### Step 4：实现 getter 接口
- 所有 getter 仅从缓存读取，不直接访问协议对象。
- `get_state()` 返回 `_state.clone()`，避免外部误改内部状态。

### Step 5：绑定与重试机制
- `_ready()` 尝试绑定一次。
- 若失败，开启 `_process(delta)` 周期重试（建议 0.5~1.0 秒）。
- 成功绑定后停止重试，避免多余开销。

### Step 6：错误处理与日志策略
- adapter 未找到时只记录节流日志（避免刷屏）。
- `message == null` 直接忽略并记录 debug/warn。
- 不抛异常中断主循环。

### Step 7：测试用例
- 新建 `rm_synapse/net/mqtt/tests/game_status_service_test.gd`（`extends SceneTree`）。
- 最小覆盖：
  - 默认缓存值检查
  - ingest 一条 GameStatus 后字段正确
  - 阶段/比分/暂停状态变更信号触发
  - `clear_cache()` 回到默认值
  - 阶段名映射正确（含未知值）

### Step 8：UI 接入约定
- UI 层优先监听 `game_status_updated(state)`。
- 需要局部刷新时监听细粒度信号（`score_changed` 等）。
- 不在 UI 侧直接解析 protobuf `message`。
- 若前端桥接层需要 JSON，再由桥接层调用 `state.to_dict()` 统一转换。

## 8. 验收标准（DoD）
- 服务能稳定接收并缓存 `GameStatus`。
- 所有 getter 返回值与最近一条消息一致。
- 阶段/比分/暂停变更信号行为符合预期。
- adapter 晚于服务启动时，最终可自动绑定成功。
- 测试脚本通过，且无明显日志刷屏。

## 9. 后续扩展（非本轮）
- 增加 `data_stale` 判断（例如超过 N 秒未更新）。
- 增加 `round_progress`（基于 elapsed/countdown 派生）。
- 将服务输出统一桥接到 UI payload 组装层。
