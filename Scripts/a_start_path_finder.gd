class_name AStarPathfinder
extends AStar2D

var _map: RPGMap
var _map_size: Vector2i
var _infinite_x: bool
var _infinite_y: bool

const COST_STRAIGHT = 1.0
const COST_DIAGONAL = 1.4142

func initialize(map: RPGMap) -> void:
	clear()
	_map = map
	_map_size = map.get_map_size_in_tiles()
	_infinite_x = map.infinite_horizontal_scroll
	_infinite_y = map.infinite_vertical_scroll
	
	_build_graph()

func _build_graph() -> void:
	# 1. Add points
	for x in range(_map_size.x):
		for y in range(_map_size.y):
			var tile = Vector2i(x, y)
			add_point(_get_id_from_tile(tile), Vector2(x, y))

	# 2. Connect neighbors
	for x in range(_map_size.x):
		for y in range(_map_size.y):
			var current_tile = Vector2i(x, y)
			
			if not _is_tile_passable_static(current_tile):
				continue

			# --- straight neighbors ---
			_try_connect(current_tile, Vector2i(1, 0), COST_STRAIGHT)  # Right
			_try_connect(current_tile, Vector2i(0, 1), COST_STRAIGHT)  # Down
			
			# --- diagonal neighbors ---
			_try_connect_diagonal(current_tile, Vector2i(1, 1))   # Down-Right
			_try_connect_diagonal(current_tile, Vector2i(-1, 1))  # Down-Left

# Attempt to connect with a relative tile (dx, dy)
func _try_connect(origin: Vector2i, offset: Vector2i, _cost: float) -> void:
	var target_x = origin.x + offset.x
	var target_y = origin.y + offset.y
	var _wrap_h = false
	var _wrap_v = false
	
	# Wrapping X
	if target_x >= _map_size.x:
		if _infinite_x: 
			target_x -= _map_size.x
			_wrap_h = true
		else: return
	elif target_x < 0:
		if _infinite_x: 
			target_x += _map_size.x
			_wrap_h = true
		else: return
	
	# Wrapping Y
	if target_y >= _map_size.y:
		if _infinite_y: 
			target_y -= _map_size.y
			_wrap_v = true
		else: return
	elif target_y < 0:
		if _infinite_y: 
			target_y += _map_size.y
			_wrap_v = true
		else: return

	var target_tile = Vector2i(target_x, target_y)
	
	# Verify that the destination is reachable
	if _is_tile_passable_static(target_tile):
		var from_id = _get_id_from_tile(origin)
		var to_id = _get_id_from_tile(target_tile)
		
		# We connect. AStar2D is bidirectional by default.
		if not are_points_connected(from_id, to_id):
			connect_points(from_id, to_id, true)

# Special logic for diagonals (avoids cutting corners of walls)
func _try_connect_diagonal(origin: Vector2i, offset: Vector2i) -> void:
	var target_x = origin.x + offset.x
	var target_y = origin.y + offset.y
	
	# Quick check of limits before calculating complex logic
	if not _infinite_x and (target_x < 0 or target_x >= _map_size.x): return
	if not _infinite_y and (target_y < 0 or target_y >= _map_size.y): return
	
	# We obtain the adjacent tiles to see if there is a blocked corner.
	# Example: If I go Right-Down (1,1), I check Right (1,0) and Down (0,1).
	var neighbor_h = _get_wrapped_tile(origin + Vector2i(offset.x, 0))
	var neighbor_v = _get_wrapped_tile(origin + Vector2i(0, offset.y))
	
	# Rule: We only connect diagonally if both sides are passable (without cutting through walls).
	if _is_tile_passable_static(neighbor_h) and _is_tile_passable_static(neighbor_v):
		_try_connect(origin, offset, COST_DIAGONAL)

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

func get_next_tile(character: Node2D, current_tile: Vector2i, target_tile: Vector2i) -> Variant:
	if not _map: return null
	
	var start_id = _get_id_from_tile(current_tile)
	var end_id = _get_id_from_tile(target_tile)
	
	if not has_point(start_id) or not has_point(end_id): return null
	
	var disabled_points = _disable_dynamic_obstacles(character, target_tile)
	
	# Important: get_id_path uses the weights defined in _compute_cost
	var path_ids = get_id_path(start_id, end_id)
	
	_restore_dynamic_obstacles(disabled_points)
	
	if path_ids.size() > 1:
		var next_point_pos = get_point_position(path_ids[1])
		return Vector2i(next_point_pos)
	
	return null

func _disable_dynamic_obstacles(me: Node2D, target_tile: Vector2i) -> Array[int]:
	var disabled_ids: Array[int] = []
	
	# We use a Dictionary to quickly avoid duplicates 
	# (an event could be close to both the beginning and the end)
	var obstacles_map: Dictionary = {} 
	
	#1. Get events near ME (so I don't crash when I start walking)
	var nearby_start = _map.map_layout.get_events_near_position(me.global_position)
	for ev in nearby_start:
		obstacles_map[ev] = true
		
	#2. Obtain events near the DESTINATION (so as not to plan a route to an occupied tile).
	var target_pos_world = _map.map_to_local(target_tile)
	var nearby_end = _map.map_layout.get_events_near_position(target_pos_world)
	for ev in nearby_end:
		obstacles_map[ev] = true

	# Add vehicles and player
	var extra_obstacles: Array = []
	if not me.is_in_group("player") and GameManager.current_player:
		extra_obstacles.append(GameManager.current_player)
	extra_obstacles.append_array(_map.get_in_game_vehicles())
	
	for obj in extra_obstacles:
		obstacles_map[obj] = true

	# --- Processing (same as before, but with the reduced list) ---
	for obj in obstacles_map.keys():
		var entity = obj
		
		# Unwrap if necessary
		if obj is Object and obj.has_method("get_class") and obj.get_class() == "IngameEvent":
			entity = obj.lpc_event
			
		if not is_instance_valid(entity) or entity == me:
			continue
			
		if not "visible" in entity or not entity.visible:
			continue
			
		# Check solidity
		var is_solid = true
		if entity.has_method("is_passable"):
			is_solid = not entity.is_passable()
		elif "character_options" in entity:
			is_solid = not entity.character_options.passable
			
		if is_solid:
			var tile = entity.get_current_tile()
			if tile != target_tile:
				var id = _get_id_from_tile(tile)
				if has_point(id) and not is_point_disabled(id):
					set_point_disabled(id, true)
					disabled_ids.append(id)
					
	return disabled_ids


func _restore_dynamic_obstacles(ids: Array[int]) -> void:
	for id in ids:
		if has_point(id):
			set_point_disabled(id, false)

func _get_id_from_tile(tile: Vector2i) -> int:
	var x = tile.x % _map_size.x
	var y = tile.y % _map_size.y
	if x < 0: x += _map_size.x
	if y < 0: y += _map_size.y
	return y * _map_size.x + x

func _is_tile_passable_static(tile: Vector2i) -> bool:
	return _map.is_tile_passable_from_direction(tile, 2) # 2 = DOWN as a reference

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
