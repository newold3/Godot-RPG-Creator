class_name ModeLSystem
extends BaseMapMode


func get_mode_name() -> String:
	return "L-System Structural"


func get_used_properties() -> Array[String]:
	return ["min_corridor_width"]


func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var thick: int = config.get("min_corridor_width", 2)
	
	grid.fill(0)
	
	var center := Vector2i(width / 2, height / 2)
	_recursive_branch(grid, width, height, center, Vector2i(0, -1), 5, float(mini(width, height)) * 0.22, thick)
	
	return []


func _recursive_branch(grid: PackedByteArray, width: int, height: int, start: Vector2i, dir: Vector2i, depth: int, length: float, thick: int) -> void:
	if depth <= 0 or length < 2.0:
		return
		
	var end := start + Vector2i(int(float(dir.x) * length), int(float(dir.y) * length))
	end.x = clampi(end.x, 5, width - 6)
	end.y = clampi(end.y, 5, height - 6)
	
	_carve_line(grid, width, height, start, end, thick)
	
	var next_len := length * 0.68
	var left_dir := Vector2i(dir.y, -dir.x)
	var right_dir := Vector2i(-dir.y, dir.x)
	
	_recursive_branch(grid, width, height, end, left_dir, depth - 1, next_len, thick)
	_recursive_branch(grid, width, height, end, right_dir, depth - 1, next_len, thick)
	
	if randf() < 0.35:
		_recursive_branch(grid, width, height, end, dir, depth - 1, next_len, thick)


func _carve_line(grid: PackedByteArray, width: int, height: int, p1: Vector2i, p2: Vector2i, thick: int) -> void:
	var start := Vector2(p1)
	var end := Vector2(p2)
	var steps := int(start.distance_to(end))
	
	for i in range(steps + 1):
		var t := float(i) / float(steps) if steps > 0 else 0.0
		var p := start.lerp(end, t)
		_carve_circle(grid, width, height, int(p.x), int(p.y), thick)


func _carve_circle(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
				
			var px := cx + dx
			var py := cy + dy
			
			if px >= 0 and px < width and py >= 0 and py < height:
				grid[py * width + px] = 1
