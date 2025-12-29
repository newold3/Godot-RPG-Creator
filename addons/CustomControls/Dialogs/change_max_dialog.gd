@tool
extends Window


signal apply_changes(value: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	var text_edit = %Value.get_line_edit()
	text_edit.caret_blink = true
	text_edit.select_all()
	text_edit.caret_column = text_edit.text.length()
	text_edit.grab_focus()


func set_value(value: int) -> void:
	%Value.set_value(value)
	
	await get_tree().process_frame
	var text_edit = %Value.get_line_edit()
	text_edit.select_all()
	text_edit.caret_column = text_edit.text.length()


func _on_ok_button_pressed() -> void:
	%Value.apply()
	apply_changes.emit(%Value.value)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
