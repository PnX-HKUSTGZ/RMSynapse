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
- RobotDynamicStatus（5Hz）：同步机器人实时动态状态。
- RobotModuleStatus（5Hz）：同步机器人各模块运行状态。
- RobotPosition（5Hz）：同步机器人位置与朝向。
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

- Event（1Hz）：全局事件通知消息。
- PenaltyInfo（触发发送，其余时间 1Hz）：判罚信息同步，用于提示黄牌、红牌、判负等裁判处罚。
- SentryCtrlResult（1Hz）：哨兵控制指令的结果反馈，包含对应指令编号和执行结果码。

## operate 类

- KeyboardMouseControl（75Hz）：传输鼠标键盘输入，用于把客户端键鼠操作下发给机器人。
<!-- - CustomControl（75Hz）：发送最大 30 字节的自定义控制数据。 -->
<!-- - MapClickInfoNotify（触发式发送）：小地图点击交互指令，用于把地图坐标、按键、目标机器人 ID 等信息发给机器人。 -->
- AssemblyCommand（1Hz）：工程装配指令。
- RobotPerformanceSelectionCommand（1Hz）：切换地面机器人性能体系或控制方式。
- CommonCommand（触发式发送，最高 10Hz）：机器人多种常用指令。
- HeroDeployModeEventCommand（1Hz）：英雄部署模式相关指令。
- RuneActivateCommand（1Hz）：能量机关激活指令。
- DartCommand（1Hz）：飞镖控制指令。
- SentryCtrlCommand（1Hz）：哨兵控制指令请求，用于补血点补弹、补给站补弹、远程补弹、远程回血、确认复活、花费金币复活、地图标点、切换进攻/防御/移动姿态等操作。
- AirSupportCommand（1Hz）：空中支援操作指令，用于免费呼叫空中支援、花费金币呼叫空中支援、或中断空中支援。

# 推送逻辑
- 可参考`rm_synapse/ui/hud.gd`中的`push_payload`函数
- 主要是调用了cef插件中的`web.eval`函数