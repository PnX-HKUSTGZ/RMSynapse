class_name RMProto

# Facade for split protobuf definitions.
# Keep this path stable so existing code can still use:
# const Proto = preload("res://protocol/generated/rm_proto.gd")

const _state = preload("res://protocol/generated/split/rm_proto_state.gd")
const _control = preload("res://protocol/generated/split/rm_proto_control.gd")
const _command = preload("res://protocol/generated/split/rm_proto_command.gd")

# Shared protobuf core types.
const PROTO_VERSION = _state.PROTO_VERSION
const DEBUG_TAB = _state.DEBUG_TAB
const PB_ERR = _state.PB_ERR
const PB_DATA_TYPE = _state.PB_DATA_TYPE
const DEFAULT_VALUES_2 = _state.DEFAULT_VALUES_2
const DEFAULT_VALUES_3 = _state.DEFAULT_VALUES_3
const PB_TYPE = _state.PB_TYPE
const PB_RULE = _state.PB_RULE
const PB_SERVICE_STATE = _state.PB_SERVICE_STATE
const PBField = _state.PBField
const PBTypeTag = _state.PBTypeTag
const PBServiceField = _state.PBServiceField
const PBPacker = _state.PBPacker

# Control/trigger messages.
const RemoteControl = _control.RemoteControl
const MapClickInfoNotify = _control.MapClickInfoNotify

# State/downlink messages.
const GameStatus = _state.GameStatus
const GlobalUnitStatus = _state.GlobalUnitStatus
const GlobalLogisticsStatus = _state.GlobalLogisticsStatus
const GlobalSpecialMechanism = _state.GlobalSpecialMechanism
const Event = _state.Event
const RobotInjuryStat = _state.RobotInjuryStat
const RobotRespawnStatus = _state.RobotRespawnStatus
const RobotStaticStatus = _state.RobotStaticStatus
const RobotDynamicStatus = _state.RobotDynamicStatus
const RobotModuleStatus = _state.RobotModuleStatus
const RobotPosition = _state.RobotPosition
const Buff = _state.Buff
const PenaltyInfo = _state.PenaltyInfo
const RobotPathPlanInfo = _state.RobotPathPlanInfo
const RaderInfoToClient = _state.RaderInfoToClient
const CustomByteBlock = _state.CustomByteBlock

# Command/sync messages.
const AssemblyCommand = _command.AssemblyCommand
const TechCoreMotionStateSync = _command.TechCoreMotionStateSync
const RobotPerformanceSelectionCommand = _command.RobotPerformanceSelectionCommand
const RobotPerformanceSelectionSync = _command.RobotPerformanceSelectionSync
const HeroDeployModeEventCommand = _command.HeroDeployModeEventCommand
const DeployModeStatusSync = _command.DeployModeStatusSync
const RuneActivateCommand = _command.RuneActivateCommand
const RuneStatusSync = _command.RuneStatusSync
const SentinelStatusSync = _command.SentinelStatusSync
const DartCommand = _command.DartCommand
const DartSelectTargetStatusSync = _command.DartSelectTargetStatusSync
const GuardCtrlCommand = _command.GuardCtrlCommand
const GuardCtrlResult = _command.GuardCtrlResult
const AirSupportCommand = _command.AirSupportCommand
const AirSupportStatusSync = _command.AirSupportStatusSync
