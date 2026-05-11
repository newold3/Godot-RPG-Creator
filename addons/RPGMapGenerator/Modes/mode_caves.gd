class_name ModeCaves
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Caves (Cellular)"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["cave_fill_ratio", "cave_smoothing_iterations", "min_corridor_width", "max_corridor_width"]



## Executes the core math logic to generate organic caves using cellular automata
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var is_valid: bool = false
	var attempts: int = 0
	var top_wall_height: int = config.get("top_wall_height", 3)
	var cave_fill_ratio: int = config.get("cave_fill_ratio", 48)
	var cave_smoothing_iterations: int = config.get("cave_smoothing_iterations", 5)
	var min_corridor_width: int = config.get("min_corridor_width", 1)
	var max_corridor_width: int = config.get("max_corridor_width", 2)
	
	while not is_valid and attempts < 10:
		attempts += 1
		grid.fill(0)
		
		for y in range(height):
			for x in range(width):
				var idx: int = y * width + x
				if x < 3 or x > width - 4 or y < 3 + top_wall_height or y > height - 4:
					grid[idx] = 0
				else:
					var current_ratio: int = cave_fill_ratio + (attempts - 1) * 2
					grid[idx] = 1 if randi() % 100 < current_ratio else 0
					
		for iteration in range(cave_smoothing_iterations):
			var temp: PackedByteArray = grid.duplicate()
			for y in range(1, height - 1):
				for x in range(1, width - 1):
					var neighbors: int = 0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if dx == 0 and dy == 0: continue
							if temp[(y + dy) * width + (x + dx)] == 1: neighbors += 1
					grid[y * width + x] = 1 if neighbors > 4 else (0 if neighbors < 4 else temp[y * width + x])
					
		var visited: PackedByteArray = PackedByteArray()
		visited.resize(width * height)
		visited.fill(0)
		var regions: Array[Array] = []
		
		for y in range(height):
			for x in range(width):
				var idx: int = y * width + x
				if grid[idx] == 1 and visited[idx] == 0:
					var stack: Array[Vector2i] = [Vector2i(x, y)]
					var current_region: Array[Vector2i] = []
					
					while stack.size() > 0:
						var curr: Vector2i = stack.pop_back()
						var cidx: int = curr.y * width + curr.x
						
						if visited[cidx] == 1: continue
						visited[cidx] = 1
						current_region.append(curr)
						
						if curr.y > 0 and grid[cidx - width] == 1 and visited[cidx - width] == 0: stack.append(Vector2i(curr.x, curr.y - 1))
						if curr.y < height - 1 and grid[cidx + width] == 1 and visited[cidx + width] == 0: stack.append(Vector2i(curr.x, curr.y + 1))
						if curr.x > 0 and grid[cidx - 1] == 1 and visited[cidx - 1] == 0: stack.append(Vector2i(curr.x - 1, curr.y))
						if curr.x < width - 1 and grid[cidx + 1] == 1 and visited[cidx + 1] == 0: stack.append(Vector2i(curr.x + 1, curr.y))
						
					regions.append(current_region)
					
		if regions.size() > 0:
			regions.sort_custom(func(a: Array, b: Array): return a.size() > b.size())
			
			if regions[0].size() > 20:
				is_valid = true
				var main_region: Array[Vector2i] = regions[0]
				
				for i in range(1, regions.size()):
					var sub_region: Array[Vector2i] = regions[i]
					
					if sub_region.size() < 10:
						for cell in sub_region:
							grid[cell.y * width + cell.x] = 0
						continue
						
					var p1: Vector2i = sub_region[randi() % sub_region.size()]
					var p2: Vector2i = main_region[randi() % main_region.size()]
					var min_dist: float = 999999.0
					
					for _s in range(min(15, sub_region.size())):
						var c1: Vector2i = sub_region[randi() % sub_region.size()]
						for _m in range(min(15, main_region.size())):
							var c2: Vector2i = main_region[randi() % main_region.size()]
							var dist: float = Vector2(c1).distance_squared_to(Vector2(c2))
							if dist < min_dist:
								min_dist = dist
								p1 = c1
								p2 = c2
								
					var c_width: int = randi_range(min_corridor_width, max_corridor_width)
					carve_corridor(p1, p2, c_width, width, height, grid)
					main_region.append_array(sub_region)
					
		for y in range(height):
			for x in range(width):
				if x < 3 or x > width - 4 or y < 3 + top_wall_height or y > height - 4:
					grid[y * width + x] = 0
					
	return []
#endregion
