extends Control

const BASE_MAX_HP: float = 5000.0
const BASE_MAX_SHIELD: float = 1500.0
const OUTPOST_MAX_HP: float = 750.0

const BASE_STATE_TEXT := ["无敌", "接敌", "护甲"]
const OUTPOST_STATE_TEXT := ["锁", "转", "停", "毁", "修", "候"]

var time_left: int = 420
var current_round: int = 2
var total_rounds: int = 5
var second_acc: float = 0.0

var scores := {"left": 0, "right": 0}
var bases := {
	"left": {"hp": 4200, "shield": 1500, "state": 0},
	"right": {"hp": 2800, "shield": 800, "state": 0}
}
var outposts := {
	"left": {"hp": 750, "state": 1},
	"right": {"hp": 0, "state": 3}
}
var stats := {
	"left": {"eco": 50, "total_eco": 300, "tech": 2, "radar": 3},
	"right": {"eco": 120, "total_eco": 450, "tech": 4, "radar": 5}
}
var robots := {
	"left": [
		{"id": 7, "hp": 600, "max": 600},
		{"id": 6, "hp": 500, "max": 500},
		{"id": 4, "hp": 200, "max": 400},
		{"id": 3, "hp": 400, "max": 400},
		{"id": 2, "hp": 150, "max": 400},
		{"id": 1, "hp": 2000, "max": 2000}
	],
	"right": [
		{"id": 1, "hp": 1800, "max": 2000},
		{"id": 2, "hp": 400, "max": 400},
		{"id": 3, "hp": 0, "max": 400},
		{"id": 4, "hp": 400, "max": 400},
		{"id": 6, "hp": 500, "max": 500},
		{"id": 7, "hp": 600, "max": 600}
	]
}

@onready var round_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/RoundBg
@onready var time_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/TimeBg
@onready var left_score_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftScore
@onready var right_score_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/RightScore
@onready var left_base_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftBase
@onready var right_base_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/RightBase
@onready var left_outpost_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftOutpost
@onready var right_outpost_bg: Control = $CanvasLayer/Margin/VBoxRoot/TopRow/RightOutpost
@onready var center_stats_bg: Control = $CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats

@onready var round_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/RoundBg/Center/RoundLabel
@onready var time_label_m: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/TimeBg/Center/TimeHBox/MinLabel
@onready var time_label_s: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/TimeBg/Center/TimeHBox/SecLabel
@onready var colon_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/CenterWrap/TimeBg/Center/TimeHBox/ColonLabel

@onready var score_label_l: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftScore/Center/ScoreLabel
@onready var score_label_r: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightScore/Center/ScoreLabel

@onready var left_base_state_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftBase/Content/StateLabel
@onready var left_base_hp_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftBase/Content/HpLabel
@onready var left_base_shield_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftBase/Content/ShieldLabel
@onready var right_base_state_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightBase/Content/StateLabel
@onready var right_base_hp_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightBase/Content/HpLabel
@onready var right_base_shield_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightBase/Content/ShieldLabel

@onready var left_outpost_icon_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftOutpost/Content/IconLabel
@onready var left_outpost_hp_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/LeftOutpost/Content/Text/HpLabel
@onready var right_outpost_icon_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightOutpost/Content/IconLabel
@onready var right_outpost_hp_label: Label = $CanvasLayer/Margin/VBoxRoot/TopRow/RightOutpost/Content/Text/HpLabel

@onready var eco_value_label: Label = $CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/EcoRow/EcoValue
@onready var tech_blocks: Array[ColorRect] = [
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/TechRow/Bars/B0,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/TechRow/Bars/B1,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/TechRow/Bars/B2,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/TechRow/Bars/B3
]
@onready var radar_blocks: Array[ColorRect] = [
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/Bars/B0,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/Bars/B1,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/Bars/B2,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/Bars/B3,
	$CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/Bars/B4
]

var left_robot_cards: Array[Control] = []
var right_robot_cards: Array[Control] = []
var left_robot_id_labels: Array[Label] = []
var right_robot_id_labels: Array[Label] = []
var left_robot_hp_labels: Array[Label] = []
var right_robot_hp_labels: Array[Label] = []

var blink_timer: float = 0.0
var colon_visible: bool = true

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	$CanvasLayer.layer = 100
	randomize()

	_setup_panels()
	_collect_robot_nodes()
	_style_static_labels()
	_connect_clickable_controls()
	_setup_responsive_layout()
	_update_all_ui()

func _process(delta: float) -> void:
	second_acc += delta
	while second_acc >= 1.0:
		second_acc -= 1.0
		_tick_one_second()

	blink_timer += delta
	if blink_timer >= 0.5:
		blink_timer = 0.0
		colon_visible = !colon_visible
		colon_label.modulate.a = 1.0 if colon_visible else 0.65

func _setup_panels() -> void:
	_register_panel(round_bg, "round")
	_register_panel(time_bg, "time")
	_register_panel(left_score_bg, "score", "left")
	_register_panel(right_score_bg, "score", "right")
	_register_panel(left_base_bg, "base", "left")
	_register_panel(right_base_bg, "base", "right")
	_register_panel(left_outpost_bg, "outpost", "left")
	_register_panel(right_outpost_bg, "outpost", "right")
	_register_panel(center_stats_bg, "stats")

func _register_panel(node: Control, panel_kind: String, side: String = "", index: int = -1) -> void:
	var draw_callable := Callable(self, "_on_panel_draw").bind(node, panel_kind, side, index)
	if not node.is_connected("draw", draw_callable):
		node.connect("draw", draw_callable)
	if not node.is_connected("resized", Callable(node, "queue_redraw")):
		node.connect("resized", Callable(node, "queue_redraw"))
	node.queue_redraw()

func _collect_robot_nodes() -> void:
	left_robot_cards.clear()
	right_robot_cards.clear()
	left_robot_id_labels.clear()
	right_robot_id_labels.clear()
	left_robot_hp_labels.clear()
	right_robot_hp_labels.clear()

	for child in $CanvasLayer/Margin/VBoxRoot/BottomRow/LeftRobots.get_children():
		if child is Control:
			var card := child as Control
			left_robot_cards.append(card)
			left_robot_id_labels.append(card.get_node("IdLabel") as Label)
			left_robot_hp_labels.append(card.get_node("HpLabel") as Label)
			_register_panel(card, "robot", "left", left_robot_cards.size() - 1)

	for child in $CanvasLayer/Margin/VBoxRoot/BottomRow/RightRobots.get_children():
		if child is Control:
			var card := child as Control
			right_robot_cards.append(card)
			right_robot_id_labels.append(card.get_node("IdLabel") as Label)
			right_robot_hp_labels.append(card.get_node("HpLabel") as Label)
			_register_panel(card, "robot", "right", right_robot_cards.size() - 1)

func _style_static_labels() -> void:
	_style_label(round_label, 14, Color(0.75, 0.96, 1.0), false)
	_style_label(time_label_m, 40, Color(0.98, 0.99, 1.0), true)
	_style_label(time_label_s, 40, Color(0.98, 0.99, 1.0), true)
	_style_label(colon_label, 33, Color(0.42, 0.92, 1.0), true)

	_style_label(score_label_l, 44, Color(0.98, 0.99, 1.0), true)
	_style_label(score_label_r, 44, Color(0.98, 0.99, 1.0), true)

	_style_label(left_base_state_label, 13, Color(1.0, 0.82, 0.82), true)
	_style_label(left_base_shield_label, 12, Color(0.45, 0.98, 0.6), true)
	_style_label(left_base_hp_label, 25, Color(1.0, 0.98, 0.98), true)
	_style_label(right_base_state_label, 13, Color(0.82, 0.9, 1.0), true)
	_style_label(right_base_shield_label, 12, Color(0.45, 0.98, 0.6), true)
	_style_label(right_base_hp_label, 25, Color(0.98, 0.99, 1.0), true)

	_style_label(left_outpost_icon_label, 16, Color(1.0, 0.86, 0.86), true)
	_style_label(left_outpost_hp_label, 17, Color(1.0, 0.9, 0.9), true)
	_style_label(right_outpost_icon_label, 16, Color(0.86, 0.92, 1.0), true)
	_style_label(right_outpost_hp_label, 17, Color(0.9, 0.95, 1.0), true)

	_style_label($CanvasLayer/Margin/VBoxRoot/TopRow/LeftOutpost/Content/Text/TitleLabel, 12, Color(1, 1, 1, 0.9), true)
	_style_label($CanvasLayer/Margin/VBoxRoot/TopRow/RightOutpost/Content/Text/TitleLabel, 12, Color(1, 1, 1, 0.9), true)

	_style_label($CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/EcoRow/EcoTitle, 10, Color(0.8, 0.9, 1.0), true)
	_style_label(eco_value_label, 13, Color(0.72, 0.86, 1.0), true)
	_style_label($CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/TechRow/TechTitle, 10, Color(0.8, 0.9, 1.0), true)
	_style_label($CanvasLayer/Margin/VBoxRoot/BottomRow/CenterStats/Content/Rows/RadarRow/RadarTitle, 10, Color(0.8, 0.9, 1.0), true)

	for label in left_robot_id_labels:
		_style_label(label, 15, Color(0.98, 0.99, 1.0), true)
	for label in right_robot_id_labels:
		_style_label(label, 15, Color(0.98, 0.99, 1.0), true)
	for label in left_robot_hp_labels:
		_style_label(label, 10, Color(1.0, 0.9, 0.9), true)
	for label in right_robot_hp_labels:
		_style_label(label, 10, Color(0.9, 0.95, 1.0), true)

func _connect_clickable_controls() -> void:
	_connect_click(left_score_bg, "_on_left_score_input")
	_connect_click(right_score_bg, "_on_right_score_input")
	_connect_click(left_base_bg, "_on_left_base_input")
	_connect_click(right_base_bg, "_on_right_base_input")
	_connect_click(left_outpost_bg, "_on_left_outpost_input")
	_connect_click(right_outpost_bg, "_on_right_outpost_input")

func _connect_click(node: Control, method_name: String) -> void:
	node.mouse_filter = MOUSE_FILTER_STOP
	node.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	var callable := Callable(self, method_name)
	if not node.is_connected("gui_input", callable):
		node.connect("gui_input", callable)

func _setup_responsive_layout() -> void:
	var resize_cb := Callable(self, "_on_root_resized")
	if not is_connected("resized", resize_cb):
		connect("resized", resize_cb)
	call_deferred("_apply_responsive_layout")

func _on_root_resized() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	_layout_base_labels("left")
	_layout_base_labels("right")
	_layout_robot_labels()

func _layout_base_labels(side: String) -> void:
	var box := left_base_bg if side == "left" else right_base_bg
	var state_label := left_base_state_label if side == "left" else right_base_state_label
	var shield_label := left_base_shield_label if side == "left" else right_base_shield_label
	var hp_label := left_base_hp_label if side == "left" else right_base_hp_label

	var w := box.size.x
	var h := box.size.y
	if w <= 0 or h <= 0:
		return

	var state_w := clampf(w * 0.22, 86.0, 130.0)
	var shield_w := clampf(w * 0.24, 100.0, 148.0)
	var hp_w := clampf(w * 0.32, 130.0, 190.0)
	var pad := 12.0

	if side == "left":
		state_label.offset_left = 12
		state_label.offset_top = 8
		state_label.offset_right = 12 + state_w
		state_label.offset_bottom = h - 6

		shield_label.offset_right = w - pad
		shield_label.offset_left = shield_label.offset_right - shield_w
		shield_label.offset_top = 5
		shield_label.offset_bottom = 22

		hp_label.offset_right = w - pad
		hp_label.offset_left = hp_label.offset_right - hp_w
		hp_label.offset_top = 18
		hp_label.offset_bottom = h - 2
	else:
		state_label.offset_right = w - 12
		state_label.offset_left = state_label.offset_right - state_w
		state_label.offset_top = 8
		state_label.offset_bottom = h - 6

		shield_label.offset_left = pad
		shield_label.offset_right = pad + shield_w
		shield_label.offset_top = 5
		shield_label.offset_bottom = 22

		hp_label.offset_left = pad
		hp_label.offset_right = pad + hp_w
		hp_label.offset_top = 18
		hp_label.offset_bottom = h - 2

func _layout_robot_labels() -> void:
	var left_count: int = mini(mini(left_robot_cards.size(), left_robot_id_labels.size()), left_robot_hp_labels.size())
	for i in range(left_count):
		var card := left_robot_cards[i]
		var id_label := left_robot_id_labels[i]
		var hp_label := left_robot_hp_labels[i]
		var w := card.size.x
		var h := card.size.y
		id_label.offset_left = 7
		id_label.offset_top = 1
		id_label.offset_right = 25
		id_label.offset_bottom = 17
		hp_label.offset_left = w - 38
		hp_label.offset_top = h - 15
		hp_label.offset_right = w - 4
		hp_label.offset_bottom = h - 1

	var right_count: int = mini(mini(right_robot_cards.size(), right_robot_id_labels.size()), right_robot_hp_labels.size())
	for i in range(right_count):
		var card := right_robot_cards[i]
		var id_label := right_robot_id_labels[i]
		var hp_label := right_robot_hp_labels[i]
		var w := card.size.x
		var h := card.size.y
		id_label.offset_left = w - 24
		id_label.offset_top = 1
		id_label.offset_right = w - 6
		id_label.offset_bottom = 17
		hp_label.offset_left = 4
		hp_label.offset_top = h - 15
		hp_label.offset_right = 38
		hp_label.offset_bottom = h - 1

func _tick_one_second() -> void:
	if time_left > 0:
		time_left -= 1

	var left_list: Array = robots["left"]
	for i in range(left_list.size()):
		if randf() > 0.8:
			left_list[i]["hp"] = max(0, int(left_list[i]["hp"]) - 10)

	var right_list: Array = robots["right"]
	for i in range(right_list.size()):
		if randf() > 0.8:
			right_list[i]["hp"] = max(0, int(right_list[i]["hp"]) - 15)

	_update_all_ui()

func _update_all_ui() -> void:
	_apply_responsive_layout()
	_update_time_and_round()
	_update_scores()
	_update_base("left")
	_update_base("right")
	_update_outpost("left")
	_update_outpost("right")
	_update_robots("left")
	_update_robots("right")
	_update_stats()
	_queue_dynamic_panels()

func _update_time_and_round() -> void:
	round_label.text = "Round %d/%d" % [current_round, total_rounds]
	time_label_m.text = "%02d" % int(time_left / 60)
	time_label_s.text = "%02d" % int(time_left % 60)

func _update_scores() -> void:
	score_label_l.text = str(scores.left)
	score_label_r.text = str(scores.right)

func _update_base(side: String) -> void:
	var base: Dictionary = bases[side]
	var state_idx := clampi(int(base["state"]), 0, BASE_STATE_TEXT.size() - 1)
	if side == "left":
		left_base_state_label.text = BASE_STATE_TEXT[state_idx]
		left_base_hp_label.text = str(base["hp"])
		left_base_shield_label.text = str(base["shield"])
	else:
		right_base_state_label.text = BASE_STATE_TEXT[state_idx]
		right_base_hp_label.text = str(base["hp"])
		right_base_shield_label.text = str(base["shield"])

func _update_outpost(side: String) -> void:
	var outpost: Dictionary = outposts[side]
	var state_idx := clampi(int(outpost["state"]), 0, OUTPOST_STATE_TEXT.size() - 1)
	if side == "left":
		left_outpost_icon_label.text = OUTPOST_STATE_TEXT[state_idx]
		left_outpost_hp_label.text = str(outpost["hp"])
	else:
		right_outpost_icon_label.text = OUTPOST_STATE_TEXT[state_idx]
		right_outpost_hp_label.text = str(outpost["hp"])

func _update_robots(side: String) -> void:
	var list: Array = robots[side]
	var id_labels: Array[Label] = left_robot_id_labels if side == "left" else right_robot_id_labels
	var hp_labels: Array[Label] = left_robot_hp_labels if side == "left" else right_robot_hp_labels

	for i in range(mini(list.size(), id_labels.size())):
		var robot: Dictionary = list[i]
		id_labels[i].text = str(robot["id"])
		hp_labels[i].text = str(robot["hp"])

func _update_stats() -> void:
	var s: Dictionary = stats["right"]
	eco_value_label.text = "%d/%d" % [int(s["eco"]), int(s["total_eco"])]

	var tech := clampi(int(s["tech"]), 0, tech_blocks.size())
	var radar := clampi(int(s["radar"]), 0, radar_blocks.size())
	for i in range(tech_blocks.size()):
		tech_blocks[i].color = Color(0.4, 0.72, 1.0, 0.95) if i < tech else Color(0.1, 0.14, 0.2, 0.9)
	for i in range(radar_blocks.size()):
		radar_blocks[i].color = Color(0.4, 0.72, 1.0, 0.95) if i < radar else Color(0.1, 0.14, 0.2, 0.9)

func _queue_dynamic_panels() -> void:
	left_base_bg.queue_redraw()
	right_base_bg.queue_redraw()
	left_outpost_bg.queue_redraw()
	right_outpost_bg.queue_redraw()
	left_score_bg.queue_redraw()
	right_score_bg.queue_redraw()
	for card in left_robot_cards:
		card.queue_redraw()
	for card in right_robot_cards:
		card.queue_redraw()

func _on_panel_draw(node: Control, panel_kind: String, side: String, index: int) -> void:
	match panel_kind:
		"round":
			_draw_round(node)
		"time":
			_draw_time(node)
		"score":
			_draw_score(node, side)
		"base":
			_draw_base(node, side)
		"outpost":
			_draw_outpost(node, side)
		"robot":
			_draw_robot(node, side, index)
		"stats":
			_draw_stats(node)

func _draw_round(node: Control) -> void:
	var w := node.size.x
	var h := node.size.y
	var d := h * 0.45
	var pts := PackedVector2Array([
		Vector2(d, 0),
		Vector2(w - d, 0),
		Vector2(w, h),
		Vector2(0, h)
	])
	node.draw_colored_polygon(pts, Color(0.06, 0.14, 0.2, 0.96))
	_draw_outline(node, pts, Color(0.45, 0.94, 1.0, 0.55), 1.6)
	node.draw_line(pts[0], pts[1], Color(0.65, 0.98, 1.0, 0.55), 1.6, true)

func _draw_time(node: Control) -> void:
	var w := node.size.x
	var h := node.size.y
	var d := h * 0.22
	var pts := PackedVector2Array([
		Vector2(0, 0),
		Vector2(w, 0),
		Vector2(w - d, h),
		Vector2(d, h)
	])
	node.draw_colored_polygon(pts, Color(0.05, 0.1, 0.16, 0.94))
	_draw_outline(node, pts, Color(0.42, 0.9, 1.0, 0.56), 1.9)
	node.draw_line(pts[3], pts[2], Color(0.45, 0.95, 1.0, 1.0), 3.2, true)

func _draw_score(node: Control, side: String) -> void:
	var w := node.size.x
	var h := node.size.y
	var d := h * 0.34
	var pts := PackedVector2Array()
	if side == "left":
		pts.append_array([Vector2(0, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(d, h)])
	else:
		pts.append_array([Vector2(d, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(0, h)])
	var edge := Color(1.0, 0.38, 0.38, 0.66) if side == "left" else Color(0.42, 0.72, 1.0, 0.66)
	node.draw_colored_polygon(pts, Color(0.03, 0.06, 0.1, 0.82))
	_draw_outline(node, pts, edge, 1.5)

func _draw_base(node: Control, side: String) -> void:
	var data: Dictionary = bases[side]
	var hp_pct := clampf(float(data["hp"]) / BASE_MAX_HP, 0.0, 1.0)
	var sh_pct := clampf(float(data["shield"]) / BASE_MAX_SHIELD, 0.0, 1.0)

	var team_primary := Color(0.92, 0.2, 0.2, 0.55) if side == "left" else Color(0.22, 0.5, 0.95, 0.55)
	var team_line := Color(1.0, 0.35, 0.35, 0.65) if side == "left" else Color(0.35, 0.65, 1.0, 0.65)

	var w := node.size.x
	var h := node.size.y
	var d := h * 0.35
	var pts := PackedVector2Array()
	if side == "left":
		pts.append_array([Vector2(0, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(d, h)])
	else:
		pts.append_array([Vector2(d, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(0, h)])

	node.draw_colored_polygon(pts, Color(0.03, 0.07, 0.11, 0.86))

	if side == "left":
		var hp_w_l := w * hp_pct
		node.draw_rect(Rect2(w - hp_w_l, 6, hp_w_l, h - 6), team_primary, true)
		var sh_w_l := w * sh_pct
		node.draw_rect(Rect2(w - sh_w_l, 0, sh_w_l, 5), Color(0.2, 0.95, 0.35, 0.95), true)
	else:
		var hp_w_r := w * hp_pct
		node.draw_rect(Rect2(0, 6, hp_w_r, h - 6), team_primary, true)
		var sh_w_r := w * sh_pct
		node.draw_rect(Rect2(0, 0, sh_w_r, 5), Color(0.2, 0.95, 0.35, 0.95), true)

	node.draw_rect(Rect2(0, 0, w, 10), Color(0, 0, 0, 0.22), true)
	_draw_outline(node, pts, team_line, 1.4)

func _draw_outpost(node: Control, side: String) -> void:
	var data: Dictionary = outposts[side]
	var hp_pct := clampf(float(data["hp"]) / OUTPOST_MAX_HP, 0.0, 1.0)
	var team_fill := Color(0.9, 0.18, 0.18, 0.5) if side == "left" else Color(0.2, 0.45, 0.9, 0.5)
	var team_line := Color(1.0, 0.35, 0.35, 0.5) if side == "left" else Color(0.35, 0.65, 1.0, 0.5)

	var w := node.size.x
	var h := node.size.y
	var d := h * 0.42
	var pts := PackedVector2Array()
	if side == "left":
		pts.append_array([Vector2(0, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(d, h)])
	else:
		pts.append_array([Vector2(d, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(0, h)])

	node.draw_colored_polygon(pts, Color(0.03, 0.07, 0.11, 0.84))
	if side == "left":
		var fill_w_l := w * hp_pct
		node.draw_rect(Rect2(w - fill_w_l, 4, fill_w_l, h - 4), team_fill, true)
	else:
		var fill_w_r := w * hp_pct
		node.draw_rect(Rect2(0, 4, fill_w_r, h - 4), team_fill, true)
	_draw_outline(node, pts, team_line, 1.35)

func _draw_robot(node: Control, side: String, index: int) -> void:
	var list: Array = robots[side]
	if index < 0 or index >= list.size():
		return
	var robot: Dictionary = list[index]
	var hp_pct := clampf(float(robot["hp"]) / maxf(1.0, float(robot["max"])), 0.0, 1.0)
	var dead := int(robot["hp"]) <= 0

	var w := node.size.x
	var h := node.size.y
	var d := h * 0.35
	var pts := PackedVector2Array()
	if side == "left":
		pts.append_array([Vector2(0, 0), Vector2(w - d, 0), Vector2(w, h), Vector2(d, h)])
	else:
		pts.append_array([Vector2(d, 0), Vector2(w, 0), Vector2(w - d, h), Vector2(0, h)])

	node.draw_colored_polygon(pts, Color(0.03, 0.06, 0.11, 0.8))
	if dead:
		node.draw_rect(Rect2(0, 6, w * hp_pct, h - 6), Color(0.45, 0.45, 0.45, 0.36), true)
		_draw_outline(node, pts, Color(0.6, 0.6, 0.6, 0.62), 1.3)
	else:
		if side == "left":
			node.draw_rect(Rect2(0, 6, w * hp_pct, h - 6), Color(0.95, 0.22, 0.22, 0.36), true)
			_draw_outline(node, pts, Color(1.0, 0.4, 0.4, 0.78), 1.3)
		else:
			node.draw_rect(Rect2(w * (1.0 - hp_pct), 6, w * hp_pct, h - 6), Color(0.22, 0.52, 0.95, 0.36), true)
			_draw_outline(node, pts, Color(0.42, 0.74, 1.0, 0.78), 1.3)

func _draw_stats(node: Control) -> void:
	var rect := Rect2(Vector2.ZERO, node.size)
	node.draw_rect(rect, Color(0.02, 0.05, 0.1, 0.86), true)
	node.draw_rect(Rect2(0, 0, node.size.x, 1), Color(0.42, 0.74, 1.0, 0.58), true)
	node.draw_rect(Rect2(0, node.size.y - 1, node.size.x, 1), Color(0.42, 0.74, 1.0, 0.38), true)
	node.draw_rect(Rect2(0, 0, 1, node.size.y), Color(0.42, 0.74, 1.0, 0.3), true)
	node.draw_rect(Rect2(node.size.x - 1, 0, 1, node.size.y), Color(0.42, 0.74, 1.0, 0.3), true)

func _draw_scanlines(node: Control, color: Color) -> void:
	var y := 0.0
	while y < node.size.y:
		node.draw_line(Vector2(0, y), Vector2(node.size.x, y), color, 1.0)
		y += 4.0

func _draw_outline(node: Control, pts: PackedVector2Array, color: Color, width: float) -> void:
	var outline := pts.duplicate()
	outline.push_back(pts[0])
	node.draw_polyline(outline, color, width, true)

func _style_label(label: Label, size: int, color: Color, is_bold: bool = false) -> void:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.shadow_size = 2
	settings.shadow_color = Color(0, 0, 0, 0.75)
	settings.outline_size = 1
	settings.outline_color = Color(0, 0, 0, 0.9)

	var sys_font := SystemFont.new()
	sys_font.font_names = ["SF Pro Display", "Helvetica Neue", "Arial Black", "Impact", "sans-serif"]
	sys_font.font_weight = 900 if is_bold else 700
	settings.font = sys_font
	label.label_settings = settings

func _on_left_score_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		scores.left += 1
		_update_scores()
		left_score_bg.queue_redraw()

func _on_right_score_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		scores.right += 1
		_update_scores()
		right_score_bg.queue_redraw()

func _on_left_base_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		bases["left"]["state"] = (int(bases["left"]["state"]) + 1) % 3
		_update_base("left")
		left_base_bg.queue_redraw()

func _on_right_base_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		bases["right"]["state"] = (int(bases["right"]["state"]) + 1) % 3
		_update_base("right")
		right_base_bg.queue_redraw()

func _on_left_outpost_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		outposts["left"]["state"] = (int(outposts["left"]["state"]) + 1) % 6
		if int(outposts["left"]["state"]) >= 3:
			outposts["left"]["hp"] = 0
		else:
			outposts["left"]["hp"] = int(OUTPOST_MAX_HP)
		_update_outpost("left")
		left_outpost_bg.queue_redraw()

func _on_right_outpost_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		outposts["right"]["state"] = (int(outposts["right"]["state"]) + 1) % 6
		if int(outposts["right"]["state"]) >= 3:
			outposts["right"]["hp"] = 0
		else:
			outposts["right"]["hp"] = int(OUTPOST_MAX_HP)
		_update_outpost("right")
		right_outpost_bg.queue_redraw()
