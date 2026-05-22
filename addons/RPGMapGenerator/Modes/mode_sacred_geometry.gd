class_name ModeSacredGeometry
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Sacred Geometry"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width"]


## Generates a map grid based on geometric shapes and cleans up autotile artifacts
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var thick: int = config.get("min_corridor_width", 2)
	
	grid.fill(0)
	
	var center := Vector2i(width / 2, height / 2)
	var max_r := mini(width, height) / 2 - 20
	var ring_count := 4
	
	for i in range(ring_count):
		var r := int(float(max_r) * float(i + 1) / float(ring_count))
		_carve_circle_line(grid, width, height, center.x, center.y, r, thick)
		
	var axis_count := 6
	for i in range(axis_count):
		var angle := float(i) * (TAU / float(axis_count))
		var target := Vector2i(
			center.x + int(cos(angle) * max_r),
			center.y + int(sin(angle) * max_r)
		)
		_carve_line(grid, width, height, center, target, thick)
		
	var node_ring_r := int(float(max_r) * 0.5)
	for i in range(axis_count):
		var angle := float(i) * (TAU / float(axis_count))
		var node_p := Vector2i(
			center.x + int(cos(angle) * node_ring_r),
			center.y + int(sin(angle) * node_ring_r)
		)
		_carve_circle_line(grid, width, height, node_p.x, node_p.y, int(node_ring_r * 0.5), thick)
		
	_carve_circle(grid, width, height, center.x, center.y, thick * 3)
	
	_smooth_grid(grid, width, height)
	
	var result: Array[Rect2i] = [Rect2i(center, Vector2i.ONE)]
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


## Carves a ring line of floor tiles into the grid
func _carve_circle_line(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int, thick: int) -> void:
	for dy in range(-radius - thick, radius + thick + 1):
		for dx in range(-radius - thick, radius + thick + 1):
			var dist_sq := dx * dx + dy * dy
			var r_min := radius - thick
			var r_max := radius + thick
			
			if dist_sq >= r_min * r_min and dist_sq <= r_max * r_max:
				var px := cx + dx
				var py := cy + dy
				if px >= 0 and px < width and py >= 0 and py < height:
					grid[py * width + px] = 1


## Carves a line between two points using interpolation
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2i, p2: Vector2i, thick: int) -> void:
	var start := Vector2(p1)
	var end := Vector2(p2)
	var steps := int(start.distance_to(end) * 2.0) + 1
	
	for i in range(steps + 1):
		var t := float(i) / float(steps) if steps > 0 else 0.0
		var p := start.lerp(end, t)
		_carve_circle(grid, width, height, roundi(p.x), roundi(p.y), thick)


## Smooths the grid to correct autotile errors while preserving geometric forms
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
