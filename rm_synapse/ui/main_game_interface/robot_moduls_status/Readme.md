# 实时监控机器人各硬件模块（如主控、装甲、图传等）的在线/离线状态并更新 UI 图标与文字
1. _on_module：模块状态回调函数，遍历 MODULE_FIELDS 定义的所有硬件字段，解析其在线数值并触发 UI 更新。

2. _set_one：核心 UI 更新逻辑，根据模块的在线状态切换对应的 SVG 图标（ONLINE/OFFLINE）并修改状态文本颜色或内容。

3. _find_icon / _find_label：节点搜索工具，根据模块名称在预定义的布局路径（VBox/HBox）中动态查找对应的 TextureRect 和 RichTextLabel。

4. _pretty_name：名称转换函数，将代码中的模块枚举名转换为用户友好的中文显示名称（如 "Video" 转换为 "图传"）。

5. _get_val：安全取值工具，支持从字典、对象或方法中提取模块状态值。

6. _set_all：初始化或批量重置所有模块的显示状态。

7. 剩余均为初始化或工具函数：包括 _ready 中的信号绑定、MODULE_FIELDS 映射表定义以及游戏状态节点的解析。