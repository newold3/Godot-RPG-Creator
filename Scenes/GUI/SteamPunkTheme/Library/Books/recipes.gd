class_name RecipesPage
extends GuiCoreRecipesPage

func _config_hand_on_button() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()


func _config_hand_on_item_list() -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.force_show_cursor()
