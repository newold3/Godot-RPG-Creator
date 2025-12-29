@tool
extends Window


signal command_selected(type: int, seconds: float)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(type: int, seconds: float) -> void:
	type = clamp(type, 0, 1)
	%Type.select(type)
	%Type.item_selected.emit(type)
	%Seconds.value = seconds


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var type = %Type.get_selected_id()
	var seconds = %Seconds.value
	command_selected.emit(type, seconds)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_type_item_selected(index: int) -> void:
	%SecondsContainer.visible = index == 0
	size.y = 0
