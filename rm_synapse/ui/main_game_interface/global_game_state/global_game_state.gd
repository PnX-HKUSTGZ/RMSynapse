extends Node2D

const STAGE_NAME := {
	0: "未开始比赛",
	1: "准备阶段",
	2: "十五秒裁判系统自检",
	3: "五秒倒计时",
	4: "比赛中",
	5: "比赛结束"
}

const STAGE_NOT_STARTED := 0
const STAGE_PREPARE := 1
const STAGE_SELF_CHECK := 2
const STAGE_COUNTDOWN_5S := 3
const STAGE_IN_PROGRESS := 4
const STAGE_FINISHED := 5


@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _round_label: RichTextLabel = $Round
@onready var _main_time: RichTextLabel = $MainGameTime
@onready var _red_score: RichTextLabel = $RedScore
@onready var _blue_score: RichTextLabel = $BlueScore
@onready var _other_panel: Node = $OtherGameStateShow
@onready var _other_name: RichTextLabel = $OtherGameStateShow/OtherStatusName
@onready var _other_time: RichTextLabel = $OtherGameStateShow/OtherStatusTime
var _gs: Node = null

func _ready() -> void:
	_reset_ui()
	_gs = _resolve_game_state()
	if not _gs:
		push_error("Failed to resolve game state node at path: %s" % str(game_state_path))
		return
	if _gs and _gs.has_signal("game_status_updated"):
		print("Connected to game state signals.")
		_gs.connect("game_status_updated", Callable(self, "update_game_status"))
		print("GlobalGameState initialized, game_state_path=%s, gs=%s" % [str(game_state_path), str(_gs)])
	else:
		push_error("Game state node has no signal 'game_status_updated'")

func update_game_status(status) -> void:
	print("Updating game status: %s" % str(status))
	# status 可为 Dictionary 或 rm_proto.GameStatus
	var cur_round = _get_val(status, "current_round", 0)
	var total_rounds = _get_val(status, "total_rounds", 0)
	var red = _get_val(status, "red_score", 0)
	var blue = _get_val(status, "blue_score", 0)
	var stage = _get_val(status, "current_stage", 0)
	var cd = _get_val(status, "stage_countdown_sec", 0)
	var _elapsed = _get_val(status, "stage_elapsed_sec", 0)
	var paused = _get_val(status, "is_paused", false)

	_round_label.text = "Round %d/%d" % [cur_round, total_rounds]
	_red_score.text = str(red)
	_blue_score.text = str(blue)

	# 比赛中才显示主计时，否则 --/--
	if stage == STAGE_IN_PROGRESS:
		_main_time.text = _format_time(cd)
	else:
		_main_time.text = "--/--"

	# 非比赛中显示其他状态面板
	_other_panel.visible = stage != STAGE_IN_PROGRESS
	_other_name.text = STAGE_NAME.get(stage, "未知状态")

	if stage in [STAGE_PREPARE, STAGE_SELF_CHECK, STAGE_COUNTDOWN_5S]:
		_other_time.text = _format_time(cd)
	else:
		_other_time.text = "--/--"

	if paused:
		_other_name.text += " (暂停)"

func _format_time(sec_val) -> String:
	if typeof(sec_val) != TYPE_INT and typeof(sec_val) != TYPE_FLOAT:
		return "--/--"
	var secs: int = int(sec_val)
	if secs < 0:
		secs = 0
	var m: int = int(secs / 60.0)
	var s: int = secs % 60
	return "%02d:%02d" % [m, s]

func _get_val(src, key_name: String, default_val):
	if typeof(src) == TYPE_DICTIONARY:
		return src.get(key_name, default_val)
	if src == null:
		push_warning("[_get_val] src null, key=%s -> default=%s" % [key_name, str(default_val)])
		return default_val
	if src.has_method("get_"+key_name):
		return src.call("get_"+key_name)
	if src.has_method("has") and src.has(key_name):
		return src.get(key_name)
	print("[_get_val] key=%s not found on %s, use default=%s" % [key_name, str(src), str(default_val)])
	return default_val

func _resolve_game_state() -> Node:
	if game_state_path != NodePath("") and has_node(game_state_path):
		return get_node(game_state_path)
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return null

func _reset_ui() -> void:
	_round_label.text = "Round -/-"
	_main_time.text = "--/--"
	_red_score.text = "0"
	_blue_score.text = "0"
	_other_panel.visible = true
	_other_name.text = STAGE_NAME.get(STAGE_NOT_STARTED, "未开始比赛")
	_other_time.text = "--/--"
