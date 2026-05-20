# TODO
- [x] 上层全局信息绘制
- [x] 中间瞄准信息绘制
- [x] 左下及底部机器人信息绘制
- [ ] 选择交互界面绘制
- [ ] 事件弹窗绘制
- [ ] 小地图绘制
  - 坐标当前按协议侧 `0~1000` 归一化范围映射到 `28m x 15m` 地图显示比例；`MapClickInfoNotify.map_x/map_y` 也按 `0~1000` 输出。
- [ ] 详细buff绘制
- [ ] 裁判系统等debug界面绘制
- [ ] ESC 网络设置后续确认
  - MQTT：ESC 中仅保留 Broker、Port、Client ID，下发到 `/root/Mqtt/Transport` 并重启连接。
  - Video：ESC 中仅保留图传 UDP Port，下发到 `RMVideoCanvas.port`。

# 快速配置(下载插件)

1. 打开GODOT，点击上方资产库
2. 搜索cef，点击第一个插件下载并安装（约500M）至addons文件夹中
3. 安装完毕后即可点击GODOT运行

# 调试配置

1. 需求nodejs版本≥22
2. 进入react-ui文件夹`cd ./react-ui`
3. 下载依赖，`npm install lucide-react`
4. 运行`npm run dev`即可进入http://localhost:5173/ 查看ui

# 需求清单
## getter 类
- GameStatus（5Hz）：同步比赛全局状态，比如当前局号、总局数、红蓝比分、当前阶段、剩余时间、已过时间、是否暂停。
- GlobalUnitStatus（1Hz）：同步基地、前哨站和所有机器人状态，包括基地/前哨站血量、护盾、所有机器人血量、己方累计发弹量、双方累计总伤害。
- GlobalLogisticsStatus（1Hz）：同步全局后勤信息，比如己方当前经济、累计总经济、科技等级、加密等级。
- GlobalSpecialMechanism（1Hz）：同步当前正在生效的全局特殊机制及剩余时间。
- RobotInjuryStat（1Hz）：同步机器人单次存活周期内的累计受伤统计。
- RobotRespawnStatus（1Hz）：同步机器人复活状态。
- RobotStaticStatus（1Hz）：同步机器人静态属性。
- RobotDynamicStatus（10Hz）：同步机器人实时动态状态。
- RobotModuleStatus（1Hz）：同步机器人各模块运行状态。
- RobotPosition（1Hz）：同步机器人位置与朝向。
- Buff（1Hz）：同步增益信息，如回血、冷却、防御、负防御、攻击、剩余能量反馈等。
- RobotPathPlanInfo（1Hz）：同步路径规划结果。
- RadarInfoToClient（1Hz）：同步雷达发给客户端的目标位置信息。
<!-- - CustomByteBlock（50Hz）：机器人自定义上传数据流，对应机器人端 0x0310。 -->
- TechCoreMotionStateSync（1Hz）：同步科技核心运动状态。
- RobotPerformanceSelectionSync（1Hz）：同步步兵/英雄性能体系状态。
- DeployModeStatusSync（1Hz）：同步英雄部署模式状态。
- RuneStatusSync（1Hz）：同步能量机关状态。
- SentryStatusSync（1Hz）：同步哨兵姿态相关信息。
- DartSelectTargetStatusSync（1Hz）：同步飞镖目标选择状态。
- AirSupportStatusSync（1Hz）：同步空中支援状态，比如当前是否支援、剩余免费时间、已花费金币、是否被照射、是否被反制。

## event 类

- Event（触发式发送）：全局事件通知消息。
- PenaltyInfo（触发发送，其余时间 1Hz）：判罚信息同步，用于提示黄牌、红牌、判负等裁判处罚。
- SentryCtrlResult（1Hz）：哨兵控制指令的结果反馈，包含对应指令编号和执行结果码。

## operate 类

- KeyboardMouseControl（5Hz，HUD 默认关闭）：传输鼠标键盘输入，用于把客户端键鼠操作下发给机器人。
<!-- - CustomControl（75Hz）：发送最大 30 字节的自定义控制数据。 -->
<!-- - MapClickInfoNotify（触发式发送）：小地图点击交互指令，用于把地图坐标、按键、目标机器人 ID 等信息发给机器人。 -->
- AssemblyCommand（1Hz）：工程装配指令。<!-- 按键触发（给个标识） -->
- RobotPerformanceSelectionCommand（1Hz）：切换地面机器人性能体系或控制方式。<!-- 点击选择 -->
- CommonCommand（触发式发送，最高 10Hz）：机器人多种常用指令。<!-- 买弹/血可点击，复活的话弹窗点击吧 -->
- HeroDeployModeEventCommand（1Hz）：英雄部署模式相关指令。<!-- 按键触发 -->
- RuneActivateCommand（1Hz）：能量机关激活指令。<!-- 按键激活 -->
- DartCommand（1Hz）：飞镖控制指令。<!-- 点击 -->
- SentryCtrlCommand（1Hz）：哨兵控制指令请求，用于补血点补弹、补给站补弹、远程补弹、远程回血、确认复活、花费金币复活、地图标点、切换进攻/防御/移动姿态等操作。<!-- 点击 -->
- AirSupportCommand（1Hz）：空中支援操作指令，用于免费呼叫空中支援、花费金币呼叫空中支援、或中断空中支援。<!-- 点击 -->


# 交互界面：
操作界面针对：步兵、英雄、哨兵（即不显示其他人的交互界面）
1. 选择性能体系与控制方式（选择完后需要有个确认键进行锁死）
    - 步兵：
        - 底盘性能：血量优先/功率优先
        - 发射性能：爆发优先/冷却优先
    - 英雄
        - 底盘性能：血量优先/功率优先
        - 发射性能：近战优先/远程优先
    - 哨兵
        - 自动/半自动
2. 买弹/血
    - 普通
        - 步兵买弹，10 金币/10 发
        - 英雄买弹，100 金币/100 发
    - 远程买
        - 步兵买弹，15 金币/10 发
        - 英雄买弹，150 金币/100 发
        - 买血 200/次
3. 哨兵only界面
    - 飞镖选择
        - 选择目标 ID（1 为前哨站，2 为基地固定目标，3 为基地随机固定目标，4 为基地随机移动目标，5 为基地末端移动目标）
        - 控制闸门开关（开/关）
        - 确认是否发射
    - 哨兵控制
        -  1: 补血点补弹  2: 补给站实体补弹  3: 远程补弹  4: 远程回血  5: 确认复活  6: 确认花费金币复活  7: 地图标点  8：切换为进攻姿态  9: 切换为防御姿态
    - 飞机控制
        - 免费呼叫空中支援
        - 花费金币呼叫空中支援（仍优先使用免费时长）
        - 中断空中支援
    



# 推送逻辑
- 可参考`rm_synapse/ui/hud.gd`中的`push_payload`函数
- 主要是调用了cef插件中的`web.eval`函数

## 消息发送（MessageCenter）

消息通过 `window.godotPush(...)` 推送到前端，挂在 `messageCenter.items` 下。

示例（JS 对象）：

```js
window.godotPush({
  messageCenter: {
    items: [
      {
        id: 'event-20260314-001',
        tag: 'base-shield-broken',
        level: 'critical',
        text: '基地护盾崩溃，进入高危状态',
        duration: 8000,
        timestamp: 1741939200000
      }
    ]
  }
});
```

字段要求：

- `text`：必填，非空字符串。
- `level`：可选，支持 `critical | important | normal`，缺省按 `normal`。
- `duration`：可选，毫秒，`>0` 时生效，否则使用 `defaultDurationMs`。
- `id`：建议必填，事件唯一标识。
- `timestamp`：建议必填（毫秒时间戳），用于排序与去重。
- `tag`：可选；当同一 `tag` 的消息已经在显示中时，不会新弹窗，而是重置该条消息时长并更新内容。

续时规则说明：

- 想触发同 `tag` 续时时，请发送“新事件”（建议更新 `id` 或 `timestamp`）。
- 若 `id + timestamp` 与已处理事件相同，会被视为重复事件并忽略。
- `items` 推荐只携带“本次新增事件”，不要每帧全量重发历史列表。

## UI 数据统一入口

当前 UI 的默认数据统一维护在：

- `react-ui/src/uiState.js` 的 `DEFAULT_UI_STATE`

约定：

- 新增 UI 字段时，先补充到 `DEFAULT_UI_STATE`，再由后端按需 `godotPush` 局部覆盖。
- 目前消息中心（`messageCenter`）、复活面板（`respawn`）等动态数据都已纳入 `uiState` 统一管理。
