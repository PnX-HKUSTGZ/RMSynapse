# MQTTClientSetter

## 作用
- 在场景启动时统一配置 `NetworkTransport` 与 `ProtocolAdapter`。
- 适合把连接参数、自动订阅、绑定策略放在 Inspector 中集中管理。

## 文件
- `mqtt_client_setter.gd`

## 主要能力
- 配置 transport：`broker_url`、`auto_connect`、重连、心跳、鉴权等。
- 配置 adapter：`auto_subscribe`、`transport_path`、是否立即绑定。
- 可选在应用配置后主动触发连接。

## 关键接口
- `apply_settings() -> void`
- `get_adapter() -> ProtocolAdapter`
- `get_transport() -> NetworkTransport`

## 行为说明
- `_ready()` 根据 `apply_on_ready` / `defer_apply` 决定何时执行 `apply_settings()`。
- 如果节点路径无效，会记录告警，不会阻断主循环。
- `bind_transport_on_apply=true` 时会调用 `adapter.bind_transport(transport)` 触发公开绑定流程，不依赖私有字段判定。
- `force_rebind=false` 时，若 adapter 已绑定当前 transport 会跳过重绑；`force_rebind=true` 时会强制触发 `bind_transport`。
