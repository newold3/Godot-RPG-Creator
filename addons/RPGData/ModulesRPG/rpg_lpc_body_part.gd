@tool
class_name RPGLPCBodyPart
extends  Resource


func get_class(): return "RPGLPCBodyPart"

var is_cleaning_for_save: bool = false

@export var current_primary_color_id: int = 0
@export var current_secondary_color_id: int = 0
@export var current_fixed_color_id: int = 0
@export var part_id: String = ""
@export var layer_id: String = ""
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

var _gradient1: PackedColorArray
@export var gradient1: PackedColorArray:
	set(v): _gradient1 = v
	get:
		if is_cleaning_for_save:
			return PackedColorArray()
		if _gradient1.is_empty() and palette1 and not palette1.colors.is_empty():
			_gradient1 = _generate_gradient_internal(palette1.colors)
		return _gradient1

var _gradient2: PackedColorArray
@export var gradient2: PackedColorArray:
	set(v): _gradient2 = v
	get:
		if is_cleaning_for_save:
			return PackedColorArray()
		if _gradient2.is_empty() and palette1 and not palette1.colors.is_empty():
			_gradient2 = _generate_gradient_internal(palette1.colors)
		return _gradient2

var _gradient3: PackedColorArray
@export var gradient3: PackedColorArray:
	set(v): _gradient3 = v
	get:
		if is_cleaning_for_save:
			return PackedColorArray()
		if _gradient3.is_empty() and palette1 and not palette1.colors.is_empty():
			_gradient3 = _generate_gradient_internal(palette1.colors)
		return _gradient3


func _generate_gradient_internal(current_data_color: PackedInt64Array) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	
	if current_data_color.size() > 0:
		for i in range(0, current_data_color.size(), 2):
			var index = int(current_data_color[i])
			
			if i + 1 < current_data_color.size():
				var color_val = Color(int(current_data_color[i+1]))
				
				if index >= 0 and index < 256:
					colors[index] = color_val
		
	return colors


func clear() -> void:
	for key in ["part_id", "config_path", "alt_config_path", "front_texture", "back_texture", "equipment_preview"]:
		set(key, "")
	is_large_texture = false
	is_alt = false
	for key in ["palette1", "palette2", "palette3", "gradient1", "gradient2", "gradient3"]:
		get(key).clear()


func _to_string() -> String:
	return "part_id: %s, pal 1 = %s, pal 2 = %s, pal3 = %s" % [part_id, palette1, palette2, palette3]
