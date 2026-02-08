extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var low_rate_sender_path: NodePath = NodePath("/root/MqttNet/LowRateSender")
@export var toggle_action: String = "o"

@onready var yes : Label = $CanvasLayer/Label2
@onready var no : Label =  $CanvasLayer/Label3
@onready var onoff : CheckButton = $ColorRect/CheckButton
@onready var target_btn: Button = $Button
@onready var hold_progress: ProgressBar = $ProgressBar
var is_holding: bool = false  # 标记是否正在按住按钮
var hold_duration: float = 0.0 # 累计按住时长（单位：秒）
var threshold : float = 1.0   # 长按触发阈值（1秒）
var deploy : bool = false     # 部署状态标记
var deploy_check : bool = false
var _gs: Node = null
var _sender: Node = null
var _keycode : int = KEY_NONE
var _prekey_state : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	_gs = get_node_or_null(game_state_path)
	if _gs:
		if _gs.has_signal("deploy_mode_status_sync_updated"):
			_gs.connect("deploy_mode_status_sync_updated", Callable(self, "_on_updated"))
	else:
		push_warning("[HeroDeployMode] GameState not found at %s" % str(game_state_path))
	
	_sender = get_node_or_null(low_rate_sender_path)
	_keycode = OS.find_keycode_from_string(toggle_action)
	if _keycode == KEY_NONE:
		_keycode = KEY_O
		push_warning("快捷键解析失败，默认使用O键")
		
	# 【核心修改1】替换Button正确的按下/松开信号：button_down（按下）、button_up（松开）
	target_btn.button_down.connect(_on_btn_pressed)  # 按下：开始计时
	target_btn.button_up.connect(_on_btn_released)   # 松开：结束计时
	# 绑定CheckButton的toggled信号（原有逻辑保留）
	onoff.toggled.connect(_on_check_button_toggled)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 快捷键O切换UI显隐（原有逻辑保留）
	var curr_key_state = Input.is_key_pressed(KEY_O)
	if curr_key_state and not _prekey_state:
		visible = not visible
		print("英雄部署UI显隐切换：", visible)
	_prekey_state = curr_key_state
	
	# 【计时核心】仅按住时累加时长，与帧率解耦
	if is_holding:
		hold_duration += delta
		var progress_percent = (hold_duration / threshold) * 100
		# 限制进度最大值为100（避免按住超过阈值后进度溢出）
		hold_progress.value = min(progress_percent, 100)
	
	# 动态更新按钮文本（原有逻辑保留）
	if deploy:
		target_btn.text = "取消部署\n(长按)"
		
	else:
		target_btn.text = "英雄部署\n(长按)"
		
		
	if deploy_check:
		yes.visible = true
		no.visible = false
	else:
		yes.visible =false
		no.visible = true
		

# 发送指令核心方法（原有逻辑保留）
func _send_cmd(op: int) -> void:
	if _sender and _sender.has_method("set_hero_deploy_mode"):
		_sender.set_hero_deploy_mode(op)
	else:
		push_warning("[HeroDeployMode] LowRateSender not found or missing set_hero_deploy_mode")

# CheckButton勾选状态切换（原有逻辑保留）
func _on_check_button_toggled(toggled_on: bool) -> void:
	yes.visible = toggled_on
	no.visible = not toggled_on

# 按下按钮：初始化计时（状态+时长重置）
func _on_btn_pressed() -> void:
	is_holding = true
	hold_duration = 0.0  # 每次按下都重置，避免叠加上次时长
	hold_progress.visible = true
	hold_progress.value = 0
# 松开按钮：判断长按阈值，执行对应逻辑【优化后】
func _on_btn_released() -> void:
	if is_holding: # 防止重复触发
		is_holding = false
		hold_progress.visible = false
		hold_progress.value = 0
		# 核心逻辑：仅长按超过阈值时，切换部署状态并发送指令，短按无反应
		if hold_duration >= threshold:
			deploy = not deploy  
			if deploy==true:
				_send_cmd(1)
			else:
				_send_cmd(0)
			#_send_cmd(1 if deploy else 0)  # 根据新状态发送对应指令
			#print("英雄部署状态切换")
		# 短按（不足阈值）：无任何操作，无需额外代码
func _on_updated(value)->void:
	# 第一步：类型检查，确保value是预期的Protobuf对象
	#if value is Proto.DeployModeStatusSync:
	# 第二步：通过get_status()获取真正的整数值
	var status = value.get_status()
	# 第三步：用整数比较，更新部署状态
	if status == 1:
		deploy_check = true
	elif status == 0:
		deploy_check = false
