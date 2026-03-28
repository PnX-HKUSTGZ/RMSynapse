extends SceneTree

const HIT_TEAM_RED := EventService.HitTeam.RED
const HIT_TEAM_BLUE := EventService.HitTeam.BLUE
const DART_TARGET_BASE_TERMINAL_MOVING := EventService.DartHitTarget.BASE_TERMINAL_MOVING_TARGET

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

	svc.ingest_event(EventService.EventId.OUTPOST_DESTROYED, "111")
	var destroys = svc.get_destroy_events()
	if destroys.size() != 1 or destroys[0].target_id != 111:
		ok = false
		errors.append("destroy_events")

	svc.ingest_event(EventService.EventId.BIG_RUNE_ACTIVE_ARMS_CHANGED, "10,9.6")
	if svc.get_big_rune_active_arms_count() != 10:
		ok = false
		errors.append("big_rune_active_arms_count")
	if not is_equal_approx(svc.get_big_rune_average_rings(), 9.6):
		ok = false
		errors.append("big_rune_average_rings")

	var energy_activate := [-1]
	svc.energy_mech_activated.connect(func(activate_type):
		energy_activate[0] = int(activate_type)
	)
	svc.ingest_event(EventService.EventId.ENERGY_MECH_ACTIVATED, "2")
	if energy_activate[0] != 2:
		ok = false
		errors.append("energy_mech_activated")

	var ally_sniper := [-1]
	svc.ally_hero_sniper_damage.connect(func(total_damage):
		ally_sniper[0] = int(total_damage)
	)
	svc.ingest_event(EventService.EventId.ALLY_HERO_SNIPER_DAMAGE, "120")
	if svc.get_ally_sniper_damage_total() != 120 or ally_sniper[0] != 120:
		ok = false
		errors.append("ally_hero_sniper_damage")

	var enemy_sniper := [-1]
	svc.enemy_hero_sniper_damage.connect(func(total_damage):
		enemy_sniper[0] = int(total_damage)
	)
	svc.ingest_event(EventService.EventId.ENEMY_HERO_SNIPER_DAMAGE, "240")
	if svc.get_enemy_sniper_damage_total() != 240 or enemy_sniper[0] != 240:
		ok = false
		errors.append("enemy_hero_sniper_damage")

	var air_called := [false]
	svc.enemy_air_support_called.connect(func():
		air_called[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_AIR_SUPPORT_CALLED)
	if not air_called[0]:
		ok = false
		errors.append("enemy_air_support_called")

	svc.ingest_event(EventService.EventId.ENEMY_AIR_SUPPORT_COUNTERED, "2")
	if svc.get_ally_air_support_counter_left() != 2:
		ok = false
		errors.append("ally_air_support_counter_left")

	svc.ingest_event(EventService.EventId.DART_HIT, "2,5")
	var hits = svc.get_dart_hit_events()
	if hits.size() != 1:
		ok = false
		errors.append("dart_hit size")
	else:
		var hit = hits[0]
		if int(hit.hit_team) != HIT_TEAM_BLUE or int(hit.target) != DART_TARGET_BASE_TERMINAL_MOVING:
			ok = false
			errors.append("dart_hit values")

	var gate_opened := [false]
	svc.enemy_dart_gate_opened.connect(func():
		gate_opened[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_DART_GATE_OPENED)
	if not gate_opened[0]:
		ok = false
		errors.append("enemy_dart_gate_opened signal")

	var base_under_attack := [false]
	svc.base_under_attack.connect(func():
		base_under_attack[0] = true
	)
	svc.ingest_event(EventService.EventId.BASE_UNDER_ATTACK)
	if not base_under_attack[0]:
		ok = false
		errors.append("base_under_attack signal")

	var outpost_stopped := [false]
	svc.enemy_outpost_stopped.connect(func():
		outpost_stopped[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_OUTPOST_STOPPED)
	if not outpost_stopped[0]:
		ok = false
		errors.append("enemy_outpost_stopped signal")

	var armor_deployed := [false]
	svc.enemy_base_armor_deployed.connect(func():
		armor_deployed[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_BASE_ARMOR_DEPLOYED)
	if not armor_deployed[0]:
		ok = false
		errors.append("enemy_base_armor_deployed signal")

	var request_level4 := [false]
	svc.enemy_requested_level4_assembly.connect(func():
		request_level4[0] = true
	)
	svc.ingest_event(EventService.EventId.ENEMY_REQUESTED_LEVEL4_ASSEMBLY)
	if not request_level4[0]:
		ok = false
		errors.append("enemy_requested_level4_assembly signal")

	var assembly_result := [-1]
	svc.assembly_result.connect(func(code):
		assembly_result[0] = int(code)
	)
	svc.ingest_event(EventService.EventId.ASSEMBLY_RESULT, "7")
	if svc.get_last_assembly_result() != 7 or assembly_result[0] != 7:
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
	if svc.get_big_rune_active_arms_count() != 0:
		ok = false
		errors.append("clear_cache big_rune_active_arms_count")
	if not is_equal_approx(svc.get_big_rune_average_rings(), 0.0):
		ok = false
		errors.append("clear_cache big_rune_average_rings")
	if svc.get_ally_air_support_counter_left() != 0:
		ok = false
		errors.append("clear_cache ally_air_support_counter_left")
	if svc.get_ally_sniper_damage_total() != 0:
		ok = false
		errors.append("clear_cache ally_sniper_damage_total")
	if svc.get_enemy_sniper_damage_total() != 0:
		ok = false
		errors.append("clear_cache enemy_sniper_damage_total")
	if svc.get_last_assembly_result() != -1:
		ok = false
		errors.append("clear_cache last_assembly_result")
	if svc.get_event_name(EventService.EventId.ASSEMBLY_RESULT) != "Assembly Result":
		ok = false
		errors.append("event_name assembly_result")

	if ok:
		print("EVENT_SERVICE_TEST_OK")
	else:
		print("EVENT_SERVICE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	quit()
