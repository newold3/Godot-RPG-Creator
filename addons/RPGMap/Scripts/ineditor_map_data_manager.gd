@tool
class_name IneditorMapDataManager
extends RefCounted


## Map data reference
var map: RPGMap


func _init(p_map: RPGMap) -> void:
	map = p_map


func get_region(index: int) -> EnemySpawnRegion:
	if map.regions.size() > index and index >= 0:
		return map.regions[index]
	return null


func get_event_region(index: int) -> EventRegion:
	if map.event_regions.size() > index and index >= 0:
		return map.event_regions[index]
	return null


func generate_16_digit_id() -> int:
	var id_str = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % characters.length()
		id_str += characters.substr(random_index, 1)
	return int(id_str)


func _is_place_free(pos: Vector2i) -> bool:
	var is_place_free: bool = map.events.is_place_free_in(pos)
	if is_place_free:
		for event in map.extraction_events:
			if event.x == pos.x and event.y == pos.y:
				is_place_free = false
				break
	return is_place_free


func add_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	if _is_place_free(pos):
		var event_id: int = map.events.get_next_id()
		var event := RPGEvent.new(event_id, pos.x, pos.y)
		
		if RPGSYSTEM.database:
			event.legacy_mode = RPGSYSTEM.database.system.legacy_mode
			event.fade_page_swap_enabled = RPGSYSTEM.database.system.fade_page_swap_enabled
			
		map.events.add_event(event)
		map.current_event = event
		map.notify_property_list_changed()
		
		if map.editor_canvas and map.editor_canvas.event_canvas: 
			map.editor_canvas.event_canvas.queue_redraw()
		return true
	else:
		map.select_event(pos)
		return false


func _get_next_extraction_event_id() -> int:
	var existing_ids = map.extraction_events.map(func(obj): return obj.id)
	existing_ids.sort()
	
	var expected_id: int = 1
	for id in existing_ids:
		if id == expected_id:
			expected_id += 1
		elif id > expected_id:
			return expected_id
	return expected_id


func add_extraction_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	if _is_place_free(pos):
		var event_id: int = _get_next_extraction_event_id()
		var event := RPGExtractionItem.new(event_id, pos.x, pos.y)
		event.name = "EV" + str(event.id).pad_zeros(4)
		
		map.extraction_events.append(event)
		map.current_extraction_event = event
		map.notify_property_list_changed()
		
		if map.editor_canvas and map.editor_canvas.extraction_event_canvas: 
			map.editor_canvas.extraction_event_canvas.queue_redraw()
		return true
	else:
		map.select_extraction_event(pos)
		return false


func get_region_in(pos: Vector2i) -> EnemySpawnRegion:
	for region in map.regions:
		if region.rect.has_point(pos):
			return region
	return null


func get_event_region_in(pos: Vector2i) -> EventRegion:
	for region in map.event_regions:
		if region.rect.has_point(pos):
			return region
	return null


func get_event_regions_in(pos: Vector2i) -> Array[EventRegion]:
	var regions: Array[EventRegion] = []
	for region in map.event_regions:
		if region.rect.has_point(pos):
			regions.append(region)
	return regions


func random_color_in_range(hue_min: float, hue_max: float) -> Color:
	return Color.from_hsv(randf_range(hue_min, hue_max), randf_range(0.5, 1.0), randf_range(0.5, 1.0))


func add_region(new_region: EnemySpawnRegion) -> EnemySpawnRegion:
	var id: int
	var existing_ids = map.regions.map(func(r): return r.id)
	
	while true:
		id = generate_16_digit_id()
		if not id in existing_ids:
			break
			
	new_region.id = id
	new_region.name = ""
	new_region.color = random_color_in_range(0.0, 1.0)
	new_region.color.a = 0.4
	map.regions.append(new_region)
	map.refresh_canvas()
	return new_region


func add_event_region(new_region: EventRegion) -> EventRegion:
	new_region.id = _get_next_event_region_id()
	new_region.name = ""
	new_region.color = random_color_in_range(0.0, 1.0)
	new_region.color.a = 0.4
	map.event_regions.append(new_region)
	map.refresh_canvas()
	return new_region


func _update_spawn_region(index: int, region: EnemySpawnRegion) -> void:
	if index >= 0 and index < map.regions.size():
		map.regions[index] = region
		map.refresh_canvas()


func _update_event_region(index: int, region: EventRegion) -> void:
	if index >= 0 and index < map.event_regions.size():
		map.event_regions[index] = region
		map.refresh_canvas()


func update_region(region_updated: EnemySpawnRegion) -> void:
	var rect = Rect2i(region_updated.rect.position * map.tile_size, region_updated.rect.size * map.tile_size)
	if map.get_used_rect().intersects(rect):
		for region in map.regions:
			if region.id == region_updated.id:
				region.rect = region_updated.rect
				break
	map.refresh_canvas()


func update_event_region(region_updated: EventRegion) -> void:
	var rect = Rect2i(region_updated.rect.position * map.tile_size, region_updated.rect.size * map.tile_size)
	if map.get_used_rect().intersects(rect):
		for region in map.event_regions:
			if region.id == region_updated.id:
				region.rect = region_updated.rect
				break
	map.refresh_canvas()


func paste_event_in(pos: Vector2i, event: RPGEvent) -> bool:
	if !Engine.is_editor_hint():
		return false
	
	var result = map.events.paste_event_in(pos, event)
	map.notify_property_list_changed()
	
	if map.editor_canvas and map.editor_canvas.event_canvas: 
		map.editor_canvas.event_canvas.queue_redraw()
	return result


func _add_extraction_event(event: RPGExtractionItem, rename: bool = true) -> void:
	if rename:
		event.name = "EV" + str(event.id).pad_zeros(4)
	map.extraction_events.append(event)
	if map.extraction_events.size() > 0:
		map.extraction_events.sort_custom(sort_events_by_id)


func _update_extraction_event(index: int, event: RPGExtractionItem) -> void:
	if index >= 0 and index < map.extraction_events.size():
		map.extraction_events[index] = event


func sort_events_by_id(a: RPGExtractionItem, b: RPGExtractionItem) -> bool:
	return a.id < b.id


func paste_extraction_event_in(pos: Vector2i, new_event: RPGExtractionItem) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	for ev in map.extraction_events:
		if ev.x == pos.x and ev.y == pos.y:
			var properties = ["name", "scene_path", "required_profession", "required_level", "max_uses", "respawn_time", "drop_table", "extraction_fx"]
			for p in properties:
				ev.set(p, new_event.get(p))
			return true
	
	new_event.id = _get_next_extraction_event_id()
	new_event.x = pos.x
	new_event.y = pos.y
	map.last_extraction_event_pasted_id = new_event.id
	_add_extraction_event(new_event, false)
		
	map.notify_property_list_changed()
	if map.editor_canvas and map.editor_canvas.extraction_event_canvas: 
		map.editor_canvas.extraction_event_canvas.queue_redraw()
	return true


func paste_region_in(pos: Vector2i, region: EnemySpawnRegion) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	region.id = generate_16_digit_id()
	region.rect.position = pos
	region.color = random_color_in_range(0.0, 1.0)
	region.color.a = 0.4
	map.regions.append(region)
	map.notify_property_list_changed()
	
	if map.editor_canvas and map.editor_canvas.enemy_spawn_canvas: 
		map.editor_canvas.enemy_spawn_canvas.queue_redraw()
	return true


func _get_next_event_region_id() -> int:
	var used_ids := {}
	for region in map.event_regions:
		used_ids[region.id] = true
	var next_id := 1
	while used_ids.has(next_id):
		next_id += 1
	return next_id


func paste_event_region_in(pos: Vector2i, region: EventRegion) -> bool:
	if !Engine.is_editor_hint():
		return false
		
	region.id = _get_next_event_region_id()
	region.rect.position = pos
	region.color = random_color_in_range(0.0, 1.0)
	region.color.a = 0.4
	map.event_regions.append(region)
	map.notify_property_list_changed()
	
	if map.editor_canvas and map.editor_canvas.event_region_canvas: 
		map.editor_canvas.event_region_canvas.queue_redraw()
	return true


func get_last_event_added() -> int:
	return map.events.get_last_event_added()


func get_last_extraction_event_added() -> int:
	return map.last_extraction_event_pasted_id


func get_event_in(pos: Vector2i) -> RPGEvent:
	return map.events.get_event_in(pos)


func get_extraction_event_in(pos: Vector2i) -> RPGExtractionItem:
	for ev: RPGExtractionItem in map.extraction_events:
		var p = Vector2i(ev.x, ev.y)
		if p == pos:
			return ev
	return null


func get_event_by_id(id: int) -> RPGEvent:
	return map.events.get_event_by_id(id)


func get_event_by_uniq_id(id: int) -> RPGEvent:
	return map.events.get_event_by_uniq_id(id)


func remove_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	var result = map.events.remove_event_in(pos)
	if result:
		map.notify_property_list_changed()
		if map.editor_canvas and map.editor_canvas.event_canvas: 
			map.editor_canvas.event_canvas.queue_redraw()
	return result


func remove_extraction_event_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	var result: bool = false
	for event in map.extraction_events:
		if event.x == pos.x and event.y == pos.y:
			map.extraction_events.erase(event)
			result = true
			break
	if result:
		map.notify_property_list_changed()
		if map.editor_canvas and map.editor_canvas.extraction_event_canvas: 
			map.editor_canvas.extraction_event_canvas.queue_redraw()
	return result


func remove_region_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	var region: EnemySpawnRegion = get_region_in(pos)
	if region:
		remove_region(region)
	return region != null


func remove_event_region_in(pos: Vector2i) -> bool:
	if !Engine.is_editor_hint():
		return false
	var region: EventRegion = get_event_region_in(pos)
	if region:
		remove_event_region(region)
	return region != null


func remove_region(region: EnemySpawnRegion) -> void:
	map.regions.erase(region)
	if map.editor_canvas and map.editor_canvas.enemy_spawn_canvas: 
		map.editor_canvas.enemy_spawn_canvas.queue_redraw()


func remove_event_region(region: EventRegion) -> void:
	map.event_regions.erase(region)
	if map.editor_canvas and map.editor_canvas.event_region_canvas: 
		map.editor_canvas.event_region_canvas.queue_redraw()


func set_events(values: RPGEvents) -> void:
	map.events = values


func select_event(pos: Vector2i) -> void:
	if Engine.is_editor_hint():
		var old_event = map.current_event
		map.current_event = get_event_in(pos)
		if old_event != map.current_event:
			if map.editor_canvas and map.editor_canvas.event_canvas: 
				map.editor_canvas.event_canvas.queue_redraw()


func select_extraction_event(pos: Vector2i) -> void:
	if Engine.is_editor_hint():
		var old_event = map.current_extraction_event
		map.current_extraction_event = get_extraction_event_in(pos)
		if old_event != map.current_extraction_event:
			if map.editor_canvas and map.editor_canvas.extraction_event_canvas: 
				map.editor_canvas.extraction_event_canvas.queue_redraw()


func is_mouse_over_event() -> bool:
	if map.events:
		var pos = map.get_global_mouse_position()
		for event: RPGEvent in map.events.get_events():
			var rect = Rect2i(Vector2i(event.x, event.y) * map.tile_size, map.tile_size)
			if rect.has_point(Vector2i(pos)):
				return true
	return false


func is_mouse_over_extraction_event() -> bool:
	if map.extraction_events:
		var pos = map.get_global_mouse_position()
		for event: RPGExtractionItem in map.extraction_events:
			var rect = Rect2i(Vector2i(event.x, event.y) * map.tile_size, map.tile_size)
			if rect.has_point(Vector2i(pos)):
				return true
	return false


func is_selected_in_editor() -> bool:
	if Engine.is_editor_hint():
		var selection = EditorInterface.get_selection()
		if not selection:
			return false
		
		var selected_nodes = selection.get_selected_nodes()
		return map in selected_nodes and selected_nodes.size() == 1
	
	return false


func is_mouse_inside_viewport() -> bool:
	if not Engine.is_editor_hint():
		return false
	
	var viewport_control = EditorInterface.get_editor_viewport_2d()
	if not viewport_control:
		return false
	
	var local_mouse = viewport_control.get_mouse_position()
	var viewport_rect = Rect2(Vector2.ZERO, viewport_control.size)
	
	return viewport_rect.has_point(local_mouse)


func bake_keot_data_fast() -> void:
	var time = Time.get_ticks_msec()
	map._baked_keot_data.clear()
	var layar_data = "Keep Events On Top"
	
	for layer in map.get_children():
		if not layer is TileMapLayer: continue
	
		var tile_set: TileSet = layer.tile_set
		
		if not tile_set: continue
		
		if not tile_set.has_custom_data_layer_by_name(layar_data): continue
		
		var cache: Dictionary = {}
		var source_count = tile_set.get_source_count()
		
		for i in range(source_count):
			var source_id = tile_set.get_source_id(i)
			var source = tile_set.get_source(source_id)
			
			if source is TileSetAtlasSource:
				var tiles_count = source.get_tiles_count()
				
				for j in range(tiles_count):
					var atlas_coords = source.get_tile_id(j)
					var tile_data = source.get_tile_data(atlas_coords, 0)
					
					if tile_data and tile_data.get_custom_data(layar_data):
						var z = tile_data.z_index + layer.z_index + 1
						if not cache.has(source_id): cache[source_id] = {}
						cache[source_id][atlas_coords] = z

		var cells = layer.get_used_cells()
		
		for coords in cells:
			var id = layer.get_cell_source_id(coords)
			
			if cache.has(id):
				var atlas_coords = layer.get_cell_atlas_coords(coords)
				
				if cache[id].has(atlas_coords):
					var z_val = cache[id][atlas_coords]
					
					if map._baked_keot_data.has(coords):
						map._baked_keot_data[coords] = max(map._baked_keot_data[coords], z_val)
					else:
						map._baked_keot_data[coords] = z_val
