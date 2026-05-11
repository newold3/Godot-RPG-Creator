class_name ModeTown
extends BaseMapMode


#region INTERFACE


## Returns the display name of this generation mode for the editor dropdown
func get_mode_name() -> String:
	return "Town / Village Exterior"



## Returns an array of core property names that this specific mode uses
func get_used_properties() -> Array[String]:
	return ["min_room_size", "max_room_size", "target_room_count", "min_corridor_width"]



## Executes the core math logic to generate a village by punching building footprints into a solid ground
func generate(grid: PackedByteArray, width: int, height: int, config: Dictionary) -> Array[Rect2i]:
	var min_size: int = config.get("min_room_size", 6)
	var max_size: int = config.get("max_room_size", 14)
	var count: int = config.get("target_room_count", 25)
	var street_w: int = config.get("min_corridor_width", 2)
	var top_wall: int = config.get("top_wall_height", 3)
	
	var margin_x: int = 5
	var margin_y: int = 5 + top_wall
	var town_w: int = width - (margin_x * 2)
	var town_h: int = height - (margin_y * 2)
	
	if town_w <= 0 or town_h <= 0:
		return []
		
	for y in range(margin_y, margin_y + town_h):
		for x in range(margin_x, margin_x + town_w):
			grid[y * width + x] = 1
			
	var buildings: Array[Rect2i] = []
	var attempts: int = count * 3 
	
	for i in range(attempts):
		if buildings.size() >= count:
			break
			
		var b_w: int = randi_range(min_size, max_size)
		var b_h: int = randi_range(min_size, max_size)
		
		var max_x: int = margin_x + town_w - b_w - street_w
		var max_y: int = margin_y + town_h - b_h - street_w - top_wall
		
		if max_x <= margin_x + street_w or max_y <= margin_y + street_w:
			continue
			
		var b_x: int = randi_range(margin_x + street_w, max_x)
		var b_y: int = randi_range(margin_y + street_w, max_y)
		var b_rect: Rect2i = Rect2i(b_x, b_y, b_w, b_h)
		var overlap: bool = false
		
		var pad_top: int = street_w
		var pad_bottom: int = street_w + top_wall 
		var pad_sides: int = street_w
		var check_rect: Rect2i = Rect2i(b_x - pad_sides, b_y - pad_top, b_w + pad_sides * 2, b_h + pad_top + pad_bottom)
		
		for existing in buildings:
			if check_rect.intersects(existing):
				overlap = true
				break
				
		if not overlap:
			buildings.append(b_rect)
			
			for by in range(b_rect.position.y, b_rect.end.y):
				for bx in range(b_rect.position.x, b_rect.end.x):
					grid[by * width + bx] = 0
					
	var results: Array[Rect2i] = [Rect2i(margin_x, margin_y, town_w, town_h)]
	results.append_array(buildings)
	
	return results
#endregion
