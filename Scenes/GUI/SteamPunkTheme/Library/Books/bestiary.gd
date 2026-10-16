class_name BestiaryPage
extends GuiCoreBestiaryPage

func _apply_monster_shader(mat: ShaderMaterial, is_killed: bool) -> void:
	if not mat: return
	if is_killed:
		mat.set_shader_parameter("pencil_strength", 0.658)
		mat.set_shader_parameter("shade_levels", 14.0)
	else:
		mat.set_shader_parameter("pencil_strength", 0.071)
		mat.set_shader_parameter("shade_levels", 1.197)


func _config_hand_in_description() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_stats() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_drops() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(-2, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_item_list() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()
