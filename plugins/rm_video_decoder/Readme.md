# rm_video_decoder

Robomaster 自定义客户端视频流接受实现

# 依赖

```bash
sudo apt update
sudo apt install build-essential cmake
# 安装 FFmpeg (核心解码)
sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswscale-dev
# 安装 OpenCV (用于简易显示)
sudo apt install libopencv-dev
```

# VideoCore实现方式

1. 使用三缓冲的方式实现实现网络线程和godot的进程的交换
2. 使用三帧缓冲接受来自UDP的数据，并且加上时间验证
3. 初步全部使用CPU解码，转换为 YUV 格式后交由 godot 处理