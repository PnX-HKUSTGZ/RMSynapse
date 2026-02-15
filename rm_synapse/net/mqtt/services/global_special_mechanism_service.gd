extends Node
class_name GlobalSpecialMechanismService

enum EffectId {
	ALLY_BASE_OCCUPIED = 1,
	ENEMY_BASE_OCCUPIED = 2
}

const EFFECT_NAMES := [
	"Unknown",
	"己方堡垒被对方占领计时",
	"对方堡垒被己方占领计时"
]

@export var adapter_getter: MQTTProtocolAdapterGetter

class EffectState:
	extends RefCounted
	var id: int = 0
	var remaining_sec: int = 0

class EffectInfo:
	extends RefCounted
	var id: int = 0
	var name: String = ""
	var remaining_sec: int = 0

var _effects: Array = []
var _adapter_bound: bool = false
var _logged_missing: bool = false
var _logged_mismatch: bool = false

func _ready() -> void:
	_try_bind_adapter()

func get_active_effects() -> Array:
	if not _adapter_bound:
		_try_bind_adapter()
	var result: Array = []
	for i in range(_effects.size()):
		var state: EffectState = _effects[i]
		var info = EffectInfo.new()
		info.id = state.id
		info.name = get_effect_name(state.id)
		info.remaining_sec = state.remaining_sec
		result.append(info)
	return result

func get_effect_name(effect_id: int) -> String:
	if effect_id >= 0 and effect_id < EFFECT_NAMES.size():
		return EFFECT_NAMES[effect_id]
	return "Unknown"

func _on_global_special_mechanism(message) -> void:
	var ids: Array = message.get_mechanism_id()
	var times: Array = message.get_mechanism_time_sec()
	var count = min(ids.size(), times.size())
	if ids.size() != times.size() and not _logged_mismatch:
		Log.warn("[GlobalSpecialMechanismService] mechanism_id/time length mismatch: %d vs %d" % [ids.size(), times.size()])
		_logged_mismatch = true
	var new_effects: Array = []
	for i in range(count):
		var effect_id = int(ids[i])
		var sec = int(times[i])
		if sec < 0:
			sec = 0
		var state = EffectState.new()
		state.id = effect_id
		state.remaining_sec = sec
		new_effects.append(state)
	_effects = new_effects

func _try_bind_adapter() -> void:
	if _adapter_bound:
		return
	if adapter_getter == null:
		if not _logged_missing:
			Log.error("[GlobalSpecialMechanismService] adapter_getter is not set.")
			_logged_missing = true
		return
	var adapter = adapter_getter.get_adapter()
	if adapter == null:
		if not _logged_missing:
			Log.error("[GlobalSpecialMechanismService] ProtocolAdapter not available.")
			_logged_missing = true
		return
	adapter.global_special_mechanism.connect(_on_global_special_mechanism)
	_adapter_bound = true
	_logged_missing = false
