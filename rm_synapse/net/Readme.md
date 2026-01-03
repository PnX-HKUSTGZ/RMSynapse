# 网络发送/接收组件使用说明

## 统一 MQTT 实例
- 在 Project Settings → AutoLoad 注册 `res://addons/mqtt/mqtt.tscn` 名为 `MQTT`（你已配置）。
- 所有组件（接收/发送）都复用该实例；不再自行实例化。

## 接收与状态
- `mqtt_game_state.gd`：复用 AutoLoad `MQTT`，解码所有服务器→客户端主题，填充默认值后更新状态并发信号。

## 发送组件
- `mqtt_sender.gd`：底层发送队列，提供 `enqueue_latest`（高频覆盖）、`enqueue_event`（触发式）、`publish_now`（定频调用）。QoS1 有简单 ACK/超时重试。
- `remote_control_service.gd`：高频 RemoteControl（默认 75Hz latest-only）。接口：`update_mouse(dx,dy,dz)`、`set_buttons(l,r,m)`、`set_keyboard_mask(mask)`、`set_custom_data(bytes, clear_after_send)`.
- `low_rate_sender.gd`：按 topic 定时发送（每 topic 一个 Timer），`register_topic(topic, interval, qos, retain)` + `update_payload(topic, payload)`.
- `trigger_service.gd`：触发式发送，`fire(topic, payload, qos, retain, cooldown_ms)`，可选冷却/缓冲。

## 典型挂载方式
- 场景或 AutoLoad 中放置：
  - AutoLoad: `MQTT`（已放）
  - Node: `MqttSender`（可 AutoLoad 或场景节点）
  - Node: `RemoteControlService`, `LowRateSender`, `TriggerService`，它们的路径指向同一个 `MqttSender`。
- `mqtt_game_state.gd` 可保持 AutoLoad（名称 `GameState`）负责接收。

## 高频/低频/触发策略
- 高频 RemoteControl：latest-only，不缓存断线数据；custom bytes 长度>30 自动截断。
- 低频：每个 topic 独立定时发送，未更新沿用最新值。
- 触发式：即时发送，可配置冷却，断线可缓冲有限条（TriggerService 内部）。

## 配置提示
- `mqtt_sender.gd`：`ack_timeout_sec`、`max_retries`、`max_batch_per_frame`、`drop_highrate_on_disconnect`。
- `remote_control_service.gd`：`rate_hz`、`qos`、`clear_custom_after_send`.
- `low_rate_sender.gd`：为每个低频 topic 注册 interval；可指向 `MqttSender` 以获得 QoS1 重试能力。
