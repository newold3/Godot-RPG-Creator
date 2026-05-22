class_name ModeSpaceColonization
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Space Colonization"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width"]


## Generates a map grid using the space colonization algorithm and cleans up autotile artifacts
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var thick: int = config.get("min_corridor_width", 2)
	
	grid.fill(0)
	
	var attractors: Array[Vector2] = []
	var num_attractors := 150
	for i in range(num_attractors):
		attractors.append(Vector2(randf_range(10.0, float(width - 11)), randf_range(10.0, float(height - 11))))
		
	var nodes: Array[Vector2] = [Vector2(width / 2.0, height / 2.0)]
	var max_dist := 35.0
	var min_dist := 4.0
	var grow_step := 3.0
	
	var iterations := 40
	for iter in range(iterations):
		if attractors.is_empty():
			break
			
		var node_dirs: Dictionary = {}
		var node_counts: Dictionary = {}
		var to_remove: Array[int] = []
		
		for i in range(attractors.size() - 1, -1, -1):
			var attr := attractors[i]
			var closest_idx := -1
			var closest_dist := 999999.0
			
			for j in range(nodes.size()):
				var d := nodes[j].distance_to(attr)
				if d < closest_dist:
					closest_dist = d
					closest_idx = j
					
			if closest_idx != -1:
				if closest_dist < min_dist:
					if not to_remove.has(i):
						to_remove.append(i)
				elif closest_dist < max_dist:
					var dir := (attr - nodes[closest_idx]).normalized()
					if not node_dirs.has(closest_idx):
						node_dirs[closest_idx] = Vector2.ZERO
						node_counts[closest_idx] = 0
					node_dirs[closest_idx] += dir
					node_counts[closest_idx] += 1
					
		to_remove.sort()
		to_remove.reverse()
		for idx in to_remove:
			attractors.remove_at(idx)
			
		var new_nodes: Array[Vector2] = []
		for idx in node_dirs:
			var avg_dir: Vector2 = node_dirs[idx] / float(node_counts[idx])
			var next_pos := nodes[idx] + avg_dir.normalized() * grow_step
			
			next_pos.x = clampf(next_pos.x, 5.0, float(width - 6))
			next_pos.y = clampf(next_pos.y, 5.0, float(height - 6))
			
			new_nodes.append(next_pos)
			_carve_line(grid, width, height, nodes[idx], next_pos, thick)
			
		if new_nodes.is_empty() and not attractors.is_empty():
			var random_attr := attractors.pick_random()
			var closest_node := nodes[0]
			var min_d := 999999.0
			for n in nodes:
				var d := n.distance_to(random_attr)
				if d < min_d:
					min_d = d
					closest_node = n
			var next_pos = closest_node + (random_attr - closest_node).normalized() * grow_step
			new_nodes.append(next_pos)
			_carve_line(grid, width, height, closest_node, next_pos, thick)
			
		nodes.append_array(new_nodes)
		
	_smooth_grid(grid, width, height)
	
	return []


## Carves a dense line of circles between two points to prevent any gaps
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2, p2: Vector2, thick: int) -> void:
	var steps := int(p1.distance_to(p2) * 2.0) + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps) if steps > 0 else 0.0
		var p := p1.lerp(p2, t)
		_carve_circle(grid, width, height, roundi(p.x), roundi(p.y), thick)


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
