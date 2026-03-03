extends Node

class DummyPenaltyInfoMessage:
	extends RefCounted
	var penalty_type: int = 0
	var penalty_effect_sec: int = 0
	var total_penalty_num: int = 0

	func get_penalty_type() -> int:
		return penalty_type

	func get_penalty_effect_sec() -> int:
		return penalty_effect_sec

	func get_total_penalty_num() -> int:
		return total_penalty_num

class FakeAdapter:
	extends Node
	signal penalty_info(message)

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

	var svc = PenaltyInfoService.new()
	svc.clear_cache()

	if svc.get_penalty_type() != 0:
		ok = false
		errors.append("default penalty_type")
	if svc.get_penalty_effect_sec() != 0:
		ok = false
		errors.append("default penalty_effect_sec")
	if svc.get_total_penalty_num() != 0:
		ok = false
		errors.append("default total_penalty_num")

	var update_count := [0]
	var type_count := [0]
	var effect_count := [0]
	var total_count := [0]
	svc.penalty_info_updated.connect(func(_state):
		update_count[0] += 1
	)
	svc.penalty_type_changed.connect(func(_value):
		type_count[0] += 1
	)
	svc.penalty_effect_changed.connect(func(_value):
		effect_count[0] += 1
	)
	svc.penalty_count_changed.connect(func(_value):
		total_count[0] += 1
	)

	var m = DummyPenaltyInfoMessage.new()
	m.penalty_type = 2
	m.penalty_effect_sec = 30
	m.total_penalty_num = 4
	svc.ingest_penalty_info(m)

	if svc.get_penalty_type() != 2:
		ok = false
		errors.append("ingest penalty_type")
	if svc.get_penalty_effect_sec() != 30:
		ok = false
		errors.append("ingest penalty_effect_sec")
	if svc.get_total_penalty_num() != 4:
		ok = false
		errors.append("ingest total_penalty_num")
	if update_count[0] != 1:
		ok = false
		errors.append("updated signal")
	if type_count[0] != 1 or effect_count[0] != 1 or total_count[0] != 1:
		ok = false
		errors.append("changed signals")

	var state_copy = svc.get_state()
	state_copy.penalty_type = 99
	if svc.get_penalty_type() == 99:
		ok = false
		errors.append("state clone isolation")

	svc.clear_cache()
	if svc.get_penalty_type() != 0 or svc.get_penalty_effect_sec() != 0 or svc.get_total_penalty_num() != 0:
		ok = false
		errors.append("clear_cache values")
	if update_count[0] != 2:
		ok = false
		errors.append("clear_cache updated signal")

	var getter = FakeAdapterGetter.new()
	var delayed = PenaltyInfoService.new()
	delayed.adapter_getter = getter
	delayed.bind_retry_interval_sec = 0.01
	delayed._logged_missing = true
	add_child(delayed)

	var adapter_a = FakeAdapter.new()
	var m2 = DummyPenaltyInfoMessage.new()
	m2.penalty_type = 6
	m2.penalty_effect_sec = 45
	m2.total_penalty_num = 7
	adapter_a.penalty_info.emit(m2)
	if delayed.get_penalty_type() != 0:
		ok = false
		errors.append("delayed bind pre-adapter ingest")

	getter.adapter_ref = adapter_a
	delayed._process(0.2)
	adapter_a.penalty_info.emit(m2)
	if delayed.get_penalty_type() != 6 or delayed.get_penalty_effect_sec() != 45 or delayed.get_total_penalty_num() != 7:
		ok = false
		errors.append("delayed bind ingest")

	var adapter_b = FakeAdapter.new()
	getter.adapter_ref = adapter_b
	delayed._process(0.2)

	var stale = DummyPenaltyInfoMessage.new()
	stale.penalty_type = 8
	stale.penalty_effect_sec = 50
	stale.total_penalty_num = 9
	adapter_a.penalty_info.emit(stale)
	if delayed.get_penalty_type() == 8:
		ok = false
		errors.append("adapter replace disconnect old")

	var m3 = DummyPenaltyInfoMessage.new()
	m3.penalty_type = 10
	m3.penalty_effect_sec = 55
	m3.total_penalty_num = 11
	adapter_b.penalty_info.emit(m3)
	if delayed.get_penalty_type() != 10 or delayed.get_penalty_effect_sec() != 55 or delayed.get_total_penalty_num() != 11:
		ok = false
		errors.append("adapter replace ingest new")

	if ok:
		print("PENALTY_INFO_SERVICE_SCENE_TEST_OK")
	else:
		print("PENALTY_INFO_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
