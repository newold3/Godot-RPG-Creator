@tool
class_name MapTerrainProcessor
extends RefCounted


#region VARIABLES
var _generator: Node
#endregion



## Initializes the processor with a reference to the main generator to access dimensions and settings
func _init(generator: Node) -> void:
	_generator = generator



## Precalculates all bitmask combinations and stores their individual TileSet probabilities
func build_terrain_cache(tm: TileMapLayer, t_id: int) -> Dictionary:
	var cache: Dictionary = {}
	
	if not tm or not tm.tile_set or t_id == -1:
		return cache
		
	var ts: TileSet = tm.tile_set
	
	for source_idx in ts.get_source_count():
		var source_id: int = ts.get_source_id(source_idx)
		var source: TileSetSource = ts.get_source(source_id)
		
		if source is TileSetAtlasSource:
			for tile_idx in source.get_tiles_count():
				var coord: Vector2i = source.get_tile_id(tile_idx)
				var data: TileData = source.get_tile_data(coord, 0)
				
				if data and data.terrain_set == _generator.terrain_set and data.terrain == t_id:
					var mask: int = 0
					
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == t_id: mask |= 1
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == t_id: mask |= 2
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == t_id: mask |= 4
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == t_id: mask |= 8
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == t_id: mask |= 16
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == t_id: mask |= 32
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == t_id: mask |= 64
					if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == t_id: mask |= 128
					
					if not cache.has(mask):
						cache[mask] = []
						
					cache[mask].append({"source": source_id, "coord": coord, "prob": data.probability})
					
	if cache.is_empty():
		return cache
		
	var base_keys: Array = cache.keys()
	
	for m in range(256):
		if not cache.has(m):
			var best_mask: int = -1
			var best_score: int = -1
			
			for k in base_keys:
				var score: int = 0
				
				for i in range(8):
					var bit: int = 1 << i
					
					if (m & bit) == (k & bit):
						if bit == 1 or bit == 4 or bit == 16 or bit == 64:
							score += 2
						else:
							score += 1
							
				if score > best_score:
					best_score = score
					best_mask = k
					
			cache[m] = cache[best_mask]
			
	return cache



## Checks if a cell inside the flat array matches a specific terrain value
func check_grid(grid: PackedByteArray, x: int, y: int, targets: Array[int]) -> bool:
	if x >= 0 and x < _generator.map_width and y >= 0 and y < _generator.map_height:
		return grid[y * _generator.map_width + x] in targets
		
	return false



## Generates the bitmask for a coordinate analyzing neighbors
func get_bitmask(grid: PackedByteArray, x: int, y: int, targets: Array[int]) -> int:
	var mask: int = 0
	var n: bool = check_grid(grid, x, y - 1, targets)
	var s: bool = check_grid(grid, x, y + 1, targets)
	var w: bool = check_grid(grid, x - 1, y, targets)
	var e: bool = check_grid(grid, x + 1, y, targets)
	
	if e: mask |= 1
	if s and e and check_grid(grid, x + 1, y + 1, targets): mask |= 2
	if s: mask |= 4
	if s and w and check_grid(grid, x - 1, y + 1, targets): mask |= 8
	if w: mask |= 16
	if n and w and check_grid(grid, x - 1, y - 1, targets): mask |= 32
	if n: mask |= 64
	if n and e and check_grid(grid, x + 1, y - 1, targets): mask |= 128
	
	return mask



## Resolves a bitmask into atlas coordinates using weighted random selection
func resolve_tile(mask: int, cache: Dictionary) -> Dictionary:
	if cache.is_empty() or not cache.has(mask):
		return {"source": -1, "coord": Vector2i(-1, -1)}
		
	var options: Array = cache[mask]
	var total_weight: float = 0.0
	
	for opt in options:
		total_weight += opt["prob"]
		
	var roll: float = randf() * total_weight
	var current_weight: float = 0.0
	
	for opt in options:
		current_weight += opt["prob"]
		if roll <= current_weight:
			return opt
			
	return options[0]



## Extracts specific terrain cells from the grid into a ready-to-draw package
func package_terrain_layer(grid: PackedByteArray, self_targets: Array[int], neighbor_targets: Array[int], cache: Dictionary) -> Dictionary:
	var out_pos: Array[Vector2i] = []
	var out_src: Array[int] = []
	var out_crd: Array[Vector2i] = []
	
	for y in range(_generator.map_height):
		for x in range(_generator.map_width):
			if grid[y * _generator.map_width + x] in self_targets:
				var mask: int = get_bitmask(grid, x, y, neighbor_targets)
				var tile: Dictionary = resolve_tile(mask, cache)
				
				out_pos.append(Vector2i(x, y))
				out_src.append(tile["source"])
				out_crd.append(tile["coord"])
				
	return {"pos": out_pos, "src": out_src, "crd": out_crd}



## Packages a single specific tile into an array bypassing bitmask calculations
func package_single_tile_layer(grid: PackedByteArray, self_targets: Array[int], tile_data: Dictionary) -> Dictionary:
	var out_pos: Array[Vector2i] = []
	var out_src: Array[int] = []
	var out_crd: Array[Vector2i] = []
	var s_id: int = tile_data.get("atlas_id", -1)
	var c_id: Vector2i = tile_data.get("tile_id", Vector2i(-1, -1))
	
	if s_id != -1 and c_id != Vector2i(-1, -1):
		for y in range(_generator.map_height):
			for x in range(_generator.map_width):
				if grid[y * _generator.map_width + x] in self_targets:
					out_pos.append(Vector2i(x, y))
					out_src.append(s_id)
					out_crd.append(c_id)
					
	return {"pos": out_pos, "src": out_src, "crd": out_crd}



## Scans floor cells and generates shadows if there is a wall to their left
func package_shadow_layer(grid: PackedByteArray) -> Dictionary:
	var out_pos: Array[Vector2i] = []
	var out_src: Array[int] = []
	var out_crd: Array[Vector2i] = []
	
	var s_id: int = _generator.large_tile_shadow.get("atlas_id", -1)
	var s_crd: Vector2i = _generator.large_tile_shadow.get("tile_id", Vector2i(-1, -1))
	var sm_id: int = _generator.small_tile_shadow.get("atlas_id", -1)
	var sm_crd: Vector2i = _generator.small_tile_shadow.get("tile_id", Vector2i(-1, -1))
	
	if s_id == -1 or s_crd == Vector2i(-1, -1):
		return {"pos": out_pos, "src": out_src, "crd": out_crd}
		
	for y in range(_generator.map_height):
		for x in range(1, _generator.map_width + 1):
			var current_val: int = 0
			
			if x < _generator.map_width:
				current_val = grid[y * _generator.map_width + x]
				
			if current_val in [0, 1]:
				var wall_x: int = x - 1
				
				if grid[y * _generator.map_width + wall_x] in [2, 9]:
					var wall_above: bool = false
					
					if y > 0 and grid[(y - 1) * _generator.map_width + wall_x] in [2, 9]:
						wall_above = true
						
					var wall_below: bool = false
					var wall_below_can_draw: bool = false
					
					if y + 1 < _generator.map_height:
						if grid[(y + 1) * _generator.map_width + wall_x] in [2, 9]:
							wall_below = true
							var target_below_val: int = 0
							
							if x < _generator.map_width:
								target_below_val = grid[(y + 1) * _generator.map_width + x]
								
							if target_below_val in [0, 1]:
								wall_below_can_draw = true
								
					var draw_shadow: bool = false
					var use_small: bool = false
					
					if wall_below and wall_above:
						draw_shadow = true
						use_small = false
					elif wall_below and not wall_below_can_draw and not wall_above:
						draw_shadow = true
						use_small = true
					elif not wall_below and not wall_above:
						draw_shadow = true
						use_small = true
					elif not wall_below and wall_above:
						draw_shadow = true
						use_small = false
						
					if draw_shadow:
						out_pos.append(Vector2i(x, y))
						
						if use_small and sm_id != -1 and sm_crd != Vector2i(-1, -1):
							out_src.append(sm_id)
							out_crd.append(sm_crd)
						else:
							out_src.append(s_id)
							out_crd.append(s_crd)
							
	return {"pos": out_pos, "src": out_src, "crd": out_crd}
