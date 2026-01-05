extends Control

@export var game_state_path: NodePath = NodePath("/root/MqttNet/GameState")

@onready var _type_label: RichTextLabel = $HBox/Type
@onready var _time_label: RichTextLabel = $HBox/Time
@onready var _count_label: RichTextLabel = $HBox/Count

var _gs: Node = null

const PENALTY_NAME := {
    1: "黄牌",
    2: "双方黄牌",
    3: "红牌",
    4: "超功率",
    5: "超热量",
    6: "超射速"
}

func _ready() -> void:
    visible = false
    _gs = _resolve_game_state()
    if _gs:
        if _gs.has_signal("penalty_info_updated"):
            _gs.connect("penalty_info_updated", Callable(self, "_on_penalty"))
    else:
        push_warning("[PenaltyInfo] GameState not found at %s" % str(game_state_path))

func _on_penalty(value) -> void:
    if value == null:
        visible = false
        return
    var p_type = int(_getv(value, "penalty_type", -1))
    var p_time = int(_getv(value, "penalty_effect_sec", 0))
    var p_total = int(_getv(value, "total_penalty_num", 0))

    if p_type == -1:
        visible = false
        return

    _type_label.text = "类型: %s" % PENALTY_NAME.get(p_type, "未知(%d)" % p_type)
    _time_label.text = "剩余: %ds" % p_time
    _count_label.text = "累计: %d" % p_total

    visible = true

func _resolve_game_state() -> Node:
    if game_state_path != NodePath("") and has_node(game_state_path):
        return get_node(game_state_path)
    if Engine.has_singleton("GameState"):
        return Engine.get_singleton("GameState")
    return null

func _getv(src, key_name: String, default_val):
    if src == null:
        return default_val
    if typeof(src) == TYPE_DICTIONARY:
        return src.get(key_name, default_val)
    if src.has_method("get_" + key_name):
        return src.call("get_" + key_name)
    if src.has_method("has") and src.has(key_name):
        return src.get(key_name)
    return default_val
