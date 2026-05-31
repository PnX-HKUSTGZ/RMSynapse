# CustomByteBlock Enemy Aux Bridge

本协议用于机器人端桥接节点从雷达信息波获得对方经济和对方剩余发弹量后，通过 `0x0310 / CustomByteBlock` 转发给 RoboMaster 自定义客户端。自定义客户端只解析官方 `CustomByteBlock.data` 中的最终桥接数据，不直接解析雷达发给机器人的 `0x0301` 信息波。

本协议只处理对方经济和对方剩余发弹量，不处理位置。位置仍走 `RadarInfoToClient` 或其他位置数据源。

## 发送到自定义客户端

机器人侧通过 `SendMessage` 与 `rm_manager` 交互，发送给裁判系统：

- `target = 2`
- `cmd_id = 0x0310`
- 外层消息进入自定义客户端后表现为官方 MQTT topic `CustomByteBlock`

官方外层 Protobuf：

```proto
message CustomByteBlock {
  optional bytes data = 1;
}
```

`CustomByteBlock.data` 内部采用本文定义的 bridge record 格式。总长度需满足官方限制，不超过 300 bytes。

## CustomByteBlock.data 内部格式

`CustomByteBlock.data` 可以只包含一条记录，也可以连续拼接多条已知记录。每条记录的通用头为 5 bytes：

```cpp
#pragma pack(push, 1)
struct custom_client_bridge_record {
    uint8_t cmd_id;
    int32_t active_time; // 当前命令持续时间 ms
    uint8_t load[];
};
#pragma pack(pop)
```

解析规则：

- 所有多字节字段均按 little-endian 解析。
- `active_time` 为 `int32_t`，单位 ms。
- 当前协议没有 `data_len` 字段；记录长度由 `cmd_id` 决定。
- 客户端从 offset 0 开始逐条解析。
- 遇到未知 `cmd_id` 或当前记录长度不足时，停止解析剩余内容；已成功解析的前序记录仍然有效。
- `CustomByteBlock.data` 中的数据均表示敌方信息；HUD 会根据当前选择的 MQTT `clientId` 判断己方阵容和敌方阵容，把这些数据放到对方一侧。

## cmd_id = 0x01 敌方经济信息

`load` 是 1 个 `enemy_economics` 结构，共 8 bytes：

```cpp
#pragma pack(push, 1)
struct enemy_economics {
    uint32_t remaining;
    uint32_t total;
};

struct enemy_economics_record {
    uint8_t cmd_id;       // 0x01
    int32_t active_time;  // ms
    enemy_economics load;
};
#pragma pack(pop)
```

字段 offset 表：

| Offset | Size | Field | Rule |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd_id` | `0x01` |
| 1 | 4 | `active_time` | 当前命令持续时间，`int32le`，单位 ms |
| 5 | 4 | `remaining` | 敌方当前剩余经济，`uint32le` |
| 9 | 4 | `total` | 敌方累计经济，`uint32le`；前端解析并保留用于调试/后续扩展，当前 HUD 不显示 |

经济记录总长度为 13 bytes。

## cmd_id = 0x02 敌方剩余发弹量

`load` 是 5 个 `int32_t`，共 20 bytes：

```cpp
#pragma pack(push, 1)
struct enemy_remaining_bullets {
    int32_t remaining_bullets[5];
    // hero / 3号 / 4号 / 哨兵 / 无人机
};

struct enemy_remaining_bullets_record {
    uint8_t cmd_id;       // 0x02
    int32_t active_time;  // ms
    enemy_remaining_bullets load;
};
#pragma pack(pop)
```

`remaining_bullets` 顺序：

| Index | Source Meaning | HUD Robot | HUD Key |
| ---: | --- | ---: | --- |
| 0 | hero | 1 | `hero1` |
| 1 | 3号步兵 | 3 | `infantry3` |
| 2 | 4号步兵 | 4 | `infantry4` |
| 3 | 哨兵 | 7 | `sentry7` |
| 4 | 无人机 / 空中机器人 | 6 | `aerial6` |

字段 offset 表：

| Offset | Size | Field | Rule |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd_id` | `0x02` |
| 1 | 4 | `active_time` | 当前命令持续时间，`int32le`，单位 ms |
| 5 | 4 | `remaining_bullets[0]` | 英雄，`int32le` |
| 9 | 4 | `remaining_bullets[1]` | 3号步兵，`int32le` |
| 13 | 4 | `remaining_bullets[2]` | 4号步兵，`int32le` |
| 17 | 4 | `remaining_bullets[3]` | 哨兵，`int32le` |
| 21 | 4 | `remaining_bullets[4]` | 无人机 / 空中机器人，`int32le` |

弹量记录总长度为 25 bytes。值 `-1` 表示 unknown / invalid / not available，客户端显示为 `--`，不会显示 `-1`。

## 拼接 hex 示例

以下 `CustomByteBlock.data` 同时包含经济记录和弹量记录：

```text
01 e8 03 00 00 a7 01 00 00 67 0c 00 00
02 e8 03 00 00 1a 00 00 00 ff ff ff ff 8f 00 00 00 b6 00 00 00 00 00 00 00
```

含义：

- 经济记录 `active_time = 1000ms`
- 敌方当前经济 `remaining = 423`
- 敌方累计经济 `total = 3175`
- 弹量记录 `active_time = 1000ms`
- 英雄 `26`
- 3号步兵 `-1` -> `null`
- 4号步兵 `143`
- 哨兵 `182`
- 无人机 / 空中机器人 `0`

前端解析结果示例：

```json
{
  "receivedAtMs": 123456789,
  "activeTimeMs": 1000,
  "validAmmo": true,
  "validEconomy": true,
  "enemyProjectile": {
    "hero1": 26,
    "infantry3": null,
    "infantry4": 143,
    "sentry7": 182,
    "aerial6": 0
  },
  "enemyEconomy": {
    "coinsRemaining": 423,
    "coinsTotal": 3175
  }
}
```

当前 HUD 显示：

- 红方当前经济 / 蓝方当前经济。
- 对方机器人 `1/3/4/6/7` 的剩余发弹量。
- 更新时间 / 更新年龄。

当前 HUD 不显示累计经济 `coinsTotal`，也不显示 `SEQ`。

## 接收来自雷达的消息

本节描述机器人端 bridge 节点的数据来源，前端不直接解析这部分。

雷达通过 `cmd_id = 0x0301` 的机器人交互命令发送给己方机器人。bridge 节点启动时需要通过参数确定己方 ID 与雷达 ID，并通过监听 `core/rm_message/msg/RobotInteraction.msg` 与 `rm_manager` 通信。

`cmd_id = 0x0301` 的 `user_data` 外层定义：

```cpp
typedef _packed struct {
    uint16_t data_cmd_id;
    uint16_t sender_id;
    uint16_t receiver_id;
    uint8_t user_data[x];
} robot_interaction_data_t;
```

其中 `x` 最大为 112。

### data_cmd_id = 0x0200 敌方经济信息

```cpp
#pragma pack(push, 1)
struct enemy_economics {
    uint32_t remaining;
    uint32_t total;
};
#pragma pack(pop)
```

bridge 节点应把这 8 bytes 映射为 `CustomByteBlock.data` 中的 `cmd_id = 0x01` 记录。

### data_cmd_id = 0x0201 敌方剩余发弹量

```cpp
#pragma pack(push, 1)
struct enemy_remaining_bullets {
    int32_t remaining_bullets[5];
    // hero / 3号 / 4号 / 哨兵 / 无人机
};
#pragma pack(pop)
```

bridge 节点应把这 20 bytes 映射为 `CustomByteBlock.data` 中的 `cmd_id = 0x02` 记录。未获取到的弹量填 `-1`。

## 机器人侧打包检查表

1. 从雷达 `0x0301` 信息波获得敌方经济或敌方剩余发弹量。
2. 经济来源建议使用 `data_cmd_id = 0x0200`，写入 `remaining:uint32le` 和 `total:uint32le`。
3. 弹量来源建议使用 `data_cmd_id = 0x0201`，写入 5 个 `int32le`，顺序为英雄、3号步兵、4号步兵、哨兵、无人机。
4. 未获取到的弹量填 `-1`；如果原始弹量值异常，例如大于等于 `60000`，建议清洗为 `-1`。
5. 生成 `CustomByteBlock.data` 记录时，每条记录先写 `cmd_id:uint8`，再写 `active_time:int32le`，最后写对应 `load`。
6. 同一次 `CustomByteBlock.data` 可只发经济记录、只发弹量记录，或拼接两条记录。
7. 将拼接后的 bytes 放入官方 `CustomByteBlock.data`。
8. 通过官方 `0x0310` 机器人到自定义客户端链路发送。

## 前端 mock

开发环境可以用 mock payload 注入：

```js
import('/src/state/enemyAux.js').then(({ buildMockEnemyAuxBridgePayload }) => {
  window.godotPush({
    CustomByteBlock: {
      data: Array.from(buildMockEnemyAuxBridgePayload()),
    },
  });
});
```

预期结果：

- ECO 对方当前经济显示 `423`。
- 累计经济 `3175` 不在 HUD 显示。
- 敌方英雄弹量 `26`。
- 敌方 3 号步兵弹量 `--`。
- 敌方 4 号步兵弹量 `143`。
- 敌方哨兵弹量 `182`。
- 敌方无人机 / 空中机器人弹量 `0`。
