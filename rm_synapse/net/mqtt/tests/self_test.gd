extends SceneTree

func _init() -> void:
	var proto = RMCustomProto
	var ok = true
	var errors: Array[String] = []

	var gs = proto.GameStatus.new()
	gs.set_current_round(1)
	gs.set_total_rounds(3)
	gs.set_red_score(2)
	gs.set_blue_score(1)
	gs.set_current_stage(4)
	gs.set_stage_countdown_sec(120)
	gs.set_stage_elapsed_sec(300)
	gs.set_is_paused(false)

	var gs_bytes = gs.to_bytes()
	var gs2 = proto.GameStatus.new()
	var res = gs2.from_bytes(gs_bytes)
	if res != proto.PB_ERR.NO_ERRORS:
		ok = false
		errors.append("GameStatus decode")
	elif gs2.get_current_round() != 1 or gs2.get_total_rounds() != 3:
		ok = false
		errors.append("GameStatus values")

	var cc = proto.CustomControl.new()
	var payload = PackedByteArray([1, 2, 3, 4])
	cc.set_data(payload)
	var cc2 = proto.CustomControl.new()
	res = cc2.from_bytes(cc.to_bytes())
	if res != proto.PB_ERR.NO_ERRORS:
		ok = false
		errors.append("CustomControl decode")
	elif cc2.get_data().size() != payload.size():
		ok = false
		errors.append("CustomControl bytes")

	var rp = proto.RobotPathPlanInfo.new()
	rp.set_intention(1)
	rp.set_start_pos_x(10)
	rp.set_start_pos_y(20)
	rp.add_offset_x(1)
	rp.add_offset_x(-1)
	rp.add_offset_y(2)
	rp.add_offset_y(-2)
	rp.set_sender_id(7)
	var rp2 = proto.RobotPathPlanInfo.new()
	res = rp2.from_bytes(rp.to_bytes())
	if res != proto.PB_ERR.NO_ERRORS:
		ok = false
		errors.append("RobotPathPlanInfo decode")
	elif rp2.get_offset_x().size() != 2 or rp2.get_offset_y().size() != 2:
		ok = false
		errors.append("RobotPathPlanInfo arrays")

	var adapter = preload("res://net/mqtt/adapter/protocol_adapter.gd").new()
	adapter._register_default_mappings()
	var decoded = {"value": false}
	adapter.decoded_message.connect(func(_topic, _message):
		decoded.value = true
	)
	adapter._on_transport_message(adapter.TOPIC_GAME_STATUS, gs_bytes)
	if not decoded.value:
		ok = false
		errors.append("ProtocolAdapter decoded_message")

	if ok:
		print("SELF_TEST_OK")
	else:
		print("SELF_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	quit()
