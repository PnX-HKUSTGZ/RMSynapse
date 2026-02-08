extends TextureRect

# 编辑器可视化调节参数（想改效果直接在检查器改，不用碰代码）
@export var breath_speed: float = 1.9  # 呼吸速度，越小越慢（推荐0.8-1.5）
@export var min_alpha: float = 0.2     # 最低透明度，越高闪烁越柔和（推荐0.3-0.5）

# 仅用于驱动循环的累计时间（无需修改）
var time_accum: float = 0.0

# Godot最基础的逐帧更新函数，所有版本都支持，绝对不报错
func _process(delta: float) -> void:
	# 1. 累计时间（delta是每帧间隔，核心驱动循环）
	time_accum += delta * breath_speed
	# 2. 用fmod取余实现0-6.28的循环（对应正弦函数一个完整周期，替代math.sin）
	var cycle = fmod(time_accum, 6.28)
	# 3. 基础正弦计算（Godot原生支持sin()全局函数，无需任何库）
	var sin_val = sin(cycle)
	# 4. 将sin(-1~1)映射为0~1的平滑值，实现往返变化
	var alpha_factor = (sin_val + 1.0) / 2.0
	# 5. 锁定透明度在[min_alpha, 1]之间，避免光标全透消失
	var target_alpha = min_alpha + alpha_factor * (1.0 - min_alpha)
	# 6. 设置最终透明度（modulate是TextureRect原生属性，直接赋值）
	modulate.a = target_alpha
