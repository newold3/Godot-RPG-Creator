@tool
class_name RPGLPCEquipmentPart
extends  Resource


func get_class(): return "RPGLPCEquipmentPart"


@export var current_primary_color_id: int = 0
@export var current_secondary_color_id: int = 0
@export var current_fixed_color_id: int = 0
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
@export var gradient1: PackedColorArray = []
@export var gradient2: PackedColorArray = []
@export var gradient3: PackedColorArray = []
@export var ammo: RPGLPCEquipmentPart = null


func clear() -> void:
	for key in ["config_path", "part_id", "body_type", "head_type", "equipment_preview", "name", "front_texture", "back_texture"]:
		set(key, "")
	is_large_texture = false
	for key in ["palette1", "palette2", "palette3", "gradient1", "gradient2", "gradient3", "ammo"]:
		var obj = get(key)
		if obj:
			obj.clear()


func _to_string() -> String:
	return "part_id: %s, config_path: %s, body_type: %s, head_type: %s, %s, %s, %s" % [part_id, config_path, body_type, head_type, palette1, palette2, palette3]
