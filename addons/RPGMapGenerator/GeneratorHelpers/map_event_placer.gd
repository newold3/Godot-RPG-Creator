@tool
class_name MapEventPlacer
extends RefCounted


#region VARIABLES
var _generator: Node
#endregion



## Initializes the helper with a reference to the main generator
func _init(generator: Node) -> void:
	_generator = generator



## Opens the dialog to select and manage the map generator events library
func open_event_editor_dialog() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/select_map_generator_events_dialog.tscn"
	var dialog: Window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(_generator.events_library)
	
	if not dialog.tree_exited.is_connected(_generator.save_events_library):
		dialog.tree_exited.connect(_generator.save_events_library)
		
	if not dialog.tree_exited.is_connected(_update_event_canvas):
		dialog.tree_exited.connect(_update_event_canvas)



## Generates random events based on the probabilities and limits defined in the library
func generate_random_events() -> void:
	if not _generator.events_library or _generator.events_library.events.is_empty():
		return
		
	var new_events_list: Array[MapPlacedEvent] = []
	var grid_data: Dictionary = _generator._read_initial_grid()
	var grid: PackedByteArray = grid_data["grid"]
	var spawn_counts: Dictionary = {}
	var visited_cells: Dictionary = {}
	var available_cells: Array[Vector2i] = []
	
	for y in range(_generator.map_height):
		for x in range(_generator.map_width):
			available_cells.append(Vector2i(x, y))
			
	available_cells.shuffle()
	var valid_candidates: Array = []
	
	for ev in _generator.events_library.events:
		if not ev.locked and ev.event:
			valid_candidates.append(ev)
			
	if valid_candidates.is_empty():
		_update_event_canvas()
		return
		
	for cell in available_cells:
		if visited_cells.has(cell):
			continue
			
		valid_candidates.shuffle()
		
		for candidate in valid_candidates:
			var base_event_id: int = candidate.event.get_instance_id()
			var max_allowed: int = candidate.max_quantity
			var current_count: int = spawn_counts.get(base_event_id, 0)
			
			if max_allowed > 0 and current_count >= max_allowed:
				continue
				
			if randf() * 100.0 > candidate.probability:
				continue
				
			var ev_w: int = candidate.get("width") if "width" in candidate else 1
			var ev_h: int = candidate.get("height") if "height" in candidate else 1
			
			if ev_w <= 0:
				ev_w = 1
			if ev_h <= 0:
				ev_h = 1
				
			var area_free: bool = true
			
			for dy in range(ev_h):
				for dx in range(ev_w):
					if visited_cells.has(cell + Vector2i(dx, dy)):
						area_free = false
						break
				if not area_free:
					break
					
			if not area_free:
				continue
				
			if not is_tile_valid_for_event_placement(cell, grid, candidate):
				continue
				
			for dy in range(ev_h):
				for dx in range(ev_w):
					visited_cells[cell + Vector2i(dx, dy)] = true
					
			var new_placed_event: MapPlacedEvent = MapPlacedEvent.new()
			new_placed_event.template_uid = candidate.event._uniq_id
			new_placed_event.tile = cell
			
			new_events_list.append(new_placed_event)
			spawn_counts[base_event_id] = current_count + 1
			break
			
	var ur: Object = _generator.get("editor_undo_redo") if _generator else null
	
	if ur:
		ur.create_action("Generate Map Events")
		ur.add_do_property(_generator, "current_map_events", new_events_list)
		ur.add_undo_property(_generator, "current_map_events", _generator.current_map_events.duplicate(true))
		ur.add_do_method(self, "_update_event_canvas")
		ur.add_undo_method(self, "_update_event_canvas")
		ur.commit_action()
	else:
		_generator.current_map_events = new_events_list
		_update_event_canvas()
		
	print("MapGenerator: Generated ", new_events_list.size(), " lightweight events.")



## Retrieves the full MapGeneratorEvent wrapper from the library using the template UID
func get_wrapper_from_uid(uid: int) -> MapGeneratorEvent:
	if not _generator.events_library:
		return null
		
	for wrapper in _generator.events_library.events:
		if wrapper.event and wrapper.event._uniq_id == uid:
			return wrapper
			
	return null



## Retrieves just the event template from the library using its UID
func get_template_from_uid(uid: int) -> RPGEvent:
	if not _generator.events_library:
		return null
		
	for template in _generator.events_library.events:
		if template.event and template.event._uniq_id == uid:
			return template.event
			
	return null



## Generates events randomly but forcing the exact counts from the preset dictionary ensuring strict typing
func package_random_events_filtered(grid: PackedByteArray, env_grid: PackedByteArray, preset_data: Array) -> Array[MapPlacedEvent]:
	var out_events: Array[MapPlacedEvent] = []
	
	if not _generator.events_library:
		return out_events
		
	var target_counts: Dictionary = {}
	
	for item in preset_data:
		if typeof(item) == TYPE_DICTIONARY:
			var s_uid: String = str(item.get("uid", "0"))
			target_counts[s_uid] = int(item.get("count", 0))
		else:
			var s_uid: String = str(item)
			target_counts[s_uid] = -1
			
	var available_cells: Array[Vector2i] = []
	
	for y in range(_generator.map_height):
		for x in range(_generator.map_width):
			available_cells.append(Vector2i(x, y))
			
	available_cells.shuffle()
	var current_spawn_counts: Dictionary = {}
	var visited_cells: Dictionary = {}
	var valid_candidates: Array = []
	
	for wrapper in _generator.events_library.events:
		if wrapper.event:
			var s_uid: String = str(wrapper.event._uniq_id)
			if target_counts.has(s_uid):
				valid_candidates.append(wrapper)
				
	if valid_candidates.is_empty():
		return out_events
		
	for cell in available_cells:
		if visited_cells.has(cell):
			continue
			
		valid_candidates.shuffle()
		
		for candidate in valid_candidates:
			var s_uid: String = str(candidate.event._uniq_id)
			var target_amount: int = target_counts.get(s_uid, -1)
			var current: int = current_spawn_counts.get(s_uid, 0)
			
			if target_amount != -1 and current >= target_amount:
				continue
				
			var ev_w: int = candidate.get("width") if "width" in candidate else 1
			var ev_h: int = candidate.get("height") if "height" in candidate else 1
			
			if ev_w <= 0:
				ev_w = 1
			if ev_h <= 0:
				ev_h = 1
				
			var area_free: bool = true
			
			for dy in range(ev_h):
				for dx in range(ev_w):
					if visited_cells.has(cell + Vector2i(dx, dy)):
						area_free = false
						break
				if not area_free:
					break
					
			if not area_free:
				continue
				
			if is_tile_valid_for_event_placement(cell, grid, candidate, env_grid):
				for dy in range(ev_h):
					for dx in range(ev_w):
						visited_cells[cell + Vector2i(dx, dy)] = true
						
				var new_ev: MapPlacedEvent = MapPlacedEvent.new()
				new_ev.template_uid = int(s_uid)
				new_ev.tile = cell
				
				out_events.append(new_ev)
				current_spawn_counts[s_uid] = current + 1
				break
				
	return out_events



## Checks if a specific tile matches the placement rules defined for an event
func is_tile_valid_for_event_placement(tile_pos: Vector2i, grid: PackedByteArray, rules: MapGeneratorEvent, env_grid: PackedByteArray = [], w: int = -1, h: int = -1) -> bool:
	var cur_w: int = w if w != -1 else _generator.map_width
	var cur_h: int = h if h != -1 else _generator.map_height
	
	var ev_w: int = rules.get("width") if "width" in rules else 1
	var ev_h: int = rules.get("height") if "height" in rules else 1
	var footprint_height: int = rules.get("footprint_height") if "footprint_height" in rules else ev_h
	var wall_margins: Vector4i = rules.get("wall_margins") if "wall_margins" in rules else Vector4i(0, 0, 0, 0)
	
	if footprint_height <= 0 or footprint_height > ev_h:
		footprint_height = ev_h
		
	var vertical_offset: int = ev_h - footprint_height
	var physical_y: int = tile_pos.y + vertical_offset
	
	for dy in range(ev_h):
		for dx in range(ev_w):
			var check_pos: Vector2i = tile_pos + Vector2i(dx, dy)
			var is_physical: bool = dy >= vertical_offset
			
			if check_pos.x < 0 or check_pos.x >= cur_w or check_pos.y < 0 or check_pos.y >= cur_h:
				return false
				
			if not is_physical:
				continue
				
			var idx: int = check_pos.y * cur_w + check_pos.x
			
			if not rules.ignore_environment:
				if not env_grid.is_empty() and env_grid[idx] == 1:
					return false
				elif env_grid.is_empty() and _generator.layer_environment and _generator.layer_environment.get_cell_source_id(check_pos) != -1:
					return false
					
			var tile_val: int = grid[idx]
			var mode: int = rules.placement
			var is_wall: bool = (tile_val == 2 or tile_val == 9)
			var is_floor: bool = (tile_val == 1 or (_generator._is_world_mode() and tile_val in [1, 4, 5, 8, 10, 6, 7]))
			
			if mode == RPGEnums.MapPlacement.FLOOR and not is_floor:
				return false
				
			if mode == RPGEnums.MapPlacement.WALL and not is_wall:
				return false
				
	if wall_margins != Vector4i(0, 0, 0, 0):
		var clearance_failed: bool = false
		
		if wall_margins.x > 0:
			for my in range(physical_y, physical_y + footprint_height):
				for mx in range(tile_pos.x - wall_margins.x, tile_pos.x):
					if mx >= 0 and mx < cur_w and my >= 0 and my < cur_h:
						var val: int = grid[my * cur_w + mx]
						if val == 2 or val == 9:
							clearance_failed = true
							break
			if clearance_failed: return false
			
		if not clearance_failed and wall_margins.y > 0:
			for mx in range(tile_pos.x, tile_pos.x + ev_w):
				for my in range(physical_y - wall_margins.y, physical_y):
					if mx >= 0 and mx < cur_w and my >= 0 and my < cur_h:
						var val: int = grid[my * cur_w + mx]
						if val == 2 or val == 9:
							clearance_failed = true
							break
			if clearance_failed: return false
			
		if not clearance_failed and wall_margins.z > 0:
			for my in range(physical_y, physical_y + footprint_height):
				for mx in range(tile_pos.x + ev_w, tile_pos.x + ev_w + wall_margins.z):
					if mx >= 0 and mx < cur_w and my >= 0 and my < cur_h:
						var val: int = grid[my * cur_w + mx]
						if val == 2 or val == 9:
							clearance_failed = true
							break
			if clearance_failed: return false
			
		if not clearance_failed and wall_margins.w > 0:
			for mx in range(tile_pos.x, tile_pos.x + ev_w):
				for my in range(physical_y + footprint_height, physical_y + footprint_height + wall_margins.w):
					if mx >= 0 and mx < cur_w and my >= 0 and my < cur_h:
						var val: int = grid[my * cur_w + mx]
						if val == 2 or val == 9:
							clearance_failed = true
							break
			if clearance_failed: return false
			
	if rules.event_position != RPGEnums.MapEventPosition.ANYWHERE:
		if _generator.get("environment_placer"):
			var env_placer = _generator.environment_placer
			if env_placer.has_method("check_environment_position_dynamic"):
				if not env_placer.check_environment_position_dynamic(tile_pos, Vector2i(ev_w, ev_h), rules.event_position, grid, vertical_offset, cur_w, cur_h):
					return false
			else:
				if not env_placer.check_environment_position(tile_pos, Vector2i(ev_w, ev_h), rules.event_position, grid, vertical_offset):
					return false
					
	return true



## Clears all events currently painted on the map and updates the visual canvas
func clear_all_events() -> void:
	var empty_list: Array[MapPlacedEvent] = []
	var ur: Object = _generator.get("editor_undo_redo") if _generator else null
	
	if ur:
		ur.create_action("Clear All Map Events")
		ur.add_do_property(_generator, "current_map_events", empty_list)
		ur.add_undo_property(_generator, "current_map_events", _generator.current_map_events.duplicate(true))
		ur.add_do_method(self, "_update_event_canvas")
		ur.add_undo_method(self, "_update_event_canvas")
		ur.commit_action()
	else:
		_generator.current_map_events.clear()
		_update_event_canvas()



## Removes a specific event from the array by index and updates the visual canvas
func request_event_deletion(index: int) -> void:
	if index >= 0 and index < _generator.current_map_events.size():
		var ur: Object = _generator.get("editor_undo_redo") if _generator else null
		var do_events = _generator.current_map_events.duplicate(true)
		do_events.remove_at(index)
		
		if ur:
			ur.create_action("Delete Map Event")
			ur.add_do_property(_generator, "current_map_events", do_events)
			ur.add_undo_property(_generator, "current_map_events", _generator.current_map_events.duplicate(true))
			ur.add_do_method(self, "_update_event_canvas")
			ur.add_undo_method(self, "_update_event_canvas")
			ur.commit_action()
		else:
			_generator.current_map_events.remove_at(index)
			_update_event_canvas()
			
		print("MapGenerator: Event removed.")



## Forces the custom UI node to redraw the event icons on the 2D workspace
func _update_event_canvas() -> void:
	var canvas = _generator.get_node_or_null("%EventCanvas")
	if canvas:
		canvas.queue_redraw()
