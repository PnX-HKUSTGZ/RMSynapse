# CommonCommand Exchange 17mm Service

## 作用
封装 `CommonCommand` 的独立命令发送节点（固定 `cmd_type=1`）。

## 行为
- `send_once(param: int = 0)` 每次只发送一次，不自动重试。
- 服务内固定命令类型，调用方不可覆盖。
- `cmd_type=1` 时要求 `param % 10 == 0`，否则返回失败且不发送。

## 接口
- `send_once(param: int = 0) -> int`
- `get_last_send_result() -> int`
