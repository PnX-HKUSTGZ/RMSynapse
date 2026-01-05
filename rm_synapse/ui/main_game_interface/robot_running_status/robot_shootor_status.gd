extends Node2D

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")
@export var target_robot_id: int = -1
@export var current_heat: float = 0.0
@export var max_heat: float = 100.0
@export var radius: float = 50.0
@export var ring_width: float = 10.0

const BG_COLOR := Color(0.3, 0.3, 0.3, 0.6)
const CROSS_COLOR := Color(0.7, 0.7, 0.7, 0.9)

var _gs: Node = null

func _ready() -> void:
	_gs = _resolve_game_state()
	if _gs:
		if _gs.has_signal("robot_dynamic_status_updated"):
			_gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic"))
		if _gs.has_signal("robot_static_status_updated"):
			_gs.connect("robot_static_status_updated", Callable(self, "_on_static"))
	else:
		push_warning("[ShootorStatus] GameState not found at %s" % str(game_state_path))
	queue_redraw()

func set_heat(cur: float, maxv: float) -> void:
	current_heat = cur
	max_heat = max(1.0, maxv)
	queue_redraw()

func _on_static(value) -> void:
	var entry = _pick_entry(value)
	if entry:
		max_heat = float(_get_val(entry, "max_heat", max_heat))
		queue_redraw()

func _on_dynamic(value) -> void:
	var entry = _pick_entry(value)
	if entry:
		current_heat = float(_get_val(entry, "current_heat", current_heat))
		queue_redraw()

func _draw() -> void:
	var r = max(12.0, radius)
	var center = Vector2.ZERO
	var width = clamp(ring_width, 2.0, r * 0.4)

	# 背景环
	draw_arc(center, r, -PI, PI, 128, BG_COLOR, width)

	# 热量环（部分圆弧）
	var ratio = clamp(current_heat / max(max_heat, 0.0001), 0.0, 1.0)
	var color = _heat_color(ratio)
	var span = TAU * ratio
	if span > 0.0:
		draw_arc(center, r, -PI/2, -PI/2 + span, max(12, int(128 * ratio)), color, width)

	# 十字准星
	var arm = r * 0.35
	draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), CROSS_COLOR, 2.0)
	draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), CROSS_COLOR, 2.0)

func _heat_color(ratio: float) -> Color:
	# 0->绿 0.5->黄 1->红
	if ratio <= 0.5:
		return Color(0.2, 0.9, 0.3).lerp(Color(1, 0.85, 0.2), ratio / 0.5)
	return Color(1, 0.85, 0.2).lerp(Color(0.95, 0.2, 0.2), (ratio - 0.5) / 0.5)

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _pick_entry(data):
	if data == null:
		return null
	if typeof(data) == TYPE_DICTIONARY:
		if target_robot_id != -1 and data.has(target_robot_id):
			return data[target_robot_id]
		if _maybe_match(data):
			return data
		for v in data.values():
			if _maybe_match(v):
				return v
		return null
	if typeof(data) == TYPE_ARRAY:
		for v in data:
			if _maybe_match(v):
				return v
		return null
	if _maybe_match(data):
		return data
	return null

func _maybe_match(entry) -> bool:
	if target_robot_id == -1:
		return true
	var rid = _get_val(entry, "robot_id", -1)
	return rid == target_robot_id

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		if src.has(key_name):
			return src.get(key_name, default_val)
	if src == null:
		return default_val
	if src.has_method("get_" + key_name):
		return src.call("get_" + key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	push_warning("[ShootorStatus] missing key %s on %s, default %s" % [key_name, str(src), str(default_val)])
	return default_val
