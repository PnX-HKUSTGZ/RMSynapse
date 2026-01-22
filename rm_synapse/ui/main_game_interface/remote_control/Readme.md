# remote control ui
## 实时采集键盘鼠标输入，打包并发送数据，同时 ui 反应键鼠输入

1. _capture_frame 打包v dx dy dz mask l r m等每帧数据用于处理和显示
2. _build_mask 掩码，用一个 32 位整数表示所有按键状态
3. _unhandled_input 处理滚轮输入
4. _update_mouse_indicator 控制 ui 反应键鼠输入
5. _current_actions_text 拼接按下的绑定按键的字符串
6. _current_input_text 拼接按下的所有常见按键的字符串
7. _send_frame 发送数据给 mqtt 服务器
8. current_pressed_string 返回当前按下的绑定按键字符串;
   set_sensitivity 设置鼠标灵敏度(最小位 0.01)
   set_invert_y 设置鼠标 Y 轴反转
   set_binding 自定义按键绑定
   reset_bindings 重置为默认按键绑定
   bindings_preview 返回绑定关系预览字符串
   action_for_bit 根据位索引返回对应的按键名
9. 剩余均为初始化或工具函数