extends Node

class DummyGlobalUnitStatusMessage:
	extends RefCounted
	var base_health: int = 0
	var base_status: int = 0
	var base_shield: int = 0
	var outpost_health: int = 0
	var outpost_status: int = 0
	var enemy_base_health: int = 0
	var enemy_base_status: int = 0
	var enemy_base_shield: int = 0
	var enemy_outpost_health: int = 0
	var enemy_outpost_status: int = 0
	var robot_health: Array = []
	var robot_bullets: Array = []
	var total_damage_ally: int = 0
	var total_damage_enemy: int = 0

	func get_base_health() -> int:
		return base_health

	func get_base_status() -> int:
		return base_status

	func get_base_shield() -> int:
		return base_shield

	func get_outpost_health() -> int:
		return outpost_health

	func get_outpost_status() -> int:
		return outpost_status

	func get_enemy_base_health() -> int:
		return enemy_base_health

	func get_enemy_base_status() -> int:
		return enemy_base_status

	func get_enemy_base_shield() -> int:
		return enemy_base_shield

	func get_enemy_outpost_health() -> int:
		return enemy_outpost_health

	func get_enemy_outpost_status() -> int:
		return enemy_outpost_status

	func get_robot_health() -> Array:
		return robot_health

	func get_robot_bullets() -> Array:
		return robot_bullets

	func get_total_damage_ally() -> int:
		return total_damage_ally

	func get_total_damage_enemy() -> int:
		return total_damage_enemy

class FakeAdapter:
	extends Node
	signal global_unit_status(message)

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _make_int_array(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out

func _int_arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var svc = GlobalUnitStatusService.new()
	svc.clear_cache()

	var ally_base = svc.get_ally_base()
	if ally_base.health != 0 or ally_base.status != 0 or ally_base.shield != 0:
		ok = false
		errors.append("default ally_base")
	var enemy_base = svc.get_enemy_base()
	if enemy_base.health != 0 or enemy_base.status != 0 or enemy_base.shield != 0:
		ok = false
		errors.append("default enemy_base")
	var ally_outpost = svc.get_ally_outpost()
	if ally_outpost.health != 0 or ally_outpost.status != 0:
		ok = false
		errors.append("default ally_outpost")
	var enemy_outpost = svc.get_enemy_outpost()
	if enemy_outpost.health != 0 or enemy_outpost.status != 0:
		ok = false
		errors.append("default enemy_outpost")
	if svc.get_robot_health().size() != 0 or svc.get_robot_bullets().size() != 0:
		ok = false
		errors.append("default robot arrays")
	if svc.get_total_damage_ally() != 0 or svc.get_total_damage_enemy() != 0:
		ok = false
		errors.append("default total_damage")

	var base_signal_count := [0]
	var outpost_signal_count := [0]
	var robot_signal_count := [0]
	var total_signal_count := [0]
	var updated_signal_count := [0]

	var last_ally_base_hp := [0]
	var last_enemy_base_hp := [0]
	var last_ally_outpost_hp := [0]
	var last_enemy_outpost_hp := [0]
	var last_robot_health := [[]]
	var last_robot_bullets := [[]]
	var last_total_ally := [0]
	var last_total_enemy := [0]

	svc.base_state_changed.connect(func(changed_ally_base, changed_enemy_base):
		base_signal_count[0] += 1
		last_ally_base_hp[0] = int(changed_ally_base.health)
		last_enemy_base_hp[0] = int(changed_enemy_base.health)
	)
	svc.outpost_state_changed.connect(func(changed_ally_outpost, changed_enemy_outpost):
		outpost_signal_count[0] += 1
		last_ally_outpost_hp[0] = int(changed_ally_outpost.health)
		last_enemy_outpost_hp[0] = int(changed_enemy_outpost.health)
	)
	svc.robot_status_changed.connect(func(changed_robot_health, changed_robot_bullets):
		robot_signal_count[0] += 1
		last_robot_health[0] = changed_robot_health.duplicate()
		last_robot_bullets[0] = changed_robot_bullets.duplicate()
	)
	svc.total_damage_changed.connect(func(changed_total_damage_ally, changed_total_damage_enemy):
		total_signal_count[0] += 1
		last_total_ally[0] = int(changed_total_damage_ally)
		last_total_enemy[0] = int(changed_total_damage_enemy)
	)
	svc.global_unit_status_updated.connect(func(_state):
		updated_signal_count[0] += 1
	)

	var m1 = DummyGlobalUnitStatusMessage.new()
	m1.base_health = 1500
	m1.base_status = 1
	m1.base_shield = 200
	m1.outpost_health = 700
	m1.outpost_status = 2
	m1.enemy_base_health = 1200
	m1.enemy_base_status = 0
	m1.enemy_base_shield = 100
	m1.enemy_outpost_health = 650
	m1.enemy_outpost_status = 5
	m1.robot_health = [100, 200, 300, 400]
	m1.robot_bullets = [10, -3, 20]
	m1.total_damage_ally = 90
	m1.total_damage_enemy = 70
	svc.ingest_global_unit_status(m1)

	var m1_ally_base = svc.get_ally_base()
	if m1_ally_base.health != 1500 or m1_ally_base.status != 1 or m1_ally_base.shield != 200:
		ok = false
		errors.append("ingest ally_base")
	var m1_enemy_base = svc.get_enemy_base()
	if m1_enemy_base.health != 1200 or m1_enemy_base.status != 0 or m1_enemy_base.shield != 100:
		ok = false
		errors.append("ingest enemy_base")
	var m1_ally_outpost = svc.get_ally_outpost()
	if m1_ally_outpost.health != 700 or m1_ally_outpost.status != 2:
		ok = false
		errors.append("ingest ally_outpost")
	var m1_enemy_outpost = svc.get_enemy_outpost()
	if m1_enemy_outpost.health != 650 or m1_enemy_outpost.status != 5:
		ok = false
		errors.append("ingest enemy_outpost")
	if not _int_arrays_equal(svc.get_robot_health(), _make_int_array([100, 200, 300, 400])):
		ok = false
		errors.append("ingest robot_health")
	if not _int_arrays_equal(svc.get_robot_bullets(), _make_int_array([10, -3, 20])):
		ok = false
		errors.append("ingest robot_bullets")
	if svc.get_total_damage_ally() != 90 or svc.get_total_damage_enemy() != 70:
		ok = false
		errors.append("ingest total_damage")
	if base_signal_count[0] != 1 or last_ally_base_hp[0] != 1500 or last_enemy_base_hp[0] != 1200:
		ok = false
		errors.append("base_state_changed first")
	if outpost_signal_count[0] != 1 or last_ally_outpost_hp[0] != 700 or last_enemy_outpost_hp[0] != 650:
		ok = false
		errors.append("outpost_state_changed first")
	if robot_signal_count[0] != 1 or not _int_arrays_equal(last_robot_health[0], _make_int_array([100, 200, 300, 400])) or not _int_arrays_equal(last_robot_bullets[0], _make_int_array([10, -3, 20])):
		ok = false
		errors.append("robot_status_changed first")
	if total_signal_count[0] != 1 or last_total_ally[0] != 90 or last_total_enemy[0] != 70:
		ok = false
		errors.append("total_damage_changed first")
	if updated_signal_count[0] != 1:
		ok = false
		errors.append("global_unit_status_updated first")

	if svc.get_base_status_name(2) != "解除无敌，护甲展开":
		ok = false
		errors.append("base status name")
	if svc.get_outpost_status_name(5) != "被击毁，重建中":
		ok = false
		errors.append("outpost status name")
	if svc.get_base_status_name(99) != "Unknown":
		ok = false
		errors.append("unknown base status name")
	if svc.get_outpost_status_name(99) != "Unknown":
		ok = false
		errors.append("unknown outpost status name")

	var m2 = DummyGlobalUnitStatusMessage.new()
	m2.base_health = 1500
	m2.base_status = 1
	m2.base_shield = 200
	m2.outpost_health = 700
	m2.outpost_status = 2
	m2.enemy_base_health = 1200
	m2.enemy_base_status = 0
	m2.enemy_base_shield = 100
	m2.enemy_outpost_health = 650
	m2.enemy_outpost_status = 5
	m2.robot_health = [110, 200, 310, 400]
	m2.robot_bullets = [10, -1, 25]
	m2.total_damage_ally = 130
	m2.total_damage_enemy = 95
	svc.ingest_global_unit_status(m2)

	if base_signal_count[0] != 1:
		ok = false
		errors.append("base_state_changed second")
	if outpost_signal_count[0] != 1:
		ok = false
		errors.append("outpost_state_changed second")
	if robot_signal_count[0] != 2 or not _int_arrays_equal(last_robot_health[0], _make_int_array([110, 200, 310, 400])) or not _int_arrays_equal(last_robot_bullets[0], _make_int_array([10, -1, 25])):
		ok = false
		errors.append("robot_status_changed second")
	if total_signal_count[0] != 2 or last_total_ally[0] != 130 or last_total_enemy[0] != 95:
		ok = false
		errors.append("total_damage_changed second")
	if updated_signal_count[0] != 2:
		ok = false
		errors.append("global_unit_status_updated second")

	var state_copy = svc.get_state()
	state_copy.ally_base.health = 9999
	state_copy.robot_health.clear()
	state_copy.robot_health.append(999)
	var mutated_health: Array[int] = []
	mutated_health.append(999)
	if svc.get_ally_base().health == 9999 or _int_arrays_equal(svc.get_robot_health(), mutated_health):
		ok = false
		errors.append("state clone isolation")

	svc.clear_cache()
	if svc.get_ally_base().health != 0 or svc.get_enemy_base().health != 0:
		ok = false
		errors.append("clear_cache base")
	if svc.get_ally_outpost().health != 0 or svc.get_enemy_outpost().health != 0:
		ok = false
		errors.append("clear_cache outpost")
	if svc.get_robot_health().size() != 0 or svc.get_robot_bullets().size() != 0:
		ok = false
		errors.append("clear_cache robot arrays")
	if svc.get_total_damage_ally() != 0 or svc.get_total_damage_enemy() != 0:
		ok = false
		errors.append("clear_cache total_damage")
	if base_signal_count[0] != 2 or last_ally_base_hp[0] != 0 or last_enemy_base_hp[0] != 0:
		ok = false
		errors.append("clear_cache base_state_changed")
	if outpost_signal_count[0] != 2 or last_ally_outpost_hp[0] != 0 or last_enemy_outpost_hp[0] != 0:
		ok = false
		errors.append("clear_cache outpost_state_changed")
	if robot_signal_count[0] != 3 or last_robot_health[0].size() != 0 or last_robot_bullets[0].size() != 0:
		ok = false
		errors.append("clear_cache robot_status_changed")
	if total_signal_count[0] != 3 or last_total_ally[0] != 0 or last_total_enemy[0] != 0:
		ok = false
		errors.append("clear_cache total_damage_changed")
	if updated_signal_count[0] != 3:
		ok = false
		errors.append("clear_cache global_unit_status_updated")

	var delayed_getter = FakeAdapterGetter.new()
	var delayed_service = GlobalUnitStatusService.new()
	delayed_service.adapter_getter = delayed_getter
	delayed_service.bind_retry_interval_sec = 0.01
	delayed_service._logged_missing = true
	add_child(delayed_service)

	var adapter_a = FakeAdapter.new()
	var delayed_msg_1 = DummyGlobalUnitStatusMessage.new()
	delayed_msg_1.base_health = 1000
	delayed_msg_1.base_status = 2
	delayed_msg_1.base_shield = 333
	delayed_msg_1.outpost_health = 444
	delayed_msg_1.outpost_status = 1
	delayed_msg_1.enemy_base_health = 1111
	delayed_msg_1.enemy_base_status = 1
	delayed_msg_1.enemy_base_shield = 222
	delayed_msg_1.enemy_outpost_health = 555
	delayed_msg_1.enemy_outpost_status = 4
	delayed_msg_1.robot_health = [1, 2, 3]
	delayed_msg_1.robot_bullets = [4, 5]
	delayed_msg_1.total_damage_ally = 10
	delayed_msg_1.total_damage_enemy = 20
	adapter_a.global_unit_status.emit(delayed_msg_1)
	if delayed_service.get_ally_base().health != 0:
		ok = false
		errors.append("delayed bind should not ingest before adapter available")

	delayed_getter.adapter_ref = adapter_a
	delayed_service._process(0.2)
	adapter_a.global_unit_status.emit(delayed_msg_1)
	if delayed_service.get_ally_base().health != 1000 or delayed_service.get_enemy_base().health != 1111:
		ok = false
		errors.append("delayed bind ingest base")
	if delayed_service.get_ally_outpost().health != 444 or delayed_service.get_enemy_outpost().health != 555:
		ok = false
		errors.append("delayed bind ingest outpost")
	if not _int_arrays_equal(delayed_service.get_robot_health(), _make_int_array([1, 2, 3])) or not _int_arrays_equal(delayed_service.get_robot_bullets(), _make_int_array([4, 5])):
		ok = false
		errors.append("delayed bind ingest robot arrays")
	if delayed_service.get_total_damage_ally() != 10 or delayed_service.get_total_damage_enemy() != 20:
		ok = false
		errors.append("delayed bind ingest total_damage")

	var adapter_b = FakeAdapter.new()
	delayed_getter.adapter_ref = adapter_b
	delayed_service._process(0.2)

	var stale_msg = DummyGlobalUnitStatusMessage.new()
	stale_msg.base_health = 9999
	stale_msg.enemy_base_health = 9999
	adapter_a.global_unit_status.emit(stale_msg)
	if delayed_service.get_ally_base().health == 9999:
		ok = false
		errors.append("adapter replace should disconnect old adapter")

	var delayed_msg_2 = DummyGlobalUnitStatusMessage.new()
	delayed_msg_2.base_health = 666
	delayed_msg_2.base_status = 0
	delayed_msg_2.base_shield = 10
	delayed_msg_2.outpost_health = 77
	delayed_msg_2.outpost_status = 3
	delayed_msg_2.enemy_base_health = 777
	delayed_msg_2.enemy_base_status = 2
	delayed_msg_2.enemy_base_shield = 11
	delayed_msg_2.enemy_outpost_health = 88
	delayed_msg_2.enemy_outpost_status = 2
	delayed_msg_2.robot_health = [6, 7]
	delayed_msg_2.robot_bullets = [8]
	delayed_msg_2.total_damage_ally = 30
	delayed_msg_2.total_damage_enemy = 40
	adapter_b.global_unit_status.emit(delayed_msg_2)
	if delayed_service.get_ally_base().health != 666 or delayed_service.get_enemy_base().health != 777:
		ok = false
		errors.append("adapter replace ingest base")
	if delayed_service.get_ally_outpost().health != 77 or delayed_service.get_enemy_outpost().health != 88:
		ok = false
		errors.append("adapter replace ingest outpost")
	if not _int_arrays_equal(delayed_service.get_robot_health(), _make_int_array([6, 7])) or not _int_arrays_equal(delayed_service.get_robot_bullets(), _make_int_array([8])):
		ok = false
		errors.append("adapter replace ingest robot arrays")
	if delayed_service.get_total_damage_ally() != 30 or delayed_service.get_total_damage_enemy() != 40:
		ok = false
		errors.append("adapter replace ingest total_damage")

	if ok:
		print("GLOBAL_UNIT_STATUS_SERVICE_SCENE_TEST_OK")
	else:
		print("GLOBAL_UNIT_STATUS_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
