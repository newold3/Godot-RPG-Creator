class_name ModeLevyFlight
extends BaseMapMode


## Returns the unique name of this map generation mode
func get_mode_name() -> String:
	return "Lévy Flight"


## Returns the configuration properties used by this mode
func get_used_properties() -> Array[String]:
	return ["min_corridor_width", "max_corridor_width"]


## Generates a map grid using an orthogonal Lévy Flight algorithm to ensure clean wall autotiling
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_c: int = config.get("min_corridor_width", 2)
	var max_c: int = config.get("max_corridor_width", 4)
	
	grid.fill(0)
	
	var current := Vector2(roundf(width / 2.0), roundf(height / 2.0))
	var steps := 300
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for i in range(steps):
		var dir: Vector2 = dirs[randi() % 4]
		var length := 0.0
		
		if randf() < 0.08:
			length = float(randi_range(12, 35))
		else:
			length = float(randi_range(2, 6))
			
		var target := current + dir * length
		target.x = roundf(clampf(target.x, 6.0, float(width - 7)))
		target.y = roundf(clampf(target.y, 6.0, float(height - 7)))
		
		var thick := randi_range(min_c, max_c)
		if length > 10.0:
			_carve_line(grid, width, height, current, target, thick)
		else:
			_carve_cluster(grid, width, height, target, thick * 2)
			_carve_line(grid, width, height, current, target, thick)
			
		current = target
		
	return []


## Carves a straight line between two points using a square brush
func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2, p2: Vector2, thick: int) -> void:
	var x1 := roundi(p1.x)
	var y1 := roundi(p1.y)
	var x2 := roundi(p2.x)
	var y2 := roundi(p2.y)
	
	var dx := abs(x2 - x1)
	var dy := abs(y2 - y1)
	var sx := 1 if x1 < x2 else -1
	var sy := 1 if y1 < y2 else -1
	var err = dx - dy
	
	while true:
		_carve_square(grid, width, height, x1, y1, thick)
		
		if x1 == x2 and y1 == y2:
			break
			
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x1 += sx
		if e2 < dx:
			err += dx
			y1 += sy


## Carves a cluster of overlapping square shapes around a position
func _carve_cluster(grid: PackedByteArray, width: int, height: int, pos: Vector2, radius: int) -> void:
	for i in range(5):
		var ox := randi_range(-radius, radius)
		var oy := randi_range(-radius, radius)
		var r := randi_range(2, radius)
		
		_carve_square(grid, width, height, roundi(pos.x) + ox, roundi(pos.y) + oy, r)


## Carves a perfect square of floor tiles to eliminate diagonal aliasing
func _carve_square(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var px := cx + dx
			var py := cy + dy
			
			if px >= 0 and px < width and py >= 0 and py < height:
				grid[py * width + px] = 1
