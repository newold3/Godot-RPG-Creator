class_name ModeQuadtreeSlums
extends BaseMapMode


func get_mode_name() -> String:
	return "Quadtree Slums"


func get_used_properties() -> Array[String]:
	return ["min_room_size", "min_corridor_width"]


func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_size: int = config.get("min_room_size", 16)
	var street_w: int = config.get("min_corridor_width", 2)
	
	grid.fill(1)
	
	var rooms: Array[Rect2i] = []
	var queue: Array[Rect2i] = [Rect2i(4, 4, width - 8, height - 8)]
	
	while not queue.is_empty():
		var current := queue.pop_back()
		
		if current.size.x > min_size * 2 and current.size.y > min_size * 2 and randf() < 0.9:
			var split_x := randi_range(int(current.size.x * 0.4), int(current.size.x * 0.6))
			var split_y := randi_range(int(current.size.y * 0.4), int(current.size.y * 0.6))
			
			queue.append(Rect2i(current.position.x, current.position.y, split_x, split_y))
			queue.append(Rect2i(current.position.x + split_x, current.position.y, current.size.x - split_x, split_y))
			queue.append(Rect2i(current.position.x, current.position.y + split_y, split_x, current.size.y - split_y))
			queue.append(Rect2i(current.position.x + split_x, current.position.y + split_y, current.size.x - split_x, current.size.y - split_y))
		else:
			rooms.append(current)
			
	for room in rooms:
		if room.size.x > street_w * 2 + 2 and room.size.y > street_w * 2 + 2:
			for y in range(room.position.y + street_w, room.end.y - street_w):
				var offset := y * width
				for x in range(room.position.x + street_w, room.end.x - street_w):
					grid[offset + x] = 0
					
	var result: Array[Rect2i] = []
	if not rooms.is_empty():
		result.append(Rect2i(rooms[0].position + Vector2i(1, 1), Vector2i.ONE))
		
	return result
