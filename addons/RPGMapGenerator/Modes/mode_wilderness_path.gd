class_name ModeWildernessPath
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Wilderness Path"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["min_corridor_width", "max_corridor_width", "use_random_noise", "world_noise"]



## Executes the core math logic to carve a winding path with organic clearings and scattered ruins
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_c: int = config.get("min_corridor_width", 2)
	var max_c: int = config.get("max_corridor_width", 4)
	var top_wall: int = config.get("top_wall_height", 3)
	var noise: FastNoiseLite = config.get("world_noise")
	var use_random_noise: bool = config.get("use_random_noise", false)
	
	if use_random_noise or not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.05
		
	var margin_x: int = 5
	var margin_y: int = 5 + top_wall
	var current_x: float = width / 2.0
	var path_rects: Array[Rect2i] = []
	
	for y in range(margin_y, height - margin_y):
		var n_val: float = noise.get_noise_1d(y * 5.0)
		current_x += n_val * 4.0
		current_x = clampf(current_x, float(margin_x + max_c), float(width - margin_x - max_c))
		
		var cx: int = int(current_x)
		var w_thick: int = randi_range(min_c, max_c)
		var rect: Rect2i = Rect2i(cx - w_thick, y, w_thick * 2, 1)
		
		path_rects.append(rect)
		
		for px in range(rect.position.x, rect.end.x):
			if px >= 0 and px < width and y >= 0 and y < height:
				grid[y * width + px] = 1
				
	for i in range(15):
		var c_y: int = randi_range(margin_y, height - margin_y)
		var c_x: int = width / 2
		
		if path_rects.size() > 0:
			var p_rect: Rect2i = path_rects[randi() % path_rects.size()]
			c_x = p_rect.position.x + p_rect.size.x / 2
			
		var radius: int = randi_range(3, 8)
		var offset_x: int = randi_range(-radius, radius)
		
		c_x += offset_x
		c_x = clampi(c_x, margin_x + radius, width - margin_x - radius)
		
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					var px: int = c_x + dx
					var py: int = c_y + dy
					if px >= 0 and px < width and py >= 0 and py < height:
						grid[py * width + px] = 1
						
	for i in range(25):
		var rx: int = randi_range(margin_x, width - margin_x)
		var ry: int = randi_range(margin_y, height - margin_y)
		var surrounded: bool = true
		
		for dy in range(-2, 3 + top_wall):
			for dx in range(-2, 3):
				var px: int = rx + dx
				var py: int = ry + dy
				if px >= 0 and px < width and py >= 0 and py < height:
					if grid[py * width + px] == 0:
						surrounded = false
						break
			if not surrounded:
				break
				
		if surrounded:
			var r_w: int = randi_range(1, 3)
			var r_h: int = randi_range(1, 2)
			for dy in range(r_h):
				for dx in range(r_w):
					grid[(ry + dy) * width + (rx + dx)] = 0
					
	var return_rects: Array[Rect2i] = []
	
	if path_rects.size() > 0:
		return_rects.append(path_rects[0])
		return_rects.append(path_rects[path_rects.size() - 1])
		
	return return_rects
#endregion
