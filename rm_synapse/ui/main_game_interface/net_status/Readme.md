# 网络状态
## 展示 mqtt上下行 视频流接收 机器人连接/上场/存活 状态
1. _ready 绑定 mqtt 及 机器人状态
2. set_mqtt_up_status set_mqtt_down_status set_video_status 等配合 _set_row_status 控制文本和颜色
3. _on_robot_static_status 显示机器人状态
4. 剩余均为工具函数