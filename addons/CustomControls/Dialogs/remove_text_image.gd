@tool
extends Window


signal remove_image(type: int, id: int)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(type: int, id: int) -> void:
	type = clamp(type, 0, 1)
	%ImageType.select(type)
	%ImageType.item_selected.emit(type)
	if type == 0:
		%Position.select(id)
	else:
		%ID.value = id


func _on_ok_button_pressed() -> void:
	var id = %ImageType.get_selected_id()
	if id == 0:
		remove_image.emit(id, %Position.get_selected_id())
	else:
		remove_image.emit(id, %ID.value)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_image_type_item_selected(index: int) -> void:
	%ImageID.visible = index == 1
	%PositionID.visible = index == 0
	size.y = 0
