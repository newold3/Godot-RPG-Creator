@tool
class_name RPGLPCEquipmentPart
extends  Resource


func get_class(): return "RPGLPCEquipmentPart"


@export var config_path: String = ""
@export var part_id: String = ""
@export var body_type: String = ""
@export var head_type: String = ""
@export var equipment_preview: String = ""
@export var name: String = ""
@export var front_texture: String = ""
@export var back_texture: String = ""
@export var is_large_texture: bool = false
@export var palette1: RPGLPCPalette = RPGLPCPalette.new()
@export var palette2: RPGLPCPalette = RPGLPCPalette.new()
@export var palette3: RPGLPCPalette = RPGLPCPalette.new()
@export var ammo: RPGLPCEquipmentPart = null


func _to_string() -> String:
	return "part_id: %s, config_path: %s, body_type: %s, head_type: %s, %s, %s, %s" % [part_id, config_path, body_type, head_type, palette1, palette2, palette3]
