class_name ModeSpiderCaves
extends BaseMapMode


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Spider Caves"


## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return [
		"min_corridor_width",
		"max_corridor_width"
	]


## Executes the core math logic to carve a web-like cave network with concentric rings and radial tunnels
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_c := config.get("min_corridor_width", 4)
	var max_c := config.get("max_corridor_width", 10)
	
	var center := Vector2i(width / 2, height / 2)
	var arm_count := 8
	var ring_count := 5
	var max_radius := mini(width, height) / 2 - 16
	
	var web_nodes: Array[Array] = []
	
	for r in range(ring_count):
		var ring_nodes: Array[Vector2i] = []
		var radius := float(r + 1) * (float(max_radius) / float(ring_count))
		
		for a in range(arm_count):
			var angle := float(a) * (TAU / float(arm_count)) + randf_range(-0.12, 0.12)
			var node_pos := Vector2i(
				center.x + int(cos(angle) * radius),
				center.y + int(sin(angle) * radius)
			)
			node_pos.x = clampi(node_pos.x, 8, width - 9)
			node_pos.y = clampi(node_pos.y, 8, height - 9)
			ring_nodes.append(node_pos)
			
		web_nodes.append(ring_nodes)
		
	carve_circle(grid, width, height, center.x, center.y, randi_range(14, 24))
	
	for a in range(arm_count):
		var prev_point := center
		for r in range(ring_count):
			var curr_point: Vector2i = web_nodes[r][a]
			carve_path(grid, width, height, prev_point, curr_point, min_c, max_c)
			prev_point = curr_point
			
	for r in range(ring_count):
		var thickness_factor := lerpf(float(max_c), float(min_c), float(r) / float(ring_count))
		var current_min := maxi(2, int(thickness_factor) - 1)
		var current_max := maxi(3, int(thickness_factor) + 1)
		
		for a in range(arm_count):
			var p1: Vector2i = web_nodes[r][a]
			var p2: Vector2i = web_nodes[r][(a + 1) % arm_count]
			carve_path(grid, width, height, p1, p2, current_min, current_max)
			
	for r in range(ring_count):
		for a in range(arm_count):
			var p: Vector2i = web_nodes[r][a]
			var node_radius := randi_range(6, 14) - r
			if node_radius > 3:
				carve_circle(grid, width, height, p.x, p.y, node_radius)
				
	smooth_map(grid, width, height, 3)
	_smooth_grid(grid, width, height)
	
	var result: Array[Rect2i] = []
	result.append(Rect2i(center, Vector2i.ONE))
	
	if web_nodes.size() > 0 and web_nodes[0].size() > 0:
		result.append(Rect2i(web_nodes[ring_count - 1][0], Vector2i.ONE))
		
	return result


## Carves an organic path between two points with variable thickness
func carve_path(grid: PackedByteArray, width: int, height: int, start: Vector2i, end: Vector2i, min_c: int, max_c: int) -> void:
	var current := Vector2(start)
	var target_thickness = randf_range(min_c, max_c)
	var thickness = target_thickness
	
	while current.distance_to(end) > 1.5:
		if randf() < 0.12:
			target_thickness = randf_range(min_c, max_c)
			
		thickness = lerpf(thickness, target_thickness, 0.15)
		
		var dir := (Vector2(end) - current).normalized()
		dir += Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		dir = dir.normalized()
		
		var next_pos := current + dir * 1.5
		_carve_line(grid, width, height, current, next_pos, int(thickness))
		current = next_pos


## Carves a dense line of circles between two points to prevent any gaps
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2, p2: Vector2, thick: int) -> void:
	var dist := p1.distance_to(p2)
	var steps := int(dist * 2.0) + 1
	
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := p1.lerp(p2, t)
		carve_circle(grid, width, height, roundi(p.x), roundi(p.y), thick)


## Carves a circular brush pattern into the map byte grid
func carve_circle(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
				
			var px := cx + dx
			var py := cy + dy
			
			if px < 0 or px >= width:
				continue
			if py < 0 or py >= height:
				continue
				
			grid[py * width + px] = 1


## Smooths out raw artifact patterns using local neighbor thresholds
func smooth_map(grid: PackedByteArray, width: int, height: int, iterations: int) -> void:
	for n in range(iterations):
		var copy: PackedByteArray = grid.duplicate()
		
		for y in range(1, height - 1):
			var offset := y * width
			for x in range(1, width - 1):
				var walls := 0
				
				for dy in range(-1, 2):
					var inner_offset := (y + dy) * width
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						if copy[inner_offset + (x + dx)] == 0:
							walls += 1
							
				var idx := offset + x
				if walls <= 2:
					grid[idx] = 1
				elif walls >= 7:
					grid[idx] = 0


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
