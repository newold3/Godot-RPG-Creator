@tool
extends HFlowContainer

@export var horizontal_separator_texture: Texture

func _draw() -> void:
	if not horizontal_separator_texture:
		return
	
	var v_separation = get("theme_override_constants/v_separation")
	if v_separation == null:
		v_separation = get_theme_constant("v_separation")
	
	var children = get_children().filter(func(child): return child is Control and child.visible)
	if children.is_empty():
		return
	
	var rows = {}
	for child in children:
		var row_y = child.position.y
		if not rows.has(row_y):
			rows[row_y] = []
		rows[row_y].append(child)
	
	var sorted_row_positions = rows.keys()
	sorted_row_positions.sort()
	
	var mod_y = v_separation / 2
	
	for i in range(sorted_row_positions.size() - 1):
		var row_y = sorted_row_positions[i]
		var row_children = rows[row_y]
		
		var max_bottom = 0
		for child in row_children:
			max_bottom = max(max_bottom, child.position.y + child.size.y)
		
		var y = max_bottom + mod_y - horizontal_separator_texture.get_height() / 2
		var rect = Rect2(0, y, size.x, horizontal_separator_texture.get_height())
		draw_texture_rect(horizontal_separator_texture, rect, false)
