@tool
extends Window


var command: RPGMovementCommand


func _ready() -> void:
	close_requested.connect(queue_free)


func set_command(_command: RPGMovementCommand, updated: bool) -> void:
	command = _command
	if updated:
		command.parameters[0] = max(0, min(command.parameters[0], %BlendMode.get_item_count() - 1))
		%BlendMode.select(command.parameters[0])


func _on_ok_button_pressed() -> void:
	command.parameters.clear()
	command.parameters.append(%BlendMode.get_selected_id())
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
