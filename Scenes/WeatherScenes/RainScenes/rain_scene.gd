extends Sprite2D


func _ready() -> void:
	setup()


func setup() -> void:
	texture = %SubViewport.get_texture()
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_to_the_map()


func adjust_to_the_map() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if map:
		var map_rect = map.get_used_rect(false)
		global_position = map_rect.position
		global_scale = Vector2(map_rect.size) / texture.get_size()
		
		var mat: ShaderMaterial = %MainSprite.get_material()
		mat.set_shader_parameter("scale", Vector2(1.0 / global_scale.x, 1.0 / global_scale.y))
