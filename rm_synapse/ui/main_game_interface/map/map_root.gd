extends Control

# 支持热重载的参数
@export var north_to_x_angle : float = 0.0 # 北方向对应的X轴角度（度）
@export var world_size = Vector2(28, 15) # 世界尺寸（x,y）
@export var red_side_color : Color = Color(1, 0, 0, 1)
@export var blue_side_color : Color = Color(0, 0, 1, 1)

#不支持热重载的参数
@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var id_map_path: NodePath = NodePath("/root/IDMap")

@onready var map_texture = $MapContainer/MapTexture
@onready var paths_layer = $MapContainer/PathsLayer
@onready var icons_layer = $MapContainer/IconsLayer

const ROBOT_ICON_TSCN_PATH = "res://ui/main_game_interface/map/robot_icon.tscn"

var map_pixel_size: Vector2
var map_center_offset: Vector2
var id_map : IdMap
var self_robot_co : Vector2 = Vector2.ZERO

# 已经处理好的像素位置和朝向
# 已经处理好的像素朝向，相对于 x 轴
var self_robot_angle : float = 0.0
# 机器人ID
var self_id = -1
var self_color : Color = Color(1, 1, 1, 1)
var self_icon : Node2D = null

func _ready():
	# 初始化尺寸数据
	map_pixel_size = map_texture.size
	map_center_offset = map_pixel_size / 2
	id_map = get_node(id_map_path)
	# 监听游戏状态变化
	if not has_node(game_state_path):
		push_error("Cannot find GameState node at path: %s" % game_state_path)
		return
	var game_state = get_node(game_state_path)

	# 获取自己的id
	if game_state.has_signal("robot_static_status_updated"):
		game_state.connect("robot_static_status_updated", Callable(self, "_on_robot_static_status"))
	else:
		push_error("GameState node has no signal 'robot_static_status_updated'")

	# 获取自己的位置和朝向
	if game_state.has_signal("robot_position_updated"):
		game_state.connect("robot_position_updated", Callable(self, "_on_robot_position_updated"))
	else:
		push_error("GameState node has no signal 'robot_position_updated'")

	self_icon = preload(ROBOT_ICON_TSCN_PATH).instantiate()

func _on_robot_position_updated(value) -> void:
	var co = Vector3(value.get_x(), value.get_y(), value.get_z())
	self_robot_co = world_to_map_co(co)
	self_robot_angle = value.get_yaw() - north_to_x_angle


func _on_robot_static_status(value) -> void:
	var id = value.get_robot_id()
	if id_map and id_map.is_red(id):
		self_color = red_side_color
	elif id_map and id_map.is_blue(id):
		self_color = blue_side_color
	else:
		self_color = Color(1, 1, 1, 1)
	self_id = id_map.to_robot_number(id) if id_map else -1

# 输入是来自官方定义的世界坐标系，其中左下角为坐标原点，向右是X轴正方向，向上是Y轴正方向，垂直屏幕向外是Z轴正方向
# 输出是地图上的像素坐标系，其中左上角为坐标原点，向右是X轴正方向，向下是Y轴正方向
func world_to_map_co(world_pos: Vector3) -> Vector2:
	var ratio_x = map_pixel_size.x / world_size.x
	var ratio_y = map_pixel_size.y / world_size.y

	var x = world_pos.x * ratio_x
	var y = map_pixel_size.y - world_pos.y * ratio_y

	return Vector2(x, y)

func _process(_delta: float) -> void:
	# 画出自己的位置
	if not icons_layer.has_node("SelfRobotIcon"):
		self_icon.name = "SelfRobotIcon"
		icons_layer.add_child(self_icon)
		print("Added SelfRobotIcon to map.")
	# 计算自己的位置和朝向
	self_icon.position = self_robot_co
	self_icon.color = self_color
	self_icon.angle = self_robot_angle
	self_icon.id = str(self_id)
