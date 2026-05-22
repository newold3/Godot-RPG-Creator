class_name ModeMyceliumNetwork
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Mycelium Network"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width", "max_corridor_width"]


## Generates a map grid based on a mycelium branching network ensuring clean wall autotiling
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_w: int = config.get("min_corridor_width", 2)
	var max_w: int = config.get("max_corridor_width", 4)
	
	grid.fill(0)
	
	var spores: Array[Vector2i] = []
	for i in range(12):
		spores.append(Vector2i(randi_range(20, width - 21), randi_range(20, height - 21)))
		
	# Draw spores
	for spore in spores:
		_carve_circle(grid, width, height, spore.x, spore.y, randi_range(6, 14))
		
	# Draw branching connections
	for i in range(spores.size()):
		for j in range(i + 1, spores.size()):
			if randf() < 0.45:
				_carve_mycelium_branch(grid, width, height, spores[i], spores[j], min_w, max_w)
				
	# Apply morphological smoothing to correct autotile artifacts without losing shape
	_smooth_grid(grid, width, height)
	
	var result: Array[Rect2i] = []
	if not spores.is_empty():
		result.append(Rect2i(spores[0], Vector2i.ONE))
		result.append(Rect2i(spores[-1], Vector2i.ONE))
		
	return result


## Carves a robust branch between two spores using overlapping segments to avoid gaps
func _carve_mycelium_branch(grid: PackedByteArray, width: int, height: int, start: Vector2i, end: Vector2i, min_w: int, max_w: int) -> void:
	var current := Vector2(start)
	var next_pos := current
	var thickness := float(min_w)
	
	while current.distance_to(end) > 2.0:
		var dir := (Vector2(end) - current).normalized()
		# Add noise to the direction for organic wobbly paths
		dir += Vector2(randf_range(-0.45, 0.45), randf_range(-0.45, 0.45))
		dir = dir.normalized()
		
		# Move to a new position
		next_pos = current + dir * randf_range(1.0, 3.0)
		
		if randf() < 0.08:
			thickness = randf_range(min_w, max_w)
			
		# Draw a solid, robust segment between current and next_pos
		_carve_line(grid, width, height, current, next_pos, int(thickness))
		
		# Update current position
		current = next_pos


## Carves a solid line of circles between two points to prevent any gaps
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2, p2: Vector2, thick: int) -> void:
	var dist := p1.distance_to(p2)
	# Iterate along the line with sufficient density to fill all gaps
	var steps := int(dist * 2.0) + 1
	
	for i in range(steps + 1):
		var t := float(i) / float(steps)
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


## Smooths the grid to correct autotile errors while preserving the overall form
func _smooth_grid(grid: PackedByteArray, width: int, height: int) -> void:
	# Run a targeted smoothing CA to fill isolated gaps without altering shape much
	for iteration in range(3):
		var temp := grid.duplicate()
		
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var idx := y * width + x
				
				# Fill 1x1 floor gaps
				if temp[idx] == 1:
					var neighbors := 0
					if temp[idx - 1] == 0: neighbors += 1
					if temp[idx + 1] == 0: neighbors += 1
					if temp[idx - width] == 0: neighbors += 1
					if temp[idx + width] == 0: neighbors += 1
					
					if neighbors >= 3:
						grid[idx] = 0
				
				# Fill 1x1 wall protrusions
				elif temp[idx] == 0:
					var neighbors := 0
					if temp[idx - 1] == 1: neighbors += 1
					if temp[idx + 1] == 1: neighbors += 1
					if temp[idx - width] == 1: neighbors += 1
					if temp[idx + width] == 1: neighbors += 1
					
					if neighbors >= 3:
						grid[idx] = 1
