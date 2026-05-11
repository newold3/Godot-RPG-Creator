class_name ModeRooms
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Rooms"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["min_room_size", "max_room_size", "target_room_count", "min_corridor_width", "max_corridor_width"]



## Executes the core math logic to carve rooms and corridors into the grid
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var room_rects: Array[Rect2i] = []
	var target_room_count: int = config.get("target_room_count", 25)
	var min_room_size: int = config.get("min_room_size", 6)
	var max_room_size: int = config.get("max_room_size", 14)
	var min_corridor_width: int = config.get("min_corridor_width", 1)
	var max_corridor_width: int = config.get("max_corridor_width", 2)
	var top_wall_height: int = config.get("top_wall_height", 3)
	
	for r in range(target_room_count):
		var r_w: int = randi_range(min_room_size, max_room_size)
		var r_h: int = randi_range(min_room_size, max_room_size)
		var max_x_start: int = width - r_w - 5
		var max_y_start: int = height - r_h - 5
		
		if max_x_start <= 5 or max_y_start <= 5 + top_wall_height:
			continue
			
		var r_x: int = randi_range(5, max_x_start)
		var r_y: int = randi_range(5 + top_wall_height, max_y_start)
		var room_rect: Rect2i = Rect2i(r_x, r_y, r_w, r_h)
		var overlap: bool = false
		
		for x in range(room_rect.position.x - 2, room_rect.end.x + 2):
			for y in range(room_rect.position.y - 2 - top_wall_height, room_rect.end.y + 2 + top_wall_height):
				if x >= 0 and x < width and y >= 0 and y < height:
					if grid[y * width + x] != 0:
						overlap = true
						break
			if overlap: break
			
		if not overlap:
			for x in range(room_rect.position.x, room_rect.end.x):
				for y in range(room_rect.position.y, room_rect.end.y):
					if x >= 0 and x < width and y >= 0 and y < height:
						grid[y * width + x] = 1
			room_rects.append(room_rect)
			
	if room_rects.size() > 1:
		for i in range(room_rects.size()):
			var r1: Rect2i = room_rects[i]
			var r2: Rect2i = room_rects[(i + 1) % room_rects.size()]
			var c_width: int = randi_range(min_corridor_width, max_corridor_width)
			var p1: Vector2i = Vector2i(randi_range(r1.position.x, r1.end.x - c_width), randi_range(r1.position.y, r1.end.y - c_width))
			var p2: Vector2i = Vector2i(randi_range(r2.position.x, r2.end.x - c_width), randi_range(r2.position.y, r2.end.y - c_width))
			carve_corridor(p1, p2, c_width, width, height, grid)
			
	return room_rects
#endregion
