extends Node
class_name EventService

signal event_received(event_data: Dictionary)

signal kill_event(killer_id, victim_id)
signal base_or_outpost_destroyed(target_id)
signal energy_activation_count_changed(count)
signal energy_mech_entered_active_state()
signal energy_mech_active_arms_changed(arms_count, avg_rings)
signal energy_mech_activated(activate_type)
signal ally_hero_deploy_mode()
signal ally_hero_sniper_damage(total_damage)
signal enemy_hero_sniper_damage(total_damage)
signal ally_air_support_called()
signal enemy_air_support_called()
signal ally_air_support_interrupted(remaining)
signal enemy_air_support_interrupted(remaining)
signal dart_hit(target)
signal dart_gate_opened(side)
signal ally_base_under_attack()
signal outpost_stopped(side)
signal base_armor_deployed(side)

enum EventId {
	KILL_EVENT = 1,
	BASE_OR_OUTPOST_DESTROYED = 2,
	ENERGY_MECH_ACTIVATION_COUNT_CHANGED = 3,
	ENERGY_MECH_ENTERED_ACTIVE_STATE = 4,
	ENERGY_MECH_ACTIVE_ARMS_CHANGED = 5,
	ENERGY_MECH_ACTIVATED = 6,
	ALLY_HERO_DEPLOY_MODE = 7,
	ALLY_HERO_SNIPER_DAMAGE = 8,
	ENEMY_HERO_SNIPER_DAMAGE = 9,
	ALLY_AIR_SUPPORT_CALLED = 10,
	ALLY_AIR_SUPPORT_INTERRUPTED = 11,
	ENEMY_AIR_SUPPORT_CALLED = 12,
	ENEMY_AIR_SUPPORT_INTERRUPTED = 13,
	DART_HIT = 14,
	BOTH_DART_GATE_OPENED = 15,
	ALLY_BASE_UNDER_ATTACK = 16,
	BOTH_OUTPOST_STOPPED = 17,
	BOTH_BASE_ARMOR_DEPLOYED = 18
}

enum Side {
	UNKNOWN = 0,
	RED = 1,
	BLUE = 2,
	BOTH = 3
}

enum DartHitTarget {
	UNKNOWN = 0,
	RED_HERO = 1,
	RED_ENGINEER = 2,
	RED_INFANTRY_3 = 3,
	RED_INFANTRY_4 = 4,
	RED_INFANTRY_5 = 5,
	RED_AERIAL = 6,
	RED_SENTRY = 7,
	RED_DART = 8,
	RED_RADAR = 9,
	RED_OUTPOST = 10,
	RED_BASE = 11,
	BLUE_HERO = 101,
	BLUE_ENGINEER = 102,
	BLUE_INFANTRY_3 = 103,
	BLUE_INFANTRY_4 = 104,
	BLUE_INFANTRY_5 = 105,
	BLUE_AERIAL = 106,
	BLUE_SENTRY = 107,
	BLUE_DART = 108,
	BLUE_RADAR = 109,
	BLUE_OUTPOST = 110,
	BLUE_BASE = 111
}

const EVENT_NAMES := [
	"Unknown",
	"Kill Event",
	"Base/Outpost Destroyed",
	"Energy Activation Count Changed",
	"Energy Mechanism Entered Active State",
	"Energy Mechanism Active Arms Changed",
	"Energy Mechanism Activated",
	"Ally Hero Deploy Mode",
	"Ally Hero Sniper Damage",
	"Enemy Hero Sniper Damage",
	"Ally Air Support Called",
	"Ally Air Support Interrupted",
	"Enemy Air Support Called",
	"Enemy Air Support Interrupted",
	"Dart Hit",
	"Dart Gate Opened",
	"Ally Base Under Attack",
	"Both Outpost Stopped",
	"Both Base Armor Deployed"
]

const DART_TARGET_IDS := [
	DartHitTarget.RED_HERO,
	DartHitTarget.RED_ENGINEER,
	DartHitTarget.RED_INFANTRY_3,
	DartHitTarget.RED_INFANTRY_4,
	DartHitTarget.RED_INFANTRY_5,
	DartHitTarget.RED_AERIAL,
	DartHitTarget.RED_SENTRY,
	DartHitTarget.RED_DART,
	DartHitTarget.RED_RADAR,
	DartHitTarget.RED_OUTPOST,
	DartHitTarget.RED_BASE,
	DartHitTarget.BLUE_HERO,
	DartHitTarget.BLUE_ENGINEER,
	DartHitTarget.BLUE_INFANTRY_3,
	DartHitTarget.BLUE_INFANTRY_4,
	DartHitTarget.BLUE_INFANTRY_5,
	DartHitTarget.BLUE_AERIAL,
	DartHitTarget.BLUE_SENTRY,
	DartHitTarget.BLUE_DART,
	DartHitTarget.BLUE_RADAR,
	DartHitTarget.BLUE_OUTPOST,
	DartHitTarget.BLUE_BASE
]

const DEFAULT_ENERGY_ACTIVATION_COUNT := 0
const DEFAULT_SNIPER_DAMAGE_TOTAL := 0
const DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT := 3

@export var adapter_getter: MQTTProtocolAdapterGetter

class KillEventInfo:
	extends RefCounted
	var killer_id: int = -1
	var victim_id: int = -1

class DestroyEventInfo:
	extends RefCounted
	var target_id: int = -1

class DartHitEventInfo:
	extends RefCounted
	var target: int = DartHitTarget.UNKNOWN

var _kill_events: Array = []
var _destroy_events: Array = []
var _dart_hit_events: Array = []

var _energy_activation_count: int = DEFAULT_ENERGY_ACTIVATION_COUNT
var _ally_sniper_damage_total: int = DEFAULT_SNIPER_DAMAGE_TOTAL
var _enemy_sniper_damage_total: int = DEFAULT_SNIPER_DAMAGE_TOTAL
var _ally_air_support_interrupts_left: int = DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT
var _enemy_air_support_interrupts_left: int = DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT

var _adapter_bound: bool = false
var _logged_missing: bool = false
var _int_regex: RegEx = null

func _ready() -> void:
	_try_bind_adapter()

func ingest_event(event_id: int, param: String = "") -> void:
	_handle_event(event_id, param)

func clear_cache() -> void:
	_kill_events.clear()
	_destroy_events.clear()
	_dart_hit_events.clear()
	_energy_activation_count = DEFAULT_ENERGY_ACTIVATION_COUNT
	_ally_sniper_damage_total = DEFAULT_SNIPER_DAMAGE_TOTAL
	_enemy_sniper_damage_total = DEFAULT_SNIPER_DAMAGE_TOTAL
	_ally_air_support_interrupts_left = DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT
	_enemy_air_support_interrupts_left = DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT

func get_kill_events() -> Array:
	return _kill_events.duplicate()

func get_destroy_events() -> Array:
	return _destroy_events.duplicate()

func get_dart_hit_events() -> Array:
	return _dart_hit_events.duplicate()

func get_energy_activation_count() -> int:
	return _energy_activation_count

func get_ally_sniper_damage_total() -> int:
	return _ally_sniper_damage_total

func get_enemy_sniper_damage_total() -> int:
	return _enemy_sniper_damage_total

func get_ally_air_support_interrupts_left() -> int:
	return _ally_air_support_interrupts_left

func get_enemy_air_support_interrupts_left() -> int:
	return _enemy_air_support_interrupts_left

func get_event_name(event_id: int) -> String:
	if event_id >= 0 and event_id < EVENT_NAMES.size():
		return EVENT_NAMES[event_id]
	return "Unknown"

func _on_event_message(message) -> void:
	if message == null:
		return
	var event_id = int(message.get_event_id())
	var param = str(message.get_param())
	
	event_received.emit({
		"event_id": event_id,
		"param": param
	})
	
	_handle_event(event_id, param)

func _handle_event(event_id: int, param: String) -> void:
	match event_id:
		EventId.KILL_EVENT:
			_handle_kill_event(param)
		EventId.BASE_OR_OUTPOST_DESTROYED:
			_handle_destroy_event(param)
		EventId.ENERGY_MECH_ACTIVATION_COUNT_CHANGED:
			_energy_activation_count = _first_int(param, DEFAULT_ENERGY_ACTIVATION_COUNT)
			emit_signal("energy_activation_count_changed", _energy_activation_count)
		EventId.ENERGY_MECH_ENTERED_ACTIVE_STATE:
			emit_signal("energy_mech_entered_active_state")
		EventId.ENERGY_MECH_ACTIVE_ARMS_CHANGED:
			var vals = _extract_ints(param)
			var arms = 0
			var rings = 0
			if vals.size() > 0:
				arms = int(vals[0])
			if vals.size() > 1:
				rings = int(vals[1])
			emit_signal("energy_mech_active_arms_changed", arms, rings)
		EventId.ENERGY_MECH_ACTIVATED:
			emit_signal("energy_mech_activated", param)
		EventId.ALLY_HERO_DEPLOY_MODE:
			emit_signal("ally_hero_deploy_mode")
		EventId.ALLY_HERO_SNIPER_DAMAGE:
			_ally_sniper_damage_total = _first_int(param, DEFAULT_SNIPER_DAMAGE_TOTAL)
			emit_signal("ally_hero_sniper_damage", _ally_sniper_damage_total)
		EventId.ENEMY_HERO_SNIPER_DAMAGE:
			_enemy_sniper_damage_total = _first_int(param, DEFAULT_SNIPER_DAMAGE_TOTAL)
			emit_signal("enemy_hero_sniper_damage", _enemy_sniper_damage_total)
		EventId.ALLY_AIR_SUPPORT_CALLED:
			emit_signal("ally_air_support_called")
		EventId.ENEMY_AIR_SUPPORT_CALLED:
			emit_signal("enemy_air_support_called")
		EventId.ALLY_AIR_SUPPORT_INTERRUPTED:
			_ally_air_support_interrupts_left = _first_int(param, DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT)
			emit_signal("ally_air_support_interrupted", _ally_air_support_interrupts_left)
		EventId.ENEMY_AIR_SUPPORT_INTERRUPTED:
			_enemy_air_support_interrupts_left = _first_int(param, DEFAULT_AIR_SUPPORT_INTERRUPTS_LEFT)
			emit_signal("enemy_air_support_interrupted", _enemy_air_support_interrupts_left)
		EventId.DART_HIT:
			_handle_dart_hit(param)
		EventId.BOTH_DART_GATE_OPENED:
			emit_signal("dart_gate_opened", _parse_side(param))
		EventId.ALLY_BASE_UNDER_ATTACK:
			emit_signal("ally_base_under_attack")
		EventId.BOTH_OUTPOST_STOPPED:
			emit_signal("outpost_stopped", _parse_side(param))
		EventId.BOTH_BASE_ARMOR_DEPLOYED:
			emit_signal("base_armor_deployed", _parse_side(param))
		_:
			pass

func _handle_kill_event(param: String) -> void:
	var ids = _extract_ints(param)
	var killer_id = -1
	var victim_id = -1
	if ids.size() > 0:
		killer_id = int(ids[0])
	if ids.size() > 1:
		victim_id = int(ids[1])
	var info = KillEventInfo.new()
	info.killer_id = killer_id
	info.victim_id = victim_id
	_kill_events.append(info)
	emit_signal("kill_event", killer_id, victim_id)

func _handle_destroy_event(param: String) -> void:
	var target_id = _first_int(param, -1)
	var info = DestroyEventInfo.new()
	info.target_id = target_id
	_destroy_events.append(info)
	emit_signal("base_or_outpost_destroyed", target_id)

func _handle_dart_hit(param: String) -> void:
	var target = _parse_dart_target(param)
	var info = DartHitEventInfo.new()
	info.target = target
	_dart_hit_events.append(info)
	emit_signal("dart_hit", target)

func _parse_dart_target(param: String) -> int:
	var ids = _extract_ints(param)
	if ids.size() <= 0:
		return DartHitTarget.UNKNOWN
	var id = int(ids[0])
	if _is_known_dart_target(id):
		return id
	return DartHitTarget.UNKNOWN

func _is_known_dart_target(target_id: int) -> bool:
	for i in range(DART_TARGET_IDS.size()):
		if int(DART_TARGET_IDS[i]) == target_id:
			return true
	return false

func _parse_side(param: String) -> int:
	var ids = _extract_ints(param)
	if ids.size() > 0:
		var v = int(ids[0])
		if v == 1:
			return Side.RED
		if v == 2:
			return Side.BLUE
		if v == 3:
			return Side.BOTH
	var text = _normalize_text(param)
	if text.find("red") != -1:
		return Side.RED
	if text.find("blue") != -1:
		return Side.BLUE
	if text.find("both") != -1 or text.find("all") != -1:
		return Side.BOTH
	return Side.UNKNOWN

func _first_int(param: String, default_val: int) -> int:
	var vals = _extract_ints(param)
	if vals.size() > 0:
		return int(vals[0])
	return default_val

func _extract_ints(param: String) -> Array:
	var result: Array = []
	if param == null:
		return result
	var text = str(param)
	if text == "":
		return result
	_ensure_regex()
	var matches = _int_regex.search_all(text)
	for i in range(matches.size()):
		var m = matches[i]
		result.append(int(m.get_string()))
	return result

func _normalize_text(param: String) -> String:
	if param == null:
		return ""
	return str(param).to_lower()

func _ensure_regex() -> void:
	if _int_regex != null:
		return
	_int_regex = RegEx.new()
	_int_regex.compile("-?\\d+")

func _try_bind_adapter() -> void:
	if _adapter_bound:
		return
	if adapter_getter == null:
		if not _logged_missing:
			Log.error("[EventService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter()
	if adapter == null:
		if not _logged_missing:
			Log.error("[EventService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	adapter.event_message.connect(_on_event_message)
	_adapter_bound = true
	_logged_missing = false
