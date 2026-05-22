class_name ModeTown
extends BaseMapMode


func get_mode_name() -> String:
	return "Town / Village Exterior"


func get_used_properties() -> Array[String]:
	return [
		"min_room_size",
		"max_room_size",
		"target_room_count",
		"min_corridor_width"
	]


func generate(
	grid: PackedByteArray,
	width: int,
	height: int,
	config: Dictionary
) -> Array[Rect2i]:

	var min_size: int = config.get("min_room_size", 6)
	var max_size: int = config.get("max_room_size", 14)
	var count: int = config.get("target_room_count", 25)
	var street_w: int = config.get("min_corridor_width", 2)
	var top_wall: int = config.get("top_wall_height", 3)

	var margin_x: int = 5
	var margin_y: int = 5 + top_wall

	var town_w: int = width - margin_x * 2
	var town_h: int = height - margin_y * 2

	if town_w <= 0 or town_h <= 0:
		return []

	grid.fill(1)

	var buildings: Array[Rect2i] = []
	var attempts: int = count * 3

	for i in range(attempts):

		if buildings.size() >= count:
			break

		var b_w: int = randi_range(min_size, max_size)
		var b_h: int = randi_range(min_size, max_size)

		var max_x: int = margin_x + town_w - b_w - street_w
		var max_y: int = margin_y + town_h - b_h - street_w

		if max_x <= margin_x + street_w or max_y <= margin_y + street_w:
			continue

		var b_x: int = randi_range(margin_x + street_w, max_x)
		var b_y: int = randi_range(margin_y + street_w, max_y)

		var b_rect := Rect2i(b_x, b_y, b_w, b_h)

		var pad_top: int = street_w
		var pad_bottom: int = street_w + top_wall
		var pad_sides: int = street_w

		var cx1: int = b_x - pad_sides
		var cy1: int = b_y - pad_top
		var cx2: int = b_x + b_w + pad_sides
		var cy2: int = b_y + b_h + pad_bottom

		var overlap := false

		for j in range(buildings.size()):

			var o := buildings[j]

			if cx1 < o.end.x and cx2 > o.position.x and cy1 < o.end.y and cy2 > o.position.y:
				overlap = true
				break

		if overlap:
			continue

		buildings.append(b_rect)

		for by in range(b_y, b_y + b_h):
			var row := by * width
			for bx in range(b_x, b_x + b_w):
				grid[row + bx] = 0

	var results: Array[Rect2i] = []
	results.append(Rect2i(margin_x, margin_y, town_w, town_h))
	results.append_array(buildings)

	return results
