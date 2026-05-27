extends CanvasLayer

@onready var hud_viewport: Control = $HudViewport
@onready var web = $HudViewport/CefTexture
var map_web: Node = null

enum MessagePriority {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CRITICAL = 3
}

@export var message_default_duration := 3.5
@export var message_max_count := 6
@export var keyboard_mouse_transport_enabled := false

var _pending_message_items: Array[Dictionary] = []
var _pending_bridge_payloads: Array[Dictionary] = []
var _message_seq := 0

var page_ready := false
var update_rate := 0.0
var acc := 0.0

var hud_data_bridge = HudDataBridge.new()
var hud_operation_bridge = HudOperationBridge.new()
var keyboard_mouse_sender = KeyboardMouseControlSender.new()
var adapter_getter = MQTTProtocolAdapterGetter.new()

var _transport: NetworkTransport = null
var _mqtt_connected := false
var _transport_retry_elapsed := 0.0
var _link_push_elapsed := 0.0
var _last_data_update_msec := 0
var _command_panel_open := false
var _settings_menu_open := false
var _mouse_sensitivity := 1.0
var _debug_log_enabled := false
var _debug_log_mode := "receive"
var _debug_log_path := "user://logs/rm_synapse_debug.jsonl"
var _debug_log_file_dialog: FileDialog = null
var _debug_log_seq := 0
var _debug_log_seq_by_key: Dictionary = {}
var _debug_log_last_ticks_by_key: Dictionary = {}
var _web_runtime_ready := false
var _web_server: TCPServer = null
var _web_server_port := 0
var _web_clients: Array = []
var _map_page_ready := false
var _control_focus_active := true
var _mouse_delta := Vector2.ZERO
var _mouse_wheel_delta := 0
var _left_button_down := false
var _right_button_down := false
var _mid_button_down := false
var _pressed_key_bits: Dictionary = {}
var _pending_map_payloads: Array[Dictionary] = []
var _last_video_settings_key := ""
var _active_mqtt_connection_key := ""
var _pending_mqtt_connection_key := ""
var _pending_mqtt_client_id := ""
var _mqtt_connection_state := "disconnected"
var _mqtt_connection_reason := ""
var _pending_web_eval_payloads: Array[Dictionary] = []
var _shutting_down := false

const KEYBOARD_BIT_BY_PHYSICAL_KEY := {
	KEY_W: 0,
	KEY_S: 1,
	KEY_A: 2,
	KEY_D: 3,
	KEY_SHIFT: 4,
	KEY_CTRL: 5,
	KEY_Q: 6,
	KEY_E: 7,
	KEY_R: 8,
	KEY_F: 9,
	KEY_G: 10,
	KEY_Z: 11,
	KEY_X: 12,
	KEY_C: 13,
	KEY_V: 14,
	KEY_B: 15
}

const BRIDGE_SIGNAL_TO_PROTO_KEY := {
	"game_status_updated": "GameStatus",
	"global_unit_status_updated": "GlobalUnitStatus",
	"global_logistics_status_updated": "GlobalLogisticsStatus",
	"global_special_mechanism_updated": "GlobalSpecialMechanism",
	"event_received": "Event",
	"robot_injury_stat_updated": "RobotInjuryStat",
	"robot_respawn_status_updated": "RobotRespawnStatus",
	"robot_static_status_updated": "RobotStaticStatus",
	"robot_dynamic_status_updated": "RobotDynamicStatus",
	"robot_module_status_updated": "RobotModuleStatus",
	"robot_position_updated": "RobotPosition",
	"buff_updated": "Buff",
	"penalty_info_updated": "PenaltyInfo",
	"robot_path_plan_info_updated": "RobotPathPlanInfo",
	"radar_info_updated": "RadarInfoToClient",
	"robot_performance_selection_sync_updated": "RobotPerformanceSelectionSync",
	"deploy_mode_status_sync_updated": "DeployModeStatusSync",
	"tech_core_motion_state_sync_updated": "TechCoreMotionStateSync",
	"rune_status_sync_updated": "RuneStatusSync",
	"sentry_status_sync_updated": "SentryStatusSync",
	"dart_select_target_status_sync_updated": "DartSelectTargetStatusSync",
	"sentry_ctrl_result_updated": "SentryCtrlResult",
	"air_support_status_sync_updated": "AirSupportStatusSync",
	"custom_byte_block_received": "CustomByteBlock"
}

const MAP_PROTO_KEYS := {
	"GlobalUnitStatus": true,
	"RobotPosition": true,
	"RobotPathPlanInfo": true,
	"RadarInfoToClient": true
}

const MIN_MOUSE_SENSITIVITY := 0.1
const MAX_MOUSE_SENSITIVITY := 5.0
const MIN_PORT := 1
const MAX_PORT := 65535
const DEFAULT_MQTT_BROKER_HOST := "192.168.12.1"
const WEB_SOURCE_DIR := "res://ui/web"
const WEB_RUNTIME_DIR := "user://web"
const WEB_INDEX_FILE := "index.html"
const WEB_MAP_FILE := "map.html"
const WEB_MAP_IMAGE_FILE := "map.png"
const WEB_FAVICON_FILE := "vite.svg"
const WEB_SERVER_HOST := "127.0.0.1"
const WEB_SERVER_PORT_START := 18180
const WEB_SERVER_PORT_END := 18220
const HUD_CANVAS_SIZE := Vector2(1920, 1080)

func _enter_tree() -> void:
	_initialize_webview_urls()

func _ready():
	randomize()
	print("HUD ready. Press A to send DEFAULT_UI_STATE, B for 100Hz test, C to stop.")
	set_process(true)
	set_process_input(true)
	_setup_debug_log_file_dialog()
	_configure_hud_canvas()
	_configure_cef_node(web, "hud")
	_ensure_child_node(adapter_getter)

	if web and web.has_signal("load_finished"):
		web.load_finished.connect(func(_url: String, status: int) -> void:
			page_ready = _is_successful_cef_load(status)
			print("CEF load_finished status=", status, " page_ready=", page_ready)
			if page_ready:
				_push_link_status()
				_flush_pending_bridge_payloads()
				_flush_pending_messages()
		)
	_connect_cef_ipc_signals(web, "hud")
	_connect_cef_debug_signals(web, "hud")
	_navigate_webview_urls.call_deferred()

	_assign_adapter_getter(hud_data_bridge)
	if hud_data_bridge.get_parent() == null:
		add_child(hud_data_bridge)
	_bind_bridge_signals()

	_assign_adapter_getter(hud_operation_bridge)
	if hud_operation_bridge.get_parent() == null:
		add_child(hud_operation_bridge)
	if not hud_operation_bridge.operation_status.is_connected(_on_operation_status):
		hud_operation_bridge.operation_status.connect(_on_operation_status)
	_assign_adapter_getter(keyboard_mouse_sender)
	keyboard_mouse_sender.auto_start = keyboard_mouse_transport_enabled
	if keyboard_mouse_sender.get_parent() == null:
		add_child(keyboard_mouse_sender)
	if not keyboard_mouse_transport_enabled:
		keyboard_mouse_sender.stop_sending()
	_set_control_focus(true)
	_try_bind_transport_signals()

func _exit_tree() -> void:
	_shutting_down = true
	_pending_web_eval_payloads.clear()
	if hud_operation_bridge != null and hud_operation_bridge.operation_status.is_connected(_on_operation_status):
		hud_operation_bridge.operation_status.disconnect(_on_operation_status)
	if keyboard_mouse_sender != null:
		keyboard_mouse_sender.stop_sending()
	_shutdown_web_server()
	_shutdown_cef_node(web, "hud")
	_shutdown_cef_node(map_web, "map")

func _is_successful_cef_load(status: int) -> bool:
	return status == 0 or (status >= 200 and status < 400)

func _initialize_webview_urls() -> void:
	if not _prepare_web_runtime_dir():
		push_error("Cannot prepare CEF web runtime directory.")
		return
	_log_web_runtime_state()
	if not _ensure_web_server():
		push_error("Cannot start CEF web runtime server.")
		return
	_web_runtime_ready = true
	_assign_initial_webview_urls()

func _assign_initial_webview_urls() -> void:
	var index_url := _web_runtime_url(WEB_INDEX_FILE)
	var web_node := get_node_or_null("HudViewport/CefTexture")
	if web_node == null:
		web_node = get_node_or_null("CefTexture")
	if web_node != null:
		web_node.set("url", index_url)

func _navigate_webview_urls() -> void:
	if not _web_runtime_ready:
		_initialize_webview_urls()
		return
	var index_url := _web_runtime_url(WEB_INDEX_FILE)
	if web != null:
		_load_cef_url(web, index_url)
	if map_web != null and map_web.visible:
		_load_cef_url(map_web, _web_runtime_url(WEB_MAP_FILE))

func _load_cef_url(target: Object, url: String) -> void:
	var current_url := str(target.get("url"))
	if current_url == url:
		return
	print("CEF load url: ", url)
	target.set("url", url)
	if target.has_method("set_url_property"):
		target.call("set_url_property", url)
	if target.has_method("_deferred_create_browser"):
		target.call_deferred("_deferred_create_browser")

func _configure_cef_node(target: Object, source: String) -> void:
	if target == null:
		return
	if target is Control:
		_set_top_left_layout(target)
		target.position = Vector2.ZERO
		target.size = _hud_viewport_size()
		target.mouse_filter = Control.MOUSE_FILTER_STOP
		target.focus_mode = Control.FOCUS_ALL
	if _set_object_property_if_exists(target, "enable_accelerated_osr", false):
		print("CEF ", source, " accelerated OSR disabled")

func _configure_hud_canvas() -> void:
	if hud_viewport == null:
		return
	_set_top_left_layout(hud_viewport)
	hud_viewport.clip_contents = true
	hud_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	_update_hud_canvas_transform()
	var root := get_viewport()
	if root != null and not root.size_changed.is_connected(_update_hud_canvas_transform):
		root.size_changed.connect(_update_hud_canvas_transform)

func _update_hud_canvas_transform() -> void:
	if hud_viewport == null:
		return
	var visible_size := _hud_viewport_size()
	_set_top_left_layout(hud_viewport)
	hud_viewport.position = Vector2.ZERO
	hud_viewport.scale = Vector2.ONE
	hud_viewport.custom_minimum_size = visible_size
	hud_viewport.size = visible_size
	if web is Control:
		var web_control := web as Control
		_set_top_left_layout(web_control)
		web_control.position = Vector2.ZERO
		web_control.size = visible_size
	if map_web is Control:
		var map_control := map_web as Control
		_set_top_left_layout(map_control)
		map_control.position = Vector2.ZERO
		map_control.size = visible_size

func _set_top_left_layout(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_top = 0.0

func _hud_viewport_size() -> Vector2:
	var root := get_viewport()
	var visible_size := root.get_visible_rect().size if root != null else HUD_CANVAS_SIZE
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return HUD_CANVAS_SIZE
	return visible_size

func _ensure_map_web() -> Node:
	if map_web != null:
		return map_web
	var created: Object = ClassDB.instantiate("CefTexture")
	if not (created is Node):
		push_warning("Cannot create map CEF page.")
		return null
	map_web = created
	map_web.name = "CefMap"
	map_web.visible = false
	map_web.set("url", "")
	_configure_cef_node(map_web, "map")
	if hud_viewport != null:
		hud_viewport.add_child(map_web)
	else:
		add_child(map_web)
	if map_web.has_signal("load_finished"):
		map_web.load_finished.connect(func(_url: String, status: int) -> void:
			_map_page_ready = _is_successful_cef_load(status)
			print("CEF map load_finished status=", status, " map_page_ready=", _map_page_ready)
			if _map_page_ready:
				_push_map_snapshot()
				_flush_pending_map_payloads()
		)
	_connect_cef_ipc_signals(map_web, "map")
	_connect_cef_debug_signals(map_web, "map")
	return map_web

func _shutdown_cef_node(target: Object, source: String) -> void:
	if target == null:
		return
	if target.has_method("stop_loading"):
		target.call("stop_loading")

func _prepare_web_runtime_dir() -> bool:
	if not _ensure_dir(WEB_RUNTIME_DIR):
		return false
	if not _copy_dir_recursive(WEB_SOURCE_DIR, WEB_RUNTIME_DIR):
		return false
	if not _write_imported_texture_png(WEB_SOURCE_DIR.path_join(WEB_MAP_IMAGE_FILE), WEB_RUNTIME_DIR.path_join(WEB_MAP_IMAGE_FILE)):
		return false
	_ensure_favicon_svg(WEB_RUNTIME_DIR.path_join(WEB_FAVICON_FILE))
	return true

func _copy_dir_recursive(source_dir: String, target_dir: String) -> bool:
	var dir := DirAccess.open(source_dir)
	if dir == null:
		push_error("Cannot open web source directory: %s (error=%s)" % [source_dir, str(DirAccess.get_open_error())])
		return false
	if not _ensure_dir(target_dir):
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var source_path := source_dir.path_join(file_name)
		var target_path := target_dir.path_join(file_name)
		if dir.current_is_dir():
			if not _copy_dir_recursive(source_path, target_path):
				dir.list_dir_end()
				return false
		elif not _copy_file(source_path, target_path):
			dir.list_dir_end()
			return false
		file_name = dir.get_next()
	dir.list_dir_end()
	return true

func _copy_file(source_path: String, target_path: String) -> bool:
	if not _ensure_dir(target_path.get_base_dir()):
		return false
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		push_error("Cannot open web source file: %s (error=%s)" % [source_path, str(FileAccess.get_open_error())])
		return false
	var bytes := source_file.get_buffer(source_file.get_length())
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		push_error("Cannot write web runtime file: %s (error=%s)" % [target_path, str(FileAccess.get_open_error())])
		return false
	target_file.store_buffer(bytes)
	return true

func _write_imported_texture_png(source_path: String, target_path: String) -> bool:
	if FileAccess.file_exists(source_path):
		var raw_image := Image.load_from_file(source_path)
		if raw_image != null:
			var raw_err: int = raw_image.save_png(target_path)
			if raw_err == OK:
				return true
			push_error("Cannot write raw web PNG asset: %s (error=%s)" % [target_path, str(raw_err)])
	var texture := ResourceLoader.load(source_path) as Texture2D
	if texture != null:
		var image: Image = texture.get_image()
		if image != null:
			var err: int = image.save_png(target_path)
			if err == OK:
				return true
			push_error("Cannot write web PNG asset: %s (error=%s)" % [target_path, str(err)])
	if FileAccess.file_exists(target_path):
		return true
	push_error("Cannot prepare web PNG asset: %s" % source_path)
	return false

func _ensure_favicon_svg(target_path: String) -> void:
	if FileAccess.file_exists(target_path):
		return
	if not _ensure_dir(target_path.get_base_dir()):
		return
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write fallback favicon: %s" % target_path)
		return
	file.store_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="12" fill="#020617"/><path d="M14 42V22h16c6 0 10 4 10 9s-4 9-10 9h-8v2H14Zm8-10h7c2 0 3-1 3-3s-1-3-3-3h-7v6Zm22 10V22h8v20h-8Z" fill="#67e8f9"/></svg>')

func _ensure_web_server() -> bool:
	if _web_server != null and _web_server.is_listening():
		return true
	for port in range(WEB_SERVER_PORT_START, WEB_SERVER_PORT_END + 1):
		var server := TCPServer.new()
		var err := server.listen(port, WEB_SERVER_HOST)
		if err == OK:
			_web_server = server
			_web_server_port = port
			print("CEF web server listening: http://%s:%s/" % [WEB_SERVER_HOST, str(_web_server_port)])
			return true
	_web_server = null
	_web_server_port = 0
	return false

func _web_runtime_url(file_name: String) -> String:
	return "http://%s:%s/%s" % [WEB_SERVER_HOST, str(_web_server_port), file_name]

func _poll_web_server() -> void:
	if _web_server == null or not _web_server.is_listening():
		return
	while _web_server.is_connection_available():
		var peer := _web_server.take_connection()
		if peer != null:
			_web_clients.append({
				"peer": peer,
				"request": ""
			})
	for index in range(_web_clients.size() - 1, -1, -1):
		var item: Dictionary = _web_clients[index]
		var peer: StreamPeerTCP = item.get("peer")
		if peer == null or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_web_clients.remove_at(index)
			continue
		var available := peer.get_available_bytes()
		if available <= 0:
			continue
		item.request = str(item.get("request", "")) + peer.get_utf8_string(available)
		_web_clients[index] = item
		if not str(item.request).contains("\r\n\r\n"):
			continue
		_serve_web_request(peer, str(item.request))
		peer.disconnect_from_host()
		_web_clients.remove_at(index)

func _shutdown_web_server() -> void:
	for item in _web_clients:
		var peer: StreamPeerTCP = item.get("peer")
		if peer != null:
			peer.disconnect_from_host()
	_web_clients.clear()
	if _web_server != null:
		_web_server.stop()
		_web_server = null
		_web_server_port = 0

func _serve_web_request(peer: StreamPeerTCP, request: String) -> void:
	var first_line := request.split("\r\n", false, 1)[0]
	var parts := first_line.split(" ", false)
	if parts.size() < 2:
		_send_http_response(peer, 400, "Bad Request", "text/plain; charset=utf-8", "Bad Request".to_utf8_buffer())
		return
	var method := parts[0].to_upper()
	if method != "GET" and method != "HEAD":
		_send_http_response(peer, 405, "Method Not Allowed", "text/plain; charset=utf-8", "Method Not Allowed".to_utf8_buffer(), method == "HEAD")
		return
	var relative_path := _normalize_web_request_path(parts[1])
	if relative_path.is_empty():
		_send_http_response(peer, 403, "Forbidden", "text/plain; charset=utf-8", "Forbidden".to_utf8_buffer(), method == "HEAD")
		return
	var file_path := WEB_RUNTIME_DIR.path_join(relative_path)
	if not FileAccess.file_exists(file_path):
		push_warning("CEF web 404: request='%s' relative='%s' file='%s' absolute='%s' index_exists=%s map_exists=%s" % [
			parts[1],
			relative_path,
			file_path,
			ProjectSettings.globalize_path(file_path),
			str(FileAccess.file_exists(WEB_RUNTIME_DIR.path_join(WEB_INDEX_FILE))),
			str(FileAccess.file_exists(WEB_RUNTIME_DIR.path_join(WEB_MAP_FILE)))
		])
		_send_http_response(peer, 404, "Not Found", "text/plain; charset=utf-8", "Not Found".to_utf8_buffer(), method == "HEAD")
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_send_http_response(peer, 500, "Internal Server Error", "text/plain; charset=utf-8", "Internal Server Error".to_utf8_buffer(), method == "HEAD")
		return
	_send_http_response(peer, 200, "OK", _mime_type_for_path(relative_path), file.get_buffer(file.get_length()), method == "HEAD")

func _normalize_web_request_path(path: String) -> String:
	var clean_path := path.strip_edges()
	var scheme_index := clean_path.find("://")
	if scheme_index >= 0:
		var path_start := clean_path.find("/", scheme_index + 3)
		clean_path = "/" if path_start < 0 else clean_path.substr(path_start)
	clean_path = clean_path.split("?", false, 1)[0].split("#", false, 1)[0].uri_decode()
	if clean_path == "/" or clean_path.is_empty():
		return WEB_INDEX_FILE
	clean_path = clean_path.trim_prefix("/")
	if clean_path == "favicon.ico":
		return WEB_FAVICON_FILE
	var parts := PackedStringArray()
	for part in clean_path.split("/", false):
		if part == "." or part.is_empty():
			continue
		if part == "..":
			return ""
		parts.append(part)
	return "/".join(parts)

func _log_web_runtime_state() -> void:
	var index_path := WEB_RUNTIME_DIR.path_join(WEB_INDEX_FILE)
	var map_path := WEB_RUNTIME_DIR.path_join(WEB_MAP_FILE)
	print("CEF web runtime root: ", ProjectSettings.globalize_path(WEB_RUNTIME_DIR))
	print("CEF web runtime index exists: ", FileAccess.file_exists(index_path), " path=", index_path, " absolute=", ProjectSettings.globalize_path(index_path))
	print("CEF web runtime map exists: ", FileAccess.file_exists(map_path), " path=", map_path, " absolute=", ProjectSettings.globalize_path(map_path))

func _send_http_response(peer: StreamPeerTCP, status_code: int, status_text: String, content_type: String, body: PackedByteArray, head_only: bool = false) -> void:
	var header := "HTTP/1.1 %s %s\r\nContent-Type: %s\r\nContent-Length: %s\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [
		str(status_code),
		status_text,
		content_type,
		str(body.size())
	]
	peer.put_data(header.to_utf8_buffer())
	if not head_only:
		peer.put_data(body)

func _mime_type_for_path(path: String) -> String:
	match path.get_extension().to_lower():
		"html":
			return "text/html; charset=utf-8"
		"js", "mjs":
			return "text/javascript; charset=utf-8"
		"css":
			return "text/css; charset=utf-8"
		"png":
			return "image/png"
		"svg":
			return "image/svg+xml"
		"json":
			return "application/json; charset=utf-8"
		"wasm":
			return "application/wasm"
		_:
			return "application/octet-stream"

func _ensure_dir(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var err := DirAccess.make_dir_recursive_absolute(absolute_path)
	if err != OK:
		push_error("Cannot create directory: %s (error=%s)" % [path, str(err)])
		return false
	return true

func _to_file_url(path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(path).replace("\\", "/")
	return "file:///" + _encode_file_url_path(absolute_path.trim_prefix("/"))

func _encode_file_url_path(path: String) -> String:
	var encoded := ""
	for index in path.length():
		var character := path.substr(index, 1)
		if character == "/" or character == ":":
			encoded += character
		elif character.is_valid_identifier() or character in ["-", ".", "_", "~"]:
			encoded += character
		else:
			encoded += character.uri_encode()
	return encoded

func _connect_cef_ipc_signals(target: Object, source: String) -> void:
	if target == null:
		return
	for signal_name in ["ipc_message", "ipc_data_message", "ipc_binary_message"]:
		if not target.has_signal(signal_name):
			continue
		var callback := Callable(self, "_on_web_ipc_message").bind(source)
		if not target.is_connected(signal_name, callback):
			target.connect(signal_name, callback)

func _connect_cef_debug_signals(target: Object, source: String) -> void:
	if target == null:
		return
	if target.has_signal("load_started"):
		var load_started := Callable(self, "_on_cef_load_started").bind(source)
		if not target.is_connected("load_started", load_started):
			target.connect("load_started", load_started)
	if target.has_signal("load_error"):
		var load_error := Callable(self, "_on_cef_load_error").bind(source)
		if not target.is_connected("load_error", load_error):
			target.connect("load_error", load_error)
	if target.has_signal("console_message"):
		var console_message := Callable(self, "_on_cef_console_message").bind(source)
		if not target.is_connected("console_message", console_message):
			target.connect("console_message", console_message)

func _on_cef_load_started(url: String, source: String) -> void:
	print("CEF ", source, " load_started url=", url)

func _on_cef_load_error(url: String, error_code: int, error_text: String, source: String) -> void:
	if error_code == -3:
		print("CEF ", source, " load aborted during navigation: ", url)
		return
	push_error("CEF %s load_error url=%s code=%s text=%s" % [source, url, str(error_code), error_text])

func _on_cef_console_message(level: int, message: String, source_url: String, line: int, source: String) -> void:
	print("CEF ", source, " console[", level, "] ", source_url, ":", line, " ", message)

func _process(delta: float) -> void:
	_poll_web_server()
	_flush_web_eval_payloads()

	if keyboard_mouse_transport_enabled:
		_update_keyboard_mouse_sender()

	_transport_retry_elapsed += delta
	if _transport_retry_elapsed >= 1.0:
		_transport_retry_elapsed = 0.0
		_try_bind_transport_signals()

	_link_push_elapsed += delta
	if _link_push_elapsed >= 1.0:
		_link_push_elapsed = 0.0
		_push_link_status()

func _flush_web_eval_payloads() -> void:
	if _shutting_down or _pending_web_eval_payloads.is_empty():
		return
	var pending := _pending_web_eval_payloads.duplicate(true)
	_pending_web_eval_payloads.clear()
	for item in pending:
		var target: Object = item.get("target")
		var function_name := str(item.get("function_name", ""))
		var payload: Dictionary = item.get("payload", {})
		if target == null or function_name.is_empty():
			continue
		if function_name == "godotMapPush" and (map_web == null or target != map_web or not _map_page_ready or not map_web.visible):
			continue
		if function_name == "godotPush" and (target != web or not page_ready):
			continue
		var json := JSON.stringify(payload)
		target.call("eval", "if (window.%s) { window.%s(%s); }" % [function_name, function_name, json])

func _bind_bridge_signals() -> void:
	for signal_name in BRIDGE_SIGNAL_TO_PROTO_KEY.keys():
		var proto_key: String = BRIDGE_SIGNAL_TO_PROTO_KEY[signal_name]
		if not hud_data_bridge.has_signal(signal_name):
			push_warning("HudDataBridge missing signal: %s" % signal_name)
			continue
		var callback := Callable(self, "_on_bridge_signal_received").bind(signal_name, proto_key)
		if not hud_data_bridge.is_connected(signal_name, callback):
			hud_data_bridge.connect(signal_name, callback)

func _on_bridge_signal_received(value, signal_name: String, proto_key: String) -> void:
	_last_data_update_msec = Time.get_ticks_msec()
	var payload := {
		proto_key: _normalize_bridge_value(proto_key, value)
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)
	if _should_push_to_map(proto_key) and _map_page_ready and map_web != null and map_web.visible:
		push_map_payload(payload)
	elif _should_push_to_map(proto_key) and map_web != null and map_web.visible:
		_pending_map_payloads.append(payload)
	print("Bridge->UI ", signal_name, " => ", proto_key)
	_push_link_status()

func _should_push_to_map(proto_key: String) -> bool:
	return MAP_PROTO_KEYS.has(proto_key)

func _on_web_ipc_message(message, source: String = "hud") -> void:
	var parsed = _parse_ipc_payload(message)
	if not (parsed is Dictionary):
		return
	if str(parsed.get("channel", "")) != "hudOperate":
		return
	var operation = parsed.get("operation", {})
	if operation is Dictionary:
		var operation_type := str(operation.get("type", ""))
		print("UI->Godot source=", source, " operation=", operation_type)
		if operation_type == "toggleCommandPanel":
			if source == "map":
				return
			_toggle_command_panel()
			return
		if operation_type == "setCommandPanelOpen":
			if source == "map":
				return
			_set_command_panel_open(bool(operation.get("open", false)))
			return
		if operation_type == "setSettingsMenuOpen":
			if source == "map":
				return
			_set_settings_menu_open(bool(operation.get("open", false)))
			return
		if operation_type == "setMouseSensitivity":
			if source == "map":
				return
			_set_mouse_sensitivity(float(operation.get("value", operation.get("mouseSensitivity", 1.0))))
			return
		if operation_type == "setConnectionSettings":
			if source == "map":
				return
			var apply_connection := bool(operation.get("applyConnection", operation.get("applyNow", false)))
			_apply_connection_settings(operation.get("settings", {}), apply_connection)
			return
		if operation_type == "setDebugLogSettings":
			if source == "map":
				return
			_apply_debug_log_settings(operation.get("settings", {}))
			return
		if operation_type == "chooseDebugLogPath":
			if source == "map":
				return
			_open_debug_log_file_dialog(str(operation.get("currentPath", _debug_log_path)))
			return
		if operation_type == "mapClick":
			if source != "map" or map_web == null or not map_web.visible:
				return
			_send_map_click(operation)
			return
		if source == "map":
			return
		_write_debug_log("ui_operation", {
			"source": source,
			"operationType": operation_type,
			"operation": operation
		})
	hud_operation_bridge.handle_operation(operation)

func _parse_ipc_payload(message):
	if message is Dictionary:
		return message
	if message is Array and message.size() > 0:
		return _parse_ipc_payload(message[0])
	if message is PackedByteArray:
		var byte_text: String = message.get_string_from_utf8()
		return _parse_ipc_payload(byte_text)
	var message_text: String = str(message)
	var json := JSON.new()
	var err: Error = json.parse(message_text)
	if err != OK:
		push_warning("Invalid HUD IPC payload: %s" % message_text)
		return null
	return json.data

func _on_operation_status(status: Dictionary) -> void:
	_write_debug_log("operation_status", status)
	var level := "normal"
	if str(status.get("state", "")) == "failed":
		level = "critical"
	elif str(status.get("state", "")) == "pending":
		level = "important"
	var label := str(status.get("label", "操作"))
	var state := str(status.get("state", "idle"))
	var code := int(status.get("code", 0))
	var text := "%s: %s" % [label, state]
	if code != 0:
		text += " (%d)" % code
	push_payload({
		"commandStatus": status,
		"messageCenter": {
			"items": [
				_build_message_item(text, 2.5, MessagePriority.CRITICAL if level == "critical" else MessagePriority.HIGH, "cmd-%s" % str(status.get("operationType", "")))
			]
		}
	})

func _try_bind_transport_signals() -> void:
	var transport := adapter_getter.get_transport()
	if transport == null:
		_transport = null
		_mqtt_connected = false
		_mqtt_connection_state = "disconnected"
		return
	var adapter := adapter_getter.get_adapter_silent()
	if adapter != null and adapter.has_method("is_transport_bound") and not adapter.is_transport_bound(transport):
		adapter.bind_transport(transport)
	if adapter != null and adapter.has_signal("message_sent") and not adapter.message_sent.is_connected(_on_debug_message_sent):
		adapter.message_sent.connect(_on_debug_message_sent)
	_transport = transport
	_mqtt_connected = transport.is_broker_connected()
	if _mqtt_connected:
		_mqtt_connection_state = "connected"
	if not transport.connected.is_connected(_on_transport_connected):
		transport.connected.connect(_on_transport_connected)
	if not transport.disconnected.is_connected(_on_transport_disconnected):
		transport.disconnected.connect(_on_transport_disconnected)
	if not transport.connection_failed.is_connected(_on_transport_failed):
		transport.connection_failed.connect(_on_transport_failed)
	if not transport.raw_message.is_connected(_on_debug_raw_message):
		transport.raw_message.connect(_on_debug_raw_message)
	if not transport.text_message.is_connected(_on_debug_text_message):
		transport.text_message.connect(_on_debug_text_message)
	_push_link_status()

func _on_transport_connected() -> void:
	_mqtt_connected = true
	_pending_mqtt_connection_key = ""
	_pending_mqtt_client_id = ""
	_mqtt_connection_state = "connected"
	_mqtt_connection_reason = ""
	_write_debug_log("link", {"state": "connected"})
	_push_link_status()

func _on_transport_disconnected(_reason = "") -> void:
	_mqtt_connected = false
	_mqtt_connection_state = "disconnected"
	_mqtt_connection_reason = str(_reason)
	_write_debug_log("link", {"state": "disconnected", "reason": str(_reason)})
	_push_link_status()

func _on_transport_failed(_reason = "") -> void:
	_mqtt_connected = false
	_mqtt_connection_state = "failed"
	_mqtt_connection_reason = str(_reason)
	_write_debug_log("link", {"state": "failed", "reason": str(_reason)})
	_push_link_status()

func _push_link_status() -> void:
	if not page_ready:
		return
	var now := Time.get_ticks_msec()
	var has_data := _last_data_update_msec > 0
	var data_outdated := has_data and now - _last_data_update_msec > 1500
	var data_status := "ok" if has_data else "warning"
	var mqtt_status := _build_mqtt_status_payload(now)
	push_payload({
		"links": [
			{"name": "MQTT", "status": "ok" if _mqtt_connected else "warning", "outdated": false},
			{"name": "VIDEO", "status": "warning", "outdated": false},
			{"name": "DATA", "status": data_status, "outdated": data_outdated}
		],
		"networkStatus": {
			"mqtt": mqtt_status
		}
	})

func _build_mqtt_status_payload(now: int) -> Dictionary:
	var transport := _transport
	if transport == null:
		transport = adapter_getter.get_transport()
	var connected := false
	var broker_url := ""
	var client_id := ""
	if transport != null:
		connected = transport.is_broker_connected()
		broker_url = str(transport.broker_url)
		client_id = str(transport.client_id)
		_mqtt_connected = connected
	var state := _mqtt_connection_state
	if connected:
		state = "connected"
	elif state.is_empty() or state == "connected":
		state = "disconnected"
	return {
		"connected": connected,
		"state": state,
		"clientId": client_id,
		"pendingClientId": _pending_mqtt_client_id,
		"brokerUrl": _canonical_mqtt_broker_url(broker_url),
		"pending": not _pending_mqtt_connection_key.is_empty(),
		"reason": _mqtt_connection_reason,
		"updatedAt": now
	}

func _normalize_bridge_value(proto_key: String, value):
	if value == null:
		return {}
	if proto_key == "Event":
		if value is Object and value.has_method("get_event_id") and value.has_method("get_param"):
			return {
				"event_id": int(value.call("get_event_id")),
				"param": str(value.call("get_param"))
			}
	if proto_key == "CustomByteBlock":
		var data_bytes = null
		if value is PackedByteArray:
			data_bytes = value
		elif value is Object and value.has_method("get_data"):
			data_bytes = value.call("get_data")
		if data_bytes is PackedByteArray:
			return {"data": _bytes_to_int_array(data_bytes)}
	if value is Dictionary or value is Array:
		return value
	if value is PackedByteArray:
		return {"data": _bytes_to_int_array(value)}
	if value is Object and value.has_method("to_dict"):
		var dict_value = value.call("to_dict")
		if dict_value is Dictionary or dict_value is Array:
			return dict_value
	return {"value": str(value)}

func _bytes_to_int_array(bytes: PackedByteArray) -> Array[int]:
	var out: Array[int] = []
	for b in bytes:
		out.append(int(b))
	return out

func _send_map_click(operation: Dictionary) -> void:
	var adapter = adapter_getter.get_adapter_silent()
	if adapter == null:
		_on_operation_status({
			"state": "failed",
			"label": "地图标点",
			"operationType": "mapClick",
			"requestId": 0,
			"code": -1,
			"timestamp": Time.get_ticks_msec()
		})
		return
	var data = AdapterTypes.MapClickCmdData.new()
	var robot_id := str(operation.get("robotId", "")).strip_edges()
	data.is_send_all = 1 if robot_id.is_empty() else int(operation.get("isSendAll", 0))
	data.robot_id = _robot_id_to_bytes(robot_id)
	data.mode = int(operation.get("mode", 0))
	data.enemy_id = int(operation.get("enemyId", operation.get("enemy_id", 0)))
	data.ascii = int(operation.get("ascii", 0))
	data.type = int(operation.get("clickType", operation.get("typeValue", 0)))
	data.map_x = float(operation.get("mapX", 0.0))
	data.map_y = float(operation.get("mapY", 0.0))
	var result := int(adapter.send_map_click_cmd(data))
	_on_operation_status({
		"state": "success" if result >= 0 else "failed",
		"label": "地图标点",
		"operationType": "mapClick",
		"requestId": 0,
		"code": result,
		"timestamp": Time.get_ticks_msec()
	})

func _robot_id_to_bytes(value: String) -> PackedByteArray:
	var out := PackedByteArray()
	var source := value.to_utf8_buffer()
	for i in range(min(source.size(), AdapterTypes.MapClickCmdData.ROBOT_ID_BYTES)):
		out.append(source[i])
	return out

func _input(input_event):
	if input_event is InputEventKey and input_event.keycode == KEY_ESCAPE and input_event.pressed and not input_event.echo:
		_set_settings_menu_open(not _settings_menu_open)
		get_viewport().set_input_as_handled()
		return

	if input_event is InputEventKey and input_event.keycode == KEY_TAB and input_event.pressed and not input_event.echo:
		_toggle_command_panel()
		get_viewport().set_input_as_handled()
		return

	if _is_map_toggle_event(input_event):
		_toggle_map_page()
		get_viewport().set_input_as_handled()
		return

	if input_event is InputEventKey and input_event.keycode == KEY_Q and input_event.pressed and not input_event.echo:
		_spawn_mock_message()

	if keyboard_mouse_transport_enabled:
		if _control_focus_active:
			_capture_keyboard_mouse_input(input_event)
		else:
			_capture_keyboard_input(input_event)

func _is_map_toggle_event(input_event) -> bool:
	if input_event.is_action_pressed("map"):
		return true
	if not (input_event is InputEventKey):
		return false
	if not input_event.pressed or input_event.echo:
		return false
	return input_event.keycode == KEY_M or input_event.physical_keycode == KEY_M

func _toggle_map_page() -> void:
	if map_web == null:
		_ensure_map_web()
	if map_web == null:
		return
	map_web.visible = not map_web.visible
	if map_web.visible:
		_load_cef_url(map_web, _web_runtime_url(WEB_MAP_FILE))
		map_web.move_to_front()
		_push_map_snapshot()
		_flush_pending_map_payloads()
	else:
		_map_page_ready = false
	_refresh_control_focus()
	print("Toggle map UI:", map_web.visible)

func _toggle_command_panel() -> void:
	_set_command_panel_open(not _command_panel_open)

func _set_command_panel_open(open: bool) -> void:
	_command_panel_open = open
	_refresh_control_focus()
	var payload := {
		"commandPanel": {
			"open": _command_panel_open
		}
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)

func _set_settings_menu_open(open: bool) -> void:
	_settings_menu_open = open
	_refresh_control_focus()
	var payload := {
		"settingsMenu": {
			"open": _settings_menu_open
		}
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)

func _set_mouse_sensitivity(value: float) -> void:
	_mouse_sensitivity = clamp(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)

func _setup_debug_log_file_dialog() -> void:
	if _debug_log_file_dialog != null:
		return
	_debug_log_file_dialog = FileDialog.new()
	_debug_log_file_dialog.title = "选择调试日志保存位置"
	_debug_log_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_debug_log_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_debug_log_file_dialog.use_native_dialog = true
	_debug_log_file_dialog.filters = PackedStringArray(["*.jsonl ; JSON Lines", "*.log ; Log", "*.txt ; Text"])
	_debug_log_file_dialog.size = Vector2i(900, 560)
	add_child(_debug_log_file_dialog)
	if not _debug_log_file_dialog.file_selected.is_connected(_on_debug_log_file_selected):
		_debug_log_file_dialog.file_selected.connect(_on_debug_log_file_selected)

func _open_debug_log_file_dialog(current_path: String) -> void:
	_setup_debug_log_file_dialog()
	if _debug_log_file_dialog == null:
		return
	var resolved_path := _normalize_storage_path(current_path)
	if resolved_path.is_empty():
		resolved_path = _debug_log_path
	_debug_log_file_dialog.current_path = _resolve_debug_log_dialog_path(resolved_path)
	_debug_log_file_dialog.popup_centered()

func _on_debug_log_file_selected(path: String) -> void:
	var selected_path := _normalize_storage_path(path)
	if selected_path.is_empty():
		return
	_debug_log_path = selected_path
	var payload := {
		"settingsPatch": {
			"logging": {
				"path": selected_path
			}
		}
	}
	if page_ready:
		push_payload(payload)
	else:
		_pending_bridge_payloads.append(payload)
	if _debug_log_enabled:
		_write_debug_log("config", {
			"path": _debug_log_path,
			"selectedFromDialog": true
		}, true)

func _resolve_debug_log_dialog_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _normalize_storage_path(path: String) -> String:
	var normalized := path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("user://") or normalized.begins_with("res://"):
		return normalized
	if normalized.begins_with("/") or normalized.contains(":/"):
		return normalized
	return "user://" + normalized.trim_prefix("./")

func _globalize_storage_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _apply_debug_log_settings(settings) -> void:
	if not (settings is Dictionary):
		return
	_debug_log_enabled = bool(settings.get("enabled", false))
	var mode := str(settings.get("mode", "receive")).strip_edges()
	_debug_log_mode = "all" if mode == "all" else "receive"
	var path := _normalize_storage_path(str(settings.get("path", _debug_log_path)))
	_debug_log_path = path if not path.is_empty() else "user://logs/rm_synapse_debug.jsonl"
	if _debug_log_enabled:
		_write_debug_log("config", {
			"enabled": _debug_log_enabled,
			"mode": _debug_log_mode,
			"path": _debug_log_path
		}, true)

func _on_debug_raw_message(topic, payload) -> void:
	var bytes := PackedByteArray()
	if payload is PackedByteArray:
		bytes = payload
	_write_debug_log("rx", {
		"topic": str(topic),
		"payloadType": "bytes",
		"size": bytes.size(),
		"sampleHex": _bytes_to_hex_sample(bytes, 48)
	})

func _on_debug_text_message(topic, text) -> void:
	var text_value := str(text)
	_write_debug_log("rx", {
		"topic": str(topic),
		"payloadType": "text",
		"size": text_value.length(),
		"sample": text_value.substr(0, 240)
	})

func _on_debug_message_sent(topic, size, result, qos) -> void:
	_write_debug_log("tx", {
		"topic": str(topic),
		"size": int(size),
		"result": int(result),
		"qos": int(qos)
	})

func _write_debug_log(kind: String, data: Dictionary, force: bool = false) -> void:
	if not force and not _debug_log_enabled:
		return
	if not force and _debug_log_mode != "all" and kind != "rx":
		return
	var now_ticks: int = Time.get_ticks_msec()
	var unix_msec: float = Time.get_unix_time_from_system() * 1000.0
	var topic: String = str(data.get("topic", ""))
	var key: String = kind
	if not topic.is_empty():
		key += ":%s" % topic
	_debug_log_seq += 1
	var key_seq: int = int(_debug_log_seq_by_key.get(key, 0)) + 1
	_debug_log_seq_by_key[key] = key_seq
	var previous_ticks: int = int(_debug_log_last_ticks_by_key.get(key, -1))
	_debug_log_last_ticks_by_key[key] = now_ticks
	var interval_msec = null if previous_ticks < 0 else now_ticks - previous_ticks
	var path := _normalize_storage_path(_debug_log_path)
	if path.is_empty():
		path = "user://logs/rm_synapse_debug.jsonl"
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(_globalize_storage_path(dir_path))
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot open debug log file: %s" % path)
		return
	file.seek_end()
	file.store_string(JSON.stringify({
		"time": Time.get_datetime_string_from_system(true),
		"unixMsec": int(unix_msec),
		"unixUsecApprox": int(unix_msec * 1000.0),
		"ticksMsec": now_ticks,
		"deltaMsec": interval_msec,
		"intervalMsec": interval_msec,
		"seq": _debug_log_seq,
		"seqInKey": key_seq,
		"kind": kind,
		"key": key,
		"data": data
	}) + "\n")
	file.close()

func _bytes_to_hex_sample(bytes: PackedByteArray, max_count: int) -> String:
	var parts: Array[String] = []
	var count: int = min(bytes.size(), max_count)
	for i in range(count):
		parts.append("%02x" % int(bytes[i]))
	return " ".join(parts)

func _apply_connection_settings(settings, apply_connection: bool = false) -> void:
	if not (settings is Dictionary):
		return
	if settings.has("mqtt"):
		_apply_mqtt_settings(settings.get("mqtt", {}), apply_connection)
	if settings.has("video"):
		_apply_video_settings(settings.get("video", {}))
	if settings.has("input"):
		_apply_input_settings(settings.get("input", {}))
	if settings.has("debug"):
		_apply_debug_settings(settings.get("debug", {}))

func _apply_mqtt_settings(mqtt_settings, apply_connection: bool = false) -> void:
	if not (mqtt_settings is Dictionary):
		return
	var transport := adapter_getter.get_transport()
	if transport == null:
		push_warning("Cannot apply MQTT settings: transport not found.")
		return
	var broker_url := _build_endpoint_url(mqtt_settings, "tcp")
	var connection_key := _build_mqtt_connection_key(mqtt_settings, broker_url)
	var requested_client_id := str(mqtt_settings.get("clientId", "")).strip_edges()
	var previous_key := _active_mqtt_connection_key
	if previous_key.is_empty():
		previous_key = _build_mqtt_connection_key_from_transport(transport)
		_active_mqtt_connection_key = previous_key
	var connection_changed := connection_key != previous_key
	if apply_connection:
		transport.broker_url = broker_url
	transport.auto_reconnect = bool(mqtt_settings.get("autoReconnect", true))
	transport.reconnect_delay_ms = int(mqtt_settings.get("reconnectDelayMs", transport.reconnect_delay_ms))
	transport.ping_interval_sec = int(mqtt_settings.get("pingIntervalSec", transport.ping_interval_sec))
	if apply_connection:
		transport.client_id = str(mqtt_settings.get("clientId", ""))
		transport.username = str(mqtt_settings.get("username", ""))
		transport.password = str(mqtt_settings.get("password", ""))
	transport.binary_messages = true
	var client_setter := get_tree().root.get_node_or_null("/root/Mqtt/ClientSetter")
	if client_setter != null:
		_set_object_property_if_exists(client_setter, "auto_reconnect", transport.auto_reconnect)
		_set_object_property_if_exists(client_setter, "reconnect_delay_ms", transport.reconnect_delay_ms)
		_set_object_property_if_exists(client_setter, "ping_interval_sec", transport.ping_interval_sec)
		if apply_connection:
			_set_object_property_if_exists(client_setter, "broker_url", broker_url)
			_set_object_property_if_exists(client_setter, "client_id", transport.client_id)
			_set_object_property_if_exists(client_setter, "username", transport.username)
			_set_object_property_if_exists(client_setter, "password", transport.password)
	_try_bind_transport_signals()
	if apply_connection:
		_pending_mqtt_connection_key = ""
		_pending_mqtt_client_id = requested_client_id
		_mqtt_connection_state = "connecting"
		_mqtt_connection_reason = ""
		_active_mqtt_connection_key = connection_key
		if transport.is_broker_connected():
			print("MQTT settings applied; restarting connection: ", broker_url)
			transport.restart_connection()
		else:
			print("MQTT settings applied; connecting broker: ", broker_url)
			transport.connect_to_broker()
		_push_link_status()
		return
	if connection_changed:
		_pending_mqtt_connection_key = connection_key
		_pending_mqtt_client_id = requested_client_id
		print("MQTT connection settings updated; waiting for Apply & Reconnect: ", broker_url)
	else:
		_pending_mqtt_connection_key = ""
		_pending_mqtt_client_id = ""
		print("MQTT settings updated without reconnect: ", broker_url)
	_push_link_status()

func _apply_video_settings(video_settings) -> void:
	if not (video_settings is Dictionary):
		return
	var enabled := bool(video_settings.get("enabled", true))
	var root := get_tree().root
	var transfer_node := _find_first_node_by_name(root, "TransferImage")
	if transfer_node is CanvasItem:
		transfer_node.visible = enabled
	if transfer_node is Control:
		_set_mouse_filter_recursive(transfer_node, Control.MOUSE_FILTER_IGNORE)
	var video_node := _find_first_node_by_name(root, "RMVideoCanvas")
	if video_node == null:
		push_warning("Cannot apply video settings: RMVideoCanvas not found.")
		return
	if video_node is CanvasItem:
		video_node.visible = enabled
	if video_node is Control:
		_set_mouse_filter_recursive(video_node, Control.MOUSE_FILTER_IGNORE)
	var rotate_180 := bool(video_settings.get("rotate180", video_settings.get("rotate_180", false)))
	_apply_video_display_settings(video_node, rotate_180)
	var port := int(clamp(float(video_settings.get("port", 3334)), MIN_PORT, MAX_PORT))
	var host := str(video_settings.get("host", "0.0.0.0")).strip_edges()
	var source_url := _build_endpoint_url(video_settings, "udp")
	var settings_key := JSON.stringify({
		"enabled": enabled,
		"host": host,
		"port": port,
		"source_url": source_url
	})
	if settings_key == _last_video_settings_key:
		_log_video_status(video_node, "unchanged")
		return
	_last_video_settings_key = settings_key
	_set_first_existing_property(video_node, ["enabled", "active", "auto_start"], enabled)
	_set_first_existing_property(video_node, ["host", "bind_host", "listen_host", "ip", "address"], host)
	_set_first_existing_property(video_node, ["port", "udp_port", "listen_port", "server_port"], port)
	_set_first_existing_property(video_node, ["url", "source", "source_url", "stream_url", "endpoint"], source_url)
	if video_node.has_method("configure"):
		video_node.call("configure", host, port)
	elif video_node.has_method("set_endpoint"):
		video_node.call("set_endpoint", source_url)
	elif video_node.has_method("set_source"):
		video_node.call("set_source", source_url)
	if video_node.has_method("restart"):
		video_node.call("restart")
	elif enabled and video_node.has_method("start"):
		video_node.call("start")
	elif not enabled and video_node.has_method("stop"):
		video_node.call("stop")
	if video_node is Control:
		_set_mouse_filter_recursive(video_node, Control.MOUSE_FILTER_IGNORE)
	_log_video_status(video_node, "applied")

func _apply_video_display_settings(video_node: Object, rotate_180: bool) -> void:
	if video_node == null:
		return
	if video_node.has_method("set_rotate_180"):
		video_node.call("set_rotate_180", rotate_180)
		return
	_set_first_existing_property(video_node, ["rotate_180", "rotate180"], rotate_180)

func _set_mouse_filter_recursive(node: Node, mouse_filter: int) -> void:
	if node is Control:
		node.mouse_filter = mouse_filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, mouse_filter)

func _log_video_status(video_node: Object, reason: String) -> void:
	if video_node == null or not video_node.has_method("get_status"):
		return
	print("Video settings ", reason, ": ", video_node.call("get_status"))

func _apply_input_settings(input_settings) -> void:
	if not (input_settings is Dictionary):
		return
	keyboard_mouse_transport_enabled = bool(input_settings.get("keyboardMouseTransport", keyboard_mouse_transport_enabled))
	if keyboard_mouse_sender != null:
		keyboard_mouse_sender.auto_start = keyboard_mouse_transport_enabled
		if keyboard_mouse_transport_enabled:
			keyboard_mouse_sender.start_sending()
		else:
			keyboard_mouse_sender.stop_sending()

func _apply_debug_settings(debug_settings) -> void:
	if not (debug_settings is Dictionary):
		return
	var endpoint := str(debug_settings.get("logEndpoint", "")).strip_edges()
	_set_object_property_if_exists(Log, "remote_endpoint", endpoint)
	_set_object_property_if_exists(Log, "remote_enabled", not endpoint.is_empty())

func _build_mqtt_connection_key(settings: Dictionary, broker_url: String) -> String:
	return JSON.stringify({
		"broker_url": _canonical_mqtt_broker_url(broker_url),
		"client_id": str(settings.get("clientId", "")),
		"username": str(settings.get("username", "")),
		"password": str(settings.get("password", "")),
		"binary_messages": true
	})

func _build_mqtt_connection_key_from_transport(transport: NetworkTransport) -> String:
	if transport == null:
		return ""
	return JSON.stringify({
		"broker_url": _canonical_mqtt_broker_url(str(transport.broker_url)),
		"client_id": str(transport.client_id),
		"username": str(transport.username),
		"password": str(transport.password),
		"binary_messages": bool(transport.binary_messages)
	})

func _canonical_mqtt_broker_url(value: String) -> String:
	var broker_url := value.strip_edges()
	if broker_url.is_empty():
		return "tcp://%s:3333" % DEFAULT_MQTT_BROKER_HOST
	if broker_url.contains("://"):
		return broker_url
	return "tcp://" + broker_url

func _build_endpoint_url(settings: Dictionary, fallback_protocol: String) -> String:
	var protocol := str(settings.get("protocol", fallback_protocol)).strip_edges().replace("://", "").replace(":/", "")
	if protocol.is_empty():
		protocol = fallback_protocol
	var default_host := DEFAULT_MQTT_BROKER_HOST if fallback_protocol == "tcp" else "127.0.0.1"
	var host := str(settings.get("host", default_host)).strip_edges()
	if host.is_empty():
		host = default_host
	var port := int(clamp(float(settings.get("port", 3333)), MIN_PORT, MAX_PORT))
	var path := str(settings.get("path", "")).strip_edges()
	if not path.is_empty() and not path.begins_with("/"):
		path = "/" + path
	return "%s://%s:%d%s" % [protocol, host, port, path]

func _find_first_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_first_node_by_name(child, node_name)
		if found != null:
			return found
	return null

func _set_first_existing_property(target: Object, property_names: Array, value) -> bool:
	for property_name in property_names:
		if _set_object_property_if_exists(target, str(property_name), value):
			return true
	return false

func _set_object_property_if_exists(target: Object, property_name: String, value) -> bool:
	if target == null:
		return false
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return true
	return false

func _ensure_child_node(node: Node) -> void:
	if node != null and node.get_parent() == null:
		add_child(node)

func _assign_adapter_getter(owner: Object) -> void:
	if owner == null:
		return
	var previous = owner.get("adapter_getter")
	if previous == adapter_getter:
		return
	owner.set("adapter_getter", adapter_getter)
	if previous is Node and previous.get_parent() == null:
		previous.free()

func _refresh_control_focus() -> void:
	var map_open: bool = map_web != null and map_web.visible
	_set_control_focus(not _command_panel_open and not _settings_menu_open and not map_open)

func _set_control_focus(active: bool) -> void:
	_control_focus_active = active
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE)
	if not active:
		_mouse_delta = Vector2.ZERO
		_mouse_wheel_delta = 0
		_left_button_down = false
		_right_button_down = false
		_mid_button_down = false

func _capture_keyboard_mouse_input(input_event) -> void:
	if input_event is InputEventMouseMotion:
		_mouse_delta += input_event.relative
		return
	if input_event is InputEventMouseButton:
		match input_event.button_index:
			MOUSE_BUTTON_LEFT:
				_left_button_down = input_event.pressed
			MOUSE_BUTTON_RIGHT:
				_right_button_down = input_event.pressed
			MOUSE_BUTTON_MIDDLE:
				_mid_button_down = input_event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if input_event.pressed:
					_mouse_wheel_delta += 1
			MOUSE_BUTTON_WHEEL_DOWN:
				if input_event.pressed:
					_mouse_wheel_delta -= 1
		return
	if input_event is InputEventKey and not input_event.echo:
		_capture_keyboard_input(input_event)

func _capture_keyboard_input(input_event) -> void:
	if not (input_event is InputEventKey) or input_event.echo:
		return
	var bit := _keyboard_bit_for_event(input_event)
	if bit < 0:
		return
	if input_event.pressed:
		_pressed_key_bits[bit] = true
	else:
		_pressed_key_bits.erase(bit)

func _keyboard_bit_for_event(input_event: InputEventKey) -> int:
	var physical := input_event.physical_keycode
	var key := input_event.keycode
	if KEYBOARD_BIT_BY_PHYSICAL_KEY.has(physical):
		return int(KEYBOARD_BIT_BY_PHYSICAL_KEY[physical])
	if KEYBOARD_BIT_BY_PHYSICAL_KEY.has(key):
		return int(KEYBOARD_BIT_BY_PHYSICAL_KEY[key])
	return -1

func _keyboard_value() -> int:
	var value := 0
	for bit in _pressed_key_bits.keys():
		value |= 1 << int(bit)
	return value

func _update_keyboard_mouse_sender() -> void:
	var data := AdapterTypes.KeyboardMouseControlData.new()
	if _control_focus_active:
		data.mouse_x = int(round(_mouse_delta.x * _mouse_sensitivity))
		data.mouse_y = int(round(-_mouse_delta.y * _mouse_sensitivity))
		data.mouse_z = _mouse_wheel_delta
		data.left_button_down = _left_button_down
		data.right_button_down = _right_button_down
		data.mid_button_down = _mid_button_down
	data.keyboard_value = _keyboard_value()
	keyboard_mouse_sender.update_data(data)
	_mouse_delta = Vector2.ZERO
	_mouse_wheel_delta = 0

func _priority_to_level(priority: int) -> String:
	match priority:
		MessagePriority.CRITICAL:
			return "critical"
		MessagePriority.HIGH:
			return "important"
		_:
			return "normal"

func _build_message_item(text: String, duration: float, priority: int, tag: String = "") -> Dictionary:
	var ttl := duration if duration > 0.0 else message_default_duration
	ttl = max(ttl, 0.2)
	_message_seq += 1
	var now_ms := Time.get_ticks_msec()
	var item := {
		"id": "gd-msg-%s-%s" % [str(now_ms), str(_message_seq)],
		"level": _priority_to_level(priority),
		"text": text,
		"duration": int(round(ttl * 1000.0)),
		"timestamp": now_ms
	}
	if not tag.strip_edges().is_empty():
		item["tag"] = tag.strip_edges()
	return item

func _push_message_items(items: Array[Dictionary]) -> void:
	if items.is_empty():
		return

	if not page_ready:
		for item in items:
			_pending_message_items.append(item)
		while _pending_message_items.size() > max(message_max_count, 1):
			_pending_message_items.remove_at(0)
		return

	push_payload({
		"messageCenter": {
			"items": items
		}
	})

func _flush_pending_messages() -> void:
	if not page_ready or _pending_message_items.is_empty():
		return
	var pending: Array[Dictionary] = _pending_message_items.duplicate(true)
	_pending_message_items.clear()
	push_payload({
		"messageCenter": {
			"items": pending
		}
	})

func _flush_pending_bridge_payloads() -> void:
	if not page_ready or _pending_bridge_payloads.is_empty():
		return
	var pending: Array[Dictionary] = _pending_bridge_payloads.duplicate(true)
	_pending_bridge_payloads.clear()
	for payload in pending:
		print("Flushing pending bridge payload: ", payload)
		push_payload(payload)

func _flush_pending_map_payloads() -> void:
	if not _map_page_ready or map_web == null or not map_web.visible or _pending_map_payloads.is_empty():
		return
	var pending: Array[Dictionary] = _pending_map_payloads.duplicate(true)
	_pending_map_payloads.clear()
	for payload in pending:
		push_map_payload(payload)

func _push_map_snapshot() -> void:
	if not _map_page_ready or map_web == null or not map_web.visible:
		return
	_push_map_state("GlobalUnitStatus", hud_data_bridge.get_global_unit_status_state())
	_push_map_state("RobotPosition", hud_data_bridge.get_robot_position_state())
	_push_map_state("RobotPathPlanInfo", hud_data_bridge.get_robot_path_plan_info_state())
	_push_map_state("RadarInfoToClient", hud_data_bridge.get_radar_info_state())

func _push_map_state(proto_key: String, value) -> void:
	if not _should_push_to_map(proto_key):
		return
	push_map_payload({
		proto_key: _normalize_bridge_value(proto_key, value)
	})

func add_message(text: String, duration := -1.0, priority := MessagePriority.MEDIUM, tag := "") -> void:
	var trimmed_text := text.strip_edges()
	if trimmed_text.is_empty():
		return
	var item := _build_message_item(trimmed_text, duration, priority, tag)
	var items: Array[Dictionary] = [item]
	_push_message_items(items)

func _spawn_mock_message():
	var msgs := [
		{ "text": "🔥 英雄 [狂战士] 击杀了 [突击手]", "duration": 4.0, "priority": MessagePriority.HIGH, "tag": "mock-kill" },
		{ "text": "⚠️ 全局播报：左侧基地正在遭受攻击！", "duration": 6.0, "priority": MessagePriority.CRITICAL, "tag": "mock-base-under-attack" },
		{ "text": "🛡️ 团队护甲升级完毕", "duration": 3.5, "priority": MessagePriority.MEDIUM, "tag": "mock-armor-upgrade" },
		{ "text": "💠 队友占领了前哨站", "duration": 3.0, "priority": MessagePriority.LOW, "tag": "mock-outpost" }
	]
	var sample: Dictionary = msgs[randi() % msgs.size()]
	add_message(sample["text"], sample["duration"], sample["priority"], sample["tag"])

func push_payload(payload: Dictionary) -> void:
	if _shutting_down or not page_ready:
		print("CEF page not ready, skip push")
		return
	if web:
		var json := JSON.stringify(payload)
		print("Pushing HUD payload bytes=", json.length())
		_pending_web_eval_payloads.append({"target": web, "function_name": "godotPush", "payload": payload})

func push_map_payload(payload: Dictionary) -> void:
	if _shutting_down or not _map_page_ready or map_web == null or not map_web.visible:
		return
	_pending_web_eval_payloads.append({"target": map_web, "function_name": "godotMapPush", "payload": payload})
