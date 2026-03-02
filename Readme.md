# TODO
- [ ] MQTT 至 UI 的传输，需求详见 [rm_synapse/ui/Readme.md](rm_synapse/ui/Readme.md)


# RMSynapse
RoboMaster 2026 自定义客户端（Godot 4.5 + MQTT/Protobuf + UDP 视频）。

![UI 主界面](rm_synapse/ui/image.png)

## 功能亮点
- Godot 4.5 场景/UI：包含比分、局阶段、全局单位状态、后勤/特殊机制、事件提示、伤害/复活、机器人运行/模块状态、Buff/处罚及远程控制面板，可直接接在 `MqttNet` 输出上。
- 统一网络栈：AutoLoad `MqttNet` 聚合 `GameState`（收包）、`MQTTSender`、`RemoteControlSender`、`LowRateSender`、`TriggerSender`，使用 MQTT 二进制消息 + Protobuf 解码。
- 自定义视频流：C++ GDExtension `RMVideoCanvas` 基于 FFmpeg/UDP/三缓冲，支持 NV12/YUV 转 Shader 渲染或 RGBA 回退，断流自动占位并发 `stream_state_changed`。
- 上行策略：高频 75 Hz RemoteControl 最新值、低频定时命令（守卫、符文、装配、性能选择、空中支援、飞镖）与触发式地图点击，QoS1 ACK/重试可选。
- 协议与生成：`protocol/rm_custom.proto` 对齐 2026 自定义客户端协议，使用内置 Godobuf 插件生成 `protocol/generated/rm_proto.gd`。

## 目录速览
- `rm_synapse/`：Godot 工程；`net/` 网络脚本，`ui/` 主界面，`bin/` GDExtension 输出，`protocol/` 协议。
- `plugins/rm_video_decoder/`：UDP→FFmpeg 解码 GDExtension 源码（SCons 构建）与 CMake 测试。
- `plugins/rm_common/`：无依赖日志工具（供 C++/Godot 共用）。
- `plugins/godobuf/`、`godot-cpp/`：上游子模块（分别为 Protobuf 生成器、GDExtension SDK）。
- `references/`：RoboMaster 2026 规则/通信协议 PDF。
- `build/`：示例 CMake 构建产物；`rm_synapse/Export/` 为已导出的可执行/脚本。

## 快速开始（直接运行）
1) 准备：安装 Godot 4.5.x；有可访问的 MQTT Broker 以及机器人/裁判系统视频流（默认 H.265 UDP 端口 3334）。  
2) 获取源码：`git clone <repo_url> && cd RMSynapse && git submodule update --init --recursive`。  
3) 配置网络：在 `rm_synapse/net/mqtt_net.tscn` 里设置 `GameState.broker_url`（格式 `tcp://IP:3333`）及账号；如需改 MQTT 自动加载，检查 `Project Settings -> AutoLoad` 中 `MQTT` 与 `MqttNet` 已启用。  
4) 配置视频：在场景中选中 `RMVideoCanvas`（默认主场景 `test_video.tscn`），调整 `port` 与 `display_mode`；端口需与机器人视频推流一致。  
5) 运行：`godot4 --path rm_synapse` 直接播放主场景；界面自动订阅 MQTT、显示数据并抓取鼠标/键盘发送 RemoteControl（要禁用自动抓取可将 `RemoteControlCore.auto_capture_input` 置 false）。  
6) 可选：使用导出产物 `rm_synapse/Export/v1.sh`（Linux x86_64）快速启动，需确保同目录下的 `librm_video_decoder.so` 等文件完整。

## 构建 / 更新 GDExtension
- 依赖（Ubuntu 举例）：
```bash
sudo apt update
sudo apt install build-essential scons pkg-config libavcodec-dev libavutil-dev libswscale-dev \
                 libopencv-dev cmake # OpenCV 仅用于 test_video_show
```
- 重新编译视频解码插件：
```bash
cd plugins/rm_video_decoder
scons platform=linux target=template_release  # 或 template_debug
# 成品位于 rm_synapse/bin/librm_video_decoder.* 和 video_yuv.gdshader
```
- 构建独立测试程序（UDP→FFmpeg→OpenCV 预览）：
```bash
cmake -S plugins/rm_video_decoder -B build
cmake --build build
./build/test_video_show   # 端口默认 3334，可在源码中修改
```
- 其他平台：将 `platform=windows|macos|android`，若交叉编译需先让 `godot-cpp` 获取对应头/模板。构建后确保产物放入 `rm_synapse/bin/` 并与 `rm_video_decoder.gdextension` 指向的文件名一致。

## 网络与协议速览
- 下行订阅（`MQTTGameState.subscribe_topics` 默认）：`GameStatus`、`GlobalUnitStatus`、`GlobalLogisticsStatus`、`GlobalSpecialMechanism`、`Event`、`RobotInjuryStat`、`RobotRespawnStatus`、`RobotStaticStatus`、`RobotDynamicStatus`、`RobotModuleStatus`、`RobotPosition`、`Buff`、`PenaltyInfo`、`RobotPathPlanInfo`、`RaderInfoToClient`、`RobotPerformanceSelectionSync`、`DeployModeStatusSync`、`TechCoreMotionStateSync`、`RuneStatusSync`、`SentinelStatusSync`、`DartSelectTargetStatusSync`、`GuardCtrlResult`、`AirSupportStatusSync`、`CustomByteBlock`。解码成功的消息会写入状态字典并逐类触发 `*_updated` 信号。  
- 上行：
  - 高频：`RemoteControl`（75 Hz，latest-only，鼠标/键盘/自定义 ≤30 bytes）。
  - 低频：`GuardCtrlCommand`、`HeroDeployModeEventCommand`、`RuneActivateCommand`、`RobotPerformanceSelectionCommand`、`AssemblyCommand`、`AirSupportCommand`、`DartCommand`，默认 1 Hz 轮询，可配置。
  - 触发：`MapClickInfoNotify`，支持冷却与断线缓冲。
- 数据流设计：网络线程只读写线程安全队列，主线程在 `_process` 中批量落地并发信号；发送端 ACK/超时重试、断线可选择丢弃高频包（详见 `rm_synapse/net/data_flow.md` 与 `rm_synapse/net/Readme.md`）。

## 视频流协议与 RMVideoCanvas
- UDP 包头（8 bytes）：`frame_seq:uint16`，`fragment_seq:uint16`，`total_size:uint32`（通常网络字节序）；同帧多分片乱序容忍，16 MB 安全上限。  
- 解码：FFmpeg HEVC 默认，可根据推流选择编译期改 codec；三缓冲避免渲染线程争用。  
- 输出：优先 NV12→自带 Shader（`res://bin/video_yuv.gdshader`），不支持则回退 RGBA；无帧 `no_frame_timeout_sec` 后显示占位纹理。  
- 属性（Inspector）：`port`、`use_bt601`、`use_tv_range`、`force_rgba`、`no_frame_timeout_sec`、`placeholder_texture`、`display_mode(adaptive/stretch/original)`；信号 `stream_state_changed(bool is_streaming)` 可用于 UI 提示。

## UI 模块
- 主界面位于 `rm_synapse/ui/main_game_interface/`，主要子场景：  
  - `global_game_state.tscn`（比分、阶段计时），`global_unit_state.tscn`（双方单位/前哨/基地血量）。  
  - `global_logistics_status.tscn`、`global_special_mechanism.tscn`、`game_event.tscn`。  
  - `robot_status.tscn`、`robot_running.tscn`（能量/热量/射频等）、`robot_module_status.tscn`、`robot_injury_display.tscn`、`robot_respawn.tscn`、`buff_status.tscn`、`penalty_info.tscn`。  
  - `remote_control_core.tscn`（输入捕获/提示），`net_status_panel.tscn`（MQTT/UDP 状态指示）。  
- 默认主场景 `test_video.tscn` 将上述面板与 `RMVideoCanvas` 拼成一屏，便于联调。

## Protobuf 工具链
- 协议定义：`rm_synapse/protocol/rm_custom.proto`（RoboMaster 2026 自定义客户端章节）。  
- 重新生成 GDScript（需 Godot 4）：  
```bash
cd rm_synapse
godot4 --headless -s addons/protobuf/protobuf_cmdln.gd \
       --input=protocol/rm_custom.proto \
       --output=protocol/generated/rm_proto.gd
```
- Godobuf UI 版也位于 `addons/protobuf/`，勾选插件后可在编辑器侧栏编译。

## 致谢
- 视频解码依赖 FFmpeg；GDExtension 使用 `godot-cpp` 4.5。  
- MQTT 插件基于 goatchurchprime/godot-mqtt；Protobuf 生成器基于 oniksan/godobuf；C++/Godot 日志共用 `rm_common`。
