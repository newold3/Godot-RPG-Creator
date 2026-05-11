class_name IngameMapPassabilityHelper
extends RefCounted


#region VARIABLES
var map: RPGMap
#endregion



## Initializes the passability helper with the target map
func _init(p_map: RPGMap) -> void:
	map = p_map



## Checks if a tile is passable considering vehicles, events, and debug mode
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



## Evaluates the passability of a tile analyzing all layers stored in the map dictionary
func is_tile_passable_from_direction(tile_position: Vector2i, player_direction: int, invert: bool = false) -> bool:
	if map.has_any_region_passable_in(tile_position):
		return true
		
	var result = true
	
	for layer in map.MAP_LAYERS.values():
		if not layer or not layer is TileMapLayer or not layer.tile_set:
			continue
			
		var source_id = layer.get_cell_source_id(tile_position)
		
		if source_id != -1:
			var atlas_coord = layer.get_cell_atlas_coords(tile_position)
			var source: TileSetSource = layer.tile_set.get_source(source_id)
			
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				
				if tile_data and tile_data.has_custom_data("Passability"):
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					
					if passability:
						if passability.disabled: continue
						
						var passable = passability.is_passable(player_direction)
						
						if passability.is_high_priority:
							match player_direction:
								CharacterBase.DIRECTIONS.LEFT:
									result = passability.right if not invert else passability.left
								CharacterBase.DIRECTIONS.RIGHT:
									result = passability.left if not invert else passability.right
								CharacterBase.DIRECTIONS.UP:
									result = passability.down if not invert else passability.up
								CharacterBase.DIRECTIONS.DOWN:
									result = passability.up if not invert else passability.down
									
							if result:
								break
								
						elif not passable:
							result = false
							
	return result



## Retrieves custom event ordering properties evaluating the full layer dictionary
func get_cell_data(tile_position: Vector2i) -> Dictionary:
	var result = {"keep_events_on_top": false, "layer_z_index": - 1}
	
	for layer in map.MAP_LAYERS.values():
		if not layer or not layer is TileMapLayer or not layer.tile_set:
			continue
			
		var source_id = layer.get_cell_source_id(tile_position)
		
		if source_id != -1:
			var atlas_coord = layer.get_cell_atlas_coords(tile_position)
			var source: TileSetSource = layer.tile_set.get_source(source_id)
			
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				
				if tile_data and tile_data.has_custom_data("Keep Events On Top"):
					if tile_data.has_custom_data("Passability"):
						var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
						
						if passability:
							if passability.disabled: continue
							
					var keep_events_on_top = tile_data.get_custom_data("Keep Events On Top")
					
					if keep_events_on_top != null and keep_events_on_top:
						result.keep_events_on_top = true
						result.layer_z_index = max(result.layer_z_index, layer.z_index)
						
	return result



## Checks if a movement towards a direction is allowed strictly on the environment and wall layers
func can_move_to_direction(tile_position: Vector2i, player_direction: int, ignore_is_blocked_tile: bool = false) -> bool:
	var passable: bool = true
	var layers_to_check: Array[String] = ["walls", "environment"]
	
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		
		if not layer or not layer is TileMapLayer or not layer.tile_set:
			continue
			
		var source_id = layer.get_cell_source_id(tile_position)
		
		if source_id != -1:
			var atlas_coord = layer.get_cell_atlas_coords(tile_position)
			var source: TileSetSource = layer.tile_set.get_source(source_id)
			
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				
				if tile_data:
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					
					if passability:
						if ignore_is_blocked_tile:
							if not passability.is_blocked():
								passable = passability.is_passable(player_direction)
						else:
							passable = passability.is_passable(player_direction)
							
						if not passable:
							return false
							
	return passable



## Determines if a tile has the completely blocked flag active in the environment layer
func is_tile_block(tile_position: Vector2i, default_value: bool = true) -> bool:
	var block: bool = default_value
	var layers_to_check: Array[String] = ["walls", "environment"]
	
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		
		if not layer or not layer is TileMapLayer or not layer.tile_set:
			continue
			
		var source_id = layer.get_cell_source_id(tile_position)
		
		if source_id != -1:
			var atlas_coord = layer.get_cell_atlas_coords(tile_position)
			var source: TileSetSource = layer.tile_set.get_source(source_id)
			
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				
				if tile_data:
					var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
					
					if passability:
						if passability.is_blocked():
							return true
						else:
							block = false
							
	return block



## Verifies if a given tile matches the allowed or forbidden terrain types
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
	
	var layers_to_check: Array[String] = ["ground_detail", "ground"]
	
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		
		if layer and layer is TileMapLayer and layer.tile_set:
			var tile_data: TileData = layer.get_cell_tile_data(tile)
			
			if tile_data:
				var current_terrains: PackedStringArray = []
				var terrain_set = tile_data.terrain_set
				var terrain = tile_data.terrain
				
				if terrain_set != -1 and terrain != -1:
					current_terrains.append(layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower())
					
				var raw_terrain = tile_data.get_custom_data("TerrainName")
				
				if typeof(raw_terrain) == TYPE_STRING:
					if not raw_terrain.is_empty():
						current_terrains.append(raw_terrain.to_lower())
				elif typeof(raw_terrain) == TYPE_ARRAY or typeof(raw_terrain) == TYPE_PACKED_STRING_ARRAY:
					for t in raw_terrain:
						if typeof(t) == TYPE_STRING and not t.is_empty():
							current_terrains.append(t.to_lower())
							
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
	var layers: PackedStringArray = []
	var layers_to_check: Array[String] = ["ground", "ground_detail"]
	
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		
		if layer and layer is TileMapLayer and layer.tile_set:
			var tileset = layer.tile_set
			var layer_count = tileset.get_custom_data_layers_count()
			
			for i in layer_count:
				var cd_name = tileset.get_custom_data_layer_name(i)
				if not layers.has(cd_name):
					layers.append(cd_name)
					
	return layers



## Extracts the main and custom terrain tags assigned to a specific ground tile
func get_tile_terrain_name(tile: Vector2i) -> PackedStringArray:
	var terrain_name: PackedStringArray = []
	var layers_to_check: Array[String] = ["ground_detail", "ground"]
	
	for layer_name in layers_to_check:
		var layer: TileMapLayer = map.MAP_LAYERS.get(layer_name)
		
		if layer and layer is TileMapLayer and layer.tile_set:
			var tile_data: TileData = layer.get_cell_tile_data(tile)
			
			if tile_data:
				var terrain_set = tile_data.terrain_set
				var terrain = tile_data.terrain
				
				if terrain_set != -1 and terrain != -1:
					var t_name = layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower()
					if not terrain_name.has(t_name):
						terrain_name.append(t_name)
						
				var raw_terrain = tile_data.get_custom_data("TerrainName")
				
				if typeof(raw_terrain) == TYPE_STRING:
					if not raw_terrain.is_empty():
						var t_lower = raw_terrain.to_lower()
						if not terrain_name.has(t_lower):
							terrain_name.append(t_lower)
				elif typeof(raw_terrain) == TYPE_ARRAY or typeof(raw_terrain) == TYPE_PACKED_STRING_ARRAY:
					for t in raw_terrain:
						if typeof(t) == TYPE_STRING and not t.is_empty():
							var t_lower = t.to_lower()
							if not terrain_name.has(t_lower):
								terrain_name.append(t_lower)
								
				if not terrain_name.is_empty():
					return terrain_name
					
	return terrain_name
