extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _bar: ProgressBar = $Bar
@onready var _label: RichTextLabel = $Label

var _gs: Node = null
var _max_val: int = 0
var _cur_val: int = 0

func _ready() -> void:
    _reset()
    _gs = _resolve_game_state()
    if _gs:
        if _gs.has_signal("robot_static_status_updated"):
            _gs.connect("robot_static_status_updated", Callable(self, "_on_static"))
        if _gs.has_signal("robot_dynamic_status_updated"):
            _gs.connect("robot_dynamic_status_updated", Callable(self, "_on_dynamic"))
    else:
        push_warning("[BufferEnergy] GameState not found at %s" % str(game_state_path))

func _reset() -> void:
    _max_val = 0
    _cur_val = 0
    if _bar:
        _bar.max_value = 1
        _bar.value = 0
    if _label:
        _label.text = "缓冲: --/--"

func _on_static(value) -> void:
    if value:
        _max_val = int(_get_val(value, "max_buffer_energy", _max_val))
        _apply()

func _on_dynamic(value) -> void:
    if value:
        _cur_val = int(_get_val(value, "current_buffer_energy", _cur_val))
        _apply()

func _apply() -> void:
    if _bar:
        _bar.max_value = max(1, _max_val)
        _bar.value = clamp(_cur_val, 0, _bar.max_value)
    if _label:
        _label.text = "缓冲: %d/%d" % [_cur_val, _max_val]

func _resolve_game_state() -> Node:
    if game_state_path != NodePath("") and has_node(game_state_path):
        return get_node(game_state_path)
    if Engine.has_singleton("GameState"):
        return Engine.get_singleton("GameState")
    return null
func _get_val(src, key_name: String, default_val):
    if typeof(src) == TYPE_DICTIONARY:
        if src.has(key_name):
            return src.get(key_name, default_val)
    if src == null:
        return default_val
    if src.has_method("get_" + key_name):
        return src.call("get_" + key_name)
    if src.has_method("has") and src.has(key_name):
        return src.get(key_name)
    push_warning("[BufferEnergy] missing key %s on %s, default %s" % [key_name, str(src), str(default_val)])
    return default_val
