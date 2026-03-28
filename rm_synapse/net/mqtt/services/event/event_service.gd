extends Node
class_name EventService

signal kill_event(victim_id, killer_id)
signal outpost_destroyed(target_id)
signal big_rune_active_arms_changed(arms_count, avg_rings)
signal energy_mech_activated(activate_type)
signal ally_hero_sniper_damage(total_damage)
signal enemy_hero_sniper_damage(total_damage)
signal enemy_air_support_called()
signal enemy_air_support_countered(remaining)
signal dart_hit(hit_team, target)
signal enemy_dart_gate_opened()
signal base_under_attack()
signal enemy_outpost_stopped()
signal enemy_base_armor_deployed()
signal enemy_requested_level4_assembly()
signal assembly_result(result_code)

enum EventId {
	KILL_EVENT = 1,
	OUTPOST_DESTROYED = 2,
	BIG_RUNE_ACTIVE_ARMS_CHANGED = 3,
	ENERGY_MECH_ACTIVATED = 4,
	ALLY_HERO_SNIPER_DAMAGE = 5,
	ENEMY_HERO_SNIPER_DAMAGE = 6,
	ENEMY_AIR_SUPPORT_CALLED = 7,
	ENEMY_AIR_SUPPORT_COUNTERED = 8,
	DART_HIT = 9,
	ENEMY_DART_GATE_OPENED = 10,
	BASE_UNDER_ATTACK = 11,
	ENEMY_OUTPOST_STOPPED = 12,
	ENEMY_BASE_ARMOR_DEPLOYED = 13,
	ENEMY_REQUESTED_LEVEL4_ASSEMBLY = 14,
	ASSEMBLY_RESULT = 15,
}

enum HitTeam {
	UNKNOWN = 0,
	RED = 1,
	BLUE = 2,
}

enum DartHitTarget {
	UNKNOWN = 0,
	OUTPOST = 1,
	BASE_FIXED_TARGET = 2,
	BASE_RANDOM_FIXED_TARGET = 3,
	BASE_RANDOM_MOVING_TARGET = 4,
	BASE_TERMINAL_MOVING_TARGET = 5,
}

enum AssemblyResult {
	SUCCESS = 0,
	PULLED_OUT = 1,
	TIMEOUT = 2,
	LEFT_ASSEMBLY_AREA_TOO_LONG = 3,
	ENGINEER_DESTROYED = 4,
	LEVEL4_COLLAB_TIMEOUT = 5,
	ABORTED = 6,
	NO_ENERGY_UNIT_ON_SETTLEMENT = 7,
	BUFFER_TIMEOUT_FORCED_END = 8,
}

const EVENT_NAMES := {
	EventId.KILL_EVENT: "Kill Event",
	EventId.OUTPOST_DESTROYED: "Outpost Destroyed",
	EventId.BIG_RUNE_ACTIVE_ARMS_CHANGED: "Big Rune Active Arms Changed",
	EventId.ENERGY_MECH_ACTIVATED: "Energy Mechanism Activated",
	EventId.ALLY_HERO_SNIPER_DAMAGE: "Ally Hero Sniper Damage",
	EventId.ENEMY_HERO_SNIPER_DAMAGE: "Enemy Hero Sniper Damage",
	EventId.ENEMY_AIR_SUPPORT_CALLED: "Enemy Air Support Called",
	EventId.ENEMY_AIR_SUPPORT_COUNTERED: "Enemy Air Support Countered",
	EventId.DART_HIT: "Dart Hit",
	EventId.ENEMY_DART_GATE_OPENED: "Enemy Dart Gate Opened",
	EventId.BASE_UNDER_ATTACK: "Base Under Attack",
	EventId.ENEMY_OUTPOST_STOPPED: "Enemy Outpost Stopped",
	EventId.ENEMY_BASE_ARMOR_DEPLOYED: "Enemy Base Armor Deployed",
	EventId.ENEMY_REQUESTED_LEVEL4_ASSEMBLY: "Enemy Requested Level4 Assembly",
	EventId.ASSEMBLY_RESULT: "Assembly Result",
}

@export var bind_retry_interval_sec: float = 1.0

var adapter_getter: MQTTProtocolAdapterGetter = MQTTProtocolAdapterGetter.new()

class KillEventInfo:
	extends RefCounted
	var victim_id: int = -1
	var killer_id: int = -1

class DestroyEventInfo:
	extends RefCounted
	var target_id: int = -1

class DartHitEventInfo:
	extends RefCounted
	var hit_team: int = HitTeam.UNKNOWN
	var target: int = DartHitTarget.UNKNOWN

var _kill_events: Array = []
var _destroy_events: Array = []
var _dart_hit_events: Array = []

var _big_rune_active_arms_count: int = 0
var _big_rune_average_rings: float = 0.0
var _ally_sniper_damage_total: int = 0
var _enemy_sniper_damage_total: int = 0
var _ally_air_support_counter_left: int = 0
var _last_assembly_result: int = -1

var _bound_adapter = null
var _logged_missing: bool = false
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

func ingest_event(event_id: int, param: String = "") -> void:
	_handle_event(event_id, param)

func clear_cache() -> void:
	_kill_events.clear()
	_destroy_events.clear()
	_dart_hit_events.clear()
	_big_rune_active_arms_count = 0
	_big_rune_average_rings = 0.0
	_ally_sniper_damage_total = 0
	_enemy_sniper_damage_total = 0
	_ally_air_support_counter_left = 0
	_last_assembly_result = -1

func get_kill_events() -> Array:
	return _kill_events.duplicate()

func get_destroy_events() -> Array:
	return _destroy_events.duplicate()

func get_dart_hit_events() -> Array:
	return _dart_hit_events.duplicate()

func get_big_rune_active_arms_count() -> int:
	return _big_rune_active_arms_count

func get_big_rune_average_rings() -> float:
	return _big_rune_average_rings

func get_ally_sniper_damage_total() -> int:
	return _ally_sniper_damage_total

func get_enemy_sniper_damage_total() -> int:
	return _enemy_sniper_damage_total

func get_ally_air_support_counter_left() -> int:
	return _ally_air_support_counter_left

func get_last_assembly_result() -> int:
	return _last_assembly_result

func get_event_name(event_id: int) -> String:
	return String(EVENT_NAMES.get(event_id, "Unknown"))

func _on_event_message(message) -> void:
	if message == null:
		return
	_handle_event(int(message.get_event_id()), str(message.get_param()))

func _handle_event(event_id: int, param: String) -> void:
	match event_id:
		EventId.KILL_EVENT:
			_handle_kill_event(param)
		EventId.OUTPOST_DESTROYED:
			_handle_destroy_event(param)
		EventId.BIG_RUNE_ACTIVE_ARMS_CHANGED:
			_handle_big_rune_active_arms_changed(param)
		EventId.ENERGY_MECH_ACTIVATED:
			emit_signal("energy_mech_activated", _parse_csv_int(param, 0, 0))
		EventId.ALLY_HERO_SNIPER_DAMAGE:
			_ally_sniper_damage_total = _parse_csv_int(param, 0, 0)
			emit_signal("ally_hero_sniper_damage", _ally_sniper_damage_total)
		EventId.ENEMY_HERO_SNIPER_DAMAGE:
			_enemy_sniper_damage_total = _parse_csv_int(param, 0, 0)
			emit_signal("enemy_hero_sniper_damage", _enemy_sniper_damage_total)
		EventId.ENEMY_AIR_SUPPORT_CALLED:
			emit_signal("enemy_air_support_called")
		EventId.ENEMY_AIR_SUPPORT_COUNTERED:
			_ally_air_support_counter_left = _parse_csv_int(param, 0, 0)
			emit_signal("enemy_air_support_countered", _ally_air_support_counter_left)
		EventId.DART_HIT:
			_handle_dart_hit(param)
		EventId.ENEMY_DART_GATE_OPENED:
			emit_signal("enemy_dart_gate_opened")
		EventId.BASE_UNDER_ATTACK:
			emit_signal("base_under_attack")
		EventId.ENEMY_OUTPOST_STOPPED:
			emit_signal("enemy_outpost_stopped")
		EventId.ENEMY_BASE_ARMOR_DEPLOYED:
			emit_signal("enemy_base_armor_deployed")
		EventId.ENEMY_REQUESTED_LEVEL4_ASSEMBLY:
			emit_signal("enemy_requested_level4_assembly")
		EventId.ASSEMBLY_RESULT:
			_last_assembly_result = _parse_csv_int(param, 0, -1)
			emit_signal("assembly_result", _last_assembly_result)
		_:
			pass

func _handle_kill_event(param: String) -> void:
	var info = KillEventInfo.new()
	info.victim_id = _parse_csv_int(param, 0, -1)
	info.killer_id = _parse_csv_int(param, 1, -1)
	_kill_events.append(info)
	emit_signal("kill_event", info.victim_id, info.killer_id)

func _handle_destroy_event(param: String) -> void:
	var info = DestroyEventInfo.new()
	info.target_id = _parse_csv_int(param, 0, -1)
	_destroy_events.append(info)
	emit_signal("outpost_destroyed", info.target_id)

func _handle_big_rune_active_arms_changed(param: String) -> void:
	_big_rune_active_arms_count = _parse_csv_int(param, 0, 0)
	_big_rune_average_rings = _parse_csv_float(param, 1, 0.0)
	emit_signal("big_rune_active_arms_changed", _big_rune_active_arms_count, _big_rune_average_rings)

func _handle_dart_hit(param: String) -> void:
	var info = DartHitEventInfo.new()
	info.hit_team = _normalize_hit_team(_parse_csv_int(param, 0, 0))
	info.target = _normalize_dart_hit_target(_parse_csv_int(param, 1, 0))
	_dart_hit_events.append(info)
	emit_signal("dart_hit", info.hit_team, info.target)

func _normalize_hit_team(value: int) -> int:
	if value == HitTeam.RED or value == HitTeam.BLUE:
		return value
	return HitTeam.UNKNOWN

func _normalize_dart_hit_target(value: int) -> int:
	if value >= DartHitTarget.OUTPOST and value <= DartHitTarget.BASE_TERMINAL_MOVING_TARGET:
		return value
	return DartHitTarget.UNKNOWN

func _parse_csv_int(param: String, index: int, default_val: int) -> int:
	var token = _get_csv_token(param, index)
	if token == "":
		return default_val
	if token.is_valid_int():
		return token.to_int()
	if token.is_valid_float():
		return int(token.to_float())
	return default_val

func _parse_csv_float(param: String, index: int, default_val: float) -> float:
	var token = _get_csv_token(param, index)
	if token == "":
		return default_val
	if token.is_valid_float() or token.is_valid_int():
		return token.to_float()
	return default_val

func _get_csv_token(param: String, index: int) -> String:
	if param == null:
		return ""
	var text = str(param).strip_edges()
	if text == "":
		return ""
	var parts = text.split(",", false)
	if index < 0 or index >= parts.size():
		return ""
	return String(parts[index]).strip_edges()

func _try_bind_adapter() -> void:
	if adapter_getter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[EventService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = null
	if adapter_getter.has_method("get_adapter_silent"):
		adapter = adapter_getter.get_adapter_silent()
	else:
		adapter = adapter_getter.get_adapter()
	if adapter == null:
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[EventService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	if not (adapter is Object):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[EventService] Adapter getter returned non-object value.")
			_logged_missing = true
		return
	if not adapter.has_signal("event_message"):
		_disconnect_bound_adapter()
		if not _logged_missing:
			_log_error("[EventService] Adapter is missing signal: event_message.")
			_logged_missing = true
		return
	if _bound_adapter != adapter:
		_disconnect_bound_adapter()
		_bound_adapter = adapter
	if not adapter.event_message.is_connected(_on_event_message):
		adapter.event_message.connect(_on_event_message)
	_logged_missing = false

func _disconnect_bound_adapter() -> void:
	if _bound_adapter == null:
		return
	if is_instance_valid(_bound_adapter):
		if _bound_adapter.has_signal("event_message") and _bound_adapter.event_message.is_connected(_on_event_message):
			_bound_adapter.event_message.disconnect(_on_event_message)
	_bound_adapter = null

func _log_error(message: String) -> void:
	var logger = get_node_or_null("/root/Log")
	if logger != null and logger.has_method("error"):
		logger.error(message)
		return
	push_error(message)
