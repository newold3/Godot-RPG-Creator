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
		
	_generator.current_map_events.clear()
	var grid_data: Dictionary = _generator._read_initial_grid()
	var grid: PackedByteArray = grid_data["grid"]
	var spawn_counts: Dictionary = {}
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
		valid_candidates.shuffle()
		for candidate in valid_candidates:
			var base_event_id: int = candidate.event.get_instance_id()
			var max_allowed: int = candidate.max_quantity
			var current_count: int = spawn_counts.get(base_event_id, 0)
			
			if max_allowed > 0 and current_count >= max_allowed:
				continue
				
			if randf() * 100.0 > candidate.probability:
				continue
				
			if not is_tile_valid_for_event_placement(cell, grid, candidate):
				continue
				
			var new_placed_event: MapPlacedEvent = MapPlacedEvent.new()
			new_placed_event.template_uid = candidate.event._uniq_id
			new_placed_event.tile = cell
			
			_generator.current_map_events.append(new_placed_event)
			spawn_counts[base_event_id] = current_count + 1
			break
			
	_update_event_canvas()
	print("MapGenerator: Generated ", _generator.current_map_events.size(), " lightweight events.")



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
	if not _generator.events_library: return out_events
	
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
	var valid_candidates: Array = []
	
	for wrapper in _generator.events_library.events:
		if wrapper.event:
			var s_uid: String = str(wrapper.event._uniq_id)
			if target_counts.has(s_uid):
				valid_candidates.append(wrapper)
				
	if valid_candidates.is_empty():
		return out_events
		
	for cell in available_cells:
		valid_candidates.shuffle()
		
		for candidate in valid_candidates:
			var s_uid: String = str(candidate.event._uniq_id)
			var target_amount: int = target_counts.get(s_uid, -1)
			var current: int = current_spawn_counts.get(s_uid, 0)
			
			if target_amount != -1 and current >= target_amount:
				continue
				
			if is_tile_valid_for_event_placement(cell, grid, candidate, env_grid):
				var new_ev: MapPlacedEvent = MapPlacedEvent.new()
				new_ev.template_uid = int(s_uid)
				new_ev.tile = cell
				
				out_events.append(new_ev)
				current_spawn_counts[s_uid] = current + 1
				break
				
	return out_events



## Checks if a specific tile matches the placement rules defined for an event
func is_tile_valid_for_event_placement(tile_pos: Vector2i, grid: PackedByteArray, rules: MapGeneratorEvent, env_grid: PackedByteArray = []) -> bool:
	var idx: int = tile_pos.y * _generator.map_width + tile_pos.x
	if idx < 0 or idx >= grid.size(): return false
	
	var tile_val: int = grid[idx]
	var mode: int = rules.placement
	
	if not rules.ignore_environment:
		if not env_grid.is_empty() and env_grid[idx] == 1:
			return false
			
		elif env_grid.is_empty() and _generator.layer_environment and _generator.layer_environment.get_cell_source_id(tile_pos) != -1:
			return false
			
	var is_wall: bool = (tile_val == 2 or tile_val == 9)
	var is_floor: bool = (tile_val == 1 or (_generator._is_world_mode() and tile_val in [1, 4, 5, 8, 10, 6, 7]))
	
	if mode == MapGeneratorEvent.PLACEMENT.FLOOR and not is_floor: return false
	if mode == MapGeneratorEvent.PLACEMENT.WALL and not is_wall: return false
	
	if rules.event_position != MapGeneratorEvent.EVENT_POSITION.ANYWHERE:
		if _generator.get("environment_placer") and not _generator.environment_placer.check_environment_position(tile_pos, Vector2i(1, 1), rules.event_position, grid):
			return false
			
	return true



## Clears all events currently painted on the map and updates the visual canvas
func clear_all_events() -> void:
	_generator.current_map_events.clear()
	_update_event_canvas()



## Removes a specific event from the array by index and updates the visual canvas
func request_event_deletion(index: int) -> void:
	if index >= 0 and index < _generator.current_map_events.size():
		_generator.current_map_events.remove_at(index)
		_update_event_canvas()
		print("MapGenerator: Event removed.")



## Forces the custom UI node to redraw the event icons on the 2D workspace
func _update_event_canvas() -> void:
	var canvas = _generator.get_node_or_null("%EventCanvas")
	if canvas:
		canvas.queue_redraw()
