extends Sprite2D


func _ready() -> void:
	setup()


func setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_to_the_map()


func adjust_to_the_map() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if map:
		var map_rect = map.get_used_rect(false)
		global_position = map_rect.position
		var vp = get_node_or_null("MainViewport")
		var tex_size = vp.size if vp else (texture.get_size() if texture else Vector2(1, 1))
		if tex_size == Vector2.ZERO: tex_size = Vector2(1, 1)
		global_scale = Vector2(map_rect.size) / tex_size
