# RMSynapse

## MQTT

生成文件

```
path\to\Godot --headless --path rm_synapse \
  -s addons/protobuf/protobuf_cmdln.gd \
  --input=protocol/rm_custom.proto \
  --output=protocol/generated/rm_proto.gd \
  --class_name=RMProto
```

自定义客户端发送的消息：
1. 传输鼠标键盘输入和自定义数据 75Hz
2. 云台手地图点击标记 触发式
3. 工程装配指令 1Hz
4. 步兵/英雄选择性能体系 1Hz
5. 英雄部署模式相关指令 1Hz
6. 能量机关激活指令 1Hz
7. 飞镖控制指令 1Hz
8. 哨兵控制指令请求 1Hz
9. 空中支援指令 1Hz

数据流向

启动 → mqtt_client.connect() → proto_registry.auto_subscribe_downstream(mqtt_client)

线程1：

接收到消息 -> 解码 -> 推入队列

主线程：

GameState 读取更新消息/发送信号，其他节点从 GameState 获取各种状态