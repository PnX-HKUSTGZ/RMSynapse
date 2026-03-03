# CustomControlSender

## 作用
- 按固定频率（默认 `75Hz`）向 `ProtocolAdapter` 发送 `CustomControlData`。
- 适合持续上报自定义控制字节流（如上位机扩展控制通道）。

## 文件
- `custom_control_sender.gd`

## 对外接口
- `update_data(data: AdapterTypes.CustomControlData) -> void`
- `start_sending() -> void`
- `stop_sending() -> void`
- `is_sending() -> bool`

## 依赖
- `MQTTProtocolAdapterGetter`：获取 `ProtocolAdapter`。
- `ProtocolAdapter.send_custom_control(data)`：真正发送。

## 行为说明
- `_ready()` 内创建定时器并按 `auto_start` 决定是否启动发送。
- 当 adapter 不可用时，本类会跳过本轮发送并打印节流日志。
