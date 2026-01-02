# 网络数据流设计（MQTT + Protobuf）

本文档概述收包与发包的线程/队列/状态流转，便于实现与后续维护。

## 收包链路（服务器 → 客户端）
- **网络线程**：阻塞 `recv` → Protobuf `from_bytes` 解码为纯数据对象（或 Dictionary）→ 追加到线程安全 `inbox` 队列（仅数据，绝不触树/信号）。
- **主线程调度**：`_process` 或 `call_deferred` 触发 `_drain_inbox()`。
- **主线程落地**：在 `_drain_inbox` 中批量取出 `inbox` → 调用 `GameState.set_many(...)` 或按 topic 分发 → `GameState.state_changed` 信号广播。
- **UI/逻辑**：订阅 `GameState.state_changed`，或在需要时从 `GameState.snapshot()` 读取最新状态，统一在主线程更新 UI。

## 发包链路（客户端 → 服务器）
- **主线程收集意图**：UI/逻辑调用 `ControlService`（或 EventBus 信号）传入业务数据。
- **主线程组包入队**：`ControlService` 用 `RMProto` 构建消息，`to_bytes()` 得到 payload；将 `{topic, payload, qos}` 追加到线程安全 `outbox`。
- **发送线程/循环**：固定线程或 `_process` 中 `_drain_outbox()`，批量取出待发包 → 调用 `mqtt_client.publish(topic, payload, qos)`；失败可重试并回写状态/事件。
- **反馈通知（可选）**：发送结果通过 EventBus/信号 `call_deferred` 回主线程，用于提示或重试策略。

## 关键约束
- 线程安全：工作线程只接触队列和纯数据，不操作节点、不发信号。
- 批处理：`_drain_inbox/_drain_outbox` 每次取完当前队列，减少高频信号对 UI 的压力。
- 限频：高频指令（如 RemoteControl 75 Hz）在 `ControlService` 侧做节流；收包刷新 UI 时采用“脏标记 + 每帧一次渲染”。
- 失败处理：`publish/recv` 异常记录日志，必要时通过状态/信号上报 UI。
