@tool
class_name CharacterPart
extends Resource


@export var path: String = ""
@export var is_large_texture: bool = false
@export var is_hidden: bool = false
@export var is_alt: bool = false
@export var id: String
@export var part_id: String
@export var item_id: String
@export var alt_id: String
@export var palette1 := {
	"item_selected": 0, # >= 0 Default color index, -1 No color selected, -2 Custom Color Selected
	"blend_color": 0,
	"lightness": 0.0,
	"colors": PackedInt64Array([])
}
@export var palette2 = {
	"item_selected": 0, # >= 0 Default color index, -1 No color selected, -2 Custom Color Selected
	"blend_color": 0,
	"lightness": 0.0,
	"colors": PackedInt64Array([])
}
@export var palette3 = {
	"item_selected": 0, # >= 0 Default color index, -1 No color selected, -2 Custom Color Selected
	"blend_color": 0,
	"lightness": 0.0,
	"colors": PackedInt64Array([])
}


var texture: Texture = null


func _init(id: String = "") -> void:
	self.id = id


func get_uniq_id() -> String:
	return "%s_%s_%s_%s_%s" % [part_id, item_id, str(palette1), str(palette2), str(palette3)]


func check_if_is_large_texture() -> bool:
	if !texture:
		return false
	
	var texture_size = Vector2i(texture.get_size())
	if texture_size.x % 192 != 0:
		return false
		
	var height = texture_size.y
	
	if height == 192:
		return true
	
	for rows in range(4, height + 1, 4):
		if height % rows == 0:
			var frame_height = height / rows
			if frame_height == 192:
				return true
	
	return false


func set_palettes(texture_data: Dictionary, colors_data: Dictionary) -> void:
	# Set primary colors
	if texture_data.primarycolors.size() > 0:
		if palette1.item_selected == -1 or palette1.item_selected > texture_data.primarycolors.size() - 1:
			palette1.item_selected = 0
	elif palette1.item_selected != -2:
		palette1.item_selected = -1
	if palette1.item_selected >= 0:
		var current_color = colors_data[texture_data.primarycolors[palette1.item_selected]]
		palette1.colors = current_color.colors.duplicate()
	# Set secondary colors
	if texture_data.secondarycolors.size() > 0:
		if palette2.item_selected < 0 or palette2.item_selected > texture_data.secondarycolors.size() - 1:
			palette2.item_selected = 0
	elif palette2.item_selected != -2:
		palette2.item_selected = -1
	if palette2.item_selected >= 0:
		var current_color = colors_data[texture_data.secondarycolors[palette2.item_selected]]
		palette2.colors = current_color.colors.duplicate()
	# Set fixed colors
	if texture_data.fixedcolors.size() > 0:
		if palette3.item_selected < 0 or palette3.item_selected > texture_data.fixedcolors.size() - 1:
			palette3.item_selected = 0
	elif palette3.item_selected != -2:
		palette3.item_selected = -1
	if palette3.item_selected >= 0:
		var current_color = colors_data[texture_data.fixedcolors[palette3.item_selected]]
		palette3.colors = current_color.colors.duplicate()


func set_texture_data(texture_data: Dictionary, colors_data: Dictionary, set_random_color: bool = false) -> void:
	var relative_path: String
	if id == "normal" or id == "front":
		relative_path = texture_data.get("texture", {}).get("front", "none")
	else:
		relative_path = texture_data.get("texture", {}).get("back", "none")
	
	if set_random_color:
		var c1 = texture_data.get("primarycolors", [])
		var c2 = texture_data.get("secondarycolors", [])
		var c3 = texture_data.get("fixedcolors", [])
		palette1.item_selected = 0 if c1.size() == 0 else randi() % c1.size()
		palette2.item_selected = 0 if c2.size() == 0 else randi() % c2.size()
		palette3.item_selected = 0 if c3.size() == 0 else randi() % c3.size()
	
	
	if relative_path == "none" or relative_path == "empty":
		clear()
	else:
		path = "res://addons/rpg_character_creator/" + relative_path
		if ResourceLoader.exists(path):
			if (texture and texture.get_path() != path) or !texture:
				texture = ResourceLoader.load(path)
			is_large_texture = check_if_is_large_texture()
			set_palettes(texture_data, colors_data)
		else:
			clear()
	
	part_id = texture_data.part_id
	item_id = texture_data.item_id
	alt_id = texture_data.get("alt_id", "")
	
	if part_id == "ammo" and relative_path == "empty":
		set_palettes(texture_data, colors_data)


func update_texture(texture_data: Dictionary, colors_data: Dictionary) -> bool:
	var relative_path: String
	if id == "normal" or id == "front":
		relative_path = texture_data.get("texture", {}).get("front", "none")
	else:
		relative_path = texture_data.get("texture", {}).get("back", "none")
	if relative_path == "none":
		texture = null
	else:
		var path = "res://addons/rpg_character_creator/" + relative_path
		if ResourceLoader.exists(path):
			if (texture and texture.get_path() != path) or !texture:
				texture = ResourceLoader.load(path)
			is_large_texture = check_if_is_large_texture()
			# Set primary colors
			if texture_data.primarycolors.size() > 0:
				if palette1.item_selected < 0 or palette1.item_selected > texture_data.primarycolors.size() - 1:
					palette1.item_selected = 0
			else:
				palette1.item_selected = -1
			if palette1.item_selected >= 0:
				var current_color = colors_data[texture_data.primarycolors[palette1.item_selected]]
				palette1.colors = current_color.colors.duplicate()
			# Set secondary colors
			if texture_data.secondarycolors.size() > 0:
				if palette2.item_selected < 0 or palette2.item_selected > texture_data.secondarycolors.size() - 1:
					palette2.item_selected = 0
			else:
				palette2.item_selected = -1
			if palette2.item_selected >= 0:
				var current_color = colors_data[texture_data.secondarycolors[palette2.item_selected]]
				palette2.colors = current_color.colors.duplicate()
			# Set fixed colors
			if texture_data.fixedcolors.size() > 0:
				if palette3.item_selected < 0 or palette3.item_selected > texture_data.fixedcolors.size() - 1:
					palette3.item_selected = 0
			else:
				palette3.item_selected = -1
			if palette3.item_selected >= 0:
				var current_color = colors_data[texture_data.fixedcolors[palette3.item_selected]]
				palette3.colors = current_color.colors.duplicate()
			return true
	
	return false


func clear() -> void:
	path = ""
	part_id = ""
	item_id = ""
	alt_id = ""
	texture = null
	is_hidden = false
	is_alt = false
	is_large_texture = false
	palette1.item_selected = 0
	palette1.lightness = 0.0
	palette1.blend_color = 0
	palette1.colors.clear()
	palette2.item_selected = 0
	palette2.lightness = 0.0
	palette2.blend_color = 0
	palette2.colors.clear()
	palette3.item_selected = 0
	palette3.blend_color = 0
	palette3.lightness = 0.0
	palette3.colors.clear()
