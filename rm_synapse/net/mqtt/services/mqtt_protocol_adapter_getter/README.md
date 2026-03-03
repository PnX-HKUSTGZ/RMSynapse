# MQTTProtocolAdapterGetter

## 作用
- 统一封装 `ProtocolAdapter` / `NetworkTransport` 的查找逻辑。
- 避免各 service/sender 重复写 `/root/Mqtt/...` 路径访问代码。

## 文件
- `mqtt_protocol_adapter_getter.gd`

## 对外接口
- `get_adapter() -> ProtocolAdapter`
- `get_adapter_silent() -> ProtocolAdapter`
- `get_transport() -> NetworkTransport`

## 路径配置
- `adapter_path`（默认 `/root/Mqtt/Adapter`）
- `transport_path`（默认 `/root/Mqtt/Transport`）

## 行为说明
- `get_adapter()` / `get_transport()` 在查找失败时会告警。
- `get_adapter_silent()` 只返回结果，不产生日志，适合高频调用路径。
