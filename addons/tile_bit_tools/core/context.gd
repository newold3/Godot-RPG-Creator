@tool
extends Node


const G := preload("res://addons/tile_bit_tools/core/globals.gd")
const EditorBitData := preload("res://addons/tile_bit_tools/core/editor_bit_data.gd")

const Icons := preload("res://addons/tile_bit_tools/core/icons.gd")

#var _print := preload("res://addons/tile_bit_tools/core/output.gd").new()
var texts := preload("res://addons/tile_bit_tools/core/texts.gd").new()


var tile_set : TileSet
var source : TileSetAtlasSource
var tiles : Dictionary

var bit_data : EditorBitData

var base_control : Control

# {index : terrain_mode}
var terrain_sets := {}

# {terrain_set : [{
#	"index": terrain_index,
#	"color": color,
#	"name": name,
#},...]}
var terrains_by_set := {}

var ready_complete := false


func _ready() -> void:
	ready_complete = true


func finish_setup() -> G.Errors:
	var validate_result := validate()
	if validate_result != OK:
		return validate_result

	bit_data = EditorBitData.new()
	var bit_data_result := bit_data.load_from_tile_data(tiles, tile_set)
	if bit_data_result != OK:
		return bit_data_result

	_populate_terrain_sets()
	_populate_terrains()

	return G.Errors.OK


func validate() -> G.Errors:
	if tile_set.tile_shape != TileSet.TILE_SHAPE_SQUARE:
		return G.Errors.UNSUPPORTED_SHAPE
	return G.Errors.OK


func _populate_terrain_sets() -> void:
	for i in range(tile_set.get_terrain_sets_count()):
		terrain_sets[i] = tile_set.get_terrain_set_mode(i)


func _populate_terrains() -> void:
	for terrain_set in terrain_sets.keys():
		terrains_by_set[terrain_set] = []
		for i in range(tile_set.get_terrains_count(terrain_set)):
			terrains_by_set[terrain_set].append({
				"id": i,
				"text": tile_set.get_terrain_name(terrain_set, i),
				"color": tile_set.get_terrain_color(terrain_set, i),
				"icon": get_terrain_icon(tile_set.get_terrain_color(terrain_set, i))
			})


func get_terrain_icon(color : Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func get_terrain_sets() -> Array:
	return terrain_sets.keys()


func get_terrain_sets_by_mode(terrain_mode : TileSet.TerrainMode) -> Array:
	var terrain_set_list := []
	for index in terrain_sets.keys():
		if terrain_sets[index] == terrain_mode:
			terrain_set_list.append(index)
	return terrain_set_list


func get_terrain_sets_item_list(terrain_mode : TileSet.TerrainMode) -> Array:
	var icons := Icons.new(base_control)

	var terrain_set_list := []
	for index in terrain_sets.keys():
		if terrain_sets[index] == terrain_mode:
			terrain_set_list.append({
				"id": index,
				"terrain_mode": terrain_mode,
				"text": "[%s]" % [index],
				"icon": icons.get_icon(icons.TERRAIN_MODE_ICONS[terrain_mode]),
			})
	return terrain_set_list


func get_terrains_item_list(terrain_set : int) -> Array:
	return terrains_by_set[terrain_set]
