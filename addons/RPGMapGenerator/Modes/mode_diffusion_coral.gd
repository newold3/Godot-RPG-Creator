class_name ModeDiffusionCoral
extends BaseMapMode


func get_mode_name() -> String:
	return "Diffusion Coral"


func get_used_properties() -> Array[String]:
	return ["min_corridor_width"]


func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var thick: int = config.get("min_corridor_width", 2)
	
	grid.fill(0)
	
	var center := Vector2i(width / 2, height / 2)
	_carve_circle(grid, width, height, center.x, center.y, thick * 3)
	
	var branches: Array[Dictionary] = []
	var initial_dirs := 8
	for i in range(initial_dirs):
		var angle := float(i) * (TAU / float(initial_dirs))
		branches.append({
			"pos": Vector2(center),
			"dir": Vector2(cos(angle), sin(angle)),
			"length": randi_range(60, 120),
			"thick": thick
		})
		
	var max_iterations := 5
	for iteration in range(max_iterations):
		var next_branches: Array[Dictionary] = []
		
		for b in branches:
			var curr = b["pos"]
			var d = b["dir"]
			var l = b["length"]
			var t = b["thick"]
			
			for step in range(l):
				curr += d
				d = (d + Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))).normalized()
				_carve_circle(grid, width, height, int(curr.x), int(curr.y), int(t))
				
				if step > 0 and step % 30 == 0 and t > 1:
					var left_angle = d.rotated(deg_to_rad(randf_range(30, 60)))
					var right_angle = d.rotated(deg_to_rad(randf_range(-60, -30)))
					
					next_branches.append({
						"pos": curr,
						"dir": left_angle,
						"length": int(l * 0.7),
						"thick": maxi(1, int(t * 0.8))
					})
					next_branches.append({
						"pos": curr,
						"dir": right_angle,
						"length": int(l * 0.7),
						"thick": maxi(1, int(t * 0.8))
					})
					
		branches = next_branches
		
	var result: Array[Rect2i] = [Rect2i(center, Vector2i.ONE)]
	return result


func _carve_circle(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
				
			var px := cx + dx
			var py := cy + dy
			
			if px >= 0 and px < width and py >= 0 and py < height:
				grid[py * width + px] = 1
