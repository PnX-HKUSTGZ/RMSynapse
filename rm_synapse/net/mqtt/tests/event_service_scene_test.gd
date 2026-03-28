extends Node

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

	var rune_signal := [0.0]
	svc.big_rune_active_arms_changed.connect(func(_arms_count, avg_rings):
		rune_signal[0] = float(avg_rings)
	)
	svc.ingest_event(EventService.EventId.BIG_RUNE_ACTIVE_ARMS_CHANGED, "10,9.6")
	if not is_equal_approx(rune_signal[0], 9.6):
		ok = false
		errors.append("big_rune_active_arms_changed signal")

	var request_level4 := [false]
	svc.enemy_requested_level4_assembly.connect(func():
		request_level4[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_REQUESTED_LEVEL4_ASSEMBLY)
	if not request_level4[0]:
		ok = false
		errors.append("enemy_requested_level4_assembly signal")

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
	else:
		var delayed_kill = delayed_service.get_kill_events()[0]
		if delayed_kill.victim_id != 2 or delayed_kill.killer_id != 102:
			ok = false
			errors.append("delayed bind kill values")

	var delayed_msg_dart = DummyEventMessage.new()
	delayed_msg_dart.event_id = EventService.EventId.DART_HIT
	delayed_msg_dart.param = "2,5"
	adapter_a.event_message.emit(delayed_msg_dart)
	if delayed_service.get_dart_hit_events().size() != 1:
		ok = false
		errors.append("delayed bind dart hit")
	else:
		var delayed_hit = delayed_service.get_dart_hit_events()[0]
		if int(delayed_hit.hit_team) != EventService.HitTeam.BLUE or int(delayed_hit.target) != EventService.DartHitTarget.BASE_TERMINAL_MOVING_TARGET:
			ok = false
			errors.append("delayed bind dart hit values")

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
	delayed_msg_2.event_id = EventService.EventId.ASSEMBLY_RESULT
	delayed_msg_2.param = "6"
	adapter_b.event_message.emit(delayed_msg_2)
	if delayed_service.get_last_assembly_result() != 6:
		ok = false
		errors.append("adapter replace ingest assembly_result")

	if ok:
		print("EVENT_SERVICE_SCENE_TEST_OK")
	else:
		print("EVENT_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
