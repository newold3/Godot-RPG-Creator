@tool
extends Window


signal command_selected(id: int)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(id: int) -> void:
	id = clamp(id, 0, 1)
	%Selection.select(id)


func _on_ok_button_pressed() -> void:
	command_selected.emit(%Selection.get_selected_id())
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
