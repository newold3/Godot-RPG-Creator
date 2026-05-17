class_name IngameMapPassabilityHelper
extends RefCounted

#region VARIABLES

var map: RPGMap

var _terrain_cache: Dictionary = {}
var _cell_data_cache: Dictionary = {}
var _direction_passability_cache: Dictionary = {}
var _direction_passability_inverted_cache: Dictionary = {}
var _wall_env_passability_cache: Dictionary = {}
var _wall_env_passability_ignore_block_cache: Dictionary = {}
var _block_cache: Dictionary = {}
var _custom_data_layer_names: PackedStringArray = []

#endregion



## Initializes the passability helper with the target map and triggers the caching builder
func _init(p_map: RPGMap) -> void:
	map = p_map
	_build_caches()



## Builds high-performance lookup dictionaries for passability, terrain, and cell data handling giant tiles automatically
func _build_caches() -> void:
	_terrain_cache.clear()
	_cell_data_cache.clear()
	_direction_passability_cache.clear()
	_direction_passability_inverted_cache.clear()
	_wall_env_passability_cache.clear()
	_wall_env_passability_ignore_block_cache.clear()
	_block_cache.clear()
	_custom_data_layer_names.clear()
	
	var layers_to_check: Array[String] = ["ground", "ground_detail"]
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		if layer and layer.tile_set:
			var layer_count = layer.tile_set.get_custom_data_layers_count()
			for i in layer_count:
				var cd_name = layer.tile_set.get_custom_data_layer_name(i)
				if not _custom_data_layer_names.has(cd_name):
					_custom_data_layer_names.append(cd_name)
					
	var virtual_map: Dictionary = {}
	
	for layer_key in map.MAP_LAYERS:
		var layer = map.MAP_LAYERS[layer_key]
		if not layer or not layer is TileMapLayer or not layer.tile_set:
			continue
			
		var tileset: TileSet = layer.tile_set
		for pos in layer.get_used_cells():
			var tile_data: TileData = layer.get_cell_tile_data(pos)
			if not tile_data:
				continue
				
			var source_id: int = layer.get_cell_source_id(pos)
			var coord: Vector2i = layer.get_cell_atlas_coords(pos)
			var source: TileSetSource = tileset.get_source(source_id)
			var size: Vector2i = Vector2i.ONE
			
			if source is TileSetAtlasSource:
				size = source.get_tile_size_in_atlas(coord)
				
			for y in range(size.y):
				for x in range(size.x):
					var target_pos: Vector2i = pos + Vector2i(x, y)
					if not virtual_map.has(target_pos):
						virtual_map[target_pos] = {}
					virtual_map[target_pos][layer_key] = tile_data
					
	for pos in virtual_map:
		_precalculate_cell(pos, virtual_map[pos])



## Precalculates all data for a specific cell across all its active layers
func _precalculate_cell(pos: Vector2i, cell_layers: Dictionary) -> void:
	var terrains: PackedStringArray = []
	for layer_name in ["ground_detail", "ground"]:
		if cell_layers.has(layer_name):
			var tile_data: TileData = cell_layers[layer_name]
			var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
			
			var terrain_set = tile_data.terrain_set
			var terrain = tile_data.terrain
			if terrain_set != -1 and terrain != -1:
				var t_name = layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower()
				if not terrains.has(t_name):
					terrains.append(t_name)
					
			var raw_terrain = tile_data.get_custom_data("TerrainName")
			if typeof(raw_terrain) == TYPE_STRING:
				if not raw_terrain.is_empty():
					var t_lower = raw_terrain.to_lower()
					if not terrains.has(t_lower):
						terrains.append(t_lower)
			elif typeof(raw_terrain) == TYPE_ARRAY or typeof(raw_terrain) == TYPE_PACKED_STRING_ARRAY:
				for t in raw_terrain:
					if typeof(t) == TYPE_STRING and not t.is_empty():
						var t_lower = t.to_lower()
						if not terrains.has(t_lower):
							terrains.append(t_lower)
	_terrain_cache[pos] = terrains
	
	_direction_passability_cache[pos] = {}
	_direction_passability_inverted_cache[pos] = {}
	_wall_env_passability_cache[pos] = {}
	_wall_env_passability_ignore_block_cache[pos] = {}
	
	for dir in [CharacterBase.DIRECTIONS.LEFT, CharacterBase.DIRECTIONS.RIGHT, CharacterBase.DIRECTIONS.UP, CharacterBase.DIRECTIONS.DOWN]:
		var res_std = true
		for layer_name in map.MAP_LAYERS:
			var layer: TileMapLayer = map.MAP_LAYERS[layer_name]
			if layer.get_meta("collisions_disabled", false) == true:
				continue
			if cell_layers.has(layer_name):
				var tile_data: TileData = cell_layers[layer_name]
				if tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					if passability and not passability.disabled:
						var passable = passability.is_passable(dir)
						if passability.is_high_priority:
							match dir:
								CharacterBase.DIRECTIONS.LEFT: res_std = passability.right
								CharacterBase.DIRECTIONS.RIGHT: res_std = passability.left
								CharacterBase.DIRECTIONS.UP: res_std = passability.down
								CharacterBase.DIRECTIONS.DOWN: res_std = passability.up
							if res_std: break
						elif not passable:
							res_std = false
		_direction_passability_cache[pos][dir] = res_std
		
		var res_inv = true
		for layer_name in map.MAP_LAYERS:
			var layer: TileMapLayer = map.MAP_LAYERS[layer_name]
			if layer.get_meta("collisions_disabled", false) == true:
				continue
			if cell_layers.has(layer_name):
				var tile_data: TileData = cell_layers[layer_name]
				if tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					if passability and not passability.disabled:
						var passable = passability.is_passable(dir)
						if passability.is_high_priority:
							match dir:
								CharacterBase.DIRECTIONS.LEFT: res_inv = passability.left
								CharacterBase.DIRECTIONS.RIGHT: res_inv = passability.right
								CharacterBase.DIRECTIONS.UP: res_inv = passability.up
								CharacterBase.DIRECTIONS.DOWN: res_inv = passability.down
							if res_inv: break
						elif not passable:
							res_inv = false
		_direction_passability_inverted_cache[pos][dir] = res_inv
		
		var w_pass = true
		for layer_name in ["walls", "environment"]:
			var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
			if not layer or layer.get_meta("collisions_disabled", false) == true:
				continue
			if cell_layers.has(layer_name):
				var tile_data: TileData = cell_layers[layer_name]
				if tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					if passability:
						w_pass = passability.is_passable(dir)
						if not w_pass: break
		_wall_env_passability_cache[pos][dir] = w_pass
		
		var w_pass_ignore = true
		for layer_name in ["walls", "environment"]:
			var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
			if not layer or layer.get_meta("collisions_disabled", false) == true:
				continue
			if cell_layers.has(layer_name):
				var tile_data: TileData = cell_layers[layer_name]
				if tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					if passability:
						if not passability.is_blocked():
							w_pass_ignore = passability.is_passable(dir)
						if not w_pass_ignore: break
		_wall_env_passability_ignore_block_cache[pos][dir] = w_pass_ignore
		
	var cell_data_result = {"keep_events_on_top": false, "layer_z_index": -1}
	for layer_name in map.MAP_LAYERS:
		var layer: TileMapLayer = map.MAP_LAYERS[layer_name]
		if cell_layers.has(layer_name):
			var tile_data: TileData = cell_layers[layer_name]
			if tile_data.has_custom_data("Keep Events On Top"):
				var skip = false
				if tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					if passability and passability.disabled:
						skip = true
				if not skip:
					var keep_events_on_top = tile_data.get_custom_data("Keep Events On Top")
					if keep_events_on_top != null and keep_events_on_top:
						cell_data_result.keep_events_on_top = true
						cell_data_result.layer_z_index = max(cell_data_result.layer_z_index, layer.z_index)
	_cell_data_cache[pos] = cell_data_result
	
	var has_passability_data = false
	var block_result = false
	for layer_name in ["walls", "environment"]:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		if not layer or layer.get_meta("collisions_disabled", false) == true:
			continue
		if cell_layers.has(layer_name):
			var tile_data: TileData = cell_layers[layer_name]
			if tile_data.has_custom_data("Passability"):
				var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
				if passability:
					has_passability_data = true
					if passability.is_blocked():
						block_result = true
						break
					else:
						block_result = false
	_block_cache[pos] = {"has_data": has_passability_data, "result": block_result}



## Checks if a tile is passable considering vehicles, events, and debug mode dynamically
func is_passable(tile_position: Vector2i, player_direction: int, ignore_node: Node = null, ignore_debug: bool = false) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not map.moving_event and not ignore_debug:
		return true
		
	if GameManager.current_player and tile_position == GameManager.current_player.get_current_tile():
		return false
		
	for vehicle: RPGVehicle in map.entity_manager.current_ingame_vehicles:
		if ignore_node and vehicle == ignore_node:
			continue
			
		var vehicle_tile_position = map.local_to_map(Vector2i(vehicle.global_position))
		
		if tile_position == vehicle_tile_position:
			return false
			
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			
			if tile_position.x >= vehicle_left and tile_position.x < vehicle_right and tile_position.y >= vehicle_up and tile_position.y < vehicle_down:
				return false
				
	for extraction_event in map.get_tree().get_nodes_in_group("extraction_event"):
		if "is_started" in extraction_event and extraction_event.is_started:
			var event_position = map.local_to_map(Vector2i(extraction_event.global_position))
			
			if tile_position == event_position:
				return false
				
	var result = is_tile_passable_from_direction(tile_position, player_direction)
	
	if not result:
		return false
		
	for ev: IngameEvent in map.entity_manager.current_ingame_events.values():
		if not ev: continue
		
		if ev.lpc_event:
			if !ev.lpc_event.is_passable() and ev.lpc_event.get_current_tile() == tile_position:
				return false
				
	return true



## Evaluates the passability of a tile analyzing the pre-cached layer dictionary
func is_tile_passable_from_direction(tile_position: Vector2i, player_direction: int, invert: bool = false) -> bool:
	if map.has_any_region_passable_in(tile_position):
		return true
		
	if invert:
		if _direction_passability_inverted_cache.has(tile_position):
			if _direction_passability_inverted_cache[tile_position].has(player_direction):
				return _direction_passability_inverted_cache[tile_position][player_direction]
	else:
		if _direction_passability_cache.has(tile_position):
			if _direction_passability_cache[tile_position].has(player_direction):
				return _direction_passability_cache[tile_position][player_direction]
				
	return true



## Retrieves custom event ordering properties evaluating the pre-cached layer dictionary
func get_cell_data(tile_position: Vector2i) -> Dictionary:
	if _cell_data_cache.has(tile_position):
		return _cell_data_cache[tile_position]
		
	return {"keep_events_on_top": false, "layer_z_index": -1}



## Checks if a movement towards a direction is allowed strictly on the pre-cached environment and wall layers
func can_move_to_direction(tile_position: Vector2i, player_direction: int, ignore_is_blocked_tile: bool = false) -> bool:
	if ignore_is_blocked_tile:
		if _wall_env_passability_ignore_block_cache.has(tile_position):
			if _wall_env_passability_ignore_block_cache[tile_position].has(player_direction):
				return _wall_env_passability_ignore_block_cache[tile_position][player_direction]
	else:
		if _wall_env_passability_cache.has(tile_position):
			if _wall_env_passability_cache[tile_position].has(player_direction):
				return _wall_env_passability_cache[tile_position][player_direction]
				
	return true



## Determines if a tile has the completely blocked flag active in the pre-cached environment layer
func is_tile_block(tile_position: Vector2i, default_value: bool = true) -> bool:
	if _block_cache.has(tile_position):
		var c = _block_cache[tile_position]
		if c.has_data:
			return c.result
			
	return default_value



## Verifies if a given tile matches the allowed or forbidden terrain types using the cache
func can_move_over_terrain(tile: Vector2i, terrains: PackedStringArray) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not map.moving_event:
		return true
		
	if terrains.is_empty():
		return true
		
	var all_tags = Array(terrains).map(func(obj: String): return obj.to_lower())
	
	if all_tags.has("all"):
		return true
		
	var forbidden_tags = all_tags.filter(func(obj: String): return obj.begins_with("^")).map(func(obj: String): return obj.substr(1))
	var partial_tags = all_tags.filter(func(obj: String): return obj.begins_with("*")).map(func(obj: String): return obj.substr(1))
	var exact_tags = all_tags.filter(func(obj: String): return obj[0] != "*" and obj[0] != "^").map(func(obj: String): return obj)
	
	var current_terrains: PackedStringArray = get_tile_terrain_name(tile)
	
	if not current_terrains.is_empty():
		for terrain_name in current_terrains:
			for t in forbidden_tags:
				if terrain_name.find(t) != -1:
					return false
					
		for terrain_name in current_terrains:
			for t in partial_tags:
				if terrain_name.find(t) != -1:
					return true
			for t in exact_tags:
				if terrain_name == t:
					return true
					
		if forbidden_tags.size() > 0 and partial_tags.is_empty() and exact_tags.is_empty():
			return true
			
		return false
		
	if forbidden_tags.size() > 0 and partial_tags.is_empty() and exact_tags.is_empty():
		return true
		
	return false



## Retrieves the names of all custom data layers present on the base ground tileset
func get_custom_data_layer_names() -> PackedStringArray:
	return _custom_data_layer_names



## Extracts the main and custom terrain tags assigned to a specific ground tile from the cache
func get_tile_terrain_name(tile: Vector2i) -> PackedStringArray:
	if _terrain_cache.has(tile):
		return PackedStringArray(_terrain_cache[tile])
		
	return PackedStringArray()


## Forces a complete rebuild of the map cache (Use this if you change an entire TileSet or make massive map modifications)
func rebuild_entire_cache() -> void:
	_build_caches()


## Updates the cache for a specific tile coordinate (Use this when opening a door, breaking a rock, or changing a single tile)
func update_cell(pos: Vector2i) -> void:
	var cell_layers: Dictionary = {}
	
	for layer_key in map.MAP_LAYERS:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_key)
		
		if layer and layer is TileMapLayer and layer.tile_set:
			var tile_data: TileData = layer.get_cell_tile_data(pos)
			if tile_data:
				cell_layers[layer_key] = tile_data
				
	_precalculate_cell(pos, cell_layers)


## Updates a specific rectangular area of the cache efficiently
func update_region(region: Rect2i) -> void:
	for y in range(region.size.y):
		for x in range(region.size.x):
			update_cell(region.position + Vector2i(x, y))
