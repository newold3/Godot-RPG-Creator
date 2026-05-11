class_name BaseMapMode
extends RefCounted


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Base Mode"



## Returns an array of core property names that this specific mode uses (used to dynamically hide/show exports)
func get_used_properties() -> Array[String]:
	return []



## Executes the core math logic to carve the grid based on the specific algorithm. Must be overridden.
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	push_error("BaseMapMode: generate() must be overridden by child classes.")
	return []
#endregion


#region COMMON HELPERS


## Carves an L-shaped corridor of a specific width into the grid, useful for connecting rooms or areas
func carve_corridor(p1: Vector2i, p2: Vector2i, width: int, map_width: int, map_height: int, grid: PackedByteArray) -> void:
	var start_x: int = min(p1.x, p2.x)
	var end_x: int = max(p1.x, p2.x)
	var start_y: int = min(p1.y, p2.y)
	var end_y: int = max(p1.y, p2.y)
	
	for x in range(start_x, end_x + 1):
		for w in range(width):
			var y: int = p1.y + w
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				grid[y * map_width + x] = 1
				
	for y in range(start_y, end_y + 1):
		for w in range(width):
			var x: int = p2.x + w
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				grid[y * map_width + x] = 1



## Performs a flood fill to find the interior space of existing walls and fill it with floors
func derive_floor_from_walls(grid: PackedByteArray, map_width: int, map_height: int) -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(map_width * map_height)
	visited.fill(0)
	var stack: Array[Vector2i] = []
	
	for x in range(map_width):
		if grid[x] != 2: stack.append(Vector2i(x, 0))
		if grid[(map_height - 1) * map_width + x] != 2: stack.append(Vector2i(x, map_height - 1))
		
	for y in range(map_height):
		if grid[y * map_width] != 2: stack.append(Vector2i(0, y))
		if grid[y * map_width + map_width - 1] != 2: stack.append(Vector2i(map_width - 1, y))
		
	while stack.size() > 0:
		var curr: Vector2i = stack.pop_back()
		var idx: int = curr.y * map_width + curr.x
		if visited[idx] == 1: continue
		visited[idx] = 1
		
		if curr.y > 0 and grid[idx - map_width] != 2 and visited[idx - map_width] == 0:
			stack.append(Vector2i(curr.x, curr.y - 1))
		if curr.y < map_height - 1 and grid[idx + map_width] != 2 and visited[idx + map_width] == 0:
			stack.append(Vector2i(curr.x, curr.y + 1))
		if curr.x > 0 and grid[idx - 1] != 2 and visited[idx - 1] == 0:
			stack.append(Vector2i(curr.x - 1, curr.y))
		if curr.x < map_width - 1 and grid[idx + 1] != 2 and visited[idx + 1] == 0:
			stack.append(Vector2i(curr.x + 1, curr.y))
			
	for i in range(grid.size()):
		if visited[i] == 0 and grid[i] != 2:
			grid[i] = 1
#endregion
