extends ColorRect

## Create a black texture with a hole centered on the character. The start function animates the hole opening slightly. The end function causes the hole to grow until it fills the entire screen and the scene is automatically deleted.


func _ready() -> void:
	_update_hole_position()


func _update_hole_position() -> void:
	if GameManager.current_player:
		var p = GameManager.current_player.get_global_transform_with_canvas().origin
		var screen_size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
		var point = p / screen_size
		material.set_shader_parameter("hole_position", point)


func _process(_delta: float) -> void:
	_update_hole_position()


func start():
	var t = create_tween()
	t.tween_property(material, "shader_parameter/progress", 0.15, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await t.finished


func end():
	var t = create_tween()
	t.tween_property(material, "shader_parameter/progress", 1.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
	
	await t.finished
