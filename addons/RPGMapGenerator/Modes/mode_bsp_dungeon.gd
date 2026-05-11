class_name ModeBSPDungeon
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "BSP Dungeon"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["min_room_size", "max_room_size", "min_corridor_width", "max_corridor_width"]



## Executes the core math logic to carve a BSP tree based dungeon preventing overlapping rooms
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_room_size: int = config.get("min_room_size", 6)
	var max_room_size: int = config.get("max_room_size", 14)
	var min_corridor_width: int = config.get("min_corridor_width", 1)
	var max_corridor_width: int = config.get("max_corridor_width", 2)
	var top_wall_height: int = config.get("top_wall_height", 3)
	
	var start_x: int = 5
	var start_y: int = 5 + top_wall_height
	var available_w: int = width - 10
	var available_h: int = height - 10 - top_wall_height
	
	var leaves: Array[Dictionary] = []
	var root_leaf: Dictionary = {"rect": Rect2i(start_x, start_y, available_w, available_h), "left": null, "right": null, "room": Rect2i()}
	leaves.append(root_leaf)
	
	var did_split: bool = true
	var min_leaf_size: int = min_room_size + 4
	
	while did_split:
		did_split = false
		for i in range(leaves.size()):
			var l: Dictionary = leaves[i]
			if l["left"] == null and l["right"] == null:
				if l["rect"].size.x > max_room_size * 2 or l["rect"].size.y > max_room_size * 2 or randf() > 0.25:
					if l["rect"].size.x > min_leaf_size * 2 or l["rect"].size.y > min_leaf_size * 2:
						_split_leaf(l, min_leaf_size)
						if l["left"] != null and l["right"] != null:
							leaves.append(l["left"])
							leaves.append(l["right"])
							did_split = true
							
	var rooms: Array[Rect2i] = []
	_create_rooms(root_leaf, min_room_size, max_room_size)
	_carve_bsp_rooms(root_leaf, grid, width, height)
	_connect_leaves(root_leaf, min_corridor_width, max_corridor_width, width, height, grid)
	_collect_rooms(root_leaf, rooms)
	
	return rooms
#endregion


#region BSP LOGIC


## Splits a leaf into two smaller leaves randomly choosing horizontal or vertical
func _split_leaf(leaf: Dictionary, min_size: int) -> void:
	var split_h: bool = randf() > 0.5
	if leaf["rect"].size.x > leaf["rect"].size.y and leaf["rect"].size.x / float(leaf["rect"].size.y) >= 1.25:
		split_h = false
	elif leaf["rect"].size.y > leaf["rect"].size.x and leaf["rect"].size.y / float(leaf["rect"].size.x) >= 1.25:
		split_h = true
		
	var max_val: int = (leaf["rect"].size.y - min_size) if split_h else (leaf["rect"].size.x - min_size)
	if max_val <= min_size: return
	
	var split: int = randi_range(min_size, max_val)
	
	if split_h:
		leaf["left"] = {"rect": Rect2i(leaf["rect"].position.x, leaf["rect"].position.y, leaf["rect"].size.x, split), "left": null, "right": null, "room": Rect2i()}
		leaf["right"] = {"rect": Rect2i(leaf["rect"].position.x, leaf["rect"].position.y + split, leaf["rect"].size.x, leaf["rect"].size.y - split), "left": null, "right": null, "room": Rect2i()}
	else:
		leaf["left"] = {"rect": Rect2i(leaf["rect"].position.x, leaf["rect"].position.y, split, leaf["rect"].size.y), "left": null, "right": null, "room": Rect2i()}
		leaf["right"] = {"rect": Rect2i(leaf["rect"].position.x + split, leaf["rect"].position.y, leaf["rect"].size.x - split, leaf["rect"].size.y), "left": null, "right": null, "room": Rect2i()}



## Recursively creates rooms inside the lowest level leaves
func _create_rooms(leaf: Dictionary, min_r: int, max_r: int) -> void:
	if leaf["left"] != null or leaf["right"] != null:
		if leaf["left"] != null: _create_rooms(leaf["left"], min_r, max_r)
		if leaf["right"] != null: _create_rooms(leaf["right"], min_r, max_r)
	else:
		var room_w: int = randi_range(min_r, mini(leaf["rect"].size.x - 2, max_r))
		var room_h: int = randi_range(min_r, mini(leaf["rect"].size.y - 2, max_r))
		var room_x: int = leaf["rect"].position.x + randi_range(1, leaf["rect"].size.x - room_w - 1)
		var room_y: int = leaf["rect"].position.y + randi_range(1, leaf["rect"].size.y - room_h - 1)
		leaf["room"] = Rect2i(room_x, room_y, room_w, room_h)



## Carves all the generated rooms into the byte array grid
func _carve_bsp_rooms(leaf: Dictionary, grid: PackedByteArray, w: int, h: int) -> void:
	if leaf["left"] == null and leaf["right"] == null:
		var r: Rect2i = leaf["room"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x >= 0 and x < w and y >= 0 and y < h:
					grid[y * w + x] = 1
	else:
		if leaf["left"] != null: _carve_bsp_rooms(leaf["left"], grid, w, h)
		if leaf["right"] != null: _carve_bsp_rooms(leaf["right"], grid, w, h)



## Recursively connects sibling leaves with corridors
func _connect_leaves(leaf: Dictionary, min_c: int, max_c: int, map_w: int, map_h: int, grid: PackedByteArray) -> void:
	if leaf["left"] != null and leaf["right"] != null:
		_connect_leaves(leaf["left"], min_c, max_c, map_w, map_h, grid)
		_connect_leaves(leaf["right"], min_c, max_c, map_w, map_h, grid)
		
		var r1: Rect2i = _get_room(leaf["left"])
		var r2: Rect2i = _get_room(leaf["right"])
		
		if r1.size.x > 0 and r2.size.x > 0:
			var c_width: int = randi_range(min_c, max_c)
			var p1: Vector2i = Vector2i(randi_range(r1.position.x, r1.end.x - c_width), randi_range(r1.position.y, r1.end.y - c_width))
			var p2: Vector2i = Vector2i(randi_range(r2.position.x, r2.end.x - c_width), randi_range(r2.position.y, r2.end.y - c_width))
			carve_corridor(p1, p2, c_width, map_w, map_h, grid)



## Gets a valid room from a leaf or its children to use as a connection point
func _get_room(leaf: Dictionary) -> Rect2i:
	if leaf["left"] != null:
		var l_room: Rect2i = _get_room(leaf["left"])
		var r_room: Rect2i = _get_room(leaf["right"]) if leaf["right"] != null else Rect2i()
		if l_room.size.x == 0: return r_room
		if r_room.size.x == 0: return l_room
		return l_room if randf() > 0.5 else r_room
	return leaf["room"]



## Extracts all final room rectangles into a flat array for debug markers
func _collect_rooms(leaf: Dictionary, rooms: Array[Rect2i]) -> void:
	if leaf["left"] == null and leaf["right"] == null:
		rooms.append(leaf["room"])
	else:
		if leaf["left"] != null: _collect_rooms(leaf["left"], rooms)
		if leaf["right"] != null: _collect_rooms(leaf["right"], rooms)
#endregion
