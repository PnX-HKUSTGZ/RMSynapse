extends Control

# 没有支持雷达特殊标识

# 支持热重载的参数
@export var north_to_x_angle : float = 0.0 # 北方向对应的X轴角度（度）
@export var world_size = Vector2(28, 15) # 世界尺寸（x,y）
@export var red_side_color : Color = Color(1, 0, 0, 1)
@export var blue_side_color : Color = Color(0, 0, 1, 1)
@export var pos_timeout : float = 1.0 # 位置数据超时时间（秒）超时后将会不显示位置
@export var sentry_path_color : Color = Color(0, 1, 0, 1)
@export var sentry_path_width : float = 4.0
@export var sentry_path_timeout : float = 5.0 # 哨兵路径显示时间（秒）

@export_group("地图设置")
@export var reset_map : Key = KEY_R # 重置地图按键
@export var max_map_scale : float = 3.0
@export var min_map_scale : float = 0.5
@export var map_scale_step : float = 0.1
@export var map_transparency : float = 1.0 # 地图透明度 0~1
@export var drag_button : MouseButton = MOUSE_BUTTON_LEFT # 拖动地图的按键

#不支持热重载的参数
@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var id_map_path: NodePath = NodePath("/root/IDMap")

@onready var map_container = $MapContainer
@onready var map_texture = $MapContainer/MapTexture
@onready var paths_layer = $MapContainer/PathsLayer
@onready var icons_layer = $MapContainer/IconsLayer

class Line2DTime:
	var line: Line2D
	var timestamp: float

	func _init(_line: Line2D):
		self.line = _line
		self.timestamp = Time.get_ticks_msec() / 1000.0

const ROBOT_ICON_TSCN_PATH = "res://ui/main_game_interface/map/robot_icon.tscn"

var map_pixel_size: Vector2
var map_center_offset: Vector2
var self_robot_co : Vector2 = Vector2.ZERO

# 已经处理好的像素位置和朝向
# 已经处理好的像素朝向，相对于 x 轴
var self_robot_angle : float = 0.0
# 机器人ID
var self_id = -1
var self_origin_id = -1
var self_color : Color = Color(1, 1, 1, 1)
var self_icon : Node2D = preload(ROBOT_ICON_TSCN_PATH).instantiate()

var last_pos_update_times : Dictionary
var robot_positions : Dictionary
var sentry_path_list : Array[Line2DTime]

# Map 整体相关
var _current_scale : float = 1.0
var _is_dragging : bool = false
var _last_press_mouse_pos : Vector2 = Vector2.ZERO

func _build_robot_positions() -> Dictionary:
	var dict = {}
	for robot_id in IDMap.MOVEABLE_ROBOT_IDS:
		dict[robot_id] = preload(ROBOT_ICON_TSCN_PATH).instantiate()
		dict[robot_id].name = "RobotIcon_%d" % robot_id
		dict[robot_id].position = Vector2(-100, -100) # 初始位置放在不可见处
		# 添加颜色
		if IDMap.is_red(robot_id):
			dict[robot_id].color = red_side_color
		elif IDMap.is_blue(robot_id):
			dict[robot_id].color = blue_side_color
		else:
			push_warning("Robot ID %d does not belong to red or blue side." % robot_id)
			dict[robot_id].color = Color(1, 1, 1, 1)
		icons_layer.add_child(dict[robot_id])
	return dict

func _build_last_pos_update_times() -> Dictionary:
	var dict = {}
	for robot_id in IDMap.MOVEABLE_ROBOT_IDS:
		dict[robot_id] = Time.get_ticks_msec() / 1000.0
	return dict

func _sentry_intention_map(intention: int) -> String:
	match intention:
		1:
			return "攻击"
		2:
			return "防守"
		3:
			return "移动"
		_:
			return "未知"

func _ready():
	
	set_process(true)
	set_process_unhandled_input(true)
	
	# 初始化尺寸数据
	map_pixel_size = map_texture.size
	map_center_offset = map_pixel_size / 2

	last_pos_update_times = _build_last_pos_update_times()
	robot_positions = _build_robot_positions()

	# 添加RobotIcon树
	self_icon.name = "SelfRobotIcon"
	icons_layer.add_child(self_icon)
	print("Added SelfRobotIcon to map.")

	sentry_path_list = []


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

	# 获取雷达数据
	if game_state.has_signal("rader_info_updated"):
		game_state.connect("rader_info_updated", Callable(self, "_on_radar_info_updated"))
	else:
		push_error("GameState node has no signal 'rader_info_updated'")

	# 获取哨兵规划信息
	if game_state.has_signal("robot_path_plan_info_updated"):
		game_state.connect("robot_path_plan_info_updated", Callable(self, "_on_robot_path_plan_info_updated"))
	else:
		push_error("GameState node has no signal 'robot_path_plan_info_updated'")


func _on_robot_path_plan_info_updated(value) -> void:
	var sentry_id = value.get_sender_id()

	if not robot_positions.has(sentry_id):
		push_warning("Received path plan info for unknown robot ID: %d" % sentry_id)
		return
	var icon = robot_positions[sentry_id]

	# 更新意图显示
	icon.intention = _sentry_intention_map(value.get_intention())

	# 更新路径显示 注意获取的是分米

	# 清除之前的路径
	for i in sentry_path_list.size():
		var line : Line2DTime = sentry_path_list[i]
		paths_layer.remove_child(line.line)
	sentry_path_list.clear()

	# 构建新的路径
	var map_path : Array[Vector3] = []
	var screen_path : Array[Vector2] = []
	var start_point = Vector3(value.get_start_pos_x()/10, value.get_start_pos_y()/10, 0)
	map_path.push_back(start_point)

	var offset_x : Array[int] = value.get_offset_x()
	var offset_y : Array[int] = value.get_offset_y()

	if offset_x.size() != offset_y.size():
		push_warning("Offset X and Y size mismatch for robot ID: %d" % sentry_id)
		return
	
	for i in offset_x.size():
		var point = Vector3(start_point.x + offset_x[i] / 10.0, start_point.y + offset_y[i] / 10.0, 0)
		map_path.append(point)

	for point in map_path:
		var map_co = world_to_map_co(point)
		screen_path.append(map_co)
	# 绘制路径
	var line2d = Line2D.new()
	line2d.width = sentry_path_width
	line2d.default_color = sentry_path_color
	line2d.points = screen_path
	line2d.name = "PathLine_%d" % sentry_id
	paths_layer.add_child(line2d)
	sentry_path_list.append(Line2DTime.new(line2d))


func _on_robot_position_updated(value) -> void:
	var co = Vector3(value.get_x(), value.get_y(), value.get_z())
	self_robot_co = world_to_map_co(co)
	self_robot_angle = value.get_yaw() - north_to_x_angle

func _on_radar_info_updated(value) -> void:
	var robot_id = value.get_target_robot_id()
	var pos = Vector3(value.get_target_pos_x(), value.get_target_pos_y(), 0)
	var map_co = world_to_map_co(pos)
	var icon = robot_positions.get(robot_id, null)
	if not icon:
		push_warning("Received radar info for unknown robot ID: %d" % robot_id)
		return
	icon.position = map_co
	icon.angle = value.get_torward_angle()
	# 更新最后位置更新时间
	last_pos_update_times[robot_id] = Time.get_ticks_msec() / 1000.0


func _on_robot_static_status(value) -> void:
	self_origin_id = value.get_robot_id()
	if IDMap and IDMap.is_red(self_origin_id):
		self_color = red_side_color
	elif IDMap and IDMap.is_blue(self_origin_id):
		self_color = blue_side_color
	else:
		self_color = Color(1, 1, 1, 1)
	self_id = IDMap.to_robot_number(self_origin_id) if IDMap else -1
	
# 输入是来自官方定义的世界坐标系，其中左下角为坐标原点，向右是X轴正方向，向上是Y轴正方向，垂直屏幕向外是Z轴正方向
# 输出是地图上的像素坐标系，其中左上角为坐标原点，向右是X轴正方向，向下是Y轴正方向
func world_to_map_co(world_pos: Vector3) -> Vector2:
	var ratio_x = map_pixel_size.x / world_size.x
	var ratio_y = map_pixel_size.y / world_size.y

	var x = world_pos.x * ratio_x
	var y = map_pixel_size.y - world_pos.y * ratio_y

	return Vector2(x, y)

func _process(_delta: float) -> void:
	# 计算自己的位置和朝向
	self_icon.position = self_robot_co
	self_icon.color = self_color
	self_icon.angle = self_robot_angle
	self_icon.id = str(self_id)

	# 如果超时了或者属于自己，则隐藏位置
	var current_time = Time.get_ticks_msec() / 1000.0
	for robot_id in IDMap.MOVEABLE_ROBOT_IDS:
		var icon = robot_positions[robot_id]
		var last_update_time = last_pos_update_times[robot_id]
		if current_time - last_update_time > pos_timeout or robot_id == self_origin_id:
			icon.visible = false
		else:
			icon.visible = true

	# 处理哨兵路径超时
	for i in sentry_path_list.size():
		var line_time : Line2DTime = sentry_path_list[i]
		if current_time - line_time.timestamp > sentry_path_timeout:
			paths_layer.remove_child(line_time.line)
			sentry_path_list.remove_at(i)
			i -= 1

	# 处理地图
	map_container.modulate.a = map_transparency

	# 地图平移
	if Input.is_mouse_button_pressed(drag_button):
		if not _is_dragging:
			_is_dragging = true
			print("Started dragging map.")
		else:
			map_container.global_position += get_global_mouse_position() - _last_press_mouse_pos
		_last_press_mouse_pos = get_global_mouse_position()
	else :
		_is_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	# 处理重置地图按键
	if event is InputEventKey:
		if event.pressed and event.keycode == reset_map:
			_reset_map()
			return
	
	if event is InputEventMouseButton:
		# 处理缩放 (滚轮)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_handle_zoom_at_mouse(event)

# 处理以鼠标为中心的缩放逻辑
func _handle_zoom_at_mouse(event: InputEventMouseButton) -> void:
	var old_scale = _current_scale
	var new_scale = old_scale

	# 计算新比例
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		new_scale += map_scale_step
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		new_scale -= map_scale_step
	else :
		push_warning("Unhandled mouse button for zoom: %d" % event.button_index)
		return
	
	new_scale = clamp(new_scale, min_map_scale, max_map_scale)
	print("Zooming map from scale %.2f to %.2f" % [old_scale, new_scale])
	
	if new_scale == old_scale:
		return
	
	# 获取缩放前鼠标在 map_container 局部坐标系中的位置
	var mouse_in_container = map_container.get_local_mouse_position()
	
	# 获取缩放前鼠标的全局位置
	var mouse_global = get_global_mouse_position()
	
	# 应用新缩放
	_current_scale = new_scale
	map_container.scale = Vector2(_current_scale, _current_scale)
	
	# 缩放后，调整 map_container 的全局位置，使鼠标仍然指向相同的地图点
	# 公式: 新全局位置 = 鼠标全局位置 - 鼠标在容器中的局部位置 * 新缩放
	map_container.global_position = mouse_global - mouse_in_container * _current_scale

# 重置地图位置和缩放
func _reset_map() -> void:
	_current_scale = 1.0
	map_container.scale = Vector2(1.0, 1.0)
	# 重置到居中位置（计算窗口中心减去地图容器一半尺寸）
	var window_center = global_position + size / 2
	map_container.global_position = window_center - map_pixel_size / 2
