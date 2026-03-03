extends Node

class FakeAdapter:
	extends Node
	var send_result: int = 0
	var calls: Array[Dictionary] = []

	func send_common_command(data) -> int:
		calls.append({
			"cmd_type": int(data.cmd_type),
			"param": int(data.param),
		})
		return send_result

class FakeAdapterGetter:
	extends MQTTProtocolAdapterGetter
	var adapter_ref = null

	func get_adapter_silent():
		return adapter_ref

	func get_adapter():
		return adapter_ref

func _assert_call(adapter: FakeAdapter, index: int, expected_cmd_type: int, expected_param: int, errors: Array[String], label: String) -> bool:
	if index < 0 or index >= adapter.calls.size():
		errors.append("%s call missing" % label)
		return false
	var call = adapter.calls[index]
	if int(call.get("cmd_type", -1)) != expected_cmd_type:
		errors.append("%s cmd_type" % label)
		return false
	if int(call.get("param", -1)) != expected_param:
		errors.append("%s param" % label)
		return false
	return true

func _ready() -> void:
	var ok = true
	var errors: Array[String] = []

	var adapter = FakeAdapter.new()	
	adapter.send_result = 7
	var getter = FakeAdapterGetter.new()
	getter.adapter_ref = adapter

	var svc_17 = CommonCommandExchange17mmService.new()
	var svc_42 = CommonCommandExchange42mmService.new()
	var svc_confirm = CommonCommandConfirmRespawnService.new()
	var svc_buy = CommonCommandBuyRespawnService.new()
	var svc_ammo = CommonCommandRemoteBuyAmmoService.new()
	var svc_hp = CommonCommandRemoteBuyHpService.new()

	svc_17.adapter_getter = getter
	svc_42.adapter_getter = getter
	svc_confirm.adapter_getter = getter
	svc_buy.adapter_getter = getter
	svc_ammo.adapter_getter = getter
	svc_hp.adapter_getter = getter
	add_child(svc_17)
	add_child(svc_42)
	add_child(svc_confirm)
	add_child(svc_buy)
	add_child(svc_ammo)
	add_child(svc_hp)

	var r17 = svc_17.send_once(20)
	if r17 != 7 or svc_17.get_last_send_result() != 7:
		ok = false
		errors.append("17mm send result")
	if not _assert_call(adapter, 0, 1, 20, errors, "17mm"):
		ok = false

	var calls_before = adapter.calls.size()
	var invalid = svc_17.send_once(21)
	if invalid != CommonCommandExchange17mmService.RESULT_INVALID_PARAM:
		ok = false
		errors.append("17mm invalid return code")
	if adapter.calls.size() != calls_before:
		ok = false
		errors.append("17mm invalid should not send")

	if svc_42.send_once(2) != 7:
		ok = false
		errors.append("42mm send result")
	if not _assert_call(adapter, 1, 2, 2, errors, "42mm"):
		ok = false

	if svc_confirm.send_once(0) != 7:
		ok = false
		errors.append("confirm send result")
	if not _assert_call(adapter, 2, 3, 0, errors, "confirm"):
		ok = false

	if svc_buy.send_once(1) != 7:
		ok = false
		errors.append("buy send result")
	if not _assert_call(adapter, 3, 4, 1, errors, "buy"):
		ok = false

	if svc_ammo.send_once(33) != 7:
		ok = false
		errors.append("remote ammo send result")
	if not _assert_call(adapter, 4, 5, 33, errors, "remote ammo"):
		ok = false

	if svc_hp.send_once(44) != 7:
		ok = false
		errors.append("remote hp send result")
	if not _assert_call(adapter, 5, 6, 44, errors, "remote hp"):
		ok = false

	adapter.send_result = -1
	if svc_hp.send_once(55) != -1 or svc_hp.get_last_send_result() != -1:
		ok = false
		errors.append("send failure result")
	if not _assert_call(adapter, 6, 6, 55, errors, "send failure call"):
		ok = false

	adapter.send_result = 8
	var call_count_before_null = adapter.calls.size()
	getter.adapter_ref = null
	svc_42._logged_missing = true
	if svc_42.send_once(9) != -1:
		ok = false
		errors.append("null adapter return")
	if adapter.calls.size() != call_count_before_null:
		ok = false
		errors.append("null adapter should not send")

	if ok:
		print("COMMON_COMMAND_SERVICES_SCENE_TEST_OK")
	else:
		print("COMMON_COMMAND_SERVICES_SCENE_TEST_FAIL")
		for e in errors:
			print("FAIL:", e)
	get_tree().quit()
