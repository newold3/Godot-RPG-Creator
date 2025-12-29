@tool
extends TextureRect



func _on_background_inner_mask_item_rect_changed() -> void:
	position = Vector2.ZERO
	size = get_parent().size
