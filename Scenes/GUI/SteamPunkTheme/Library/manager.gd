extends GuiCoreLibraryManager

func _play_cursor_fx() -> void:
	GameManager.play_fx("cursor")


func _play_cancel_fx() -> void:
	GameManager.play_fx("cancel")


func _config_hand_for_books() -> void:
	GameManager.enable_cursor_outline(Color("cbc1b692"))
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(-6, 5), manipulator)


func _config_hand_for_back_button() -> void:
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)


func _on_book_opened_presentation() -> void:
	GameManager.enable_cursor_outline(Color("cbc1b692"))


func _on_book_closed_presentation() -> void:
	_config_hand_for_books()
