extends Control

# --- 比赛状态 ---
var time_left: float = 420.0 # 7分钟 (420秒)
var scores: Dictionary = {"left": 0, "right": 0}
var current_round: int = 2
var total_rounds: int = 5

# --- 节点引用 ---
var time_label_m: Label
var time_label_s: Label
var colon_label: Label
var score_label_l: Label
var score_label_r: Label

var blink_timer: float = 0.0
var colon_visible: bool = true

func _ready() -> void:
	# 设置根节点铺满屏幕并允许鼠标穿透到底层游戏
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	
	# 创建一个 CanvasLayer 确保 UI 始终在最上层
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	# 顶部边距
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 24)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	
	# 垂直排列 (Round 徽章在上方，主信息栏在下方)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", -2) # 负间距让两者无缝贴合
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	# --- 1. 构建顶部 Round 徽章 ---
	var round_bg = _create_custom_shape_panel(3, Vector2(160, 26))
	round_bg.size_flags_horizontal = SIZE_SHRINK_CENTER # 居中对齐
	vbox.add_child(round_bg)
	
	var round_label = _create_label("ROUND %d/%d" % [current_round, total_rounds], 14, Color(0.36, 0.88, 0.90))
	round_bg.get_node("Center").add_child(round_label)
	
	# --- 2. 构建主信息栏 (水平排列) ---
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 8)
	main_hbox.size_flags_horizontal = SIZE_SHRINK_CENTER # 居中对齐
	main_hbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(main_hbox)
	
	# 左侧分数
	var left_bg = _create_custom_shape_panel(0, Vector2(130, 64))
	left_bg.mouse_filter = MOUSE_FILTER_STOP
	left_bg.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	left_bg.connect("gui_input", Callable(self, "_on_left_score_input"))
	main_hbox.add_child(left_bg)
	
	score_label_l = _create_label("0", 42, Color.WHITE, true)
	left_bg.get_node("Center").add_child(score_label_l)
	
	# 中心时间
	var center_bg = _create_custom_shape_panel(1, Vector2(220, 64))
	main_hbox.add_child(center_bg)
	
	var time_hbox = HBoxContainer.new()
	time_hbox.add_theme_constant_override("separation", 4)
	center_bg.get_node("Center").add_child(time_hbox)
	
	time_label_m = _create_label("07", 42, Color.WHITE, true)
	colon_label = _create_label(":", 36, Color(0.36, 0.88, 0.90), true)
	time_label_s = _create_label("00", 42, Color.WHITE, true)
	
	# 冒号向上微调对齐
	colon_label.custom_minimum_size.y = 50 
	colon_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	time_hbox.add_child(time_label_m)
	time_hbox.add_child(colon_label)
	time_hbox.add_child(time_label_s)
	
	# 右侧分数
	var right_bg = _create_custom_shape_panel(2, Vector2(130, 64))
	right_bg.mouse_filter = MOUSE_FILTER_STOP
	right_bg.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	right_bg.connect("gui_input", Callable(self, "_on_right_score_input"))
	main_hbox.add_child(right_bg)
	
	score_label_r = _create_label("0", 42, Color.WHITE, true)
	right_bg.get_node("Center").add_child(score_label_r)

func _process(delta: float) -> void:
	# 倒计时逻辑
	if time_left > 0:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			
		var m = int(time_left) / 60
		var s = int(time_left) % 60
		time_label_m.text = "%02d" % m
		time_label_s.text = "%02d" % s
		
	# 冒号闪烁动画
	blink_timer += delta
	if blink_timer >= 0.5:
		blink_timer = 0.0
		colon_visible = !colon_visible
		colon_label.modulate.a = 1.0 if colon_visible else 0.3

# ==========================================
# 工具函数：生成完美的矢量几何背景 (替代切图)
# ==========================================
func _create_custom_shape_panel(shape_type: int, min_size: Vector2) -> Control:
	var ctrl = Control.new()
	ctrl.custom_minimum_size = min_size
	
	# 连接 draw 信号进行矢量绘图
	ctrl.connect("draw", Callable(self, "_on_shape_draw").bind(ctrl, shape_type))
	
	# 内部添加一个 CenterContainer 确保文字自动完美居中
	var cc = CenterContainer.new()
	cc.name = "Center"
	cc.set_anchors_preset(PRESET_FULL_RECT)
	cc.mouse_filter = MOUSE_FILTER_IGNORE
	ctrl.add_child(cc)
	
	return ctrl

func _on_shape_draw(node: Control, shape_type: int) -> void:
	var w = node.size.x
	var h = node.size.y
	var d = h * 0.38 # 控制倾斜角度 (约20度)

	var pts = PackedVector2Array()
	var bg_color = Color(0.08, 0.12, 0.16, 0.95)      # 深渊灰背景
	var border_color = Color(0.36, 0.88, 0.90, 0.3)   # 暗青色边框
	var glow_color = Color(0.36, 0.88, 0.90, 1.0)     # 亮青色发光边框
	
	# 根据类型计算多边形顶点 (完美还原 UI 切角)
	match shape_type:
		0: # 左侧分数 (向右倾斜平行四边形)
			pts.append_array([Vector2(0, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(d, h)])
		1: # 中心时间 (倒梯形)
			pts.append_array([Vector2(0, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(d, h)])
		2: # 右侧分数 (向左倾斜平行四边形)
			pts.append_array([Vector2(d, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(0, h)])
		3: # 顶部 Round (正梯形)
			pts.append_array([Vector2(d, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(0, h)])
			bg_color = Color(0.12, 0.18, 0.24, 0.95) # 徽章颜色略浅

	# 1. 绘制背景填充
	node.draw_colored_polygon(pts, bg_color)
	
	# 2. 绘制基础细边框
	var outline = pts.duplicate()
	outline.push_back(pts[0]) # 闭合路径
	node.draw_polyline(outline, border_color, 1.5, true)
	
	# 3. 绘制发光强调边框 (Neon Glow)
	var glow_width = 3.5
	match shape_type:
		0: # 左分数框的高亮边在左侧
			node.draw_line(pts[0], pts[3], glow_color, glow_width, true)
		2: # 右分数框的高亮边在右侧
			node.draw_line(pts[1], pts[2], glow_color, glow_width, true)
		1: # 中心时间的高亮边在底部
			node.draw_line(pts[3], pts[2], glow_color, glow_width, true)

# ==========================================
# 工具函数：生成带有科幻风格的文本标签
# ==========================================
func _create_label(text: String, size: int, color: Color, is_bold: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	
	var settings = LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	
	# 添加文字发光投影
	settings.shadow_size = 8
	settings.shadow_color = Color(0, 0, 0, 0.8)
	
	# 调用系统内置字体，省去导入 TTF 文件的麻烦，优先选择具有科幻感/硬朗感的字体
	var sys_font = SystemFont.new()
	sys_font.font_names = ["Impact", "Arial Black", "Trebuchet MS", "sans-serif"]
	sys_font.font_weight = 900 if is_bold else 700
	settings.font = sys_font
	
	label.label_settings = settings
	return label

# ==========================================
# 交互事件：点击分数框加分 (演示用)
# ==========================================
func _on_left_score_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		scores.left += 1
		score_label_l.text = str(scores.left)

func _on_right_score_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		scores.right += 1
		score_label_r.text = str(scores.right)