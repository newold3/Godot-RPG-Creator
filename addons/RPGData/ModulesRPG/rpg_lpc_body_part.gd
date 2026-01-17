@tool
class_name RPGLPCBodyPart
extends  Resource


func get_class(): return "RPGLPCBodyPart"


@export var current_primary_color_id: int = 0
@export var current_secondary_color_id: int = 0
@export var current_fixed_color_id: int = 0
@export var part_id: String = ""
@export var config_path: String = ""
@export var alt_config_path: String = ""
@export var front_texture: String = ""
@export var back_texture: String = ""
@export var equipment_preview: String = ""
@export var is_large_texture: bool = false
@export var is_alt: bool = false
@export var palette1: RPGLPCPalette = RPGLPCPalette.new()
@export var palette2: RPGLPCPalette = RPGLPCPalette.new()
@export var palette3: RPGLPCPalette = RPGLPCPalette.new()
@export var gradient1: PackedColorArray = []
@export var gradient2: PackedColorArray = []
@export var gradient3: PackedColorArray = []


func clear() -> void:
	for key in ["part_id", "config_path", "alt_config_path", "front_texture", "back_texture", "equipment_preview"]:
		set(key, "")
	is_large_texture = false
	is_alt = false
	for key in ["palette1", "palette2", "palette3", "gradient1", "gradient2", "gradient3"]:
		get(key).clear()


func _to_string() -> String:
	return "part_id: %s, pal 1 = %s, pal 2 = %s, pal3 = %s" % [part_id, palette1, palette2, palette3]
