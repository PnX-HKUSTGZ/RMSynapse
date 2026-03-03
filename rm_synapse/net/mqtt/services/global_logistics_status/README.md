# GlobalLogisticsStatus Service 实现文档

## 1. 目标
为 UI 提供稳定、可直接消费的全局后勤状态服务（`GlobalLogisticsStatus`），覆盖以下字段：
- `remaining_economy`：己方当前经济
- `total_economy_obtained`：己方累计总经济（`uint64`）
- `tech_level`：己方科技等级
- `encryption_level`：己方加密等级

依据来源：
- 协议定义：`rm_synapse/net/mqtt/proto/rm_custom.proto` 的 `message GlobalLogisticsStatus`
- 协议说明：`references/RoboMaster 2026 机甲大师高校系列赛通信协议 V1.2.0（20260209）.pdf` 2.2.5
- UI 需求：`rm_synapse/ui/Readme.md`（GlobalLogisticsStatus，1Hz）

## 2. 服务定位
- 类型：`getter` 类服务（只处理下行状态，不发上行指令）。
- 目录：`rm_synapse/net/mqtt/services/global_logistics_status/`
- 建议脚本名：`global_logistics_status_service.gd`
- 建议类名：`GlobalLogisticsStatusService`

## 3. 依赖关系
- 依赖 `MQTTProtocolAdapterGetter` 获取 `ProtocolAdapter`。
- 监听 `ProtocolAdapter.global_logistics_status(message)` 信号。
- 不直接依赖 UI 节点；UI 通过信号或 getter 拉取数据。

## 4. 对外接口设计

### 4.1 信号（建议）
- `global_logistics_status_updated(state)`
- `economy_changed(remaining_economy, total_economy_obtained)`
- `tech_level_changed(tech_level)`
- `encryption_level_changed(encryption_level)`

### 4.2 Getter（建议）
- `get_state() -> GlobalLogisticsStatusState`
- `get_remaining_economy() -> int`
- `get_total_economy_obtained() -> int`
- `get_tech_level() -> int`
- `get_encryption_level() -> int`

### 4.3 生命周期接口（建议）
- `clear_cache()`
- 内部自动绑定：`_ready()` 调用 `_try_bind_adapter()`
- 绑定重试：启动时 adapter 未就绪则定时重试绑定

## 5. 状态模型
不使用 `Dictionary` 作为主状态载体，改为强类型数据类：

`GlobalLogisticsStatusState extends RefCounted`
- `remaining_economy: int = 0`
- `total_economy_obtained: int = 0`
- `tech_level: int = 0`
- `encryption_level: int = 0`
- `last_update_msec: int = 0`

建议在状态类中提供：
- `clone() -> GlobalLogisticsStatusState`
- 可选 `to_dict() -> Dictionary`

备注：
- GDScript 的 `int` 可承载 64 位整数，可直接保存 `uint64 total_economy_obtained`。
- 建议保持非负语义（出现负值时可做告警或归零保护）。

## 6. 实现步骤（详细分解）

### Step 1：创建服务骨架
- 新建 `global_logistics_status/global_logistics_status_service.gd`。
- 定义 `GlobalLogisticsStatusService` 和 `GlobalLogisticsStatusState`。
- 初始化 `_state` 与绑定相关字段（`_adapter_bound`、重试计时、日志防抖）。

### Step 2：定义消息读取逻辑
- 实现 `_on_global_logistics_status(message)`：
  - `_state.remaining_economy = int(message.get_remaining_economy())`
  - `_state.total_economy_obtained = int(message.get_total_economy_obtained())`
  - `_state.tech_level = int(message.get_tech_level())`
  - `_state.encryption_level = int(message.get_encryption_level())`
  - 更新时间戳 `last_update_msec`

### Step 3：定义变更检测与信号
- 更新前保存 `old_state = _state.clone()`。
- 变化时分别发射：
  - 经济字段变化 -> `economy_changed`
  - 科技等级变化 -> `tech_level_changed`
  - 加密等级变化 -> `encryption_level_changed`
  - 每次更新 -> `global_logistics_status_updated(_state.clone())`

### Step 4：实现 Getter 接口
- 通过 getter 暴露缓存。
- `get_state()` 返回 clone，避免外部修改内部状态。

### Step 5：绑定与重试机制
- `_ready()` 尝试绑定。
- `_process(delta)` 周期重试 `_try_bind_adapter()`。
- 若 adapter 替换，先断开旧连接再连接新 adapter。
- `_exit_tree()` 做解绑清理。

### Step 6：错误处理与日志策略
- `message == null`：忽略并节流 warn。
- adapter 缺失：节流 error，避免刷屏。
- 不抛异常中断主循环。

### Step 7：测试用例
- 新建 `rm_synapse/net/mqtt/tests/global_logistics_status_service_test.gd`。
- 最小覆盖：
  - 默认值检查
  - ingest 后字段一致
  - 经济/科技/加密信号触发
  - `clear_cache()` 恢复默认
  - adapter 延迟可用与 adapter 替换重绑路径

### Step 8：UI 接入约定
- UI 优先监听 `global_logistics_status_updated(state)`。
- 局部刷新可监听 `economy_changed` 等细粒度信号。
- 若桥接层需要 JSON，再调用 `state.to_dict()` 转换。

## 7. 验收标准（DoD）
- 服务能稳定接收并缓存 `GlobalLogisticsStatus`。
- Getter 与最近一条消息一致。
- 信号触发语义与字段变化一致。
- adapter 晚启动或替换时仍可自动绑定/重绑。
- 测试可稳定通过，无明显日志刷屏。

## 8. 后续扩展（非本轮）
- 增加字段合法范围告警（如等级上限校验）。
- 增加数据时效判断（stale 检测）。
- 增加经济变化速率派生字段（供 UI 快速显示）。
