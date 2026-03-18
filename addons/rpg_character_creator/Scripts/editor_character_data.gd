class_name EditorCharacterData
extends Resource

@export var character: Dictionary

@export var textures: Dictionary = {
	"back_texture_back": CharacterPart.new("back"),
	"tail_texture_back": CharacterPart.new("back"),
	"wings_texture_back": CharacterPart.new("back"),
	"body_texture": CharacterPart.new("normal"),
	"add2_texture": CharacterPart.new("normal"),
	"suit_texture": CharacterPart.new("normal"),
	"pants_texture": CharacterPart.new("normal"),
	"shoes_texture": CharacterPart.new("normal"),
	"gloves_texture": CharacterPart.new("normal"),
	"shirt_texture": CharacterPart.new("normal"),
	"belt_texture": CharacterPart.new("normal"),
	"add3_texture": CharacterPart.new("normal"),
	"jacket_texture": CharacterPart.new("normal"),
	"head_texture": CharacterPart.new("normal"),
	"eyes_texture": CharacterPart.new("normal"),
	"facial_texture": CharacterPart.new("normal"),
	"ears_texture": CharacterPart.new("normal"),
	"nose_texture": CharacterPart.new("normal"),
	"add1_texture": CharacterPart.new("normal"),
	"mask_texture": CharacterPart.new("normal"),
	"glasses_texture": CharacterPart.new("normal"),
	"hair_texture": CharacterPart.new("normal"),
	"hairadd_texture": CharacterPart.new("normal"),
	"hat_texture": CharacterPart.new("normal"),
	"tail_texture_front": CharacterPart.new("front"),
	"back_texture_front": CharacterPart.new("front"),
	"wings_texture_front": CharacterPart.new("front"),
	"horns_texture": CharacterPart.new("normal"),
	"mainhand_texture_back": CharacterPart.new("back"),
	"mainhand_texture_front": CharacterPart.new("front"),
	"offhand_texture_back": CharacterPart.new("back"),
	"offhand_texture_front": CharacterPart.new("front"),
	"ammo_texture_back": CharacterPart.new("back"),
	"ammo_texture_front": CharacterPart.new("front"),
}

@export var slotsalt = []
@export var slotshidden = []
@export var slotsset = []

@export var weapon_data = {
	"actions": [],
	"ammo": [],
	"sounds": []
}


func load_character(character: RPGLPCCharacter, clone: bool = false) -> EditorCharacterData:
	var editor_data = self if !clone else EditorCharacterData.new()
	
	# Copiar datos del personaje
	editor_data.character = {
		"body_type": character.body_type,
		"head_type": character.head_type,
		"palette": character.palette,
		"race": character.race,
		"gender": character.gender,
		"always_show_weapon": character.always_show_weapon,
		"inmutable": character.inmutable,
		"hidden_items": character.hidden_items
	}
	
	# Mapear texturas
	var texture_mapping = {
		"back_texture_back": get_texture_from_part(character.body_parts.wings, "back"),
		"tail_texture_back": get_texture_from_part(character.body_parts.tail, "back"),
		"wings_texture_back": get_texture_from_part(character.body_parts.wings, "back"),
		"body_texture": get_texture_from_part(character.body_parts.body, "normal"),
		"add2_texture": get_texture_from_part(character.body_parts.add2, "normal"),
		"suit_texture": get_texture_from_equipment(character.equipment_parts.suit),
		"pants_texture": get_texture_from_equipment(character.equipment_parts.pants),
		"shoes_texture": get_texture_from_equipment(character.equipment_parts.shoes),
		"gloves_texture": get_texture_from_equipment(character.equipment_parts.gloves),
		"shirt_texture": get_texture_from_equipment(character.equipment_parts.shirt),
		"belt_texture": get_texture_from_equipment(character.equipment_parts.belt),
		"add3_texture": get_texture_from_part(character.body_parts.add3, "normal"),
		"jacket_texture": get_texture_from_equipment(character.equipment_parts.jacket),
		"head_texture": get_texture_from_part(character.body_parts.head, "normal"),
		"eyes_texture": get_texture_from_part(character.body_parts.eyes, "normal"),
		"facial_texture": get_texture_from_part(character.body_parts.facial, "normal"),
		"ears_texture": get_texture_from_part(character.body_parts.ears, "normal"),
		"nose_texture": get_texture_from_part(character.body_parts.nose, "normal"),
		"add1_texture": get_texture_from_part(character.body_parts.add1, "normal"),
		"mask_texture": get_texture_from_equipment(character.equipment_parts.mask),
		"glasses_texture": get_texture_from_equipment(character.equipment_parts.glasses),
		"hair_texture": get_texture_from_part(character.body_parts.hair, "normal"),
		"hairadd_texture": get_texture_from_part(character.body_parts.hairadd, "normal"),
		"hat_texture": get_texture_from_equipment(character.equipment_parts.hat),
		"tail_texture_front": get_texture_from_part(character.body_parts.tail, "front"),
		"back_texture_front": get_texture_from_part(character.body_parts.wings, "front"),
		"wings_texture_front": get_texture_from_part(character.body_parts.wings, "front"),
		"horns_texture": get_texture_from_part(character.body_parts.horns, "normal"),
		"mainhand_texture_back": get_texture_from_equipment(character.equipment_parts.mainhand, "back"),
		"mainhand_texture_front": get_texture_from_equipment(character.equipment_parts.mainhand, "front"),
		"offhand_texture_back": get_texture_from_equipment(character.equipment_parts.offhand, "back"),
		"offhand_texture_front": get_texture_from_equipment(character.equipment_parts.offhand, "front"),
		"ammo_texture_back": get_texture_from_equipment(character.equipment_parts.ammo, "back"),
		"ammo_texture_front": get_texture_from_equipment(character.equipment_parts.ammo, "front")
	}
	
	# Asignar texturas
	for key in texture_mapping.keys():
		editor_data.textures[key] = texture_mapping[key]
	
	# Copiar slots alternativos, ocultos, etc.
	editor_data.slotsalt = character.slotsalt if "slotsalt" in character else []
	editor_data.slotshidden = character.slotshidden if "slotshidden" in character else []
	editor_data.slotsset = character.slotsset if "slotsset" in character else []
	
	# Copiar datos de armas
	editor_data.weapon_data = character.weapon_data if "weapon_data" in character else {
		"actions": [],
		"ammo": [],
		"sounds": []
	}
	
	return editor_data

func get_textures_from_part(part_id: String) -> Dictionary:
	var key_normal = part_id + "_texture"
	var key_front = part_id + "_texture_front"
	var key_back = part_id + "_texture_back"
	
	var front = textures[key_front] if key_front in textures else textures[key_normal]
	var back = textures[key_back] if key_back in textures else textures[key_normal]
	
	return {
		"front": front,
		"back": back
	}

# Función auxiliar para obtener textura de una parte del cuerpo
func get_texture_from_part(part: RPGLPCBodyPart, texture_type: String = "normal") -> CharacterPart:
	var character_part = CharacterPart.new(texture_type)
	character_part.path = part.front_texture if texture_type == "front" else part.back_texture
	character_part.part_id = part.part_id
	character_part.is_large_texture = part.is_large_texture
	character_part.is_alt = part.is_alt
	
	# Copiar paletas
	character_part.palette1.item_selected = 0
	character_part.palette1.colors = part.palette1.colors
	character_part.palette1.blend_color = part.palette1.blend_color
	character_part.palette1.lightness = part.palette1.lightness
	
	character_part.palette2.item_selected = 0
	character_part.palette2.colors = part.palette2.colors
	character_part.palette2.blend_color = part.palette2.blend_color
	character_part.palette2.lightness = part.palette2.lightness
	
	character_part.palette3.item_selected = 0
	character_part.palette3.colors = part.palette3.colors
	character_part.palette3.blend_color = part.palette3.blend_color
	character_part.palette3.lightness = part.palette3.lightness
	
	return character_part

# Función auxiliar para obtener textura de equipamiento
func get_texture_from_equipment(equipment: RPGLPCEquipmentPart, texture_type: String = "normal") -> CharacterPart:
	var character_part = CharacterPart.new(texture_type)
	character_part.path = equipment.front_texture if texture_type == "front" else equipment.back_texture
	character_part.part_id = equipment.part_id
	character_part.is_large_texture = equipment.is_large_texture
	
	# Copiar paletas
	character_part.palette1.item_selected = 0
	character_part.palette1.colors = equipment.palette1.colors
	character_part.palette1.blend_color = equipment.palette1.blend_color
	character_part.palette1.lightness = equipment.palette1.lightness
	
	character_part.palette2.item_selected = 0
	character_part.palette2.colors = equipment.palette2.colors
	character_part.palette2.blend_color = equipment.palette2.blend_color
	character_part.palette2.lightness = equipment.palette2.lightness
	
	character_part.palette3.item_selected = 0
	character_part.palette3.colors = equipment.palette3.colors
	character_part.palette3.blend_color = equipment.palette3.blend_color
	character_part.palette3.lightness = equipment.palette3.lightness
	
	return character_part

func _to_string() -> String:
	return str(textures)
