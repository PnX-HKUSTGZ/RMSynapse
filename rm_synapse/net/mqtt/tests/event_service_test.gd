extends SceneTree

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

	svc.ingest_event(EventService.EventId.DART_HIT, "101")
	var hits = svc.get_dart_hit_events()
	if hits.size() != 1 or hits[0].target != EventService.DartHitTarget.BLUE_HERO:
		ok = false
		errors.append("dart_hit")

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

	if ok:
		print("EVENT_SERVICE_TEST_OK")
	else:
		print("EVENT_SERVICE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	quit()
