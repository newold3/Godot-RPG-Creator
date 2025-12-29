@tool
class_name RPGLPCBodyPart
extends  Resource


func get_class(): return "RPGLPCBodyPart"


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


func _to_string() -> String:
	return "part_id: %s, pal 1 = %s, pal 2 = %s, pal3 = %s" % [part_id, palette1, palette2, palette3]
