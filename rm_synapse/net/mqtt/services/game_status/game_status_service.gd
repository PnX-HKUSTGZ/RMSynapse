extends Node
class_name GameStatusService

signal game_status_updated(state)
signal stage_changed(stage, stage_name)
signal score_changed(red_score, blue_score)
signal pause_state_changed(is_paused)

const STAGE_NAMES := [
	"未开始比赛",
	"准备阶段",
	"十五秒裁判系统自检阶段",
	"五秒倒计时",
	"比赛中",
	"比赛结算中"
]

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class GameStatusState:
	extends RefCounted
	var current_round: int = 0
	var total_rounds: int = 0
	var red_score: int = 0
	var blue_score: int = 0
	var current_stage: int = 0
	var current_stage_name: String = "未开始比赛"
	var stage_countdown_sec: int = 0
	var stage_elapsed_sec: int = 0
	var is_paused: bool = false
	var last_update_msec: int = 0

	func clone() -> GameStatusState:
		var c = GameStatusState.new()
		c.current_round = current_round
		c.total_rounds = total_rounds
		c.red_score = red_score
		c.blue_score = blue_score
		c.current_stage = current_stage
		c.current_stage_name = current_stage_name
		c.stage_countdown_sec = stage_countdown_sec
		c.stage_elapsed_sec = stage_elapsed_sec
		c.is_paused = is_paused
		c.last_update_msec = last_update_msec
		return c

	func to_dict() -> Dictionary:
		return {
			"current_round": current_round,
			"total_rounds": total_rounds,
			"red_score": red_score,
			"blue_score": blue_score,
			"current_stage": current_stage,
			"current_stage_name": current_stage_name,
			"stage_countdown_sec": stage_countdown_sec,
			"stage_elapsed_sec": stage_elapsed_sec,
			"is_paused": is_paused,
			"last_update_msec": last_update_msec
		}

var _state: GameStatusState = GameStatusState.new()
var _adapter_bound: bool = false
var _bound_adapter = null
var _logged_missing: bool = false
var _logged_null_message: bool = false
var _bind_retry_elapsed: float = 0.0

func _ready() -> void:
	_try_bind_adapter()
	set_process(true)

func _process(delta: float) -> void:
	var interval = maxf(bind_retry_interval_sec, 0.1)
	_bind_retry_elapsed += delta
	if _bind_retry_elapsed < interval:
		return
	_bind_retry_elapsed = 0.0
	_try_bind_adapter()

func _exit_tree() -> void:
	_disconnect_bound_adapter()

func clear_cache() -> void:
	var old_state = _state.clone()
	_state = GameStatusState.new()
	_state.current_stage_name = get_stage_name(_state.current_stage)
	_state.last_update_msec = Time.get_ticks_msec()
	_emit_change_signals(old_state)
	emit_signal("game_status_updated", _state.clone())

func ingest_game_status(message) -> void:
	_on_game_status(message)

func get_state() -> GameStatusState:
	return _state.clone()

func get_current_round() -> int:
	return _state.current_round

func get_total_rounds() -> int:
	return _state.total_rounds

func get_red_score() -> int:
	return _state.red_score

func get_blue_score() -> int:
	return _state.blue_score

func get_current_stage() -> int:
	return _state.current_stage

func get_current_stage_name() -> String:
	return _state.current_stage_name

func get_stage_countdown_sec() -> int:
	return _state.stage_countdown_sec

func get_stage_elapsed_sec() -> int:
	return _state.stage_elapsed_sec

func is_paused() -> bool:
	return _state.is_paused

func get_stage_name(stage: int) -> String:
	if stage >= 0 and stage < STAGE_NAMES.size():
		return STAGE_NAMES[stage]
	return "Unknown"

func _on_game_status(message) -> void:
	if message == null:
		if not _logged_null_message:
			_log_warn("[GameStatusService] Received null game_status message.")
			_logged_null_message = true
		return
	_logged_null_message = false

	var old_state = _state.clone()

	_state.current_round = int(message.get_current_round())
	_state.total_rounds = int(message.get_total_rounds())
	_state.red_score = int(message.get_red_score())
	_state.blue_score = int(message.get_blue_score())
	_state.current_stage = int(message.get_current_stage())
	_state.current_stage_name = get_stage_name(_state.current_stage)
	_state.stage_countdown_sec = int(message.get_stage_countdown_sec())
	_state.stage_elapsed_sec = int(message.get_stage_elapsed_sec())
	_state.is_paused = bool(message.get_is_paused())
	_state.last_update_msec = Time.get_ticks_msec()

	_emit_change_signals(old_state)
	emit_signal("game_status_updated", _state.clone())

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GameStatusService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = null
	if adapter_getter.has_method("get_adapter_silent"):
		adapter = adapter_getter.get_adapter_silent()
	else:
		adapter = adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GameStatusService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GameStatusService] Adapter getter returned non-object value")
			_logged_missing = true
		return
	if not adapter.has_signal("game_status"):
		_disconnect_bound_adapter()
		_adapter_bound = false
		if not _logged_missing:
			_log_error("[GameStatusService] Adapter is missing signal: game_status")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.game_status.is_connected(_on_game_status):
		adapter.game_status.connect(_on_game_status)
	_adapter_bound = true
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("game_status") and _bound_adapter.game_status.is_connected(_on_game_status):
			_bound_adapter.game_status.disconnect(_on_game_status)
	_bound_adapter = null

func _emit_change_signals(old_state: GameStatusState) -> void:
	if _state.current_stage != old_state.current_stage:
		emit_signal("stage_changed", _state.current_stage, _state.current_stage_name)
	if _state.red_score != old_state.red_score or _state.blue_score != old_state.blue_score:
		emit_signal("score_changed", _state.red_score, _state.blue_score)
	if _state.is_paused != old_state.is_paused:
		emit_signal("pause_state_changed", _state.is_paused)

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)

func _log_warn(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("warn"):
		logger.warn(message)
		return
	push_warning(message)
