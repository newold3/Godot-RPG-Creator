class_name ModeWorldMap
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "World Map (Noise)"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["terrain_land", "terrain_water", "terrain_snow", "terrain_desert", "terrain_volcano", "terrain_swamp", "terrain_mountain", "terrain_tree", "world_max_biomes", "use_random_noise", "world_noise"]



## Executes the core math logic to carve continents and biomes into the grid
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	grid.fill(3)
	var noise: FastNoiseLite = config.get("world_noise")
	var use_random_noise: bool = config.get("use_random_noise", false)
	
	var has_snow: bool = config.get("terrain_snow", -1) != -1
	var has_desert: bool = config.get("terrain_desert", -1) != -1
	var has_volcano: bool = config.get("terrain_volcano", -1) != -1
	var has_swamp: bool = config.get("terrain_swamp", -1) != -1
	var has_mountain: bool = config.get("terrain_mountain", -1) != -1
	var has_tree: bool = config.get("terrain_tree", -1) != -1
	
	if use_random_noise or not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.015
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		noise.fractal_lacunarity = 2.0
		noise.fractal_gain = 0.5
		
	for y in range(height):
		for x in range(width):
			var dist_x: float = min(x, width - x)
			var dist_y: float = min(y, height - y)
			var min_dist: float = min(dist_x, dist_y)
			var edge_mask: float = 0.0
			
			if min_dist < 15.0:
				var f: float = (15.0 - min_dist) / 15.0
				edge_mask = f * f * 1.5
				
			var nx: float = noise.get_noise_2d(x, y)
			
			if nx - edge_mask > 0.05:
				grid[y * width + x] = 1
				
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)
	var islands: Array[Array] = []
	
	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			
			if grid[idx] == 1 and visited[idx] == 0:
				var stack: Array[Vector2i] = [Vector2i(x, y)]
				var island_cells: Array[int] = []
				
				while stack.size() > 0:
					var curr: Vector2i = stack.pop_back()
					var cidx: int = curr.y * width + curr.x
					
					if visited[cidx] == 1: 
						continue
						
					visited[cidx] = 1
					island_cells.append(cidx)
					
					if curr.y > 0 and grid[cidx - width] == 1 and visited[cidx - width] == 0:
						stack.append(Vector2i(curr.x, curr.y - 1))
					if curr.y < height - 1 and grid[cidx + width] == 1 and visited[cidx + width] == 0:
						stack.append(Vector2i(curr.x, curr.y + 1))
					if curr.x > 0 and grid[cidx - 1] == 1 and visited[cidx - 1] == 0:
						stack.append(Vector2i(curr.x - 1, curr.y))
					if curr.x < width - 1 and grid[cidx + 1] == 1 and visited[cidx + 1] == 0:
						stack.append(Vector2i(curr.x + 1, curr.y))
						
				if island_cells.size() < 10:
					for cell_idx in island_cells:
						grid[cell_idx] = 3
				else:
					islands.append(island_cells)
					
	var extra_biomes: Array[int] = []
	
	if has_snow: extra_biomes.append(4)
	if has_desert: extra_biomes.append(5)
	if has_volcano: extra_biomes.append(8)
	if has_swamp: extra_biomes.append(10)
	
	extra_biomes.shuffle()
	
	var max_b: int = config.get("world_max_biomes", 3)
	var active_biomes: Array[int] = [1]
	
	for i in range(min(max_b - 1, extra_biomes.size())):
		active_biomes.append(extra_biomes[i])
		
	var biome_weights: Dictionary = {
		1: 100,
		4: 35,
		5: 45,
		8: 10,
		10: 25
	}
	
	var total_weight: int = 0
	
	for b in active_biomes:
		total_weight += biome_weights[b]
		
	for island in islands:
		var roll: int = randi() % total_weight
		var current_weight: int = 0
		var base_terrain: int = 1
		
		for b in active_biomes:
			current_weight += biome_weights[b]
			if roll < current_weight:
				base_terrain = b
				break
				
		for cell_idx in island:
			var cy: int = cell_idx / width
			var cx: int = cell_idx % width
			var feat_noise: float = noise.get_noise_2d(cx * 2.5, cy * 2.5)
			
			grid[cell_idx] = base_terrain
			
			if base_terrain == 1:
				if has_mountain and feat_noise > 0.3:
					grid[cell_idx] = 6
				elif has_tree and feat_noise < -0.15:
					grid[cell_idx] = 7
					
			elif base_terrain == 4:
				if has_mountain and feat_noise > 0.4:
					grid[cell_idx] = 6
				elif has_tree and feat_noise < -0.2:
					grid[cell_idx] = 7
					
			elif base_terrain == 5:
				if has_mountain and feat_noise > 0.35:
					grid[cell_idx] = 6
				elif feat_noise < -0.25:
					grid[cell_idx] = 1
					
			elif base_terrain == 8:
				if has_mountain and feat_noise > 0.2:
					grid[cell_idx] = 6
					
			elif base_terrain == 10:
				if has_tree and feat_noise < 0.1:
					grid[cell_idx] = 7
					
	return []
#endregion
