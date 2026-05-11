class_name ModeHouse
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "House Interior"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["min_room_size", "max_room_size", "min_corridor_width", "max_corridor_width"]



## Executes the core math logic to divide a rectangular boundary into connected interior rooms
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_room_size: int = config.get("min_room_size", 6)
	var max_room_size: int = config.get("max_room_size", 14)
	var min_corridor_width: int = config.get("min_corridor_width", 1)
	var max_corridor_width: int = config.get("max_corridor_width", 2)
	var top_wall_height: int = config.get("top_wall_height", 3)
	
	var max_w: int = width - 10
	var max_h: int = height - 10 - top_wall_height
	var min_w_allowed: int = min_room_size * 2
	var min_h_allowed: int = (min_room_size + top_wall_height + 2) * 2
	var house_w: int = randi_range(min(min_w_allowed * 2, max_w), max_w)
	var house_h: int = randi_range(min(min_h_allowed * 2, max_h), max_h)
	var start_x: int = 5 + randi_range(0, max_w - house_w)
	var start_y: int = 5 + top_wall_height + randi_range(0, max_h - house_h)
	
	var rooms: Array[Rect2i] = []
	var queue: Array[Rect2i] = []
	var min_h: int = min_room_size + top_wall_height + 2
	var shape_roll: float = randf()
	
	if shape_roll < 0.50:
		queue.append(Rect2i(start_x, start_y, house_w, house_h))
	elif shape_roll < 0.75:
		var l_w: int = house_w / 2
		var l_h: int = house_h / 2
		queue.append(Rect2i(start_x, start_y, l_w, house_h))
		queue.append(Rect2i(start_x + l_w, start_y + l_h, house_w - l_w, house_h - l_h))
	else:
		var t_w: int = house_w / 3
		var t_h: int = house_h / 2
		queue.append(Rect2i(start_x, start_y, house_w, t_h))
		queue.append(Rect2i(start_x + t_w, start_y + t_h, t_w, house_h - t_h))
		
	while queue.size() > 0:
		var current: Rect2i = queue.pop_back()
		var w: int = current.size.x
		var h: int = current.size.y
		
		if w > max_room_size or h > max_room_size + top_wall_height:
			if w >= h and w >= min_room_size * 2:
				var split: int = randi_range(min_room_size, w - min_room_size)
				queue.append(Rect2i(current.position.x, current.position.y, split, h))
				queue.append(Rect2i(current.position.x + split, current.position.y, w - split, h))
			elif h >= min_h * 2:
				var split: int = randi_range(min_h, h - min_h)
				queue.append(Rect2i(current.position.x, current.position.y, w, split))
				queue.append(Rect2i(current.position.x, current.position.y + split, w, h - split))
			else:
				if w >= min_room_size and h >= min_h:
					rooms.append(current)
		else:
			if w >= min_room_size and h >= min_h:
				rooms.append(current)
				
	for room in rooms:
		for y in range(room.position.y + top_wall_height + 1, room.end.y - 1):
			for x in range(room.position.x + 1, room.end.x - 1):
				grid[y * width + x] = 1
				
	if rooms.size() > 1:
		for i in range(rooms.size() - 1):
			var r1: Rect2i = rooms[i]
			var r2: Rect2i = rooms[i + 1]
			var c_width: int = randi_range(min_corridor_width, max_corridor_width)
			var p1: Vector2i = Vector2i(randi_range(r1.position.x + 1, r1.end.x - 2), randi_range(r1.position.y + top_wall_height + 1, r1.end.y - 2))
			var p2: Vector2i = Vector2i(randi_range(r2.position.x + 1, r2.end.x - 2), randi_range(r2.position.y + top_wall_height + 1, r2.end.y - 2))
			carve_corridor(p1, p2, c_width, width, height, grid)
			
	return rooms
#endregion
