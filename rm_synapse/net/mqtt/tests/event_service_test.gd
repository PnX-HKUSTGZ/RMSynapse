extends SceneTree

const DART_TARGET_BASE_RANDOM_MOVING := 4
const SIDE_BLUE := 2

func _init() -> void:
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
		if k.victim_id != 1 or k.killer_id != 101:
			ok = false
			errors.append("kill_events values")

	svc.ingest_event(EventService.EventId.OUTPOST_DESTROYED, "110")
	var destroys = svc.get_destroy_events()
	if destroys.size() != 1 or destroys[0].target_id != 110:
		ok = false
		errors.append("destroy_events")

	svc.ingest_event(EventService.EventId.ENERGY_MECH_ACTIVE_ARMS_CHANGED, "10,9.6")
	if svc.get_energy_active_arms_count() != 10 or absf(svc.get_energy_average_rings() - 9.6) > 0.001:
		ok = false
		errors.append("energy_active_arms")

	svc.ingest_event(EventService.EventId.ENEMY_AIR_SUPPORT_COUNTERED, "2")
	if svc.get_enemy_air_support_interrupts_left() != 2:
		ok = false
		errors.append("enemy_air_support_interrupts_left")

	svc.ingest_event(EventService.EventId.DART_HIT, "2,4")
	var hits = svc.get_dart_hit_events()
	if hits.size() != 1 or int(hits[0].hit_side) != SIDE_BLUE or int(hits[0].target) != DART_TARGET_BASE_RANDOM_MOVING:
		ok = false
		errors.append("dart_hit")

	var gate_opened := [false]
	svc.enemy_dart_gate_opened.connect(func():
		gate_opened[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_DART_GATE_OPENED, "")
	if not gate_opened[0]:
		ok = false
		errors.append("enemy_dart_gate_opened")

	var outpost_stopped := [false]
	svc.enemy_outpost_stopped.connect(func():
		outpost_stopped[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_OUTPOST_STOPPED, "")
	if not outpost_stopped[0]:
		ok = false
		errors.append("enemy_outpost_stopped")

	var base_armor_deployed := [false]
	svc.enemy_base_armor_deployed.connect(func():
		base_armor_deployed[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_BASE_ARMOR_DEPLOYED, "")
	if not base_armor_deployed[0]:
		ok = false
		errors.append("enemy_base_armor_deployed")

	var assembly_result := [-1]
	svc.assembly_result.connect(func(result_code):
		assembly_result[0] = int(result_code)
	)
	svc.ingest_event(EventService.EventId.ASSEMBLY_RESULT, "8")
	if assembly_result[0] != 8:
		ok = false
		errors.append("assembly_result")

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
	if svc.get_energy_active_arms_count() != 0 or svc.get_energy_average_rings() != 0.0:
		ok = false
		errors.append("clear_cache energy_active_arms")
	if svc.get_enemy_air_support_interrupts_left() != 3:
		ok = false
		errors.append("clear_cache enemy_air_support_interrupts_left")

	if ok:
		print("EVENT_SERVICE_TEST_OK")
	else:
		print("EVENT_SERVICE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	quit()
