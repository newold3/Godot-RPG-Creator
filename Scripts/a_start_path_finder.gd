class_name AStarPathfinder
extends AStar2D

var _map: RPGMap
var _map_size: Vector2i
var _infinite_x: bool
var _infinite_y: bool

# Debug (for player only)
var debug_mode: bool = false
var last_path: Array[Vector2i] = []
var debug_line_color: Color = Color(1, 0, 0, 0.5)
var debug_point_color: Color = Color(1, 1, 0, 0.5)


const COST_STRAIGHT = 1.0
const COST_DIAGONAL = 1.4142


## Draws the debug path on a given canvas item (call this inside a _draw method)
func draw_debug(canvas: CanvasItem, map: RPGMap) -> void:
	if not debug_mode or last_path.size() < 2 or not canvas or not map:
		return
		
	var points_to_draw: PackedVector2Array = []
	var half_tile: Vector2 = Vector2(map.tile_size) / 2.0
	var radius = min(map.tile_size.x, map.tile_size.y) * 0.2
	var current_visual_tile = Vector2(last_path[0])
	
	for i in range(last_path.size()):
		var tile = last_path[i]
		
		if i > 0:
			var prev_tile = last_path[i - 1]
			var diff_x = tile.x - prev_tile.x
			var diff_y = tile.y - prev_tile.y
			
			if _infinite_x:
				if diff_x > _map_size.x / 2.0:
					diff_x -= _map_size.x
				elif diff_x < -_map_size.x / 2.0:
					diff_x += _map_size.x
					
			if _infinite_y:
				if diff_y > _map_size.y / 2.0:
					diff_y -= _map_size.y
				elif diff_y < -_map_size.y / 2.0:
					diff_y += _map_size.y
					
			current_visual_tile += Vector2(diff_x, diff_y)
			
		var map_pos = (current_visual_tile * Vector2(map.tile_size)) + half_tile
		var draw_pos = canvas.to_local(map_pos)
		
		points_to_draw.append(draw_pos)
		
		canvas.draw_circle(draw_pos, radius, debug_point_color)
		
	canvas.draw_polyline(points_to_draw, debug_line_color, 2.0)


func initialize(map: RPGMap) -> void:
	clear()
	_map = map
	_map_size = map.get_map_size_in_tiles()
	_infinite_x = map.infinite_horizontal_scroll
	_infinite_y = map.infinite_vertical_scroll
	
	_build_graph()


func _get_wrapped_tile(tile: Vector2i) -> Vector2i:
	var x = tile.x
	var y = tile.y
	if _infinite_x: x = posmod(x, _map_size.x)
	if _infinite_y: y = posmod(y, _map_size.y)
	return Vector2i(x, y)

# “Octile” heuristic for 8-direction movement on a grid
func _estimate_cost(from_id: int, to_id: int) -> float:
	var from_pos = get_point_position(from_id)
	var to_pos = get_point_position(to_id)
	
	var dx = abs(from_pos.x - to_pos.x)
	var dy = abs(from_pos.y - to_pos.y)
	
	if _infinite_x: dx = min(dx, _map_size.x - dx)
	if _infinite_y: dy = min(dy, _map_size.y - dy)
	
	var min_delta = min(dx, dy)
	var max_delta = max(dx, dy)
	
	# Cost: Diagonal steps * 1,414 + Remaining straight steps * 1
	return (min_delta * COST_DIAGONAL) + (max_delta - min_delta)

func _compute_cost(from_id: int, to_id: int) -> float:
	# Detect whether it is diagonal or straight to apply the correct weight
	var from_pos = get_point_position(from_id)
	var to_pos = get_point_position(to_id)
	
	var dx = abs(from_pos.x - to_pos.x)
	var dy = abs(from_pos.y - to_pos.y)
	
	# Wrapping adjustment
	if _infinite_x: dx = min(dx, _map_size.x - dx)
	if _infinite_y: dy = min(dy, _map_size.y - dy)

	# If it moves on both axes, it is diagonal.
	if dx > 0.1 and dy > 0.1: # We use 0.1 for floats, even though they are integers in grid.
		return COST_DIAGONAL
	return COST_STRAIGHT


## Gets the next tile for the character and updates the debug path if enabled
func get_next_tile(character: Node2D, current_tile: Vector2i, target_tile: Vector2i) -> Variant:
	
	if not _map:
		return null
		
	var start_id = _get_id_from_tile(current_tile)
	var end_id = _get_id_from_tile(target_tile)
	
	if start_id < 0 or end_id < 0 or not has_point(start_id) or not has_point(end_id):
		return null
		
	if _is_target_in_solid_region(target_tile):
		return null
		
	var state_data = _prepare_pathfinder_state(character, target_tile)
	var path_ids = get_id_path(start_id, end_id)
	
	_restore_pathfinder_state(state_data)
	
	if debug_mode:
		last_path.clear()
		for id in path_ids:
			last_path.append(Vector2i(get_point_position(id)))
			
	if path_ids.size() > 1:
		var next_point_pos = get_point_position(path_ids[1])
		return Vector2i(next_point_pos)
		
	return null


func _is_target_in_solid_region(target_tile: Vector2i) -> bool:
	
	if "ingame_event_regions" in _map:
		for shape in _map.ingame_event_regions:
			if is_instance_valid(shape) and not shape.disabled and shape.has_meta("type") and shape.get_meta("type") == "collision_region":
				var region_data = shape.get_meta("region_data")
				var rect = region_data.rect
				
				if target_tile.x >= int(rect.position.x) and target_tile.x < int(rect.position.x + rect.size.x) and target_tile.y >= int(rect.position.y) and target_tile.y < int(rect.position.y + rect.size.y):
					return true
					
	return false


func _prepare_pathfinder_state(me: Node2D, target_tile: Vector2i) -> Dictionary:
	
	var state: Dictionary = {"disabled_ids": [], "enabled_ids": []}
	var obstacles_to_disable: Array[Dictionary] = []
	
	if not me.is_in_group("player") and GameManager.current_player:
		var add_player = true
		
		if GameManager.current_player.is_on_vehicle and GameManager.current_player.current_vehicle == me:
			add_player = false
			
		if add_player:
			obstacles_to_disable.append({
				"tile": GameManager.current_player.get_current_tile(),
				"entity": GameManager.current_player
			})
			
	if "entity_manager" in _map and _map.entity_manager and "current_ingame_vehicles" in _map.entity_manager:
		for vehicle in _map.entity_manager.current_ingame_vehicles:
			var v_tile = _map.local_to_map(Vector2i(vehicle.global_position))
			obstacles_to_disable.append({"tile": v_tile, "entity": vehicle})
			
			if vehicle.get("extra_dimensions"):
				var extra = vehicle.extra_dimensions
				var v_left = v_tile.x - extra.grow_left
				var v_right = v_tile.x + extra.grow_right + 1
				var v_up = v_tile.y - extra.grow_up
				var v_down = v_tile.y + extra.grow_down + 1
				
				for x in range(v_left, v_right):
					for y in range(v_up, v_down):
						obstacles_to_disable.append({"tile": Vector2i(x, y), "entity": vehicle})
						
	for ev in me.get_tree().get_nodes_in_group("extraction_event"):
		if "is_started" in ev and ev.is_started:
			var ev_tile = _map.local_to_map(Vector2i(ev.global_position))
			obstacles_to_disable.append({"tile": ev_tile, "entity": ev})
			
	if "entity_manager" in _map and _map.entity_manager and "current_ingame_events" in _map.entity_manager:
		for ev in _map.entity_manager.current_ingame_events.values():
			if not ev:
				continue
				
			var lpc = ev.get("lpc_event") if "lpc_event" in ev else null
			
			if lpc and is_instance_valid(lpc):
				var is_solid = true
				
				if lpc.has_method("is_passable"):
					is_solid = not lpc.is_passable()
				elif "character_options" in lpc and lpc.character_options:
					is_solid = not lpc.character_options.passable
					
				if is_solid:
					obstacles_to_disable.append({"tile": lpc.get_current_tile(), "entity": lpc})
					
	if "ingame_event_regions" in _map:
		for shape in _map.ingame_event_regions:
			if not is_instance_valid(shape) or shape.disabled or not shape.has_meta("type"):
				continue
				
			var type = shape.get_meta("type")
			var region_data = shape.get_meta("region_data")
			var rect = region_data.rect
			
			if type == "collision_region":
				for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
					for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
						obstacles_to_disable.append({"tile": Vector2i(x, y), "entity": shape})
						
			elif type == "event_region" and region_data.get("always_passable"):
				for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
					for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
						var tile = Vector2i(x, y)
						var id = _get_id_from_tile(tile)
						
						if has_point(id) and is_point_disabled(id):
							set_point_disabled(id, false)
							state["enabled_ids"].append(id)
							
	for obs in obstacles_to_disable:
		var tile = obs["tile"]
		var entity = obs["entity"]
		
		if entity == me or tile == target_tile:
			continue
			
		var id = _get_id_from_tile(tile)
		
		if has_point(id) and not is_point_disabled(id):
			set_point_disabled(id, true)
			state["disabled_ids"].append(id)
			
	return state


func _restore_pathfinder_state(state: Dictionary) -> void:
	
	for id in state["disabled_ids"]:
		if has_point(id):
			set_point_disabled(id, false)
			
	for id in state["enabled_ids"]:
		if has_point(id):
			set_point_disabled(id, true)


func _get_id_from_tile(tile: Vector2i) -> int:
	var x = tile.x
	var y = tile.y
	if _infinite_x:
		x = x % _map_size.x
		if x < 0:
			x += _map_size.x
	elif x < 0 or x >= _map_size.x:
		return -1
	if _infinite_y:
		y = y % _map_size.y
		if y < 0:
			y += _map_size.y
	elif y < 0 or y >= _map_size.y:
		return -1
	return y * _map_size.x + x


func _is_tile_passable_static(tile: Vector2i) -> bool:
	
	if "ingame_event_regions" in _map:
		for shape in _map.ingame_event_regions:
			if is_instance_valid(shape) and shape.has_meta("type") and shape.get_meta("type") == "event_region":
				var region_data = shape.get_meta("region_data")
				
				if region_data.get("always_passable"):
					var rect = region_data.rect
					
					if tile.x >= int(rect.position.x) and tile.x < int(rect.position.x + rect.size.x) and tile.y >= int(rect.position.y) and tile.y < int(rect.position.y + rect.size.y):
						return true
						
	return _map.is_tile_passable_from_direction(tile, 2)


func vector2_to_direction(motion: Vector2i) -> int:
	if _infinite_x:
		if motion.x > 1: motion.x = -1
		elif motion.x < -1: motion.x = 1
	if _infinite_y:
		if motion.y > 1: motion.y = -1
		elif motion.y < -1: motion.y = 1
	
	# Logic to return diagonal address if it exists
	if motion.x < 0 and motion.y < 0: return 7 # UP-LEFT (8 directions)
	
	# (4 directions)
	if abs(motion.x) > abs(motion.y):
		if motion.x < 0: return CharacterBase.DIRECTIONS.LEFT
		if motion.x > 0: return CharacterBase.DIRECTIONS.RIGHT
	else:
		if motion.y < 0: return CharacterBase.DIRECTIONS.UP
		if motion.y > 0: return CharacterBase.DIRECTIONS.DOWN
	
	# Fallback
	if motion.x != 0: return CharacterBase.DIRECTIONS.RIGHT if motion.x > 0 else CharacterBase.DIRECTIONS.LEFT
	return CharacterBase.DIRECTIONS.DOWN


func direction_to_vector2i(search_dir: int) -> Vector2i:
	match search_dir:
		CharacterBase.DIRECTIONS.LEFT: return Vector2i.LEFT
		CharacterBase.DIRECTIONS.RIGHT: return Vector2i.RIGHT
		CharacterBase.DIRECTIONS.UP: return Vector2i.UP
		_: return Vector2i.DOWN


func update_tile_connections(tile: Vector2i) -> void:
	
	var id = _get_id_from_tile(tile)
	
	if not has_point(id):
		return
		
	var is_passable = _is_tile_passable_static(tile)
	
	set_point_disabled(id, not is_passable)


func _disable_dynamic_obstacles(me: Node2D, target_tile: Vector2i) -> Array[int]:
	
	var disabled_ids: Array[int] = []
	var obstacles_to_disable: Array[Dictionary] = []
	
	if not me.is_in_group("player") and GameManager.current_player:
		var add_player = true
		
		if GameManager.current_player.is_on_vehicle and GameManager.current_player.current_vehicle == me:
			add_player = false
			
		if add_player:
			obstacles_to_disable.append({
				"tile": GameManager.current_player.get_current_tile(),
				"entity": GameManager.current_player
			})
			
	if "entity_manager" in _map and _map.entity_manager and "current_ingame_vehicles" in _map.entity_manager:
		for vehicle in _map.entity_manager.current_ingame_vehicles:
			var v_tile = _map.local_to_map(Vector2i(vehicle.global_position))
			obstacles_to_disable.append({"tile": v_tile, "entity": vehicle})
			
			if vehicle.get("extra_dimensions"):
				var extra = vehicle.extra_dimensions
				var v_left = v_tile.x - extra.grow_left
				var v_right = v_tile.x + extra.grow_right + 1
				var v_up = v_tile.y - extra.grow_up
				var v_down = v_tile.y + extra.grow_down + 1
				
				for x in range(v_left, v_right):
					for y in range(v_up, v_down):
						obstacles_to_disable.append({"tile": Vector2i(x, y), "entity": vehicle})
						
	for ev in me.get_tree().get_nodes_in_group("extraction_event"):
		if "is_started" in ev and ev.is_started:
			var ev_tile = _map.local_to_map(Vector2i(ev.global_position))
			obstacles_to_disable.append({"tile": ev_tile, "entity": ev})
			
	if "entity_manager" in _map and _map.entity_manager and "current_ingame_events" in _map.entity_manager:
		for ev in _map.entity_manager.current_ingame_events.values():
			if not ev:
				continue
				
			var lpc = ev.get("lpc_event") if "lpc_event" in ev else null
			
			if lpc and is_instance_valid(lpc):
				var is_solid = true
				
				if lpc.has_method("is_passable"):
					is_solid = not lpc.is_passable()
				elif "character_options" in lpc and lpc.character_options:
					is_solid = not lpc.character_options.passable
					
				if is_solid:
					obstacles_to_disable.append({"tile": lpc.get_current_tile(), "entity": lpc})
					
	if "ingame_event_regions" in _map:
		for shape in _map.ingame_event_regions:
			if not is_instance_valid(shape) or not shape.has_meta("type"):
				continue
				
			var type = shape.get_meta("type")
			
			if type == "collision_region" and not shape.disabled:
				var region_data = shape.get_meta("region_data")
				var rect = region_data.rect
				
				for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
					for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
						obstacles_to_disable.append({"tile": Vector2i(x, y), "entity": shape})
						
			elif type == "event_region" and shape.disabled:
				var region_data = shape.get_meta("region_data")
				
				if region_data.get("always_passable"):
					var rect = region_data.rect
					
					for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
						for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
							var t = Vector2i(x, y)
							
							if not _map.is_tile_passable_from_direction(t, 2):
								obstacles_to_disable.append({"tile": t, "entity": shape})
								
	for obs in obstacles_to_disable:
		var tile = obs["tile"]
		var entity = obs["entity"]
		
		if entity == me:
			continue
			
		if tile != target_tile:
			var id = _get_id_from_tile(tile)
			
			if has_point(id) and not is_point_disabled(id):
				set_point_disabled(id, true)
				disabled_ids.append(id)
				
	return disabled_ids


func _try_connect(origin: Vector2i, offset: Vector2i) -> void:
	
	var target_x = origin.x + offset.x
	var target_y = origin.y + offset.y
	
	if target_x >= _map_size.x:
		if _infinite_x:
			target_x -= _map_size.x
		else:
			return
	elif target_x < 0:
		if _infinite_x:
			target_x += _map_size.x
		else:
			return
			
	if target_y >= _map_size.y:
		if _infinite_y:
			target_y -= _map_size.y
		else:
			return
	elif target_y < 0:
		if _infinite_y:
			target_y += _map_size.y
		else:
			return
			
	var target_tile = Vector2i(target_x, target_y)
	var from_id = _get_id_from_tile(origin)
	var to_id = _get_id_from_tile(target_tile)
	
	if not are_points_connected(from_id, to_id):
		connect_points(from_id, to_id, true)


func _try_connect_diagonal(origin: Vector2i, offset: Vector2i) -> void:
	
	var target_x = origin.x + offset.x
	var target_y = origin.y + offset.y
	
	if not _infinite_x and (target_x < 0 or target_x >= _map_size.x):
		return
		
	if not _infinite_y and (target_y < 0 or target_y >= _map_size.y):
		return
		
	_try_connect(origin, offset)


func _build_graph() -> void:
	
	for x in range(_map_size.x):
		for y in range(_map_size.y):
			var tile = Vector2i(x, y)
			add_point(_get_id_from_tile(tile), Vector2(x, y))
			
	for x in range(_map_size.x):
		for y in range(_map_size.y):
			var current_tile = Vector2i(x, y)
			
			_try_connect(current_tile, Vector2i(1, 0))
			_try_connect(current_tile, Vector2i(0, 1))
			_try_connect_diagonal(current_tile, Vector2i(1, 1))
			_try_connect_diagonal(current_tile, Vector2i(-1, 1))
			
			if not _is_tile_passable_static(current_tile):
				var id = _get_id_from_tile(current_tile)
				set_point_disabled(id, true)
