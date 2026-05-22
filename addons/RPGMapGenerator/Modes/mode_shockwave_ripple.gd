class_name ModeShockwaveRipple
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Shockwave Ripple"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width"]


## Generates a map grid based on a wave ripple pattern and cleans up autotile artifacts
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var thick: int = config.get("min_corridor_width", 2)
	
	grid.fill(0)
	
	var centers: Array[Vector2i] = []
	var center_count := randi_range(3, 6)
	for i in range(center_count):
		centers.append(Vector2i(randi_range(20, width - 21), randi_range(20, height - 21)))
		
	for y in range(5, height - 5):
		var offset := y * width
		for x in range(5, width - 5):
			var is_floor := false
			
			for c in centers:
				var dx := x - c.x
				var dy := y - c.y
				var dist := sqrt(float(dx * dx + dy * dy))
				
				var wave := int(dist) % 18
				if wave >= 0 and wave < thick + 1:
					var angle := atan2(float(dy), float(dx))
					var opening := sin(angle * 5.0)
					if opening > -0.7:
						is_floor = true
						break
						
			if is_floor:
				grid[offset + x] = 1
				
	for i in range(centers.size() - 1):
		_carve_line(grid, width, height, centers[i], centers[i + 1], thick)
		
	_smooth_grid(grid, width, height)
	
	return []


## Carves a line between two positions using a dense step count to avoid gaps
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2i, p2: Vector2i, thick: int) -> void:
	var start := Vector2(p1)
	var end := Vector2(p2)
	var steps := int(start.distance_to(end) * 2.0) + 1
	
	for i in range(steps + 1):
		var t := float(i) / float(steps) if steps > 0 else 0.0
		var p := start.lerp(end, t)
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


## Smooths the grid to correct autotile errors while preserving ripple shapes
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
