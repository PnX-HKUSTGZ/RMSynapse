extends Node

class DummyGlobalLogisticsStatusMessage:
	extends RefCounted
	var remaining_economy: int = 0
	var total_economy_obtained: int = 0
	var tech_level: int = 0
	var encryption_level: int = 0

	func get_remaining_economy() -> int:
		return remaining_economy

	func get_total_economy_obtained() -> int:
		return total_economy_obtained

	func get_tech_level() -> int:
		return tech_level

	func get_encryption_level() -> int:
		return encryption_level

class FakeAdapter:
	extends Node
	signal global_logistics_status(message)

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

	var svc = GlobalLogisticsStatusService.new()
	svc.clear_cache()

	if svc.get_remaining_economy() != 0:
		ok = false
		errors.append("default remaining_economy")
	if svc.get_total_economy_obtained() != 0:
		ok = false
		errors.append("default total_economy_obtained")
	if svc.get_tech_level() != 0:
		ok = false
		errors.append("default tech_level")
	if svc.get_encryption_level() != 0:
		ok = false
		errors.append("default encryption_level")

	var economy_signal_count := [0]
	var tech_signal_count := [0]
	var encryption_signal_count := [0]
	var updated_signal_count := [0]
	var last_remaining := [0]
	var last_total := [0]
	var last_tech := [0]
	var last_encryption := [0]

	svc.economy_changed.connect(func(remaining_economy, total_economy_obtained):
		economy_signal_count[0] += 1
		last_remaining[0] = int(remaining_economy)
		last_total[0] = int(total_economy_obtained)
	)
	svc.tech_level_changed.connect(func(tech_level):
		tech_signal_count[0] += 1
		last_tech[0] = int(tech_level)
	)
	svc.encryption_level_changed.connect(func(encryption_level):
		encryption_signal_count[0] += 1
		last_encryption[0] = int(encryption_level)
	)
	svc.global_logistics_status_updated.connect(func(_state):
		updated_signal_count[0] += 1
	)

	var m1 = DummyGlobalLogisticsStatusMessage.new()
	m1.remaining_economy = 120
	m1.total_economy_obtained = 600
	m1.tech_level = 2
	m1.encryption_level = 1
	svc.ingest_global_logistics_status(m1)

	if svc.get_remaining_economy() != 120:
		ok = false
		errors.append("ingest remaining_economy")
	if svc.get_total_economy_obtained() != 600:
		ok = false
		errors.append("ingest total_economy_obtained")
	if svc.get_tech_level() != 2:
		ok = false
		errors.append("ingest tech_level")
	if svc.get_encryption_level() != 1:
		ok = false
		errors.append("ingest encryption_level")
	if economy_signal_count[0] != 1 or last_remaining[0] != 120 or last_total[0] != 600:
		ok = false
		errors.append("economy_changed first")
	if tech_signal_count[0] != 1 or last_tech[0] != 2:
		ok = false
		errors.append("tech_level_changed first")
	if encryption_signal_count[0] != 1 or last_encryption[0] != 1:
		ok = false
		errors.append("encryption_level_changed first")
	if updated_signal_count[0] != 1:
		ok = false
		errors.append("global_logistics_status_updated first")

	var m2 = DummyGlobalLogisticsStatusMessage.new()
	m2.remaining_economy = 120
	m2.total_economy_obtained = 600
	m2.tech_level = 2
	m2.encryption_level = 3
	svc.ingest_global_logistics_status(m2)

	if economy_signal_count[0] != 1:
		ok = false
		errors.append("economy_changed second")
	if tech_signal_count[0] != 1:
		ok = false
		errors.append("tech_level_changed second")
	if encryption_signal_count[0] != 2 or last_encryption[0] != 3:
		ok = false
		errors.append("encryption_level_changed second")
	if updated_signal_count[0] != 2:
		ok = false
		errors.append("global_logistics_status_updated second")

	var state_copy = svc.get_state()
	state_copy.remaining_economy = 999
	if svc.get_remaining_economy() == 999:
		ok = false
		errors.append("state clone isolation")

	svc.clear_cache()
	if svc.get_remaining_economy() != 0:
		ok = false
		errors.append("clear_cache remaining_economy")
	if svc.get_total_economy_obtained() != 0:
		ok = false
		errors.append("clear_cache total_economy_obtained")
	if svc.get_tech_level() != 0:
		ok = false
		errors.append("clear_cache tech_level")
	if svc.get_encryption_level() != 0:
		ok = false
		errors.append("clear_cache encryption_level")
	if economy_signal_count[0] != 2 or last_remaining[0] != 0 or last_total[0] != 0:
		ok = false
		errors.append("clear_cache economy_changed")
	if tech_signal_count[0] != 2 or last_tech[0] != 0:
		ok = false
		errors.append("clear_cache tech_level_changed")
	if encryption_signal_count[0] != 3 or last_encryption[0] != 0:
		ok = false
		errors.append("clear_cache encryption_level_changed")
	if updated_signal_count[0] != 3:
		ok = false
		errors.append("clear_cache global_logistics_status_updated")

	var delayed_getter = FakeAdapterGetter.new()
	var delayed_service = GlobalLogisticsStatusService.new()
	delayed_service.adapter_getter = delayed_getter
	delayed_service.bind_retry_interval_sec = 0.01
	delayed_service._logged_missing = true
	add_child(delayed_service)

	var adapter_a = FakeAdapter.new()
	var delayed_msg_1 = DummyGlobalLogisticsStatusMessage.new()
	delayed_msg_1.remaining_economy = 88
	delayed_msg_1.total_economy_obtained = 999
	delayed_msg_1.tech_level = 3
	delayed_msg_1.encryption_level = 2
	adapter_a.global_logistics_status.emit(delayed_msg_1)
	if delayed_service.get_remaining_economy() != 0:
		ok = false
		errors.append("delayed bind should not ingest before adapter available")

	delayed_getter.adapter_ref = adapter_a
	delayed_service._process(0.2)
	adapter_a.global_logistics_status.emit(delayed_msg_1)
	if delayed_service.get_remaining_economy() != 88 or delayed_service.get_total_economy_obtained() != 999:
		ok = false
		errors.append("delayed bind ingest economy")
	if delayed_service.get_tech_level() != 3 or delayed_service.get_encryption_level() != 2:
		ok = false
		errors.append("delayed bind ingest level")

	var adapter_b = FakeAdapter.new()
	delayed_getter.adapter_ref = adapter_b
	delayed_service._process(0.2)

	var stale_msg = DummyGlobalLogisticsStatusMessage.new()
	stale_msg.remaining_economy = 777
	stale_msg.total_economy_obtained = 888
	stale_msg.tech_level = 9
	stale_msg.encryption_level = 9
	adapter_a.global_logistics_status.emit(stale_msg)
	if delayed_service.get_remaining_economy() == 777:
		ok = false
		errors.append("adapter replace should disconnect old adapter")

	var delayed_msg_2 = DummyGlobalLogisticsStatusMessage.new()
	delayed_msg_2.remaining_economy = 55
	delayed_msg_2.total_economy_obtained = 1234
	delayed_msg_2.tech_level = 4
	delayed_msg_2.encryption_level = 1
	adapter_b.global_logistics_status.emit(delayed_msg_2)
	if delayed_service.get_remaining_economy() != 55 or delayed_service.get_total_economy_obtained() != 1234:
		ok = false
		errors.append("adapter replace ingest economy")
	if delayed_service.get_tech_level() != 4 or delayed_service.get_encryption_level() != 1:
		ok = false
		errors.append("adapter replace ingest level")

	if ok:
		print("GLOBAL_LOGISTICS_STATUS_SERVICE_SCENE_TEST_OK")
	else:
		print("GLOBAL_LOGISTICS_STATUS_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
