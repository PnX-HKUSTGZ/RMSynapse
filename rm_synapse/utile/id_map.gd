extends Node
class_name IdMap

# 集中管理机器人与选手端 ID 映射，可通过 Autoload 名称 IdMap 访问。

const TEAM_RED = "red"
const TEAM_BLUE = "blue"
const TEAM_REF = "ref"

# 结构化存储，避免常量表达式限制且易于维护
class robot_state:
	var team: String
	var type_id: int
	var name: String
	var name_long: String

	func _init(_team: String, _type_id: int, _name: String, _name_long: String = "") -> void:
		self.team = _team
		self.type_id = _type_id
		self.name = _name
		self.name_long = _name_long if _name_long != "" else _name
class client_state:
	var team: String
	var robot_id: int
	var name: String

	func _init(_team: String, _robot_id: int, _name: String) -> void:
		self.team = _team
		self.robot_id = _robot_id
		self.name = _name

var ROBOT_META := {
	1: robot_state.new(TEAM_RED, 1, "红方英雄", "红方英雄机器人"),
	2: robot_state.new(TEAM_RED, 2, "红方工程", "红方工程机器人"),
	3: robot_state.new(TEAM_RED, 3, "红方步兵1", "红方步兵机器人1"),
	4: robot_state.new(TEAM_RED, 3, "红方步兵2", "红方步兵机器人2"),
	5: robot_state.new(TEAM_RED, 3, "红方步兵3", "红方步兵机器人3"),
	6: robot_state.new(TEAM_RED, 6, "红方空中", "红方空中机器人"),
	7: robot_state.new(TEAM_RED, 7, "红方哨兵", "红方哨兵机器人"),
	8: robot_state.new(TEAM_RED, 8, "红方飞镖", "红方飞镖"),
	9: robot_state.new(TEAM_RED, 9, "红方雷达", "红方雷达"),
	10: robot_state.new(TEAM_RED, 10, "红方前哨", "红方前哨站"),
	11: robot_state.new(TEAM_RED, 11, "红方基地", "红方基地"),
	101: robot_state.new(TEAM_BLUE, 1, "蓝方英雄", "蓝方英雄机器人"),
	102: robot_state.new(TEAM_BLUE, 2, "蓝方工程", "蓝方工程机器人"),
	103: robot_state.new(TEAM_BLUE, 3, "蓝方步兵1", "蓝方步兵机器人1"),
	104: robot_state.new(TEAM_BLUE, 3, "蓝方步兵2", "蓝方步兵机器人2"),
	105: robot_state.new(TEAM_BLUE, 3, "蓝方步兵3", "蓝方步兵机器人3"),
	106: robot_state.new(TEAM_BLUE, 6, "蓝方空中", "蓝方空中机器人"),
	107: robot_state.new(TEAM_BLUE, 7, "蓝方哨兵", "蓝方哨兵机器人"),
	108: robot_state.new(TEAM_BLUE, 8, "蓝方飞镖", "蓝方飞镖"),
	109: robot_state.new(TEAM_BLUE, 9, "蓝方雷达", "蓝方雷达"),
	110: robot_state.new(TEAM_BLUE, 10, "蓝方前哨", "蓝方前哨站"),
	111: robot_state.new(TEAM_BLUE, 11, "蓝方基地", "蓝方基地")
}

const ROBOT_TYPE_NAME = {
	1: "英雄",
	2: "工程",
	3: "步兵",
	4: "步兵",
	5: "步兵",
	6: "空中",
	7: "哨兵",
	8: "飞镖",
	9: "雷达/前哨",
	10: "前哨站",
	11: "基地"
}

# 选手端 / 裁判端 ID 元信息
var CLIENT_META := {
	0x0101: client_state.new(TEAM_RED, 1, "红方英雄机器人选手端"),
	0x0102: client_state.new(TEAM_RED, 2, "红方工程机器人选手端"),
	0x0103: client_state.new(TEAM_RED, 3, "红方步兵机器人1选手端"),
	0x0104: client_state.new(TEAM_RED, 4, "红方步兵机器人2选手端"),
	0x0105: client_state.new(TEAM_RED, 5, "红方步兵机器人3选手端"),
	0x0106: client_state.new(TEAM_RED, 6, "红方空中机器人选手端"),
	0x0165: client_state.new(TEAM_BLUE, 101, "蓝方英雄机器人选手端"),
	0x0166: client_state.new(TEAM_BLUE, 102, "蓝方工程机器人选手端"),
	0x0167: client_state.new(TEAM_BLUE, 103, "蓝方步兵机器人1选手端"),
	0x0168: client_state.new(TEAM_BLUE, 104, "蓝方步兵机器人2选手端"),
	0x0169: client_state.new(TEAM_BLUE, 105, "蓝方步兵机器人3选手端"),
	0x016A: client_state.new(TEAM_BLUE, 106, "蓝方空中机器人选手端"),
	0x8080: client_state.new(TEAM_REF, -1, "裁判系统服务器")
}

# 将带有阵营位的机器人 ID 归一化为“机器人号”（1-11）；其余返回 -1
const ROBOT_NUMBER_MAP = {
	1: 1, 101: 1,
	2: 2, 102: 2,
	3: 3, 103: 3,
	4: 4, 104: 4,
	5: 5, 105: 5,
	6: 6, 106: 6,
	7: 7, 107: 7,
	8: 8, 108: 8,
	9: 9, 109: 9,
	10: 10, 110: 10,
	11: 11, 111: 11
}

func get_robot_name(robot_id: int, long_form: bool = false) -> String:
	var meta = ROBOT_META.get(robot_id)
	if meta:
		return meta.name_long if long_form else meta.name
	return "ID %d" % robot_id

func get_robot_type_name(type_id: int) -> String:
	return ROBOT_TYPE_NAME.get(type_id, "类型:未知")

func get_team(id: int) -> String:
	var meta = ROBOT_META.get(id)
	if meta:
		return meta.team
	var cmeta = CLIENT_META.get(id)
	if cmeta:
		return cmeta.team
	return "unknown"

func is_robot_id(id: int) -> bool:
	return ROBOT_META.has(id)

func is_client_id(id: int) -> bool:
	return CLIENT_META.has(id)

func is_red(id: int) -> bool:
	return get_team(id) == TEAM_RED

func is_blue(id: int) -> bool:
	return get_team(id) == TEAM_BLUE

func get_client_name(id: int) -> String:
	var meta = CLIENT_META.get(id)
	if meta:
		return meta.name
	return "ID %d" % id

func client_to_robot_id(id: int) -> int:
	var meta = CLIENT_META.get(id)
	if meta:
		return int(meta.robot_id)
	return -1

func to_robot_number(robot_id: int) -> int:
	return ROBOT_NUMBER_MAP.get(robot_id, -1)
