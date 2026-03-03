extends SceneTree

class DummyGameStatusMessage:
	extends RefCounted
	var current_round: int = 0
	var total_rounds: int = 0
	var red_score: int = 0
	var blue_score: int = 0
	var current_stage: int = 0
	var stage_countdown_sec: int = 0
	var stage_elapsed_sec: int = 0
	var paused: bool = false

	func get_current_round() -> int:
		return current_round

	func get_total_rounds() -> int:
		return total_rounds

	func get_red_score() -> int:
		return red_score

	func get_blue_score() -> int:
		return blue_score

	func get_current_stage() -> int:
		return current_stage

	func get_stage_countdown_sec() -> int:
		return stage_countdown_sec

	func get_stage_elapsed_sec() -> int:
		return stage_elapsed_sec

	func get_is_paused() -> bool:
		return paused

class FakeAdapter:
	extends Node
	signal game_status(message)

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _init() -> void:
	var ok = true
	var errors: Array[String] = []

	var svc = GameStatusService.new()
	svc.clear_cache()

	if svc.get_current_round() != 0:
		ok = false
		errors.append("default current_round")
	if svc.get_total_rounds() != 0:
		ok = false
		errors.append("default total_rounds")
	if svc.get_red_score() != 0 or svc.get_blue_score() != 0:
		ok = false
		errors.append("default scores")
	if svc.get_current_stage() != 0:
		ok = false
		errors.append("default current_stage")
	if svc.get_current_stage_name() != "未开始比赛":
		ok = false
		errors.append("default stage name")
	if svc.get_stage_countdown_sec() != 0 or svc.get_stage_elapsed_sec() != 0:
		ok = false
		errors.append("default stage timer")
	if svc.is_paused():
		ok = false
		errors.append("default paused")

	var stage_signal_count := [0]
	var score_signal_count := [0]
	var pause_signal_count := [0]
	var update_signal_count := [0]
	var last_stage_name := [""]
	var last_red := [0]
	var last_blue := [0]
	var last_paused := [false]

	svc.stage_changed.connect(func(_stage, stage_name):
		stage_signal_count[0] += 1
		last_stage_name[0] = stage_name
	)
	svc.score_changed.connect(func(red, blue):
		score_signal_count[0] += 1
		last_red[0] = int(red)
		last_blue[0] = int(blue)
	)
	svc.pause_state_changed.connect(func(paused):
		pause_signal_count[0] += 1
		last_paused[0] = bool(paused)
	)
	svc.game_status_updated.connect(func(_state):
		update_signal_count[0] += 1
	)

	var m1 = DummyGameStatusMessage.new()
	m1.current_round = 1
	m1.total_rounds = 3
	m1.red_score = 10
	m1.blue_score = 8
	m1.current_stage = 1
	m1.stage_countdown_sec = 120
	m1.stage_elapsed_sec = 5
	m1.paused = false
	svc.ingest_game_status(m1)

	if svc.get_current_round() != 1 or svc.get_total_rounds() != 3:
		ok = false
		errors.append("ingest round")
	if svc.get_red_score() != 10 or svc.get_blue_score() != 8:
		ok = false
		errors.append("ingest score")
	if svc.get_current_stage() != 1 or svc.get_current_stage_name() != "准备阶段":
		ok = false
		errors.append("ingest stage")
	if svc.get_stage_countdown_sec() != 120 or svc.get_stage_elapsed_sec() != 5:
		ok = false
		errors.append("ingest stage timer")
	if svc.is_paused():
		ok = false
		errors.append("ingest paused")
	if stage_signal_count[0] != 1 or last_stage_name[0] != "准备阶段":
		ok = false
		errors.append("stage_changed signal")
	if score_signal_count[0] != 1 or last_red[0] != 10 or last_blue[0] != 8:
		ok = false
		errors.append("score_changed signal")
	if pause_signal_count[0] != 0:
		ok = false
		errors.append("pause_state_changed signal first")
	if update_signal_count[0] != 1:
		ok = false
		errors.append("game_status_updated signal first")

	var m2 = DummyGameStatusMessage.new()
	m2.current_round = 1
	m2.total_rounds = 3
	m2.red_score = 12
	m2.blue_score = 8
	m2.current_stage = 4
	m2.stage_countdown_sec = 88
	m2.stage_elapsed_sec = 37
	m2.paused = true
	svc.ingest_game_status(m2)

	if svc.get_red_score() != 12 or svc.get_blue_score() != 8:
		ok = false
		errors.append("second ingest score")
	if svc.get_current_stage_name() != "比赛中":
		ok = false
		errors.append("second ingest stage name")
	if not svc.is_paused():
		ok = false
		errors.append("second ingest paused")
	if stage_signal_count[0] != 2 or last_stage_name[0] != "比赛中":
		ok = false
		errors.append("stage_changed signal second")
	if score_signal_count[0] != 2 or last_red[0] != 12 or last_blue[0] != 8:
		ok = false
		errors.append("score_changed signal second")
	if pause_signal_count[0] != 1 or not last_paused[0]:
		ok = false
		errors.append("pause_state_changed signal second")
	if update_signal_count[0] != 2:
		ok = false
		errors.append("game_status_updated signal second")

	if svc.get_stage_name(99) != "Unknown":
		ok = false
		errors.append("unknown stage name")

	var state_copy = svc.get_state()
	state_copy.red_score = 999
	if svc.get_red_score() == 999:
		ok = false
		errors.append("state clone isolation")

	svc.clear_cache()
	if svc.get_current_round() != 0 or svc.get_total_rounds() != 0:
		ok = false
		errors.append("clear_cache round")
	if svc.get_red_score() != 0 or svc.get_blue_score() != 0:
		ok = false
		errors.append("clear_cache score")
	if svc.get_current_stage() != 0 or svc.get_current_stage_name() != "未开始比赛":
		ok = false
		errors.append("clear_cache stage")
	if svc.get_stage_countdown_sec() != 0 or svc.get_stage_elapsed_sec() != 0:
		ok = false
		errors.append("clear_cache stage timer")
	if svc.is_paused():
		ok = false
		errors.append("clear_cache paused")
	if stage_signal_count[0] != 3 or last_stage_name[0] != "未开始比赛":
		ok = false
		errors.append("clear_cache stage_changed signal")
	if score_signal_count[0] != 3 or last_red[0] != 0 or last_blue[0] != 0:
		ok = false
		errors.append("clear_cache score_changed signal")
	if pause_signal_count[0] != 2 or last_paused[0]:
		ok = false
		errors.append("clear_cache pause_state_changed signal")
	if update_signal_count[0] != 3:
		ok = false
		errors.append("clear_cache game_status_updated signal")

	var delayed_getter = FakeAdapterGetter.new()
	var delayed_service = GameStatusService.new()
	delayed_service.adapter_getter = delayed_getter
	delayed_service.bind_retry_interval_sec = 0.01
	delayed_service._logged_missing = true
	root.add_child(delayed_service)

	var adapter_a = FakeAdapter.new()
	var delayed_msg_1 = DummyGameStatusMessage.new()
	delayed_msg_1.current_round = 2
	delayed_msg_1.total_rounds = 5
	delayed_msg_1.red_score = 15
	delayed_msg_1.blue_score = 9
	delayed_msg_1.current_stage = 4
	delayed_msg_1.stage_countdown_sec = 66
	delayed_msg_1.stage_elapsed_sec = 44
	delayed_msg_1.paused = true
	adapter_a.game_status.emit(delayed_msg_1)
	if delayed_service.get_current_round() != 0:
		ok = false
		errors.append("delayed bind should not ingest before adapter available")

	delayed_getter.adapter_ref = adapter_a
	delayed_service._process(0.2)
	adapter_a.game_status.emit(delayed_msg_1)

	if delayed_service.get_current_round() != 2 or delayed_service.get_total_rounds() != 5:
		ok = false
		errors.append("delayed bind ingest round")
	if delayed_service.get_red_score() != 15 or delayed_service.get_blue_score() != 9:
		ok = false
		errors.append("delayed bind ingest score")
	if delayed_service.get_current_stage() != 4 or delayed_service.get_current_stage_name() != "比赛中":
		ok = false
		errors.append("delayed bind ingest stage")
	if delayed_service.get_stage_countdown_sec() != 66 or delayed_service.get_stage_elapsed_sec() != 44:
		ok = false
		errors.append("delayed bind ingest stage timer")
	if not delayed_service.is_paused():
		ok = false
		errors.append("delayed bind ingest paused")

	var adapter_b = FakeAdapter.new()
	delayed_getter.adapter_ref = adapter_b
	delayed_service._process(0.2)

	var stale_msg = DummyGameStatusMessage.new()
	stale_msg.current_round = 8
	stale_msg.total_rounds = 9
	stale_msg.red_score = 99
	stale_msg.blue_score = 88
	stale_msg.current_stage = 1
	stale_msg.stage_countdown_sec = 11
	stale_msg.stage_elapsed_sec = 22
	stale_msg.paused = false
	adapter_a.game_status.emit(stale_msg)
	if delayed_service.get_current_round() == 8:
		ok = false
		errors.append("adapter replace should disconnect old adapter")

	var delayed_msg_2 = DummyGameStatusMessage.new()
	delayed_msg_2.current_round = 3
	delayed_msg_2.total_rounds = 5
	delayed_msg_2.red_score = 18
	delayed_msg_2.blue_score = 12
	delayed_msg_2.current_stage = 5
	delayed_msg_2.stage_countdown_sec = 30
	delayed_msg_2.stage_elapsed_sec = 80
	delayed_msg_2.paused = false
	adapter_b.game_status.emit(delayed_msg_2)
	if delayed_service.get_current_round() != 3 or delayed_service.get_total_rounds() != 5:
		ok = false
		errors.append("adapter replace ingest round")
	if delayed_service.get_red_score() != 18 or delayed_service.get_blue_score() != 12:
		ok = false
		errors.append("adapter replace ingest score")
	if delayed_service.get_current_stage() != 5 or delayed_service.get_current_stage_name() != "比赛结算中":
		ok = false
		errors.append("adapter replace ingest stage")
	if delayed_service.get_stage_countdown_sec() != 30 or delayed_service.get_stage_elapsed_sec() != 80:
		ok = false
		errors.append("adapter replace ingest stage timer")
	if delayed_service.is_paused():
		ok = false
		errors.append("adapter replace ingest paused")

	delayed_service.queue_free()

	if ok:
		print("GAME_STATUS_SERVICE_TEST_OK")
	else:
		print("GAME_STATUS_SERVICE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	quit()
