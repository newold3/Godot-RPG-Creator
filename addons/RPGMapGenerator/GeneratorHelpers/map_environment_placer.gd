@tool
class_name MapEnvironmentPlacer
extends RefCounted


#region VARIABLES
var _generator: Node
#endregion



## Initializes the placer with a reference to the main generator
func _init(generator: Node) -> void:
	_generator = generator



## Iterates through the grid to place decorators based on probability and constraints using dynamic boundaries
func package_environment_layer_dynamic(floor_cells: Array[Vector2i], wall_cells: Array[Vector2i], grid: PackedByteArray, w: int, h: int) -> Dictionary:
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
				if randf() * 100.0 <= dec.get("alt_chance_percent", 50.0):
					chosen_coord = dec["alt_atlas_coords"]
					chosen_size = alt_size
					
			var p_mode: int = int(dec.get("placement_mode", 0))
			var is_detail: bool = dec.get("is_detail", false)
			var env_pos: int = int(dec.get("environment_position", 0))
			var footprint_height: int = int(dec.get("footprint_height", 0))
			var wall_margins: Vector4i = dec.get("wall_margins", Vector4i(0, 0, 0, 0))
			
			if footprint_height <= 0 or footprint_height > chosen_size.y:
				footprint_height = chosen_size.y
				
			var vertical_offset: int = chosen_size.y - footprint_height
			var physical_y: int = cell_pos.y + vertical_offset
			
			if is_detail:
				p_mode = 1
				
			var can_place: bool = true
			var all_walls: bool = true
			var all_floors: bool = true
			
			for dy in range(chosen_size.y):
				for dx in range(chosen_size.x):
					var check_pos: Vector2i = cell_pos + Vector2i(dx, dy)
					var is_physical: bool = dy >= vertical_offset
					
					if check_pos.x < 0 or check_pos.x >= w or check_pos.y < 0 or check_pos.y >= h:
						can_place = false
						break
						
					if visited.has(check_pos):
						can_place = false
						break
						
					var idx: int = check_pos.y * w + check_pos.x
					var tile_val: int = grid[idx]
					
					if is_physical:
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
				
			if wall_margins != Vector4i(0, 0, 0, 0):
				var clearance_failed: bool = false
				
				if p_mode == 2:
					if wall_margins.x > 0:
						for my in range(cell_pos.y, cell_pos.y + chosen_size.y):
							var count_left: int = 0
							var cx: int = cell_pos.x - 1
							while cx >= 0:
								if grid[my * w + cx] == 2:
									count_left += 1
									cx -= 1
								else:
									break
							if count_left <= wall_margins.x:
								clearance_failed = true
								break
								
					if not clearance_failed and wall_margins.y > 0:
						for mx in range(cell_pos.x, cell_pos.x + chosen_size.x):
							var count_top: int = 0
							var cy: int = cell_pos.y - 1
							while cy >= 0:
								if grid[cy * w + mx] == 2:
									count_top += 1
									cy -= 1
								else:
									break
							if count_top <= wall_margins.y:
								clearance_failed = true
								break
								
					if not clearance_failed and wall_margins.z > 0:
						for my in range(cell_pos.y, cell_pos.y + chosen_size.y):
							var count_right: int = 0
							var cx: int = cell_pos.x + chosen_size.x
							while cx < w:
								if grid[my * w + cx] == 2:
									count_right += 1
									cx += 1
								else:
									break
							if count_right <= wall_margins.z:
								clearance_failed = true
								break
								
					if not clearance_failed and wall_margins.w > 0:
						for mx in range(cell_pos.x, cell_pos.x + chosen_size.x):
							var count_bottom: int = 0
							var cy: int = cell_pos.y + chosen_size.y
							while cy < h:
								if grid[cy * w + mx] == 2:
									count_bottom += 1
									cy += 1
								else:
									break
							if count_bottom <= wall_margins.w:
								clearance_failed = true
								break
				else:
					if wall_margins.x > 0:
						for my in range(physical_y, physical_y + footprint_height):
							for mx in range(cell_pos.x - wall_margins.x, cell_pos.x):
								if mx >= 0 and mx < w and my >= 0 and my < h:
									var val: int = grid[my * w + mx]
									if val == 2 or val == 9:
										clearance_failed = true
										break
							if clearance_failed: break
							
					if not clearance_failed and wall_margins.y > 0:
						for mx in range(cell_pos.x, cell_pos.x + chosen_size.x):
							for my in range(physical_y - wall_margins.y, physical_y):
								if mx >= 0 and mx < w and my >= 0 and my < h:
									var val: int = grid[my * w + mx]
									if val == 2 or val == 9:
										clearance_failed = true
										break
							if clearance_failed: break
							
					if not clearance_failed and wall_margins.z > 0:
						for my in range(physical_y, physical_y + footprint_height):
							for mx in range(cell_pos.x + chosen_size.x, cell_pos.x + chosen_size.x + wall_margins.z):
								if mx >= 0 and mx < w and my >= 0 and my < h:
									var val: int = grid[my * w + mx]
									if val == 2 or val == 9:
										clearance_failed = true
										break
							if clearance_failed: break
							
					if not clearance_failed and wall_margins.w > 0:
						for mx in range(cell_pos.x, cell_pos.x + chosen_size.x):
							for my in range(physical_y + footprint_height, physical_y + footprint_height + wall_margins.w):
								if mx >= 0 and mx < w and my >= 0 and my < h:
									var val: int = grid[my * w + mx]
									if val == 2 or val == 9:
										clearance_failed = true
										break
							if clearance_failed: break
							
				if clearance_failed:
					continue
					
			if env_pos != 0:
				if not all_walls and not all_floors:
					continue
					
				if not check_environment_position_dynamic(cell_pos, chosen_size, env_pos, grid, vertical_offset, w, h):
					continue
					
			if randf() * 100.0 <= dec.get("appear_percent", 100.0):
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


## Evaluates if a given rectangle conforms to the environment position rules across any terrain using dynamic boundaries
func check_environment_position_dynamic(cell_pos: Vector2i, size: Vector2i, env_pos: int, grid: PackedByteArray, vertical_offset: int, w: int, h: int) -> bool:
	if env_pos == 0:
		return true
		
	var physical_y: int = cell_pos.y + vertical_offset
	var physical_h: int = size.y - vertical_offset
	var base_val: int = grid[physical_y * w + cell_pos.x]
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
	
	while start_x > 0 and match_terrain.call(grid[physical_y * w + (start_x - 1)]):
		start_x -= 1
		
	var end_x: int = cell_pos.x + size.x - 1
	
	while end_x + 1 < w and match_terrain.call(grid[physical_y * w + (end_x + 1)]):
		end_x += 1
		
	var start_y: int = physical_y
	
	while start_y > 0 and match_terrain.call(grid[(start_y - 1) * w + cell_pos.x]):
		start_y -= 1
		
	var end_y: int = physical_y + physical_h - 1
	
	while end_y + 1 < h and match_terrain.call(grid[(end_y + 1) * w + cell_pos.x]):
		end_y += 1
		
	var block_w: int = end_x - start_x + 1
	var block_h: int = end_y - start_y + 1
	
	var is_top: bool = (physical_y == start_y)
	var is_bottom: bool = ((physical_y + physical_h - 1) == end_y)
	var is_left: bool = (cell_pos.x == start_x)
	var is_right: bool = ((cell_pos.x + size.x - 1) == end_x)
	
	match env_pos:
		1: return is_top
		2: return is_bottom
		3:
			var mid_x1: int = start_x + (block_w - size.x) / 2
			var mid_x2: int = start_x + (block_w - size.x + 1) / 2
			var is_cx: bool = (cell_pos.x == mid_x1 or cell_pos.x == mid_x2)
			var mid_y1: int = start_y + (block_h - physical_h) / 2
			var mid_y2: int = start_y + (block_h - physical_h + 1) / 2
			var is_cy: bool = (physical_y == mid_y1 or physical_y == mid_y2)
			return is_cx and is_cy
		4: return is_left
		5: return is_right
		6: return is_top and is_left
		7: return is_top and is_right
		8: return is_bottom and is_left
		9: return is_bottom and is_right
			
	return true


## Evaluates if a tile position is valid for manually placing a specific decorator
func is_valid_for_decorator(grid_pos: Vector2i, dec_data: Dictionary, grid: PackedByteArray, w: int, h: int, ignore_root: Vector2i = Vector2i(-1, -1)) -> bool:
	var size: Vector2i = dec_data.get("atlas_size", Vector2i(1, 1))
	var p_mode: int = int(dec_data.get("placement_mode", 0))
	var env_pos: int = int(dec_data.get("environment_position", 0))
	var footprint_height: int = int(dec_data.get("footprint_height", 0))
	var wall_margins: Vector4i = dec_data.get("wall_margins", Vector4i(0, 0, 0, 0))
	var is_world: bool = _generator._is_world_mode()
	
	if footprint_height <= 0 or footprint_height > size.y:
		footprint_height = size.y
		
	var vertical_offset: int = size.y - footprint_height
	var physical_y: int = grid_pos.y + vertical_offset
	var is_detail: bool = dec_data.get("is_detail", false)
	
	if is_detail:
		p_mode = 1
	
	var target_layer: TileMapLayer = _generator.layer_ground_detail if is_detail else _generator.layer_environment
	var all_walls: bool = true
	var all_floors: bool = true
	
	for dy in range(size.y):
		for dx in range(size.x):
			var check_pos: Vector2i = grid_pos + Vector2i(dx, dy)
			var is_physical: bool = dy >= vertical_offset
			
			if check_pos.x < 0 or check_pos.x >= w or check_pos.y < 0 or check_pos.y >= h:
				return false
				
			var idx: int = check_pos.y * w + check_pos.x
			var tile_val: int = grid[idx]
			
			var is_self: bool = false
			if ignore_root != Vector2i(-1, -1):
				if check_pos.x >= ignore_root.x and check_pos.x < ignore_root.x + size.x and check_pos.y >= ignore_root.y and check_pos.y < ignore_root.y + size.y:
					is_self = true
					
			if not is_self:
				if target_layer and target_layer.get_cell_source_id(check_pos) != -1:
					return false
					
			if is_physical:
				if is_world and tile_val == 3:
					return false
					
				if tile_val != 2:
					all_walls = false
					
				var is_floor: bool = false
				
				if is_world:
					is_floor = (tile_val in [1, 4, 5, 8, 10, 6, 7])
				else:
					is_floor = (tile_val == 1)
					
				if not is_floor:
					all_floors = false
					
				if not is_self:
					for ev in _generator.current_map_events:
						var wrapper = _generator.event_placer.get_wrapper_from_uid(ev.template_uid)
						if wrapper:
							var ev_w: int = wrapper.get("width") if "width" in wrapper else 1
							var ev_h: int = wrapper.get("height") if "height" in wrapper else 1
							var ev_rect: Rect2i = Rect2i(ev.tile, Vector2i(ev_w, ev_h))
							
							if ev_rect.has_point(check_pos):
								return false
								
	if p_mode == 1 and not all_floors:
		return false
		
	if p_mode == 2 and not all_walls:
		return false
		
	if wall_margins != Vector4i(0, 0, 0, 0):
		var clearance_failed: bool = false
		
		if p_mode == 2:
			if wall_margins.x > 0:
				for my in range(grid_pos.y, grid_pos.y + size.y):
					var count_left: int = 0
					var cx: int = grid_pos.x - 1
					while cx >= 0:
						if grid[my * w + cx] == 2:
							count_left += 1
							cx -= 1
						else:
							break
					if count_left <= wall_margins.x:
						clearance_failed = true
						break
						
			if not clearance_failed and wall_margins.y > 0:
				for mx in range(grid_pos.x, grid_pos.x + size.x):
					var count_top: int = 0
					var cy: int = grid_pos.y - 1
					while cy >= 0:
						if grid[cy * w + mx] == 2:
							count_top += 1
							cy -= 1
						else:
							break
					if count_top <= wall_margins.y:
						clearance_failed = true
						break
						
			if not clearance_failed and wall_margins.z > 0:
				for my in range(grid_pos.y, grid_pos.y + size.y):
					var count_right: int = 0
					var cx: int = grid_pos.x + size.x
					while cx < w:
						if grid[my * w + cx] == 2:
							count_right += 1
							cx += 1
						else:
							break
					if count_right <= wall_margins.z:
						clearance_failed = true
						break
						
			if not clearance_failed and wall_margins.w > 0:
				for mx in range(grid_pos.x, grid_pos.x + size.x):
					var count_bottom: int = 0
					var cy: int = grid_pos.y + size.y
					while cy < h:
						if grid[cy * w + mx] == 2:
							count_bottom += 1
							cy += 1
						else:
							break
					if count_bottom <= wall_margins.w:
						clearance_failed = true
						break
						
			if clearance_failed: return false
		else:
			if wall_margins.x > 0:
				for my in range(physical_y, physical_y + footprint_height):
					for mx in range(grid_pos.x - wall_margins.x, grid_pos.x):
						if mx >= 0 and mx < w and my >= 0 and my < h:
							var val: int = grid[my * w + mx]
							if val == 2 or val == 9:
								clearance_failed = true
								break
				if clearance_failed: return false
				
			if not clearance_failed and wall_margins.y > 0:
				for mx in range(grid_pos.x, grid_pos.x + size.x):
					for my in range(physical_y - wall_margins.y, physical_y):
						if mx >= 0 and mx < w and my >= 0 and my < h:
							var val: int = grid[my * w + mx]
							if val == 2 or val == 9:
								clearance_failed = true
								break
				if clearance_failed: return false
				
			if not clearance_failed and wall_margins.z > 0:
				for my in range(physical_y, physical_y + footprint_height):
					for mx in range(grid_pos.x + size.x, grid_pos.x + size.x + wall_margins.z):
						if mx >= 0 and mx < w and my >= 0 and my < h:
							var val: int = grid[my * w + mx]
							if val == 2 or val == 9:
								clearance_failed = true
								break
				if clearance_failed: return false
				
			if not clearance_failed and wall_margins.w > 0:
				for mx in range(grid_pos.x, grid_pos.x + size.x):
					for my in range(physical_y + footprint_height, physical_y + footprint_height + wall_margins.w):
						if mx >= 0 and mx < w and my >= 0 and my < h:
							var val: int = grid[my * w + mx]
							if val == 2 or val == 9:
								clearance_failed = true
								break
				if clearance_failed: return false
				
	if env_pos != 0:
		if not check_environment_position_dynamic(grid_pos, size, env_pos, grid, vertical_offset, w, h):
			return false
			
	return true
