@tool
extends "res://addons/tile_bit_tools/core/bit_data.gd"

const additional_colors := [Color.RED, Color.BLUE, Color.YELLOW, Color.GREEN, Color.REBECCA_PURPLE, Color.WHEAT, Color.AQUA, Color.SALMON, Color.CHOCOLATE, Color.VIOLET, Color.CADET_BLUE, Color.NAVY_BLUE, Color.MAGENTA, Color.LAWN_GREEN, Color.KHAKI, Color.HOT_PINK, Color.FIREBRICK, Color.DARK_OLIVE_GREEN, Color.SADDLE_BROWN]

const G := preload("res://addons/tile_bit_tools/core/globals.gd")
const EditorBitData := preload("res://addons/tile_bit_tools/core/editor_bit_data.gd")
const TemplateBitData := preload("res://addons/tile_bit_tools/core/template_bit_data.gd")

var template_tag_data := preload("res://addons/tile_bit_tools/core/template_tag_data.gd").new()

@export var version : String
@export var template_name : String
@export var template_description : String
@export var _custom_tags := []
@export var template_terrain_count : int
@export var example_folder_path : String

var built_in := false
var preview_texture : Texture2D

var terrain_colors := {
	-1: Color.TRANSPARENT,
	0: ProjectSettings.get_setting(G.Settings.colors_terrain_01.path) if ProjectSettings.get_setting(G.Settings.colors_terrain_01.path) != null else additional_colors[0],
	1: ProjectSettings.get_setting(G.Settings.colors_terrain_02.path) if ProjectSettings.get_setting(G.Settings.colors_terrain_02.path) != null else additional_colors[1],
	2: ProjectSettings.get_setting(G.Settings.colors_terrain_03.path) if ProjectSettings.get_setting(G.Settings.colors_terrain_03.path) != null else additional_colors[2],
	3: ProjectSettings.get_setting(G.Settings.colors_terrain_04.path) if ProjectSettings.get_setting(G.Settings.colors_terrain_04.path) != null else additional_colors[3],
}


## Attempts to return the template terrain color set in Project Settings
## If index is too high, returns a color constant from additional_colors
func get_terrain_color(terrain_index : int) -> Color:
	return terrain_colors.get(terrain_index, additional_colors[terrain_index])


func get_custom_tags() -> Array:
	return _custom_tags


func load_editor_bit_data(bit_data : EditorBitData) -> G.Errors:
	var result := _validate_editor_source(bit_data)
	if result != OK:
		return result

	# terrain_set will remain NULL_TERRAIN_SET (-1)
	terrain_mode = bit_data.terrain_mode
	var terrain_mapping := _get_terrain_mapping(bit_data)
	_load_tiles(bit_data, terrain_mapping)

	return G.Errors.OK


func _validate_editor_source(bit_data : EditorBitData) -> G.Errors:
	if has_data():
		return G.Errors.FAILED
	if bit_data.get_tile_count() == 0:
		return G.Errors.FAILED
	if bit_data.get_terrain_count() == 0:
		return G.Errors.FAILED
	return G.Errors.OK


## Sort terrains by frequency and return mapping
## with highest frequency = 0
func _get_terrain_mapping(bit_data : EditorBitData) -> Dictionary:
	var terrains_by_count := {}
	for coords in bit_data.get_coordinates_list():
		var terrain_index : int = bit_data.get_tile_terrain(coords)
		if terrains_by_count.has(terrain_index):
			terrains_by_count[terrain_index] += 1
		else:
			terrains_by_count[terrain_index] = 0
	var terrains := terrains_by_count.keys().duplicate()
	terrains.sort_custom(func(a, b): return terrains_by_count[a] > terrains_by_count[b])
	var terrain_mapping := {}
	for i in range(terrains.size()):
		terrain_mapping[terrains[i]] = i
	return terrain_mapping


func _load_tiles(bit_data : EditorBitData, terrain_mapping : Dictionary) -> void:
	var offset := bit_data.get_atlas_offset()
	var next_template_terrain := terrain_mapping.size()

	for coords in bit_data.get_coordinates_list():
		var template_coords : Vector2i = coords - offset
		_add_tile(template_coords)

		for bit in bit_data.get_terrain_bits_list(true):
			var editor_terrain := bit_data.get_bit_terrain(coords, bit)
			if !terrain_mapping.has(editor_terrain):
				var template_terrain := next_template_terrain
				terrain_mapping[editor_terrain] = template_terrain
				next_template_terrain += 1

			set_bit_terrain(template_coords, bit, terrain_mapping[editor_terrain])

	template_terrain_count = terrain_mapping.keys().size()






