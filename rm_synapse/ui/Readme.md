
## 1. 控制类 (Control)
**用途**：客户端向机器人发送操控指令，或向服务器发送控制请求。
### 1.1 `KeyboardMouseControl` (2.2.1)
- **方向**：客户端 -> 机器人 (图传链路)
- **频率**：75Hz
- **用途**：传输键鼠操作。
- **字段详情**：
    - `1: mouse_x` (int32): 鼠标 X 轴移动速度（负左正右）
    - `2: mouse_y` (int32): 鼠标 Y 轴移动速度（负下正上）
    - `3: mouse_z` (int32): 鼠标滚轮速度（负后正前）
    - `4: left_button_down` (bool): 左键按下
    - `5: right_button_down` (bool): 右键按下
    - `6: keyboard_value` (uint32): 键盘按键位掩码（0=未按，1=按下）
        - Bit 0-3: W, S, A, D
        - Bit 4-7: Shift, Ctrl, Q, E
        - Bit 8-11: R, F, G, Z
        - Bit 12-15: X, C, V, B
    - `7: mid_button_down` (bool): 中键按下
### 1.2 `CommonCommand` (2.2.24) [V1.2.0 新增]
- **方向**：客户端 -> 服务器
- **频率**：触发式 (上限 10Hz)
- **用途**：发送机器人常用指令。
- **字段详情**：
    - `1: cmd_type` (uint32): 命令类型
    - `2: param` (uint32): 参数
- **枚举 (`cmd_type`)**：
    1. **兑换 17mm 发弹量**（`param` 必须为 10 的倍数）
    2. **兑换 42mm 发弹量**
    3. **确认复活**（若读条完成则立即复活）
    4. **兑换立即复活**（消耗金币）
    5. **远程兑换允许发弹量**
    6. **远程兑换血量**
### 1.3 `CustomControl` (2.2.2)
- **方向**：客户端 -> 机器人 (图传链路)
- **频率**：75Hz
- **字段详情**：
    - `1: data` (bytes): 最大 30 字节的自定义数据（透传给机器人 0x0311）。
### 1.4 `RobotPerformanceSelectionCommand` (2.2.22)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **用途**：选择性能体系或控制方式。
- **字段详情**：
    - `1: shooter` (uint32): 发射机构性能（1=冷却优先, 2=爆发优先, 3=英雄近战, 4=英雄远程）
    - `2: chassis` (uint32): 底盘性能（1=血量优先, 2=功率优先, 3=英雄近战, 4=英雄远程）
    - `3: sentry_control` (uint32): 哨兵控制方式（0=自动, 1=半自动）
### 1.5 `SentryCtrlCommand` (2.2.32)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **用途**：请求哨兵执行特定动作。
- **字段详情**：
    - `1: command_id` (uint32): 指令编号
- **枚举 (`command_id`)**：
    - `1`: 补血点补弹
    - `2`: 补给站实体补弹
    - `3`: 远程补弹
    - `4`: 远程回血
    - `5`: 确认复活
    - `6`: 确认金币复活
    - `7`: 地图标点
    - `8`: 进攻姿态
    - `9`: 防御姿态
    - `10`: 移动姿态
### 1.6 `HeroDeployModeEventCommand` (2.2.25)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **字段详情**：
    - `1: mode` (uint32): 0=退出部署, 1=进入部署。
### 1.7 `AirSupportCommand` (2.2.34)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **字段详情**：
    - `1: command_id` (uint32): 1=免费呼叫, 2=金币呼叫, 3=中断支援。
### 1.8 `DartCommand` (2.2.30)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **字段详情**：
    - `1: target_id` (uint32): 1=前哨站, 2=基地固定, 3=基地随机固定, 4=基地随机移动, 5=基地末端移动
    - `2: open` (bool): 闸门开关
    - `3: launch_confirm` (bool): 确认发射 (1=确认)
### 1.9 `AssemblyCommand` (2.2.20)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **字段详情**：
    - `1: operation` (uint32): 1=确认装配, 2=取消装配
    - `2: difficulty` (uint32): 选中的装配难度等级
### 1.10 `RuneActivateCommand` (2.2.27)
- **方向**：客户端 -> 服务器
- **频率**：1Hz
- **字段详情**：
    - `1: activate` (uint32): 1=开启激活。
## 2. 比赛全局类 (Game Global)
**用途**：同步比赛整体状态、单位存活情况及经济信息。
### 2.1 `GameStatus` (2.2.3)
- **方向**：服务器 -> 客户端
- **频率**：5Hz
- **字段详情**：
    - `1: current_round` (uint32): 当前局号
    - `2: total_rounds` (uint32): 总局数
    - `3: red_score` (uint32): 红方得分
    - `4: blue_score` (uint32): 蓝方得分
    - `5: current_stage` (uint32): 0=未开始, 1=准备, 2=自检, 3=倒计时, 4=比赛中, 5=结算
    - `6: stage_countdown_sec` (int32): 阶段剩余时间(秒)
    - `7: stage_elapsed_sec` (int32): 阶段已过时间
    - `8: is_paused` (bool): 是否暂停
### 2.2 `GlobalUnitStatus` (2.2.4)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **用途**：全场建筑和机器人的核心状态。
- **字段详情**：
    - `1: base_health` (uint32): 己方基地血量
    - `2: base_status` (uint32): 0=无敌, 1=无敌解除+护甲未开, 2=无敌解除+护甲展开
    - `3: base_shield` (uint32): 己方基地护盾值
    - `4: outpost_health` (uint32): 己方前哨站血量
    - `5: outpost_status` (uint32): 0=无敌, 1=存活+旋转, 2=存活+停转, 3=击毁(不可建), 4=击毁(可建), 5=重建中
    - `6-10`: 对方基地/前哨站信息（同上）
    - `11: robot_health` (repeated uint32): 所有机器人血量（先己方后对方）
    - `12: robot_bullets` (repeated int32): 己方机器人剩余累计发弹量
    - `13: total_damage_ally` (uint32): 己方累计总伤害
    - `14: total_damage_enemy` (uint32): 对方累计总伤害
### 2.3 `GlobalLogisticsStatus` (2.2.5)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: remaining_economy` (uint32): 己方当前金币
    - `2: total_economy_obtained` (uint64): 己方累计获取金币
    - `3: tech_level` (uint32): 己方科技等级
    - `4: encryption_level` (uint32): 己方加密等级（雷达）
### 2.4 `Event` (2.2.7)
- **方向**：服务器 -> 客户端
- **频率**：触发式
- **字段详情**：
    - `1: event_id` (int32): 事件编号
    - `2: param` (string): 事件参数
- **事件列表 (`event_id`)**：
    - `1`: 击杀 (参数: 击杀者ID+被击毁ID)
    - `2`: 基地/前哨被毁 (参数: 被毁目标ID)
    - `3`: 能量机关可激活次数变化
    - `4`: 能量机关可进入激活状态
    - `5`: 能量机关激活成功 (参数: 臂数+平均环数)
    - `6`: 能量机关被激活（含类型）
    - `7`: 己方英雄进入部署
    - `8`: 己方英雄造成狙击伤害 (参数: 累计伤害)
    - `9`: 对方英雄造成狙击伤害
    - `10`: 己方呼叫空中支援
    - `11`: 己方空中支援被打断 (参数: 对方剩余打断次数)
    - `12`: 对方呼叫空中支援
    - `13`: 对方空中支援被打断
    - `14`: 飞镖命中 (参数: 目标ID 1-5)
    - `15`: 飞镖闸门开启 (参数: 1=己方, 2=对方)
    - `16`: 己方基地受袭 (5s 冷却)
    - `17`: 前哨站停转 (参数: 1=己方, 2=对方)
    - `18`: 基地护甲展开 (参数: 1=己方, 2=对方)
## 3. 机器人状态类 (Robot Status)
**用途**：同步本机器人的详细状态。
### 3.1 `RobotDynamicStatus` (2.2.11)
- **方向**：服务器 -> 客户端
- **频率**：10Hz
- **字段详情**：
    - `1: current_health` (uint32): 当前血量
    - `2: current_heat` (float): 当前热量
    - `3: last_projectile_fire_rate` (float): 上次射速
    - `4: current_chassis_energy` (uint32): 底盘能量
    - `5: current_buffer_energy` (uint32): 缓冲能量
    - `6: current_experience` (uint32): 当前经验
    - `7: experience_for_upgrade` (uint32): 升级所需经验
    - `8: total_projectiles_fired` (uint32): 累计发弹量
    - `9: remaining_ammo` (uint32): 剩余允许发弹量
    - `10: is_out_of_combat` (bool): 是否脱战
    - `11: out_of_combat_countdown` (uint32): 脱战倒计时
    - `12: can_remote_heal` (bool): 可否远程补血
    - `13: can_remote_ammo` (bool): 可否远程补弹
### 3.2 `RobotStaticStatus` (2.2.10)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: connection_state` (uint32): 0=未连, 1=连接
    - `2: field_state` (uint32): 0=上场, 1=未上场
    - `3: alive_state` (uint32): 0=未知, 1=存活, 2=战亡
    - `4: robot_id` (uint32): 机器人 ID
    - `5: robot_type` (uint32): 机器人类型
    - `6: performance_system_shooter` (uint32): 1=冷却优先, 2=爆发优先, 3=英雄近战, 4=英雄远程
    - `7: performance_system_chassis` (uint32): 1=血量优先, 2=功率优先, 3=英雄近战, 4=英雄远程
    - `8: level` (uint32): 当前等级
    - `9-14`: 最大血量/热量/热量冷却/功率/缓冲/底盘能量 (数值)
### 3.3 `RobotModuleStatus` (2.2.12)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **状态值**：0=离线, 1=在线, 2=异常
- **字段详情**：
    - `1: power_manager`: 电源管理模块
    - `2: rfid`: RFID 模块
    - `3: light_strip`: 灯条模块
    - `4: small_shooter`: 17mm 发射机构
    - `5: big_shooter`: 42mm 发射机构
    - `6: uwb`: 定位模块
    - `7: armor`: 装甲模块
    - `8: video_transmission`: 图传模块
    - `9: capacitor`: 电容模块
    - `10: main_controller`: 主控
    - `11: laser_detection_module`: 激光检测模块
### 3.4 `RobotPosition` (2.2.13)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: x` (float): 世界坐标 X
    - `2: y` (float): 世界坐标 Y
    - `3: z` (float): 世界坐标 Z
    - `4: yaw` (float): 测速模块朝向 (度, 正北为0)
### 3.5 `RobotInjuryStat` (2.2.8)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **用途**：统计本条命期间受到的伤害。
- **字段详情**：
    - `1: total_damage` (uint32): 总伤害
    - `2-9`: 分项伤害 (撞击/17mm/42mm/飞镖溅射/模块离线/异常离线/判罚/强制战亡)
    - `10: killer_id` (uint32): 击杀者 ID
### 3.6 `RobotRespawnStatus` (2.2.9)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: is_pending_respawn` (bool): 待复活状态
    - `2: total_respawn_progress` (uint32): 总读条
    - `3: current_respawn_progress` (uint32): 当前进度
    - `4: can_free_respawn` (bool): 可免费复活
    - `5: gold_cost_for_respawn` (uint32): 复活所需金币
    - `6: can_pay_for_respawn` (bool): 可付费复活
### 3.7 `DeployModeStatusSync` (2.2.26)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: status` (uint32): 0=未部署, 1=已部署
### 3.8 `RobotPerformanceSelectionSync` (2.2.23)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: shooter` (uint32): 发射性能体系
    - `2: chassis` (uint32): 底盘性能体系
    - `3: sentry_control` (uint32): 哨兵控制方式
## 4. 增益/判罚/战术类 (Buff/Penalty/Tactics)
### 4.1 `Buff` (2.2.14)
- **方向**：服务器 -> 客户端
- **频率**：触发后 1Hz
- **字段详情**：
    - `1: robot_id` (uint32): 获得 Buff 的机器人 ID
    - `2: buff_type` (uint32): Buff 类型
    - `3: buff_level` (int32): 增益值
    - `4: buff_max_time` (uint32): 最大剩余时间
    - `5: buff_left_time` (uint32): 当前剩余时间
- **类型枚举 (`buff_type`)**： 1: 攻击, 2: 防御, 3: 冷却, 4: 功率, 5: 回血, 6: 可兑换发弹量, 7: 地形跨越预备
### 4.2 `PenaltyInfo` (2.2.15)
- **方向**：服务器 -> 客户端
- **频率**：触发式
- **字段详情**：
    - `1: penalty_type` (uint32): 1=黄牌, 2=双方黄牌, 3=红牌, 4=超功率, 5=超热量, 6=超射速
    - `2: penalty_effect_sec` (uint32): 受罚时长
    - `3: total_penalty_num` (uint32): 判罚数量
### 4.3 `GlobalSpecialMechanism` (2.2.6)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: mechanism_id` (repeated uint32): 1=己方堡垒被占领计时, 2=对方堡垒被占领计时
    - `2: mechanism_time_sec` (repeated int32): 对应时间参数
### 4.4 `AirSupportStatusSync` (2.2.35)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: airsupport_status` (uint32): 0=未支援, 1=正在支援
    - `2: left_time` (uint32): 免费剩余时间
    - `3: cost_coins` (uint32): 已花费金币
    - `4: is_being_targeted` (uint32): 激光是否检测到被照射 (1=是)
    - `5: shooter_status` (uint32): 0=被雷达反制锁定, 1=正常
## 5. 地图/雷达/交互类 (Map/Radar/Interaction)
### 5.1 `MapClickInfoNotify` (2.2.17)
- **方向**：客户端 -> 服务器
- **频率**：触发式 (同 0x0303)
- **字段详情**：
    - `1: is_send_all` (uint32): 0=指定客户端, 1=除哨兵, 2=包含哨兵
    - `2: robot_id` (bytes): 目标机器人 ID 列表 (固定 7 字节)
    - `3: type` (uint32): 标记类型 (1=攻击, 2=防御, 3=警戒, 4=自定义)
    - `4: enemy_id` (uint32): 标定的对方 ID
    - `5: ascii` (uint32): 自定义图标 ASCII 码
    - `6: mode` (uint32): 标记模式 (1=地图坐标, 2=对方机器人)
    - `7-8`: 屏幕坐标 X/Y (像素)
    - `9-10`: 地图坐标 X/Y (米)
### 5.2 `RadarInfoToClient` (2.2.18)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **用途**：雷达站发送给选手的“小地图作弊”信息。
- **字段详情**：
    - `1: target_robot_id` (uint32): 目标 ID
    - `2: target_pos_x` (float): X (米)
    - `3: target_pos_y` (float): Y (米)
    - `4: torward_angle` (float): 朝向
    - `5: is_high_light` (uint32): 特殊标识 (0=无, 1=被标记进度<100, 2=被标记进度>=100但无定位)
### 5.3 `RobotPathPlanInfo` (2.2.16)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **用途**：哨兵路径规划可视化。
- **字段详情**：
    - `1: intention` (uint32): 1=攻击, 2=防守, 3=移动
    - `2: start_pos_x` (uint32): 起点 X (分米)
    - `3: start_pos_y` (uint32): 起点 Y (分米)
    - `4: offset_x` (repeated int32): X 增量数组
    - `5: offset_y` (repeated int32): Y 增量数组
    - `6: sender_id` (uint32): 发送者 ID
### 5.4 `CustomByteBlock` (2.2.19)
- **方向**：机器人 -> 客户端 (图传链路)
- **频率**：50Hz
- **字段详情**：
    - `1: data` (bytes): 自定义数据包 (最大 2.4kbit)
### 5.5 `SentryCtrlResult` (2.2.33)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: command_id` (uint32): 指令编号
    - `2: result_code` (uint32): 0=成功, 其他=失败
## 6. 拓展/高级机制类 (Extended/Advanced Mechanisms)
### 6.1 `TechCoreMotionStateSync` (2.2.21)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **用途**：工程机器人科技核心状态。
- **字段详情**：
    - `1: maximum_difficulty_level` (uint32): 可选最高装配难度
    - `2: status` (uint32): 状态枚举
        - 1: 未装配
        - 2: 已选难度，移动中
        - 3: 移动完成，可做首步
        - 4: 上一步完成，可做下一步
        - 5: 全部完成
        - 6: 已确认装配，移动中
    - `3: enemy_core_status` (uint32): 对方核心状态 (0=无, 1=非4级, 2=4级)
    - `4: remain_time_all` (uint32): 总剩余时间
    - `5: remain_time_step` (uint32): 单步剩余时间
### 6.2 `RuneStatusSync` (2.2.28)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: rune_status` (uint32): 1=未激活, 2=正在激活, 3=已激活
    - `2: activated_arms` (uint32): 已激活臂数
    - `3: average_rings` (uint32): 平均环数
### 6.3 `DartSelectTargetStatusSync` (2.2.31)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: target_id` (uint32): 目标 ID
    - `2: open` (uint32): 闸门状态 (0=关, 1=开启中, 2=已开)
### 6.4 `SentryStatusSync` (2.2.29)
- **方向**：服务器 -> 客户端
- **频率**：1Hz
- **字段详情**：
    - `1: posture_id` (uint32): 1=进攻, 2=防御, 3=移动
    - `2: is_weakened` (bool): 是否弱化

---
# 布局设计
## 1. 中央瞄准区
- RobotDynamicStatus：（英雄/步兵）
	- 当前热量、剩余允许发弹量
	- *debug* 上次射速
- Buff：获得 buff（攻击/防御only）
- DeployModeStatusSync：部署状态 (英雄only)
- RuneStatusSync：（步兵only）
	- 能量机关激活（只在激活时显示）
	- 状态（显示目前激活灯臂数量及总环数）
- TechCoreMotionStateSync：（工程only）
	- 工程机器人科技核心状态
## 2. 底部状态栏
### A. 主要信息
- RobotDynamicStatus：
	- 血量，底盘/缓冲能量
	- 脱战/倒计时，可否远程补血/补弹
### B. 次要信息
- KeyboardMouseControl：显示主要按键情况，*debug用*
- RobotDynamicStatus：
	- 经验/升级所需经验，累计发弹量
- RobotPerformanceSelectionSync
	- 底盘、机构类型
- RobotStaticStatus：
	- 连接/上场情况，机器人类型/ID
	- 底盘、机构类型，等级
	- 最大血量/缓冲/功率等
	- 最大热量、热量冷却
- RobotModuleStatus：
	- RFID 识别
	- 发射机构
	- 图传
## 3. 顶部全局栏
- GameStatus：比赛进程
- GlobalUnitStatus：*双方*
	- 基地、前哨站、兵种血量
	- 前哨站、基地状态
	- 总发弹量、累计伤害
- GlobalLogisticsStatus：*己方*经济等级、情况、雷达加密等级
## 4. 右下地图 buff
### A. 地图
全局信息（决策用）
- AirSupportStatusSync：是否正在支援，剩余时长
- SentryStatusSync：哨兵状态
- DartSelectTargetStatusSync：飞镖目标及状态
地图信息
- RobotPathPlanInfo：哨兵路径
- MapClickInfoNotify：地图相关
- RadarInfoToClient：雷达地图相关
- RobotPosition：机器人所在位置
### B. BUFF
- Buff：
	- 获得buff，持续时间
## 5. 弹窗/消息类
## A. 决策弹窗
>  按下热键后弹出选择窗口 (可呼出)
### 局初
- RobotPerformanceSelectionCommand：选择发射机构、底盘性能和哨兵控制
### 局中
云台手
- SentryCtrlCommand：控制哨兵相关
- AirSupportCommand：呼叫空中支援
- DartCommand：飞镖目标选择
操作手
- CommonCommand：兑换发弹量、远程兑换发胆量、远程兑换血量
- HeroDeployModeEventCommand：进入部署模式（英雄only）
- AssemblyCommand：装配确认及难度选择（工程only）
- RuneActivateCommand：激活能量机关（步兵only）
### 调试
- RobotModuleStatus：各模块信息
## B. 消息弹窗
>  满足特定情况后弹出窗口
### 全局消息
- GlobalSpecialMechanism：堡垒占领情况
- Event：一堆
### 个人消息
需确认
- CommonCommand：死亡后兑换复活，复活读秒完毕确认复活
无需确认
- RobotModuleStatus：模块异常/离线
- RobotInjuryStat：死亡后弹出，受伤统计
- RobotRespawnStatus：复活进度
- PenaltyInfo：判罚情况
- SentryCtrlResult：哨兵控制反馈
