class_name IngameMapLayoutHelper
extends RefCounted


var map: RPGMap


func _init(p_map: RPGMap) -> void:
	map = p_map


func map_to_local(grid_position: Vector2i) -> Vector2i:
	return grid_position * map.tile_size


func local_to_map(local_position: Vector2i) -> Vector2i:
	var pos = Vector2(local_position.x / float(map.tile_size.x), local_position.y / float(map.tile_size.y)) - Vector2.ONE
	var real_pos = Vector2i(pos.ceil())
	return real_pos


func get_map_size_info() -> Dictionary:
	var rect = get_used_rect(false)
	var tiles = {}

	tiles.min_tile = rect.position / map.tile_size
	tiles.max_tile = tiles.min_tile + rect.size / map.tile_size
	tiles.min_position = rect.position
	tiles.max_position = rect.end
	
	return tiles


func get_used_rect(add_margin: bool = true) -> Rect2i:
	if not Engine.is_editor_hint():
		var r = map.rect_size_cache.get("map_used_rect")
		if r: return r
		
	var margin = 5
	var rect: Rect2i = Rect2i()
	var tile = Vector2(map.tile_size)
	for child in map.get_children():
		if child is TileMapLayer:
			var child_rect = Rect2(child.get_used_rect())
			var child_global_position = child.global_position
			var top_left = child_global_position + child_rect.position * tile * child.scale
			var bottom_right = child_global_position + (child_rect.position + child_rect.size) * tile * child.scale
			var screen_rect = Rect2i(Vector2i(top_left), Vector2i(bottom_right - top_left))
			if screen_rect.has_area():
				if rect:
					rect = rect.merge(screen_rect)
				else:
					rect = screen_rect

	if add_margin and rect.has_area():
		rect.position -= map.tile_size * margin
		rect.size += Vector2i(map.tile_size * margin) * 2
	
	if not Engine.is_editor_hint():
		map.rect_size_cache.map_used_rect = rect

	return rect


func get_ingame_rect() -> Rect2i:
	if not Engine.is_editor_hint():
		var r = map.rect_size_cache.get("map_ingame_rect")
		if r: return r
	
	var rect: Rect2i = Rect2i()
	for child in map.get_children():
		if child is TileMapLayer:
			var child_rect = Rect2(child.get_used_rect())
			rect = rect.merge(child_rect)
	
	if not Engine.is_editor_hint():
		map.rect_size_cache.map_ingame_rect = rect
	
	return rect


func get_map_size() -> Vector2i:
	if not Engine.is_editor_hint():
		var r = map.rect_size_cache.get("map_size")
		if r: return r
		
	var rect = get_used_rect(false)
	var size = rect.size - rect.position
	
	if not Engine.is_editor_hint():
		map.rect_size_cache.map_size = size
		
	return size


func get_map_size_in_tiles() -> Vector2i:
	if not Engine.is_editor_hint():
		var r = map.rect_size_cache.get("map_size_in_tiles")
		if r: return r
		
	var rect = get_ingame_rect()
	var size = rect.size - rect.position
	
	if not Engine.is_editor_hint():
		map.rect_size_cache.map_size_in_tiles = size
		
	return size


func get_tile_from_position(pos: Vector2) -> Vector2i:
	var tile_coords = local_to_map(Vector2i(pos))
	return Vector2i(tile_coords)


# Returns the wrapped tile coordinates based on map scroll settings
func get_wrapped_tile(tile: Vector2i) -> Vector2i:
	var rect = map.get_ingame_rect()
	
	if rect.has_point(Vector2(tile)):
		return tile
		
	var min_pos = rect.position
	var size = rect.size
	
	var map_width: int = int(size.x)
	var map_height: int = int(size.y)
	
	var wrapped_x: int
	var wrapped_y: int
	
	if map.infinite_horizontal_scroll:
		wrapped_x = min_pos.x + (int(tile.x - min_pos.x) % map_width + map_width) % map_width
	else:
		wrapped_x = tile.x
		
	if map.infinite_vertical_scroll:
		wrapped_y = min_pos.y + (int(tile.y - min_pos.y) % map_height + map_height) % map_height
	else:
		wrapped_y = tile.y
		
	return Vector2i(wrapped_x, wrapped_y)


# Returns the wrapped world position based on map scroll settings
func get_wrapped_position(pos: Vector2) -> Vector2:
	var rect = map.get_ingame_rect()
	var min_pos = rect.position * map.tile_size.x
	var size = rect.size * map.tile_size.y
	
	var wrapped_x = pos.x
	var wrapped_y = pos.y
	
	if map.infinite_horizontal_scroll:
		wrapped_x = min_pos.x + fposmod(pos.x - min_pos.x, size.x)
		
	if map.infinite_vertical_scroll:
		wrapped_y = min_pos.y + fposmod(pos.y - min_pos.y, size.y)
		
	return Vector2(wrapped_x, wrapped_y)


func get_tile_position(tile: Vector2i) -> Vector2:
	var start_position = Vector2(tile)
	var target_position = map.map_to_local(start_position)
	target_position = target_position.snapped(map.tile_size)
	
	return (Vector2(target_position) + map.event_offset)
