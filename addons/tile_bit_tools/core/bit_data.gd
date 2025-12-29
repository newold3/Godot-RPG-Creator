@tool
extends Resource


## Redefined CellNeighbors enum to include center tile (terrain).
## Allows tile.terrain not to require separate logic when iterating.
enum TerrainBits {
	CENTER=99,
	TOP_LEFT_CORNER=TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TOP_SIDE=TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TOP_RIGHT_CORNER=TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	RIGHT_SIDE=TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	BOTTOM_RIGHT_CORNER=TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	BOTTOM_SIDE=TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	BOTTOM_LEFT_CORNER=TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	LEFT_SIDE=TileSet.CELL_NEIGHBOR_LEFT_SIDE,
}

const NULL_TERRAIN_INDEX := -1
const NULL_TERRAIN_SET := -1
const NULL_TERRAIN_MODE := -1

const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")

var CellNeighborsByMode := {
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	],
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS: [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	],
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_SIDES: [
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	],
}


enum _TileKeys {TERRAIN, PEERING_BITS}


# _tiles[coords : Vector2i][_TileKey]
# TERRAIN = terrain_index
# PEERING_BITS = Dictionary of {CellNeighbors : terrain_index}
@export var _tiles := {}

@export var terrain_set := NULL_TERRAIN_SET
@export var terrain_mode := TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES



# ITERATOR HELPERS

# returns terrain bits in terrain_set's mode
# center bit, if requested, will be listed first
func get_terrain_bits_list(include_center_bit := false) -> Array:
	var list : Array = CellNeighborsByMode[terrain_mode].duplicate()
	if include_center_bit:
		list.push_front(TerrainBits.CENTER)
	return list

# returns all terrain bits regardless of terrain_set's mode
func get_all_terrain_bits(include_center_bit := false) -> Array:
	var list : Array = CellNeighborsByMode[TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES].duplicate()
	if include_center_bit:
		list.push_front(TerrainBits.CENTER)
	return list


func get_coordinates_list() -> Array:
	return _tiles.keys()


# RESOURCE DATA
func has_data() -> bool:
	return get_tile_count() > 0

func has_terrain_set() -> bool:
	return terrain_set != NULL_TERRAIN_SET


func has_tile(coords : Vector2i) -> bool:
	return _tiles.has(coords)


func get_tile_count() -> int:
	return _tiles.size()


func get_terrain_count() -> int:
	return get_terrains().size()


func get_terrains() -> Array:
	var terrains := []
	for coords in get_coordinates_list():
		for bit in get_terrain_bits_list(true):
			var terrain_index := get_bit_terrain(coords, bit)
			if !terrains.has(terrain_index):
				terrains.append(terrain_index)
	return terrains


# ATLAS RECT
func get_atlas_offset() -> Vector2i:
	return get_atlas_rect().position


func get_atlas_rect() -> Rect2i:
	return _get_rect_from_points(_tiles.keys())


func _get_rect_from_points(p_points : Array) -> Rect2i:
	var points := p_points.duplicate(true)
	points.sort_custom(func(a,b): return a.x < b.x)
	var x : int = points.front().x
	var width : int = points.back().x + 1 - x
	points.sort_custom(func(a,b): return a.y < b.y)
	var y : int = points.front().y
	var height : int = points.back().y + 1 - y
	return Rect2i(x,y,width,height)



# TERRAIN DATA
func set_tile_terrain(coords : Vector2i, terrain_index : int) -> void:
	_tiles[coords][_TileKeys.TERRAIN] = terrain_index


func get_tile_terrain(coords : Vector2i) -> int:
	return _tiles[coords].get(_TileKeys.TERRAIN, NULL_TERRAIN_INDEX)


func set_bit_terrain(coords : Vector2i, bit : TerrainBits, terrain_index : int) -> void:
	if bit == TerrainBits.CENTER:
		set_tile_terrain(coords, terrain_index)
		return
	_tiles[coords][_TileKeys.PEERING_BITS][bit] = terrain_index


func get_bit_terrain(coords : Vector2i, bit : TerrainBits) -> int:
	if bit == TerrainBits.CENTER:
		return get_tile_terrain(coords)
	return _tiles[coords][_TileKeys.PEERING_BITS].get(bit, NULL_TERRAIN_INDEX)


func get_bit_color(coords : Vector2i, bit : TerrainBits) -> Color:
	var terrain_index := get_bit_terrain(coords, bit)
	return get_terrain_color(terrain_index)


func get_terrain_color(_terrain_index : int) -> Color:
	# override this function
	return Color.BLACK


func get_terrain_colors_dict() -> Dictionary:
	var d := {}
	for i in get_terrains():
		d[i] = get_terrain_color(i)
	return d



func _add_tile(coords : Vector2i, terrain_index := NULL_TERRAIN_INDEX) -> void:
	assert(!_tiles.has(coords))

	_tiles[coords] = {
		_TileKeys.TERRAIN: terrain_index,
		_TileKeys.PEERING_BITS: {},
	}


# TERRAIN MANIPULATION

## Sets all tiles' terrain and peering_bits to terrain_index
func fill_all_tile_terrains(p_terrain_set : int, p_terrain_mode : TileSet.TerrainMode, terrain_index : int) -> void:
	terrain_set = p_terrain_set
	terrain_mode = p_terrain_mode

	for coords in get_coordinates_list():
		fill_tile_terrains(coords, terrain_index)


## Sets a single tile's terrain and peering_bits to terrain_index
func fill_tile_terrains(coords : Vector2i, terrain_index : int) -> void:
	_clear_tile_peering_bits(coords)
	set_tile_terrain(coords, terrain_index)

	if terrain_index == NULL_TERRAIN_INDEX:
		return

	for bit in get_terrain_bits_list():
		set_bit_terrain(coords, bit, terrain_index)


func clear_all_tile_terrains() -> void:
	terrain_set = NULL_TERRAIN_SET
	# do not need to clear terrain_mode as it is only used internally

	for coords in get_coordinates_list():
		clear_tile_terrains(coords)


func clear_tile_terrains(coords : Vector2i) -> void:
	set_tile_terrain(coords, NULL_TERRAIN_INDEX)
	_clear_tile_peering_bits(coords)


func replace_all_tile_terrains(old_terrain_index : int, new_terrain_index : int) -> void:
	for coords in get_coordinates_list():
		replace_tile_terrains(coords, old_terrain_index, new_terrain_index)


func replace_tile_terrains(coords : Vector2i, old_terrain_index : int, new_terrain_index : int) -> void:
	# includes tile.terrain
	for bit in get_terrain_bits_list(true):
		if get_bit_terrain(coords, bit) == old_terrain_index:
			set_bit_terrain(coords, bit, new_terrain_index)


func set_all_bit_terrains(terrain_bit : TerrainBits, terrain_index : int) -> void:
	for coords in get_coordinates_list():
		set_bit_terrain(coords, terrain_bit, terrain_index)



func _clear_tile_peering_bits(coords : Vector2i) -> void:
	_tiles[coords][_TileKeys.PEERING_BITS].clear()
