class_name ModeLabyrinth
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Labyrinth"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["labyrinth_path_thickness"]



## Executes the core math logic to carve a thick-corridor maze respecting 3D perspective
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var path_width: int = config.get("labyrinth_path_thickness", 1)
	var top_wall_height: int = config.get("top_wall_height", 3)
	var gap_x: int = 2
	var gap_y: int = top_wall_height + 2
	var step_x: int = path_width + gap_x
	var step_y: int = path_width + gap_y
	
	var max_w: int = width - 10
	var max_h: int = height - 10 - top_wall_height
	var min_w_allowed: int = step_x * 4
	var min_h_allowed: int = step_y * 4
	
	var lab_w: int = randi_range(min(min_w_allowed * 2, max_w), max_w)
	var lab_h: int = randi_range(min(min_h_allowed * 2, max_h), max_h)
	var start_x: int = 5 + randi_range(0, max_w - lab_w)
	var start_y: int = 5 + top_wall_height + randi_range(0, max_h - lab_h)
	
	var zones: Array[Rect2i] = []
	var shape_roll: float = randf()
	
	if shape_roll < 0.50:
		zones.append(Rect2i(start_x, start_y, lab_w, lab_h))
	elif shape_roll < 0.75:
		var l_w: int = lab_w / 2
		var l_h: int = lab_h / 2
		zones.append(Rect2i(start_x, start_y, l_w, lab_h))
		zones.append(Rect2i(start_x + l_w, start_y + l_h, lab_w - l_w, lab_h - l_h))
	else:
		var t_w: int = lab_w / 3
		var t_h: int = lab_h / 2
		zones.append(Rect2i(start_x, start_y, lab_w, t_h))
		zones.append(Rect2i(start_x + t_w, start_y + t_h, t_w, lab_h - t_h))
		
	var z0 = zones[0]
	var s_x: int = z0.position.x + (step_x - (z0.position.x % step_x)) % step_x
	var s_y: int = z0.position.y + (step_y - (z0.position.y % step_y)) % step_y
	var current: Vector2i = Vector2i(s_x, s_y)
	var stack: Array[Vector2i] = []
	
	var carve_block = func(cx: int, cy: int) -> void:
		for dy in range(path_width):
			for dx in range(path_width):
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < width and py >= 0 and py < height:
					grid[py * width + px] = 1
					
	carve_block.call(current.x, current.y)
	stack.append(current)
	var dirs: Array[Vector2i] = [Vector2i(0, -step_y), Vector2i(0, step_y), Vector2i(-step_x, 0), Vector2i(step_x, 0)]
	
	while stack.size() > 0:
		current = stack.back()
		var unvisited: Array[Vector2i] = []
		
		for d in dirs:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			var block_rect = Rect2i(nx, ny, path_width, path_width)
			var is_inside = false
			
			for z in zones:
				if z.encloses(block_rect):
					is_inside = true
					break
					
			if is_inside:
				var is_empty: bool = true
				for dy in range(path_width):
					for dx in range(path_width):
						if grid[(ny + dy) * width + (nx + dx)] != 0:
							is_empty = false
							break
				if is_empty: unvisited.append(d)
				
		if unvisited.size() > 0:
			var dir: Vector2i = unvisited[randi() % unvisited.size()]
			var nx: int = current.x + dir.x
			var ny: int = current.y + dir.y
			carve_block.call(nx, ny)
			
			if dir.x != 0:
				for dy in range(path_width):
					for dx in range(gap_x):
						grid[(current.y + dy) * width + min(current.x, nx) + path_width + dx] = 1
			elif dir.y != 0:
				for dx in range(path_width):
					for dy in range(gap_y):
						grid[(min(current.y, ny) + path_width + dy) * width + current.x + dx] = 1
			stack.append(Vector2i(nx, ny))
		else: 
			stack.pop_back()
			
	return []
#endregion
