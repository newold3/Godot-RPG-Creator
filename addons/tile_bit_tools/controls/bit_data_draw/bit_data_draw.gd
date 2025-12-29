@tool
extends Control


enum RectPoint {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	RIGHT_CENTER,
	BOTTOM_RIGHT,
	BOTTOM_CENTER,
	BOTTOM_LEFT,
	LEFT_CENTER,
}

var bit_shapes := {
	TileSet.TERRAIN_MODE_MATCH_SIDES: {
		BitData.TerrainBits.TOP_SIDE:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.TOP_LEFT),
				_get_rect_point(rect, RectPoint.TOP_RIGHT),
				_get_center_rect_point(rect, RectPoint.TOP_RIGHT),
				_get_center_rect_point(rect, RectPoint.TOP_LEFT),
			],
		BitData.TerrainBits.RIGHT_SIDE:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.TOP_RIGHT),
				_get_rect_point(rect, RectPoint.BOTTOM_RIGHT),
				_get_center_rect_point(rect, RectPoint.BOTTOM_RIGHT),
				_get_center_rect_point(rect, RectPoint.TOP_RIGHT),
			],
		BitData.TerrainBits.BOTTOM_SIDE:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.BOTTOM_RIGHT),
				_get_rect_point(rect, RectPoint.BOTTOM_LEFT),
				_get_center_rect_point(rect, RectPoint.BOTTOM_LEFT),
				_get_center_rect_point(rect, RectPoint.BOTTOM_RIGHT),
			],
		BitData.TerrainBits.LEFT_SIDE:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.BOTTOM_LEFT),
				_get_rect_point(rect, RectPoint.TOP_LEFT),
				_get_center_rect_point(rect, RectPoint.TOP_LEFT),
				_get_center_rect_point(rect, RectPoint.BOTTOM_LEFT),
			],
		BitData.TerrainBits.CENTER:
			func(rect : Rect2): return _get_center_rect(rect), #.grow(-3),
	},
	TileSet.TERRAIN_MODE_MATCH_CORNERS: {
		BitData.TerrainBits.TOP_LEFT_CORNER:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.LEFT_CENTER),
				_get_rect_point(rect, RectPoint.TOP_LEFT),
				_get_rect_point(rect, RectPoint.TOP_CENTER),
				_get_center_rect_point(rect, RectPoint.TOP_CENTER),
				_get_center_rect_point(rect, RectPoint.TOP_LEFT),
				_get_center_rect_point(rect, RectPoint.LEFT_CENTER),
			],
		BitData.TerrainBits.TOP_RIGHT_CORNER:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.TOP_CENTER),
				_get_rect_point(rect, RectPoint.TOP_RIGHT),
				_get_rect_point(rect, RectPoint.RIGHT_CENTER),
				_get_center_rect_point(rect, RectPoint.RIGHT_CENTER),
				_get_center_rect_point(rect, RectPoint.TOP_RIGHT),
				_get_center_rect_point(rect, RectPoint.TOP_CENTER),
			],
		BitData.TerrainBits.CENTER:
			func(rect : Rect2): return _get_center_rect(rect), #.grow(-3),
#			func(rect : Rect2):
#				var center_rect := _get_center_rect(rect).grow(-1)
#				var radius := center_rect.size.x/2
#				return {"position": center_rect.get_center(), "radius": radius},
		BitData.TerrainBits.BOTTOM_RIGHT_CORNER:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.RIGHT_CENTER),
				_get_rect_point(rect, RectPoint.BOTTOM_RIGHT),
				_get_rect_point(rect, RectPoint.BOTTOM_CENTER),
				_get_center_rect_point(rect, RectPoint.BOTTOM_CENTER),
				_get_center_rect_point(rect, RectPoint.BOTTOM_RIGHT),
				_get_center_rect_point(rect, RectPoint.RIGHT_CENTER),
			],
		BitData.TerrainBits.BOTTOM_LEFT_CORNER:
			func(rect : Rect2): return [
				_get_rect_point(rect, RectPoint.BOTTOM_CENTER),
				_get_rect_point(rect, RectPoint.BOTTOM_LEFT),
				_get_rect_point(rect, RectPoint.LEFT_CENTER),
				_get_center_rect_point(rect, RectPoint.LEFT_CENTER),
				_get_center_rect_point(rect, RectPoint.BOTTOM_LEFT),
				_get_center_rect_point(rect, RectPoint.BOTTOM_CENTER),
			],
	},
	TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES: {
		BitData.TerrainBits.TOP_LEFT_CORNER:
			func(rect : Rect2): return Rect2(
				rect.position,
				_get_bit_size(rect)
			),
		BitData.TerrainBits.TOP_SIDE:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + rect.size.x/3, rect.position.y),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.TOP_RIGHT_CORNER:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + 2*rect.size.x/3, rect.position.y),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.LEFT_SIDE:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x, rect.position.y + rect.size.y/3),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.CENTER:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + rect.size.x/3, rect.position.y + rect.size.y/3),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.RIGHT_SIDE:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + 2*rect.size.x/3, rect.position.y + rect.size.y/3),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.BOTTOM_LEFT_CORNER:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x, rect.position.y + 2*rect.size.y/3),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.BOTTOM_SIDE:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + rect.size.x/3, rect.position.y + 2*rect.size.y/3),
				_get_bit_size(rect)
			),
		BitData.TerrainBits.BOTTOM_RIGHT_CORNER:
			func(rect : Rect2): return Rect2(
				Vector2(rect.position.x + 2*rect.size.x/3, rect.position.y + 2*rect.size.y/3),
				_get_bit_size(rect)
			),
	}
}

const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")

var bit_data : BitData :
	set(value):
		bit_data = value
		_update_properties()
		queue_redraw()

var draw_size : Vector2i :
	set(value):
		draw_size = value
		_update_properties()
		queue_redraw()

var spacing := 5

var atlas_rect : Rect2i
var atlas_offset : Vector2i
var tile_size : Vector2

var terrain_set : int
var terrain_mode : TileSet.TerrainMode
var terrain_colors := {}




func _update_properties() -> void:
	if !bit_data or draw_size == Vector2i.ZERO:
		return

	atlas_rect = bit_data.get_atlas_rect()

	# changing to floats avoids rounding errors/gaps
	tile_size = Vector2(draw_size) / Vector2(atlas_rect.size)
	atlas_offset = atlas_rect.position

	terrain_set = bit_data.terrain_set
	terrain_mode = bit_data.terrain_mode
	terrain_colors = bit_data.get_terrain_colors_dict()



func _draw() -> void:
	if !bit_data or draw_size == Vector2i.ZERO:
		return

	for coords in bit_data.get_coordinates_list():
		var adj_coords : Vector2 = coords - atlas_offset
		var tile_pos := adj_coords * tile_size
		var tile_rect := Rect2(tile_pos, tile_size).grow(-spacing)

		for bit in bit_data.get_terrain_bits_list(true):
			var terrain_index := bit_data.get_bit_terrain(coords, bit)
			var color = terrain_colors[terrain_index]
			var shape = bit_shapes[terrain_mode][bit].call(tile_rect)

			if typeof(shape) == TYPE_ARRAY:
				draw_colored_polygon(shape, color)
			elif typeof(shape) == TYPE_RECT2:
				draw_rect(shape, color)
			elif typeof(shape) == TYPE_DICTIONARY:
				draw_circle(shape.position, shape.radius, color)



func _get_rect_point(rect : Rect2, point : RectPoint) -> Vector2:
	match point:
		RectPoint.TOP_LEFT:
			return rect.position
		RectPoint.TOP_CENTER:
			return Vector2(rect.get_center().x, rect.position.y)
		RectPoint.TOP_RIGHT:
			return Vector2(rect.end.x, rect.position.y)
		RectPoint.RIGHT_CENTER:
			return Vector2(rect.end.x, rect.get_center().y)
		RectPoint.BOTTOM_RIGHT:
			return rect.end
		RectPoint.BOTTOM_CENTER:
			return Vector2(rect.get_center().x, rect.end.y)
		RectPoint.BOTTOM_LEFT:
			return Vector2(rect.position.x, rect.end.y)
		RectPoint.LEFT_CENTER:
			return Vector2(rect.position.x, rect.get_center().y)
	return Vector2.ZERO

func _get_center_rect_point(rect : Rect2, point : RectPoint) -> Vector2:
	return _get_rect_point(_get_center_rect(rect), point)

func _get_center_rect(rect : Rect2) -> Rect2:
	return Rect2(rect.position + rect.size/3.0, rect.size/3.0)

func _get_bit_size(rect : Rect2) -> Vector2:
	return rect.size/3.0


