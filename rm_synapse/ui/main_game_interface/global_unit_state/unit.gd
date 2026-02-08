extends Node2D
class_name RM_Unit_Node

@export var unit_id: int = -1
@export var unit_image: Texture2D = null
@export var unit_max_hp: float = 100.0
@export var unit_current_hp: float = 100.0

# 关键1：_ready()前加async，开启协程支持
func _ready() -> void:
	# 关键2：等待1帧，让CanvasLayer/Panel/HPBar完成加载
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 原有路径，无需修改
	var id = $ID as RichTextLabel
	var image =  $"哨兵icon" as TextureRect
	var hp_bar = $HPBar  as ProgressBar

	# 空判断保留，双重保险
	if id:
		id.text = str(unit_id)
	if unit_image != null and image:
		image.texture = unit_image
	if hp_bar:
		hp_bar.max_value = unit_max_hp
		hp_bar.value = unit_current_hp
	else:
		print("❌ 等待帧后仍未找到HPBar，检查节点是否属于UnitBlue子树")

func set_max_hp(hp: float) -> void:
	var hp_bar = $HPBar as ProgressBar
	if hp_bar:
		hp_bar.max_value = hp

func set_current_hp(hp: float) -> void:
	var hp_bar = $HPBar as ProgressBar
	if hp_bar:
		hp_bar.value = hp
