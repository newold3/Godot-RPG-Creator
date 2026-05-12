@tool
class_name MapEnvironmentPlacer
extends RefCounted


#region VARIABLES
var _generator: Node
#endregion



## Initializes the placer with a reference to the main generator
func _init(generator: Node) -> void:
	_generator = generator



## Iterates through the grid to place decorators based on probability and constraints
func package_environment_layer(floor_cells: Array[Vector2i], wall_cells: Array[Vector2i], grid: PackedByteArray) -> Dictionary:
	var out_env_pos: Array[Vector2i] = []
	var out_env_src: Array[int] = []
	var out_env_crd: Array[Vector2i] = []
	var out_det_pos: Array[Vector2i] = []
	var out_det_src: Array[int] = []
	var out_det_crd: Array[Vector2i] = []
	var is_world: bool = _generator._is_world_mode()
	
	if _generator.decorator_data.is_empty():
		return {
			"environment": {"pos": out_env_pos, "src": out_env_src, "crd": out_env_crd},
			"detail_environment": {"pos": out_det_pos, "src": out_det_src, "crd": out_det_crd}
		}
		
	var visited: Dictionary = {}
	var spawn_counts: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	var evaluate_cell = func(cell_pos: Vector2i):
		for i in range(_generator.decorator_data.size()):
			var dec: Dictionary = _generator.decorator_data[i]
			
			if not dec.get("enabled", true):
				continue
				
			var max_allowed: int = int(dec.get("max_quantity", 0))
			
			if max_allowed > 0 and spawn_counts.get(i, 0) >= max_allowed:
				continue
				
			var size: Vector2i = dec.get("atlas_size", Vector2i(1, 1))
			var alt_size: Vector2i = dec.get("alt_atlas_size", Vector2i(1, 1))
			var chosen_coord: Vector2i = dec.get("atlas_coords", Vector2i(0, 0))
			var chosen_size: Vector2i = size
			
			if dec.get("alt_atlas_coords", Vector2i(-1, -1)) != Vector2i(-1, -1):
				if rng.randf() * 100.0 <= dec.get("alt_chance_percent", 50.0):
					chosen_coord = dec["alt_atlas_coords"]
					chosen_size = alt_size
					
			var p_mode: int = int(dec.get("placement_mode", 0))
			var is_detail: bool = dec.get("is_detail", false)
			
			if is_detail:
				p_mode = 1
				
			var env_pos: int = int(dec.get("environment_position", 0))
			var can_place: bool = true
			var all_walls: bool = true
			var all_floors: bool = true
			
			for dy in range(chosen_size.y):
				for dx in range(chosen_size.x):
					var check_pos: Vector2i = cell_pos + Vector2i(dx, dy)
					
					if check_pos.x < 0 or check_pos.x >= _generator.map_width or check_pos.y < 0 or check_pos.y >= _generator.map_height:
						can_place = false
						break
						
					if visited.has(check_pos):
						can_place = false
						break
						
					var idx: int = check_pos.y * _generator.map_width + check_pos.x
					var tile_val: int = grid[idx]
					
					if is_world and tile_val == 3:
						can_place = false
						break
						
					if tile_val != 2:
						all_walls = false
						
					var is_floor: bool = false
					
					if is_world:
						is_floor = (tile_val in [1, 4, 5, 8, 10, 6, 7])
					else:
						is_floor = (tile_val == 1)
						
					if not is_floor:
						all_floors = false
						
				if not can_place:
					break
					
			if not can_place:
				continue
				
			if p_mode == 1 and not all_floors:
				continue
				
			if p_mode == 2 and not all_walls:
				continue
				
			if env_pos != 0:
				if not all_walls and not all_floors:
					continue
					
				if not check_environment_position(cell_pos, chosen_size, env_pos, grid):
					continue
					
			if rng.randf() * 100.0 <= dec.get("appear_percent", 100.0):
				for dy in range(chosen_size.y):
					for dx in range(chosen_size.x):
						var place_pos: Vector2i = cell_pos + Vector2i(dx, dy)
						visited[place_pos] = true
						
						if is_detail:
							out_det_pos.append(place_pos)
							out_det_src.append(dec.get("source_id", 0))
							out_det_crd.append(chosen_coord + Vector2i(dx, dy))
						else:
							out_env_pos.append(place_pos)
							out_env_src.append(dec.get("source_id", 0))
							out_env_crd.append(chosen_coord + Vector2i(dx, dy))
							
				spawn_counts[i] = spawn_counts.get(i, 0) + 1
				break
				
	var combined_cells: Array[Vector2i] = []
	combined_cells.append_array(wall_cells)
	combined_cells.append_array(floor_cells)
	combined_cells.shuffle()
	
	for cell in combined_cells:
		if not visited.has(cell):
			evaluate_cell.call(cell)
			
	return {
		"environment": {"pos": out_env_pos, "src": out_env_src, "crd": out_env_crd},
		"detail_environment": {"pos": out_det_pos, "src": out_det_src, "crd": out_det_crd}
	}

## Evaluates if a given rectangle conforms to the environment position rules across any terrain
func check_environment_position(cell_pos: Vector2i, size: Vector2i, env_pos: int, grid: PackedByteArray) -> bool:
	if env_pos == 0:
		return true
		
	var base_val: int = grid[cell_pos.y * _generator.map_width + cell_pos.x]
	var is_base_wall: bool = (base_val == 2)
	var is_base_floor: bool = false
	var is_world: bool = _generator._is_world_mode()
	
	if is_world:
		is_base_floor = (base_val in [1, 4, 5, 8, 10, 6, 7])
	else:
		is_base_floor = (base_val == 1)
		
	var match_terrain = func(v: int) -> bool:
		if is_base_wall: return v == 2
		if is_base_floor:
			if is_world: return v in [1, 4, 5, 8, 10, 6, 7]
			else: return v == 1
		return v == base_val
		
	var start_x: int = cell_pos.x
	
	while start_x > 0 and match_terrain.call(grid[cell_pos.y * _generator.map_width + (start_x - 1)]):
		start_x -= 1
		
	var end_x: int = cell_pos.x + size.x - 1
	
	while end_x + 1 < _generator.map_width and match_terrain.call(grid[cell_pos.y * _generator.map_width + (end_x + 1)]):
		end_x += 1
		
	var start_y: int = cell_pos.y
	
	while start_y > 0 and match_terrain.call(grid[(start_y - 1) * _generator.map_width + cell_pos.x]):
		start_y -= 1
		
	var end_y: int = cell_pos.y + size.y - 1
	
	while end_y + 1 < _generator.map_height and match_terrain.call(grid[(end_y + 1) * _generator.map_width + cell_pos.x]):
		end_y += 1
		
	var block_w: int = end_x - start_x + 1
	var block_h: int = end_y - start_y + 1
	
	var is_top: bool = (cell_pos.y == start_y)
	var is_bottom: bool = ((cell_pos.y + size.y - 1) == end_y)
	var is_left: bool = (cell_pos.x == start_x)
	var is_right: bool = ((cell_pos.x + size.x - 1) == end_x)
	
	match env_pos:
		1:
			return is_top
		2:
			return is_bottom
		3:
			var mid_x1: int = start_x + (block_w - size.x) / 2
			var mid_x2: int = start_x + (block_w - size.x + 1) / 2
			var is_cx: bool = (cell_pos.x == mid_x1 or cell_pos.x == mid_x2)
			var mid_y1: int = start_y + (block_h - size.y) / 2
			var mid_y2: int = start_y + (block_h - size.y + 1) / 2
			var is_cy: bool = (cell_pos.y == mid_y1 or cell_pos.y == mid_y2)
			return is_cx and is_cy
		4:
			return is_left
		5:
			return is_right
		6:
			return is_top and is_left
		7:
			return is_top and is_right
		8:
			return is_bottom and is_left
		9:
			return is_bottom and is_right
			
	return true
