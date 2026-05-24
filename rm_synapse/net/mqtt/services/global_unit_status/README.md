# GlobalUnitStatus Service 实现文档

## 1. 目标
为 UI 提供稳定、可直接消费的全局单位状态服务（`GlobalUnitStatus`），覆盖以下协议字段：
- 己方基地：`base_health`、`base_status`、`base_shield`
- 己方前哨站：`outpost_health`、`outpost_status`
- 对方基地：`enemy_base_health`、`enemy_base_status`、`enemy_base_shield`
- 对方前哨站：`enemy_outpost_health`、`enemy_outpost_status`
- 全机器人血量：`robot_health`（`repeated uint32`，先己方后对方）
- 己方累计发弹量：`robot_bullets`（`repeated int32`）
- 双方累计总伤害：`total_damage_ally`、`total_damage_enemy`

依据来源：
- 协议定义：`rm_synapse/net/mqtt/proto/rm_custom.proto` 的 `message GlobalUnitStatus`
- 协议枚举：`references/RoboMaster_2026_机甲大师高校系列赛通信协议_V1.3.1（20260519）.pdf` 2.2.4
- UI 需求：`rm_synapse/ui/Readme.md`（GlobalUnitStatus，1Hz）

## 2. 服务定位
- 类型：`getter` 类服务（只处理下行状态，不发上行指令）。
- 目录：`rm_synapse/net/mqtt/services/global_unit_status/`
- 建议脚本名：`global_unit_status_service.gd`
- 建议类名：`GlobalUnitStatusService`

## 3. 依赖关系
- 依赖 `MQTTProtocolAdapterGetter` 获取 `ProtocolAdapter`。
- 监听 `ProtocolAdapter.global_unit_status(message)` 信号。
- 不直接依赖 UI 节点；UI 通过信号或 getter 拉取数据。

## 4. 对外接口设计

### 4.1 信号（建议）
- `global_unit_status_updated(state)`
- `base_state_changed(ally_base, enemy_base)`
- `outpost_state_changed(ally_outpost, enemy_outpost)`
- `robot_status_changed(robot_health, robot_bullets)`
- `total_damage_changed(total_damage_ally, total_damage_enemy)`

### 4.2 Getter（建议）
- `get_state() -> GlobalUnitStatusState`
- `get_ally_base() -> BaseState`
- `get_enemy_base() -> BaseState`
- `get_ally_outpost() -> OutpostState`
- `get_enemy_outpost() -> OutpostState`
- `get_robot_health() -> Array[int]`
- `get_robot_bullets() -> Array[int]`
- `get_total_damage_ally() -> int`
- `get_total_damage_enemy() -> int`
- `get_base_status_name(status: int) -> String`
- `get_outpost_status_name(status: int) -> String`

### 4.3 生命周期接口（建议）
- `clear_cache()`
- 内部自动绑定：`_ready()` 调用 `_try_bind_adapter()`
- 绑定重试：启动时 adapter 未就绪则定时重试绑定

## 5. 状态模型
不使用 `Dictionary` 作为主状态载体，改为强类型数据类：

`BaseState extends RefCounted`
- `health: int = 0`
- `status: int = 0`
- `shield: int = 0`

`OutpostState extends RefCounted`
- `health: int = 0`
- `status: int = 0`

`GlobalUnitStatusState extends RefCounted`
- `ally_base: BaseState`
- `enemy_base: BaseState`
- `ally_outpost: OutpostState`
- `enemy_outpost: OutpostState`
- `robot_health: Array[int] = []`
- `robot_bullets: Array[int] = []`
- `total_damage_ally: int = 0`
- `total_damage_enemy: int = 0`
- `last_update_msec: int = 0`

建议在状态类内提供：
- `clone() -> GlobalUnitStatusState`（深拷贝）
- 可选 `to_dict() -> Dictionary`（仅用于最终 Web payload 组装）

## 6. 状态枚举映射

### 6.1 基地状态 `base_status`
- `0`: 无敌
- `1`: 解除无敌，护甲未展开
- `2`: 解除无敌，护甲展开

### 6.2 前哨站状态 `outpost_status`
- `0`: 无敌
- `1`: 存活，解除无敌，中部装甲旋转
- `2`: 存活，解除无敌，中部装甲停转
- `3`: 被击毁，不可重建
- `4`: 被击毁，可重建
- `5`: 被击毁，重建中

建议提供：
- `get_base_status_name(status: int) -> String`
- `get_outpost_status_name(status: int) -> String`

## 7. 实现步骤（详细分解）

### Step 1：创建服务骨架
- 新建 `global_unit_status/global_unit_status_service.gd`。
- 定义 `GlobalUnitStatusService` 与状态类（`BaseState` / `OutpostState` / `GlobalUnitStatusState`）。
- 初始化 `_state` 与绑定相关字段（`_adapter_bound`、重试计时、日志防抖字段）。

### Step 2：定义消息读取逻辑
- 实现 `_on_global_unit_status(message)`：
  - 读取所有 `get_*` 字段（含 repeated 字段）。
  - 使用 `int(...)` 归一化数值。
  - repeated 字段使用新数组拷贝，避免共享引用。
  - 更新 `last_update_msec`。

### Step 3：定义变更检测与信号
- 更新前保存 `old_state = _state.clone()`。
- 更新后按需发信号：
  - 基地字段变化 -> `base_state_changed`
  - 前哨字段变化 -> `outpost_state_changed`
  - 机器人数组变化 -> `robot_status_changed`
  - 总伤害变化 -> `total_damage_changed`
  - 每次更新 -> `global_unit_status_updated(_state.clone())`

### Step 4：实现 Getter 接口
- 所有 getter 均读取缓存，不直接暴露 protobuf message。
- `get_state()` 必须返回 clone，防止外部修改内部状态。

### Step 5：绑定与重试机制
- `_ready()` 尝试绑定一次。
- `_process(delta)` 周期重试 `_try_bind_adapter()`。
- 若 adapter 发生替换，先断开旧连接再连接新 adapter。
- `_exit_tree()` 时执行解绑，避免悬挂连接。

### Step 6：错误处理与数据稳健性
- `message == null` 直接忽略并记录节流 warn。
- 对 repeated 字段长度不做强假设；按原样缓存到 typed array。
- 若未来需要索引到机器人 ID，建议增加显式顺序常量，不在当前轮硬编码。

### Step 7：测试用例
- 新建 `rm_synapse/net/mqtt/tests/global_unit_status_service_test.gd`。
- 最小覆盖：
  - 默认值检查
  - ingest 后字段一致性
  - 枚举名称映射（含未知值）
  - 变更信号触发次数与参数
  - `clear_cache()` 后恢复默认
  - adapter 延迟可用与 adapter 替换重绑路径

### Step 8：UI 接入约定
- UI 优先监听 `global_unit_status_updated(state)`。
- 局部刷新可监听 `base_state_changed` / `robot_status_changed`。
- 前端桥接层若需 JSON，由桥接层调用 `state.to_dict()`。

## 8. 验收标准（DoD）
- 服务可稳定接收并缓存 `GlobalUnitStatus`。
- Getter 与最近一条消息数据一致。
- 基地/前哨/机器人/总伤害的变化信号行为符合预期。
- adapter 晚启动或替换时可自动绑定/重绑。
- 测试脚本可稳定通过，无明显日志刷屏。

## 9. 后续扩展（非本轮）
- 增加“机器人数组 -> 机器人 ID”显式映射辅助函数。
- 增加合法范围检查（如状态值越界告警）。
- 增加数据时效判断（stale 检测）。
