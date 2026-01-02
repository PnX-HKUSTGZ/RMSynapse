# 网络层说明

- 统一 MQTT 实例：场景中放置一个名为 `MQTT` 的节点（addons/mqtt/mqtt.tscn 实例）。所有网络节点（如 `mqtt_game_state.gd` 以及发送端）通过 `mqtt_path` 引用同一个实例，不再自行实例化。
- `mqtt_game_state.gd`：只负责收包、解码、状态信号。需要将其 `mqtt_path` 指向上述 `MQTT` 节点。
- 发送侧（若有）：同样应复用该 `MQTT` 节点的 `publish`，不要再创建新的 MQTT 客户端。

这样可避免多个客户端抢占同一 client_id 或重复连接，确保收发使用同一条连接。 
