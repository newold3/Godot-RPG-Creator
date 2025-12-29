@tool
extends Window

signal command_selected(value: int)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(value: int) -> void:
	var index = clamp(value, 0, 1)
	%Position.select(index)


func _on_ok_button_pressed() -> void:
	command_selected.emit(%Position.get_selected_id())
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
