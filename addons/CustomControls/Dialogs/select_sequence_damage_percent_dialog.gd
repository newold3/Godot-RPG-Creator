@tool
extends Window

signal selected_value(value: float)


func _ready() -> void:
	close_requested.connect(queue_free)
	await get_tree().process_frame
	%Percent.get_line_edit().select_all()
	%Percent.get_line_edit().grab_focus()


func set_value(value: int) -> void:
	%Percent.value = value
	%Percent.get_line_edit().select_all()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_ok_button_pressed() -> void:
	%Percent.apply()
	selected_value.emit(%Percent.value)
	queue_free()
