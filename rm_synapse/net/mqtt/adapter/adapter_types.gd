extends Object
class_name AdapterTypes

class KeyboardMouseControlData:
	extends RefCounted
	var mouse_x: int = 0
	var mouse_y: int = 0
	var mouse_z: int = 0
	var left_button_down: bool = false
	var right_button_down: bool = false
	var keyboard_value: int = 0
	var mid_button_down: bool = false

class CustomControlData:
	extends RefCounted
	const MAX_DATA_BYTES := 30
	var data: PackedByteArray = PackedByteArray()

class MapClickCmdData:
	extends RefCounted
	const ROBOT_ID_BYTES := 7
	var is_send_all: int = 0
	var robot_id: PackedByteArray = PackedByteArray()
	var mode: int = 0
	var enemy_id: int = 0
	var ascii: int = 0
	var type: int = 0
	var map_x: float = 0.0
	var map_y: float = 0.0

class MapClickInfoNotifyData:
	extends MapClickCmdData

class AssemblyCommandData:
	extends RefCounted
	var operation: int = 0
	var difficulty: int = 0

class RobotPerformanceSelectionCommandData:
	extends RefCounted
	var shooter: int = 0
	var chassis: int = 0
	var sentry_control: int = 0

class CommonCommandData:
	extends RefCounted
	var cmd_type: int = 0
	var param: int = 0

class HeroDeployModeEventCommandData:
	extends RefCounted
	var mode: int = 0

class RuneActivateCommandData:
	extends RefCounted
	var activate: int = 0

class DartCommandData:
	extends RefCounted
	var target_id: int = 0
	var open: bool = false
	var launch_confirm: bool = false

class SentryCtrlCommandData:
	extends RefCounted
	var command_id: int = 0

class AirSupportCommandData:
	extends RefCounted
	var command_id: int = 0
