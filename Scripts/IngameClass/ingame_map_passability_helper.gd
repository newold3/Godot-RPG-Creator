class_name IngameMapPassabilityHelper
extends RefCounted

var map: RPGMap



func _init(p_map: RPGMap) -> void:
	map = p_map



func is_passable(tile_position: Vector2i, player_direction: int, ignore_node: Node = null, ignore_debug: bool = false) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not map.moving_event and not ignore_debug:
		return true
	
	if GameManager.current_player and tile_position == GameManager.current_player.get_current_tile():
		return false
	
	for vehicle: RPGVehicle in map.entity_manager.current_ingame_vehicles:
		if ignore_node and vehicle == ignore_node:
			continue
		
		# Fixed: Use global_position instead of position to prevent tile offsets
		var vehicle_tile_position = map.local_to_map(Vector2i(vehicle.global_position))
		if tile_position == vehicle_tile_position:
			return false
		elif vehicle.extra_dimensions:
			var extra_dimensions: RPGDimension = vehicle.extra_dimensions
			var vehicle_left = vehicle_tile_position.x - extra_dimensions.grow_left
			var vehicle_right = vehicle_tile_position.x + extra_dimensions.grow_right + 1
			var vehicle_up = vehicle_tile_position.y - extra_dimensions.grow_up
			var vehicle_down = vehicle_tile_position.y + extra_dimensions.grow_down + 1
			if tile_position.x >= vehicle_left and tile_position.x < vehicle_right and \
			   tile_position.y >= vehicle_up and tile_position.y < vehicle_down:
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



func is_tile_passable_from_direction(tile_position: Vector2i, player_direction: int, invert: bool = false) -> bool:
	if map.has_any_region_passable_in(tile_position):
		return true
		
	var result = true
	for child in map.get_children():
		if child is TileMapLayer and child.tile_set:
			var source_id = child.get_cell_source_id(tile_position)
			if source_id != -1:
				var atlas_coord = child.get_cell_atlas_coords(tile_position)
				var source: TileSetSource = child.tile_set.get_source(source_id)
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



func get_cell_data(tile_position: Vector2i) -> Dictionary:
	var result = {"keep_events_on_top": false, "layer_z_index": - 1}
	for child in map.get_children():
		if child is TileMapLayer and child.tile_set:
			var source_id = child.get_cell_source_id(tile_position)
			if source_id != -1:
				var atlas_coord = child.get_cell_atlas_coords(tile_position)
				var source: TileSetSource = child.tile_set.get_source(source_id)
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
							result.layer_z_index = max(result.layer_z_index, child.z_index)
	
	return result



func can_move_to_direction(tile_position: Vector2i, player_direction: int, ignore_is_blocked_tile: bool = false) -> bool:
	var passable: bool = true
	var source_id = map.MAP_LAYERS.environment.get_cell_source_id(tile_position)
	if source_id != -1:
		var atlas_coord = map.MAP_LAYERS.environment.get_cell_atlas_coords(tile_position)
		var source: TileSetSource = map.MAP_LAYERS.environment.tile_set.get_source(source_id)
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
	
	return passable



func is_tile_block(tile_position: Vector2i, default_value: bool = true) -> bool:
	var block: bool = default_value
	var source_id = map.MAP_LAYERS.environment.get_cell_source_id(tile_position)
	if source_id != -1:
		var atlas_coord = map.MAP_LAYERS.environment.get_cell_atlas_coords(tile_position)
		var source: TileSetSource = map.MAP_LAYERS.environment.tile_set.get_source(source_id)
		if source:
			var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
			if tile_data:
				var passability: RPGMapPassability = tile_data.get_custom_data("Passability")
				if passability:
					block = passability.is_blocked()
	
	return block



func can_move_over_terrain(tile: Vector2i, terrains: PackedStringArray) -> bool:
	if Input.is_key_pressed(KEY_CTRL) and OS.is_debug_build() and not map.moving_event:
		return true

	var tile_map_layer: TileMapLayer = map.MAP_LAYERS.ground
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile)
	var all_tags = Array(terrains).map(
		func(obj: String): return obj.to_lower())
	var forbidden_tags = all_tags.filter(
		func(obj: String): return obj.begins_with("^")).map(func(obj: String): return obj.substr(1))
	var partial_tags = all_tags.filter(
		func(obj: String): return obj.begins_with("*")).map(func(obj: String): return obj.substr(1))
	var exact_tags = all_tags.filter(
		func(obj: String): return obj[0] != "*" and obj[0] != "^").map(func(obj: String): return obj)
	
	if exact_tags.has("all"):
		return true
	
	if tile_data:
		var terrain_set = tile_data.terrain_set
		var terrain = tile_data.terrain
		var current_terrains: PackedStringArray = []
		if terrain_set != -1 and terrain != -1:
			current_terrains.append(tile_map_layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower())
		var other_terrains: PackedStringArray = tile_data.get_custom_data("TerrainName")
		if not other_terrains.is_empty():
			current_terrains.append_array(other_terrains)

		if not current_terrains.is_empty():
			for terrain_name in current_terrains:
				for t in forbidden_tags:
					if terrain_name.find(t) != -1:
						return false
					
				for t in partial_tags:
					if terrain_name.find(t) != -1:
						return true
			
				for t in exact_tags:
					if terrain_name == t:
						return true
	else:
		return false
	
	if forbidden_tags.size() > 0 and partial_tags.is_empty() and exact_tags.is_empty():
		return true
		
	return false



func get_custom_data_layer_names() -> PackedStringArray:
	var layers: PackedStringArray = []
	var tile_map_layer: TileMapLayer = map.MAP_LAYERS.ground
	var tileset = tile_map_layer.tile_set
	var layer_count = tileset.get_custom_data_layers_count()
	
	for i in layer_count:
		layers.append(tileset.get_custom_data_layer_name(i))
	
	return layers



func get_tile_terrain_name(tile: Vector2i) -> PackedStringArray:
	var terrain_name: PackedStringArray = []
	var tile_map_layer: TileMapLayer = map.MAP_LAYERS.ground
	var tile_data: TileData = tile_map_layer.get_cell_tile_data(tile)
	if tile_data:
		var terrain_set = tile_data.terrain_set
		var terrain = tile_data.terrain
		if terrain_set != -1 and terrain != -1:
			terrain_name.append(tile_map_layer.tile_set.get_terrain_name(terrain_set, terrain).to_lower())
		
		var other_terrains: PackedStringArray = tile_data.get_custom_data("TerrainName")
		if other_terrains:
			terrain_name.append_array(other_terrains)
	
	return terrain_name
