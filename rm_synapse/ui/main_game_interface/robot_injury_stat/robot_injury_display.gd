extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var display_seconds: float = 4.0

const TAU := PI * 2.0

# 伤害字段定义（键、显示名、颜色）
const DAMAGE_FIELDS := [
	{"key": "collision_damage", "name": "撞击", "color": Color8(255, 191, 105)},
	{"key": "small_projectile_damage", "name": "17mm", "color": Color8(114, 196, 255)},
	{"key": "large_projectile_damage", "name": "42mm", "color": Color8(255, 137, 122)},
	{"key": "dart_splash_damage", "name": "飞镖", "color": Color8(122, 255, 211)},
	{"key": "module_offline_damage", "name": "模块离线", "color": Color8(186, 152, 255)},
	{"key": "wifi_offline_damage", "name": "WiFi 离线", "color": Color8(255, 222, 122)},
	{"key": "penalty_damage", "name": "判罚", "color": Color8(255, 105, 180)},
	{"key": "server_kill_damage", "name": "强制击杀", "color": Color8(160, 160, 160)}
]

var _gs: Node = null
var _last_hp: int = -1                  # 最近一次血量
var _last_injury                        # 最近一次伤害统计（Proto.RobotInjuryStat 实例）
var _segments: Array = []               # 当前绘制的饼图分片
var _timer: float = 0.0

@onready var _legend: RichTextLabel = $Legend

func _ready() -> void:
	visible = false
	if size.x <= 0.0 or size.y <= 0.0:
		size = custom_minimum_size
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_dynamic_status_updated"):
			_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic_status"))
		if _gs.has_signal("robot_injury_stat_updated"):
			_gs.connect("robot_injury_stat_updated", Callable(self, "_on_injury_stat"))
	else:
		push_warning("[RobotInjuryDisplay] GameState not found at %s" % game_state_path)

func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		visible = false

#================ 信号处理 =================#
func _on_dynamic_status(value) -> void:
	var hp = int(_get_val(value, "current_health", -1))
	if hp < 0:
		push_warning("[RobotInjuryDisplay] Invalid health value: %s" % str(hp))
		return
	if _last_hp > 0 and hp <= 0:
		print("[RobotInjuryDisplay] Robot destroyed, showing injury chart.")
		_show_chart()
	_last_hp = hp

func _on_injury_stat(value) -> void:
	_last_injury = value

#================ 绘制与展示 =================#
func _show_chart() -> void:
	var injury = _last_injury
	_segments = _build_segments(injury)
	_timer = display_seconds
	_update_legend(injury)
	visible = true
	queue_redraw()

func _build_segments(injury) -> Array:
	var segments: Array = []
	if injury == null:
		return segments

	var total = float(_get_val(injury, "total_damage", 0))
	if total <= 0.0:
		# 如果总伤害为 0，则用各项之和
		for entry in DAMAGE_FIELDS:
			total += float(_get_val(injury, entry["key"], 0))
	if total <= 0.0:
		return segments

	for entry in DAMAGE_FIELDS:
		var dmg = float(_get_val(injury, entry["key"], 0))
		if dmg <= 0.0:
			continue
		var seg = {
			"name": entry["name"],
			"color": entry["color"],
			"ratio": clamp(dmg / total, 0.0, 1.0),
			"value": dmg
		}
		segments.append(seg)
	return segments

func _update_legend(injury) -> void:
	if _legend == null:
		return
	if injury == null:
		_legend.text = "[center]未收到伤害统计[/center]"
		return
	var total = float(_get_val(injury, "total_damage", 0))
	var killer = _get_val(injury, "killer_id", 0)
	var lines: Array[String] = []
	lines.append("总伤害: %.0f" % total)
	if killer != 0:
		lines.append("击杀者ID: %s" % str(killer))
	for seg in _segments:
		lines.append("%s: %.0f (%.1f%%)" % [seg["name"], seg["value"], seg["ratio"] * 100.0])
	_legend.text = "[center]%s[/center]" % "\n".join(lines)

func _draw() -> void:
	if _segments.is_empty():
		return
	var radius = min(size.x, size.y) * 0.45
	if radius < 8:
		return
	var center = size * 0.5
	draw_circle(center, radius, Color(0.15, 0.15, 0.15, 0.35))
	var start_angle = -PI / 2.0
	for seg in _segments:
		var sweep = seg["ratio"] * TAU
		if sweep <= 0:
			continue
		var pts: Array = [center]
		var steps = max(8, int(ceil(abs(sweep) / 0.15)))
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var a = start_angle + sweep * t
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_polygon(pts, _repeat_color(seg["color"], pts.size()))
		start_angle += sweep

func _repeat_color(c: Color, count: int) -> Array:
	var arr: Array = []
	for i in range(count):
		arr.append(c)
	return arr

#================ 辅助 =================#
func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	return default_val

func _to_int(v, fallback: int) -> int:
	match typeof(v):
		TYPE_INT: return v
		TYPE_FLOAT: return int(v)
		TYPE_STRING:
			var parsed = int(v)
			return parsed
		_: return fallback

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null
