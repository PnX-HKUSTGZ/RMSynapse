# map 地图组件
## big map_root 大动态地图
1. 定义了 north_to_x_angle 等战场参数(支持热重载) 以及 map_container 等不支持热重载参数
2. _build_robot_positions _build_last_pos_update_times 为所有可移动机器人创建图标，记录每个机器人位置的最后更新时间，为后续 超时隐藏 做准备
3. _ready 绑定 GameState 的自身ID、自身位置、雷达、哨兵路径 信号
4. _on_robot_path_plan_info_updated 解析哨兵路径数据并绘制新路径
5. _on_robot_position_updated 更新自身像素坐标和朝向，为帧更新时渲染图标做准备
6. _on_radar_info_updated 接收雷达检测到的敌方机器人位置，更新对应图标位置 / 朝向，并记录更新时间
7. _on_robot_static_status 获取自身机器人的原始 ID，判断阵营并设置颜色
8. world_to_map_co 转换世界坐标系及 ui 像素坐标系
9. _process 帧更新函数，渲染机器人图标，敌方超时隐藏，哨兵路径超时清除，左键拖动地图
10. _unhandled_input _handle_zoom_at_mouse _reset_map R键重置地图缩放，滚轮缩放地图(以鼠标位中心)，缩放后自动调整地图位置，保证鼠标始终指向同一点
11. 剩余均为初始化或工具函数
## small map_root 小静态地图
1. 相较于 big_map_root 移除交互功能，改为通过导出变量静态配置地图的缩放和偏移，适合固定位置的小地图
## map_system 地图尺寸切换控制器
1. 通过默认按键(M)切换大小地图
## robot_icon 机器人图标
1. 渲染 颜色、朝向、ID、哨兵

   