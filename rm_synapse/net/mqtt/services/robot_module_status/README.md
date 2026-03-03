# RobotModuleStatus Service

## 作用
缓存并分发 `RobotModuleStatus` 消息，提供各模块状态原始值。

## 监听信号
- `ProtocolAdapter.robot_module_status(message)`

## 状态模型
- `RobotModuleStatusState`
  - `power_manager/rfid/light_strip/small_shooter/big_shooter`
  - `uwb/armor/video_transmission/capacitor/main_controller/laser_detection_module`

## 对外信号
- `robot_module_status_updated(state)`
- `critical_module_changed(main_controller, power_manager, armor)`

## 主要接口
- `get_state()`
- 各字段 getter
- `clear_cache()`
