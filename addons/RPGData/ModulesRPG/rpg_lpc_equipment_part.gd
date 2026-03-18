@tool
class_name RPGLPCEquipmentPart
extends  Resource


func get_class(): return "RPGLPCEquipmentPart"


var is_cleaning_for_save: bool = false

@export var current_primary_color_id: int = 0
@export var current_secondary_color_id: int = 0
@export var current_fixed_color_id: int = 0
@export var config_path: String = ""
@export var part_id: String = ""
@export var layer_id: String = ""
@export var body_type: String = ""
@export var head_type: String = ""
@export var equipment_preview: String = ""
@export var name: String = ""
@export var front_texture: String = ""
@export var back_texture: String = ""
@export var is_large_texture: bool = false
@export var tags: PackedStringArray = []
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

@export var ammo: RPGLPCEquipmentPart = null


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
	for key in ["config_path", "part_id", "body_type", "head_type", "equipment_preview", "name", "front_texture", "back_texture"]:
		set(key, "")
	is_large_texture = false
	for key in ["palette1", "palette2", "palette3", "gradient1", "gradient2", "gradient3", "ammo", "tags"]:
		var obj = get(key)
		if obj:
			obj.clear()


func _to_string() -> String:
	return "part_id: %s, config_path: %s, body_type: %s, head_type: %s, %s, %s, %s" % [part_id, config_path, body_type, head_type, palette1, palette2, palette3]
