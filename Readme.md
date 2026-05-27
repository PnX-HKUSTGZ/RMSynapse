# TODO
- [x] 主 UI MQTT 接收/发送桥接：下行状态经 `HudDataBridge -> hud.gd -> window.godotPush` 进入 React，上行操作经 `emitGodotOperation -> HudOperationBridge` 发送到 MQTT command services。
- [ ] 主 UI 还未提供 `KeyboardMouseControl`、`CustomControl`、`MapClickCmd` 的前端交互入口；底层 `ProtocolAdapter` 已有发送 API，但当前 React 主 UI 没有对应控件或输入捕获逻辑。


# RMSynapse
RoboMaster 2026 自定义客户端（Godot 4.5 + MQTT/Protobuf + UDP 视频）。

![UI 主界面](rm_synapse/ui/image.png)

## 功能亮点
- Godot 4.5 场景/UI：包含比分、局阶段、全局单位状态、后勤/特殊机制、事件提示、伤害/复活、机器人运行/模块状态、Buff/处罚及远程控制面板，可直接接在 `/root/Mqtt/Adapter` 输出上。
- 统一网络栈：AutoLoad `Mqtt` 聚合 `Adapter`、`Transport`、`ClientSetter`，使用 MQTT 二进制消息 + Protobuf 解码。
- 自定义视频流：C++ GDExtension `RMVideoCanvas` 从 `rm_synapse/addons/rm_video_decoder/` 加载，负责 UDP H.265 分片重组、FFmpeg 解码和 Godot 画布显示。
- 上行策略：通过 `ProtocolAdapter` 发送键鼠、自定义控制、地图点击、买血/买弹/复活、部署、符文、装配、性能选择、空中支援、飞镖等命令。
- 协议与生成：`rm_synapse/net/mqtt/proto/rm_custom.proto` 对齐 2026 自定义客户端协议，使用内置 Godobuf 插件生成 `rm_synapse/net/mqtt/proto/generated/rm_custom_pb.gd`。

## 目录速览
- `rm_synapse/`：Godot 工程；`net/mqtt/` 网络脚本，`ui/` 主界面，`bin/` GDExtension 输出，`net/mqtt/proto/` 协议。
- `plugins/rm_video_decoder/`：UDP→FFmpeg 解码 GDExtension 源码（SCons 构建）与 CMake 测试。
- `plugins/rm_common/`：无依赖日志工具（供 C++/Godot 共用）。
- `plugins/godobuf/`、`godot-cpp/`：上游子模块（分别为 Protobuf 生成器、GDExtension SDK）。
- `references/`：RoboMaster 2026 规则/通信协议 PDF。
- `build/`：示例 CMake 构建产物；`rm_synapse/Export/` 为已导出的可执行/脚本。

## 快速开始（直接运行）
1) 准备：安装 Godot 4.5.x；有可访问的 MQTT Broker 以及机器人/裁判系统视频流（默认 H.265 UDP 端口 3334）。  
2) 获取源码：`git clone <repo_url> && cd RMSynapse && git submodule update --init --recursive`。  
3) 配置网络：在 ESC 设置中配置 MQTT Broker、Port、ClientID；默认场景也可在 `rm_synapse/net/mqtt/mqtt.tscn` 里调整 `Transport.broker_url`。  
4) 配置视频：在 ESC 设置中配置图传端口；默认 UDP 图传端口为 `3334`，视频插件随 `rm_synapse/addons/rm_video_decoder/` 一起分发。  
5) 运行：`godot4 --path rm_synapse` 直接播放主场景；界面自动订阅 MQTT、显示数据并按当前设置发送交互命令。  
6) 可选：使用导出产物 `rm_synapse/Export/linux/`、`rm_synapse/Export/windows/`、`rm_synapse/Export/macos/` 中对应平台文件启动。

## 编译与分发
本项目的发布包由三部分组成：React HUD 静态资源、Godot 工程导出、`rm_video_decoder` C++ GDExtension。正式分发前建议在目标平台或兼容 sysroot 中完成一次构建，因为 Godot CEF、FFmpeg、glibc 与动态库加载路径都和平台/架构强相关。

### 通用准备
1) 拉取源码、LFS 大文件和子模块：
```bash
git clone <repo_url> RMSynapse
cd RMSynapse
git lfs pull
git submodule update --init --recursive
```
`rm_synapse/addons/godot_cef/**` 使用 Git LFS 管理；如果没有执行 `git lfs pull`，CEF 运行库会只是 pointer 文件，Godot 导出后无法加载 HUD WebView。

2) 安装工具链：
- Godot 4.5.x，并在编辑器中安装对应平台的 Export Templates。
- Node.js 20+ 与 npm，用于构建 `react-ui`。
- Python 3、SCons、CMake；如果需要视频插件，还要安装 FFmpeg 开发库。

3) 构建并同步 React HUD：
```bash
cd react-ui
npm ci
npm run build
```
Linux/macOS 可直接执行同步脚本：
```bash
./ui.sh
```
Windows PowerShell 使用等价命令：
```powershell
cd react-ui
npm ci
npm run build
Remove-Item -Recurse -Force ..\rm_synapse\ui\web -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force ..\rm_synapse\ui\web | Out-Null
Copy-Item -Recurse .\dist\* ..\rm_synapse\ui\web\
```
导出预设的 `include_filter` 已包含 `ui/web/**`，因此需要先同步这一步，再做 Godot 导出。

### 一键脚本
仓库在 `scripts/` 下提供了三平台构建脚本。默认会构建 React HUD、同步 `rm_synapse/ui/web/`，并编译当前平台的视频 GDExtension；需要 Godot 导出时额外加 `--export` 或 `-Export`。

Linux：
```bash
scripts/build_linux.sh
scripts/build_linux.sh --export
scripts/build_linux.sh --skip-video --export
```

macOS：
```bash
scripts/build_macos.sh --arch arm64
scripts/build_macos.sh --arch x86_64 --export
scripts/build_macos.sh --arch universal --export --copy-ffmpeg yes --ffmpeg-runtime /path/to/ffmpeg/lib
```

Windows PowerShell：
```powershell
.\scripts\build_windows.ps1 -Toolchain msvc -FfmpegRoot "$env:VCPKG_ROOT\installed\x64-windows"
.\scripts\build_windows.ps1 -Toolchain mingw -FfmpegRoot "$env:VCPKG_ROOT\installed\x64-mingw-dynamic"
.\scripts\build_windows.ps1 -SkipVideo -Export -GodotBin "D:\Users\18384\Desktop\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64_console.exe"
```

常用选项：
- Linux/macOS：`--debug`、`--arch <arch>`、`--skip-ui`、`--skip-video`、`--export`、`--godot <path>`、`--lfs-pull`、`--ffmpeg-root <path>`、`--ffmpeg-runtime <path>`。
- Windows：`-Debug`、`-Arch <arch>`、`-SkipUi`、`-SkipVideo`、`-Export`、`-GodotBin <path>`、`-LfsPull`、`-FfmpegRoot <path>`、`-FfmpegRuntimeDir <path>`。

当前维护者常用分发命令：
```powershell
# Windows x86_64，使用本仓库 build/thirdparty 下的 FFmpeg shared 包。
.\scripts\build_windows.ps1 `
  -Toolchain mingw `
  -GodotBin "D:\Users\18384\Desktop\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64_console.exe" `
  -FfmpegRoot (Resolve-Path "build\thirdparty\ffmpeg-n7.1-win64-gpl-shared").Path `
  -CopyFfmpegRuntime yes `
  -NoNpmCi `
  -Export

tar -czf rm_synapse/Export/windows.tar.gz -C rm_synapse/Export/windows .
```

```bash
# Ubuntu 22.04 x86_64。必须在 Ubuntu 22.04 或更老兼容 sysroot 中构建插件，
# 不要直接在 Ubuntu 24.04 主机上编译，否则可能引入 GLIBC_2.38+ 依赖。
scripts/build_linux.sh --export --static-ffmpeg --no-npm-ci
tar -czf rm_synapse/Export/linux.tar.gz -C rm_synapse/Export/linux .
```

### 编译视频 GDExtension
视频插件源码位于 `plugins/rm_video_decoder/`，SCons 构建完成后会把插件、`.gdextension` 和 shader 复制到 `rm_synapse/addons/rm_video_decoder/`。如果要接 UDP H.265 图传，需要按目标平台编译对应二进制。

Ubuntu x86_64：
```bash
sudo apt update
sudo apt install build-essential scons pkg-config cmake \
                 libavcodec-dev libavutil-dev libswscale-dev

cd plugins/rm_video_decoder
scons platform=linux target=template_release arch=x86_64
```

macOS arm64 或 x86_64：
```bash
brew install scons pkg-config ffmpeg cmake

cd plugins/rm_video_decoder
scons platform=macos target=template_release arch=arm64    # Apple Silicon
scons platform=macos target=template_release arch=x86_64   # Intel
```
`arch=universal` 只在 FFmpeg 本身也是 universal 库时使用；否则请按宿主架构构建。

Windows MSVC + vcpkg：
```powershell
vcpkg install ffmpeg:x64-windows

cd plugins\rm_video_decoder
scons platform=windows target=template_release arch=x86_64 `
      ffmpeg_root=$env:VCPKG_ROOT\installed\x64-windows
```

Windows MinGW + vcpkg：
```powershell
vcpkg install ffmpeg:x64-mingw-dynamic

cd plugins\rm_video_decoder
scons platform=windows target=template_release arch=x86_64 use_mingw=yes `
      ffmpeg_root=$env:VCPKG_ROOT\installed\x64-mingw-dynamic
```

插件输出文件名应为：
- Linux：`rm_synapse/addons/rm_video_decoder/bin/linux-x86_64/librm_video_decoder.so`
- Windows：`rm_synapse/addons/rm_video_decoder/bin/windows-x86_64/rm_video_decoder.dll`
- macOS：`rm_synapse/addons/rm_video_decoder/bin/macos-<arch>/librm_video_decoder.dylib`
- 共享资源：`rm_synapse/addons/rm_video_decoder/rm_video_decoder.gdextension`、`rm_synapse/addons/rm_video_decoder/video_yuv.gdshader`

FFmpeg 不在系统搜索路径时，可额外传入 `ffmpeg_include=<path>`、`ffmpeg_libpath=<path>`、`ffmpeg_runtime_dir=<path>`。Windows 默认会尝试从 `ffmpeg_root/bin` 复制 `av*.dll`、`sw*.dll` 及其依赖到 `rm_synapse/addons/rm_video_decoder/bin/windows-x86_64/`；Linux/macOS 如需随包分发动态库，可显式使用 `copy_ffmpeg_runtime=yes ffmpeg_runtime_dir=<path>`。Ubuntu 22.04 分发推荐使用 `static_ffmpeg=yes copy_ffmpeg_runtime=no`，降低运行机 FFmpeg 依赖要求。

### CMake 验证构建
CMake 入口只构建 `video_core` 和可选预览测试程序，不负责 Godot 插件发布。默认不依赖 OpenCV：
```bash
cmake -S plugins/rm_video_decoder -B build/rm_video_decoder -DRM_VIDEO_DECODER_BUILD_TESTS=OFF
cmake --build build/rm_video_decoder
```
需要 UDP→FFmpeg→OpenCV 预览时再开启测试：
```bash
cmake -S plugins/rm_video_decoder -B build/rm_video_decoder-test \
      -DRM_VIDEO_DECODER_BUILD_TESTS=ON \
      -DOpenCV_DIR=<opencv-config-dir>
cmake --build build/rm_video_decoder-test
```

### Godot 导出
导出预设位于 `rm_synapse/export_presets.cfg`，当前维护三个目标：`Linux`、`Windows Desktop`、`macOS`。导出前确认：
- Godot 已安装对应平台 Export Templates。
- `rm_synapse/ui/web/` 已是最新 React 构建产物。
- `rm_synapse/addons/godot_cef/bin/<platform>/` 不是 LFS pointer。
- `rm_synapse/addons/rm_video_decoder/bin/<platform>/` 已有对应平台的 `rm_video_decoder` 动态库；Windows 还需要同目录 FFmpeg 运行时库。

Linux：
```bash
godot --headless --path rm_synapse --export-release "Linux" "Export/linux/rmsynapse.x86_64"
```
产物默认放在 `rm_synapse/Export/linux/`。分发时至少包含可执行文件；如果未使用 embed pck，还要同时带上 `.pck`。

Windows：
```powershell
godot --headless --path rm_synapse --export-release "Windows Desktop" "Export/windows/rmsynapse.exe"
```
推荐使用控制台版 Godot 执行导出，便于看到缺失库或资源导入错误。分发目录应包含 `rmsynapse.exe`，以及 Godot/CEF/FFmpeg 没有被自动打入可执行文件旁边的运行时文件。

macOS：
```bash
godot --headless --path rm_synapse --export-release "macOS" "Export/macos/rmsynapse.dmg"
```
当前预设为 universal 导出；如果只准备单架构 CEF 或视频插件，需要在 Godot 导出预设中把 `binary_format/architecture` 调整为对应架构，或补齐 universal 运行库后再导出。

### 发布检查
每个平台发布前至少做一次快速检查：
```bash
godot --headless --path rm_synapse --quit
```
然后启动导出产物，确认 HUD 能显示、MQTT 设置能保存、无 CEF/GDExtension 缺失库报错。有视频流时打开 `rm_synapse/net/video_udp/transfer_image.tscn` 做一次画面烟测；无视频流时，只出现 UDP timeout 日志不视为失败。

平台动态库检查命令：
- Linux：`ldd rm_synapse/addons/rm_video_decoder/bin/linux-x86_64/librm_video_decoder.so`
- Windows MSVC：`dumpbin /dependents rm_synapse\addons\rm_video_decoder\bin\windows-x86_64\rm_video_decoder.dll`
- Windows MinGW：`objdump -p rm_synapse\addons\rm_video_decoder\bin\windows-x86_64\rm_video_decoder.dll`
- macOS：`otool -L rm_synapse/addons/rm_video_decoder/bin/macos-<arch>/librm_video_decoder.dylib`

`rm_synapse/Export/`、`godot-cpp/bin/` 和构建缓存默认被 `.gitignore` 排除。`rm_synapse/addons/rm_video_decoder/` 使用 Git LFS 管理，可用于提交经过验证的插件二进制；普通导出目录仍不应作为源码改动提交。

## 网络与协议速览
- 下行订阅（`ProtocolAdapter.DEFAULT_SUBSCRIBE_TOPICS` 默认）：`GameStatus`、`GlobalUnitStatus`、`GlobalLogisticsStatus`、`GlobalSpecialMechanism`、`Event`、`RobotInjuryStat`、`RobotRespawnStatus`、`RobotStaticStatus`、`RobotDynamicStatus`、`RobotModuleStatus`、`RobotPosition`、`Buff`、`PenaltyInfo`、`RobotPathPlanInfo`、`RadarInfoToClient`、`RobotPerformanceSelectionSync`、`DeployModeStatusSync`、`TechCoreMotionStateSync`、`RuneStatusSync`、`SentryStatusSync`、`DartSelectTargetStatusSync`、`SentryCtrlResult`、`AirSupportStatusSync`、`CustomByteBlock`。解码成功的消息会写入状态服务并逐类触发 `*_updated` 信号。  
- 上行：
  - 高频：`KeyboardMouseControl`、`CustomControl`（75 Hz，latest-only，自定义数据最大 30 bytes）。
  - 请求/低频：`RobotPerformanceSelectionCommand`、`HeroDeployModeEventCommand`、`RuneActivateCommand`、`AssemblyCommand`、`DartCommand`、`SentryCtrlCommand`、`AirSupportCommand`。
  - 触发：`CommonCommand`、`MapClickCmd`，支持协议侧最小发送间隔。
- 数据流设计：网络线程只读写线程安全队列，主线程在 `_process` 中批量落地并发信号；发送端 ACK/超时重试、断线可选择丢弃高频包（详见 `rm_synapse/net/data_flow.md` 与 `rm_synapse/net/Readme.md`）。

## 视频流协议与 RMVideoCanvas
- UDP 包头（8 bytes）：`frame_seq:uint16`，`fragment_seq:uint16`，`total_size:uint32`（通常网络字节序）；同帧多分片乱序容忍，16 MB 安全上限。  
- 解码：FFmpeg HEVC 默认，可根据推流选择编译期改 codec；三缓冲避免渲染线程争用。  
- 输出：优先 NV12→自带 Shader（`res://bin/video_yuv.gdshader`），不支持则回退 RGBA；无帧 `no_frame_timeout_sec` 后显示占位纹理。  
- 属性（Inspector）：`port`、`use_bt601`、`use_tv_range`、`force_rgba`、`no_frame_timeout_sec`、`placeholder_texture`、`display_mode(adaptive/stretch/original)`；信号 `stream_state_changed(bool is_streaming)` 可用于 UI 提示。

## UI 模块
- 主界面位于 `react-ui/src/`，构建产物复制到 `rm_synapse/ui/web/` 后由 `rm_synapse/ui/HUD.tscn` 内的 CEF 节点加载。
- 默认主场景 `rm_synapse/Main.tscn` 组合 HUD 与视频占位场景，网络数据经 `hud.gd` 推送到 React。

## Protobuf 工具链
- 协议定义：`rm_synapse/net/mqtt/proto/rm_custom.proto`（RoboMaster 2026 自定义客户端章节）。  
- 重新生成 GDScript（需 Godot 4）：  
```bash
cd rm_synapse
godot4 --headless -s addons/protobuf/protobuf_cmdln.gd \
       --input=net/mqtt/proto/rm_custom.proto \
       --output=net/mqtt/proto/generated/rm_custom_pb.gd
```
- Godobuf UI 版也位于 `addons/protobuf/`，勾选插件后可在编辑器侧栏编译。

## 致谢
- 视频解码依赖 FFmpeg；GDExtension 使用 `godot-cpp` 4.5。  
- MQTT 插件基于 goatchurchprime/godot-mqtt；Protobuf 生成器基于 oniksan/godobuf；C++/Godot 日志共用 `rm_common`。
