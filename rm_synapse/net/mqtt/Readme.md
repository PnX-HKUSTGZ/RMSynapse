# Mqtt

主要实现mqtt层的数据交换，其具体架构如下

```
[ 表现层 (View/GameLogic) ]  <-- (业务数据/信号)
       |
[ 业务服务层 (Services) ]    <-- (处理具体逻辑，如 LoginService, BattleService)
       |
[ 协议适配层 (Adapter) ]     <-- (Protobuf 序列化/反序列化，Topic 映射)
       |
[ 传输层 (Transport) ]       <-- (MQTT Client 封装，负责网络IO)
```

**传输层 (NetworkTransport)**

> 需要 AutoLoad

职责：只管“发字节”和“收字节”，不知道什么是Protobuf，也不关心业务。

核心功能：MQTT连接保活、断线重连、Topic订阅管理。

需要实现的功能：
1. 初始化链接
2. 断线重连
3. Topic订阅管理
4. 切换重启链接
5. 发送原始字节数据
6. 接受定义数据

**协议适配层 (ProtocolAdapter)**

> 需要 AutoLoad

职责：它负责将 Topic + Bytes 转换为 Godot Object / Protobuf Object。并且订阅Topic，设置消息级别

解耦策略：建立一个 Topic <-> Protobuf Type 的映射表。

并且将接受到的消息转为信号发送出去，将接受到的消息序列化，交给传输层

**业务服务层 (BusinessServices)**

实现一些基础功能，并且提供一些服务，比如发送键鼠消息，发送并且确认装配指令。获取当前机器人信息等。隐藏协议适配层细节。

**表现层 (View/GameLogic)**

> 不在这里实现，只是用作展示结构

通过调用 业务服务层 提供的service，获取消息。

## 计划（先写计划，未获许可不写代码）

### 目标与规则约束（基于通信协议 V1.3.1）
- 自定义客户端使用 Protobuf v3 + MQTT，Topic 即消息名，服务端地址：192.168.12.1:3333。
- 可通过操作间 RJ45 有线接入赛事引擎服务器，并可与自定义控制器进行有线通信。
- 可接收比赛状态、机器人状态、事件、判罚等数据，并发送操作指令（性能体系、兑换、空中支援等）。
- 图传码流可通过 UDP 3334 监听（HEVC，分片帧头 8 字节）。

### 依赖与待确认
- 协议来源：已改为《RoboMaster 2026 机甲大师高校系列赛通信协议 V1.3.1（20260519）》。
- 仍需确认：实际比赛是否存在 Topic 前缀或命名差异（当前按“消息名即 Topic”实现）。
- 允许信息范围与 UI 需求：确认要展示/控制的功能清单，避免超出规则允许范围。

### 技术方案（结合现有插件）
- 传输层：基于 `addons/mqtt/mqtt.gd` 的 MQTT Client，连接 `tcp://192.168.12.1:3333/`，binary 模式收发。
- 协议适配层：基于 `addons/protobuf` 编译的 GDScript Protobuf 类，Topic ↔ Message 映射。
- 业务服务层：对外提供高层 API（性能体系选择、发弹量兑换、空中支援等）与状态信号。

### 实施步骤（里程碑）
1. 协议准备：已按通信协议 2.2 详细定义重写 proto 并生成 GDScript；如协议有更新再同步修改。
2. 传输层打通：配置 MQTT 连接参数、订阅策略、断线重连与日志；验证字节收发与 QoS 行为。
3. 协议适配：建立 Topic ↔ Protobuf Type 映射；解码后统一转信号；编码后统一下发。
4. 业务服务：封装规则允许的指令与数据模型；提供缓存与变更信号，供 UI/逻辑层订阅。
5. 集成验证：先用本地/回放数据验证，再接入裁判系统实测；补齐异常场景（断线、乱序、缺包）。

> 说明：在你确认计划前，我不会开始写代码或修改逻辑实现。

## 实现摘要
- 传输层：`rm_synapse/net/mqtt/transport/network_transport.gd`
- 协议文件：`rm_synapse/net/mqtt/proto/rm_custom.proto`
- 生成代码：`rm_synapse/net/mqtt/proto/generated/rm_custom_pb.gd`（由 `addons/protobuf` 生成）
- 协议适配层：`rm_synapse/net/mqtt/adapter/protocol_adapter.gd`

> 备注：当前 proto 已按通信协议 V1.3.1（20260519）2.2 详细定义同步。
