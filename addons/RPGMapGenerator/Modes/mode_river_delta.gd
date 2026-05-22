class_name ModeRiverDelta
extends BaseMapMode


func get_mode_name() -> String:
	return "River Delta"


func get_used_properties() -> Array[String]:
	return ["min_corridor_width", "max_corridor_width"]


func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_w: int = config.get("min_corridor_width", 2)
	var max_w: int = config.get("max_corridor_width", 5)
	
	grid.fill(0)
	
	var active_streams: Array[Dictionary] = []
	active_streams.append({
		"x": float(width / 2),
		"thick": float(max_w)
	})
	
	for y in range(4, height - 5):
		var next_streams: Array[Dictionary] = []
		
		for stream in active_streams:
			var cx: float = stream["x"]
			var t: float = stream["thick"]
			
			cx += randf_range(-2.0, 2.0)
			cx = clampf(cx, 10.0, float(width - 11))
			
			_carve_horizontal_line(grid, width, height, int(cx), y, int(t))
			
			if randf() < 0.02 and active_streams.size() < 12 and t > 2.0:
				var split_t := t * 0.65
				next_streams.append({"x": cx - (t * 0.5), "thick": split_t})
				next_streams.append({"x": cx + (t * 0.5), "thick": split_t})
			else:
				if randf() < 0.01:
					t = clampf(t + randf_range(-1.0, 1.0), float(min_w), float(max_w))
				next_streams.append({"x": cx, "thick": t})
				
		active_streams = next_streams
		
	var result: Array[Rect2i] = []
	result.append(Rect2i(Vector2i(width / 2, 4), Vector2i.ONE))
	
	return result


func _carve_horizontal_line(grid: PackedByteArray, width: int, height: int, cx: int, cy: int, thick: int) -> void:
	var radius := thick
	for dx in range(-radius, radius + 1):
		var px := cx + dx
		if px >= 0 and px < width and cy >= 0 and cy < height:
			grid[cy * width + px] = 1
