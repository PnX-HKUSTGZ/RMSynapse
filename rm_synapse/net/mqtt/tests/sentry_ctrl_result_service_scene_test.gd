extends Node

class DummySentryCtrlResultMessage:
	extends RefCounted
	var command_id: int = 0
	var result_code: int = 0

	func get_command_id() -> int:
		return command_id

	func get_result_code() -> int:
		return result_code

class FakeAdapter:
	extends Node
	signal sentry_ctrl_result(message)

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

	var svc = SentryCtrlResultService.new()
	svc.clear_cache()

	if svc.get_command_id() != 0:
		ok = false
		errors.append("default command_id")
	if svc.get_result_code() != 0:
		ok = false
		errors.append("default result_code")

	var updated_count := [0]
	var changed_count := [0]
	var changed_pair := [PackedInt32Array([0, 0])]
	svc.sentry_ctrl_result_updated.connect(func(_state):
		updated_count[0] += 1
	)
	svc.command_result_changed.connect(func(command_id, result_code):
		changed_count[0] += 1
		changed_pair[0] = PackedInt32Array([int(command_id), int(result_code)])
	)

	var m = DummySentryCtrlResultMessage.new()
	m.command_id = 12
	m.result_code = 3
	svc.ingest_sentry_ctrl_result(m)

	if svc.get_command_id() != 12 or svc.get_result_code() != 3:
		ok = false
		errors.append("ingest values")
	if updated_count[0] != 1 or changed_count[0] != 1:
		ok = false
		errors.append("ingest signals")
	if changed_pair[0][0] != 12 or changed_pair[0][1] != 3:
		ok = false
		errors.append("changed signal payload")

	var state_copy = svc.get_state()
	state_copy.result_code = 99
	if svc.get_result_code() == 99:
		ok = false
		errors.append("state clone isolation")

	svc.clear_cache()
	if svc.get_command_id() != 0 or svc.get_result_code() != 0:
		ok = false
		errors.append("clear_cache values")
	if updated_count[0] != 2 or changed_count[0] != 2:
		ok = false
		errors.append("clear_cache signals")

	var getter = FakeAdapterGetter.new()
	var delayed = SentryCtrlResultService.new()
	delayed.adapter_getter = getter
	delayed.bind_retry_interval_sec = 0.01
	delayed._logged_missing = true
	add_child(delayed)

	var adapter_a = FakeAdapter.new()
	var m2 = DummySentryCtrlResultMessage.new()
	m2.command_id = 5
	m2.result_code = 0
	adapter_a.sentry_ctrl_result.emit(m2)
	if delayed.get_command_id() != 0:
		ok = false
		errors.append("delayed bind pre-adapter ingest")

	getter.adapter_ref = adapter_a
	delayed._process(0.2)
	adapter_a.sentry_ctrl_result.emit(m2)
	if delayed.get_command_id() != 5 or delayed.get_result_code() != 0:
		ok = false
		errors.append("delayed bind ingest")

	var adapter_b = FakeAdapter.new()
	getter.adapter_ref = adapter_b
	delayed._process(0.2)

	var stale = DummySentryCtrlResultMessage.new()
	stale.command_id = 9
	stale.result_code = 1
	adapter_a.sentry_ctrl_result.emit(stale)
	if delayed.get_command_id() == 9:
		ok = false
		errors.append("adapter replace disconnect old")

	var m3 = DummySentryCtrlResultMessage.new()
	m3.command_id = 7
	m3.result_code = 2
	adapter_b.sentry_ctrl_result.emit(m3)
	if delayed.get_command_id() != 7 or delayed.get_result_code() != 2:
		ok = false
		errors.append("adapter replace ingest new")

	if ok:
		print("SENTRY_CTRL_RESULT_SERVICE_SCENE_TEST_OK")
	else:
		print("SENTRY_CTRL_RESULT_SERVICE_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
