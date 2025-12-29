@tool
extends GridContainer

@export var vertical_separator_texture: Texture


func _draw() -> void:
	if vertical_separator_texture:
		var y: int
		var mod_y = get("theme_override_constants/v_separation") / 2
		for child in get_children():
			if child is Control:
				y = child.position.y + child.size.y + mod_y - vertical_separator_texture.get_height() / 2
				var rect = Rect2(0, y, size.x, vertical_separator_texture.get_height())
				draw_texture_rect(vertical_separator_texture, rect, false)
