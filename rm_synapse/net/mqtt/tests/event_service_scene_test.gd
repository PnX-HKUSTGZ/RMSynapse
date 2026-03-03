extends Node

const DART_TARGET_BASE_RANDOM_MOVING := 4
const RELATIVE_SIDE_ALLY := 1
const RELATIVE_SIDE_ENEMY := 2
const RELATIVE_SIDE_UNKNOWN := 0

class DummyEventMessage:
	extends RefCounted
	var event_id: int = 0
	var param: String = ""

	func get_event_id() -> int:
		return event_id

	func get_param() -> String:
		return param

class FakeAdapter:
	extends Node
	signal event_message(message)

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var svc = EventService.new()
	svc.clear_cache()

	svc.ingest_event(EventService.EventId.KILL_EVENT, "1,101")
	var kills = svc.get_kill_events()
	if kills.size() != 1:
		ok = false
		errors.append("kill_events size")
	else:
		var k = kills[0]
		if k.killer_id != 1 or k.victim_id != 101:
			ok = false
			errors.append("kill_events values")

	svc.ingest_event(EventService.EventId.BASE_OR_OUTPOST_DESTROYED, "110")
	var destroys = svc.get_destroy_events()
	if destroys.size() != 1 or destroys[0].target_id != 110:
		ok = false
		errors.append("destroy_events")

	svc.ingest_event(EventService.EventId.ENERGY_MECH_ACTIVATION_COUNT_CHANGED, "5")
	if svc.get_energy_activation_count() != 5:
		ok = false
		errors.append("energy_activation_count")

	svc.ingest_event(EventService.EventId.ALLY_AIR_SUPPORT_INTERRUPTED, "2")
	if svc.get_ally_air_support_interrupts_left() != 2:
		ok = false
		errors.append("ally_air_support_interrupts_left")

	svc.ingest_event(EventService.EventId.DART_HIT, "4")
	var hits = svc.get_dart_hit_events()
	if hits.size() != 1 or int(hits[0].target) != DART_TARGET_BASE_RANDOM_MOVING:
		ok = false
		errors.append("dart_hit")

	var gate_side := [0]
	svc.dart_gate_opened.connect(func(side):
		gate_side[0] = int(side)
	)
	svc.ingest_event(EventService.EventId.BOTH_DART_GATE_OPENED, "1")
	if gate_side[0] != RELATIVE_SIDE_ALLY:
		ok = false
		errors.append("dart_gate_opened side")

	var outpost_side := [0]
	svc.outpost_stopped.connect(func(side):
		outpost_side[0] = int(side)
	)
	svc.ingest_event(EventService.EventId.BOTH_OUTPOST_STOPPED, "2")
	if outpost_side[0] != RELATIVE_SIDE_ENEMY:
		ok = false
		errors.append("outpost_stopped side")

	var base_armor_side := [RELATIVE_SIDE_ALLY]
	svc.base_armor_deployed.connect(func(side):
		base_armor_side[0] = int(side)
	)
	svc.ingest_event(EventService.EventId.BOTH_BASE_ARMOR_DEPLOYED, "3")
	if base_armor_side[0] != RELATIVE_SIDE_UNKNOWN:
		ok = false
		errors.append("base_armor_deployed side strict")

	svc.clear_cache()
	if svc.get_kill_events().size() != 0:
		ok = false
		errors.append("clear_cache kill_events")
	if svc.get_destroy_events().size() != 0:
		ok = false
		errors.append("clear_cache destroy_events")
	if svc.get_dart_hit_events().size() != 0:
		ok = false
		errors.append("clear_cache dart_hit_events")
	if svc.get_energy_activation_count() != 0:
		ok = false
		errors.append("clear_cache energy_activation_count")
	if svc.get_ally_air_support_interrupts_left() != 3:
		ok = false
		errors.append("clear_cache ally_air_support_interrupts_left")

	var delayed_getter = FakeAdapterGetter.new()
	var delayed_service = EventService.new()
	delayed_service.adapter_getter = delayed_getter
	delayed_service.bind_retry_interval_sec = 0.01

	var adapter_a = FakeAdapter.new()
	var delayed_msg_1 = DummyEventMessage.new()
	delayed_msg_1.event_id = EventService.EventId.KILL_EVENT
	delayed_msg_1.param = "2,102"

	adapter_a.event_message.emit(delayed_msg_1)
	if delayed_service.get_kill_events().size() != 0:
		ok = false
		errors.append("delayed bind should not ingest before adapter available")

	delayed_getter.adapter_ref = adapter_a
	delayed_service._process(0.2)
	adapter_a.event_message.emit(delayed_msg_1)
	if delayed_service.get_kill_events().size() != 1:
		ok = false
		errors.append("delayed bind ingest kill event")

	var adapter_b = FakeAdapter.new()
	delayed_getter.adapter_ref = adapter_b
	delayed_service._process(0.2)

	var stale_msg = DummyEventMessage.new()
	stale_msg.event_id = EventService.EventId.KILL_EVENT
	stale_msg.param = "9,109"
	adapter_a.event_message.emit(stale_msg)
	if delayed_service.get_kill_events().size() != 1:
		ok = false
		errors.append("adapter replace should disconnect old adapter")

	var delayed_msg_2 = DummyEventMessage.new()
	delayed_msg_2.event_id = EventService.EventId.KILL_EVENT
	delayed_msg_2.param = "3,103"
	adapter_b.event_message.emit(delayed_msg_2)
	if delayed_service.get_kill_events().size() != 2:
		ok = false
		errors.append("adapter replace ingest kill event")

	if ok:
		print("EVENT_SERVICE_SCENE_TEST_OK")
	else:
		print("EVENT_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
