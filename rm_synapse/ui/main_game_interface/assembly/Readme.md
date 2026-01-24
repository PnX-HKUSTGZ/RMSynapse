# assembly 装配
## 完成装配流程

1. 监听 GameState 节点的 tech_core_motion_state_sync_updated 信号
2. 通过 LowRateSender 节点的 set_assembly_command 方法发送装配指令: 1 为发送，2 为取消
3. 通过 _on_state 函数根据装配状态控制 ui 组件显隐性
4. 根据选定的最大难度maximum_difficulty_level生成下拉框
5. 剩余均为工具函数