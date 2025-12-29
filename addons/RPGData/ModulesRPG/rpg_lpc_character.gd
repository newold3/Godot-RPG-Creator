@tool
class_name RPGLPCCharacter
extends  Resource


func get_class(): return "RPGLPCCharacter"


@export var body_type: String = ""
@export var head_type: String = ""
@export var palette: String = ""
@export var race: String = ""
@export var gender: String = ""
@export var equipment_parts: RPGLPCEquipmentData = RPGLPCEquipmentData.new()
@export var body_parts: RPGLPCBodyData = RPGLPCBodyData.new()
@export var always_show_weapon: bool = false
@export var inmutable: bool = false
@export var face_preview: String = ""
@export var character_preview: String = ""
@export var battler_preview: String = ""
@export var event_preview: String = ""
@export var scene_path: String = ""
@export var hidden_items: Array = []


func set_generic_config() -> void:
	equipment_parts = null
	body_parts = null
	hidden_items.clear()


func _to_string() -> String:
	return str([
		"Body = %s" % body_type,
		"Head = %s" % head_type,
		"Palette = %s" % palette,
		"Race = %s" % race,
		"Gender = %s" % gender
	])


func serialize_character_to_database() -> Dictionary:
	var character_data = {
		"body_type": body_type,
		"head_type": head_type,
		"palette": palette,
		"race": race,
		"gender": gender,
		"always_show_weapon": always_show_weapon,
		"inmutable": inmutable,
		"previews": {
			"face": face_preview,
			"character": character_preview,
			"battler": battler_preview,
			"event": event_preview
		},
		"scene_path": scene_path,
		"hidden_items": hidden_items,
		
		"equipment": serialize_equipment_data(equipment_parts),
		"body_parts": serialize_body_parts(body_parts)
	}
	
	return character_data

func serialize_equipment_data(equipment: RPGLPCEquipmentData) -> Dictionary:
	return {
		"mask": serialize_equipment_part(equipment.mask),
		"hat": serialize_equipment_part(equipment.hat),
		"glasses": serialize_equipment_part(equipment.glasses),
		"suit": serialize_equipment_part(equipment.suit),
		"jacket": serialize_equipment_part(equipment.jacket),
		"shirt": serialize_equipment_part(equipment.shirt),
		"gloves": serialize_equipment_part(equipment.gloves),
		"belt": serialize_equipment_part(equipment.belt),
		"pants": serialize_equipment_part(equipment.pants),
		"shoes": serialize_equipment_part(equipment.shoes),
		"back": serialize_equipment_part(equipment.back),
		"mainhand": serialize_equipment_part(equipment.mainhand),
		"offhand": serialize_equipment_part(equipment.offhand),
		"ammo": serialize_equipment_part(equipment.ammo)
	}

func serialize_equipment_part(part: RPGLPCEquipmentPart) -> Dictionary:
	return {
		"config_path": part.config_path,
		"part_id": part.part_id,
		"body_type": part.body_type,
		"head_type": part.head_type,
		"equipment_preview": part.equipment_preview,
		"name": part.name,
		"front_texture": part.front_texture,
		"back_texture": part.back_texture,
		"is_large_texture": part.is_large_texture,
		"palettes": {
			"palette1": serialize_palette(part.palette1),
			"palette2": serialize_palette(part.palette2),
			"palette3": serialize_palette(part.palette3)
		}
	}

func serialize_body_parts(body_data: RPGLPCBodyData) -> Dictionary:
	var parts = {}
	var part_names = [
		"body", "head", "eyes", "wings", "tail", "horns", 
		"hair", "hairadd", "ears", "nose", "facial", 
		"add1", "add2", "add3"
	]
	
	for part_name in part_names:
		var part = body_data.get(part_name)
		parts[part_name] = serialize_body_part(part)
	
	return parts

func serialize_body_part(part: RPGLPCBodyPart) -> Dictionary:
	return {
		"part_id": part.part_id,
		"config_path": part.config_path,
		"alt_config_path": part.alt_config_path,
		"front_texture": part.front_texture,
		"back_texture": part.back_texture,
		"equipment_preview": part.equipment_preview,
		"is_large_texture": part.is_large_texture,
		"is_alt": part.is_alt,
		"palettes": {
			"palette1": serialize_palette(part.palette1),
			"palette2": serialize_palette(part.palette2),
			"palette3": serialize_palette(part.palette3)
		}
	}

func serialize_palette(palette: RPGLPCPalette) -> Dictionary:
	return {
		"blend_color": palette.blend_color,
		"lightness": palette.lightness,
		"colors": Array(palette.colors)  # Convert PackedInt64Array to regular Array
	}
