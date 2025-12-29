@tool
extends Window


var command: RPGMovementCommand


func _ready() -> void:
	close_requested.connect(queue_free)
	%Duration.get_line_edit().grab_focus()


func set_command(_command: RPGMovementCommand, updated: bool) -> void:
	command = _command
	if updated:
		%Duration.value = command.parameters[0]


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	command.parameters.clear()
	command.parameters.append(%Duration.value)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
