class_name ModeVoronoiTectonic
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Voronoi Tectonic"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width", "max_corridor_width"]


## Generates a map grid based on a Voronoi diagram and cleans up autotile artifacts
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_w: int = config.get("min_corridor_width", 2)
	var max_w: int = config.get("max_corridor_width", 3)
	
	grid.fill(0)
	
	var points: Array[Vector2i] = []
	var point_count := 30
	for i in range(point_count):
		points.append(Vector2i(randi_range(10, width - 11), randi_range(10, height - 11)))
		
	var cell_ids := PackedInt32Array()
	cell_ids.resize(width * height)
	
	for y in range(height):
		var row_offset := y * width
		for x in range(width):
			var min_dist := 9999999.0
			var nearest_idx := 0
			
			for i in range(point_count):
				var dx := x - points[i].x
				var dy := y - points[i].y
				var dsq := dx * dx + dy * dy
				if dsq < min_dist:
					min_dist = dsq
					nearest_idx = i
					
			cell_ids[row_offset + x] = nearest_idx
			
	for y in range(1, height - 1):
		var row_offset := y * width
		for x in range(1, width - 1):
			var current_id := cell_ids[row_offset + x]
			
			if current_id != cell_ids[row_offset + x + 1] or current_id != cell_ids[(y + 1) * width + x]:
				var thickness := randi_range(min_w, max_w)
				_carve_circle(grid, width, height, x, y, thickness)
				
	_smooth_grid(grid, width, height)
	
	var result: Array[Rect2i] = []
	if points.size() >= 2:
		result.append(Rect2i(points[0], Vector2i.ONE))
		result.append(Rect2i(points[1], Vector2i.ONE))
		
	return result


## Carves a circle of floor tiles into the byte array grid
func _carve_circle(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
				
			var px := cx + dx
			var py := cy + dy
			
			if px >= 0 and px < width and py >= 0 and py < height:
				grid[py * width + px] = 1


## Smooths the grid to correct autotile errors while preserving shapes
func _smooth_grid(grid: PackedByteArray, width: int, height: int) -> void:
	for iteration in range(3):
		var temp := grid.duplicate()
		
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var idx := y * width + x
				
				if temp[idx] == 1:
					var neighbors := 0
					if temp[idx - 1] == 0: neighbors += 1
					if temp[idx + 1] == 0: neighbors += 1
					if temp[idx - width] == 0: neighbors += 1
					if temp[idx + width] == 0: neighbors += 1
					
					if neighbors >= 3:
						grid[idx] = 0
				
				elif temp[idx] == 0:
					var neighbors := 0
					if temp[idx - 1] == 1: neighbors += 1
					if temp[idx + 1] == 1: neighbors += 1
					if temp[idx - width] == 1: neighbors += 1
					if temp[idx + width] == 1: neighbors += 1
					
					if neighbors >= 3:
						grid[idx] = 1
