extends MarginContainer


## Emitted when the player confirms or clicks an item
signal item_activated(item_type: int, item_id: int)
## Emitted when an item receives focus
signal item_focused(item_type: int, item_id: int)
## Signal emitted when the dialog requests to be closed
signal close_requested()

func start() -> void:
	var stream = preload("uid://cegbob6fb11g2")
	GameManager.play_se(stream)
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.force_hide_cursor()
	
	var node = %MainAnimator
	var t = create_tween()
	t.tween_property(node, "speed_scale", 1.5, 0.2).from(0.0)
	t.tween_callback(%ItemList.select_item.bind(0))
	t.tween_property(node, "speed_scale", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func end() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.play_fx("cancel")
	
	var node = %MainAnimator
	var t = create_tween()
	t.tween_property(node, "speed_scale", 1.5, 0.1).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	t.tween_callback(
		func():
			%ItemList.select_item(0)
			close_requested.emit()
	)
	t.tween_property(node, "speed_scale", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _on_item_list_item_activated(item_type: int, item_id: int) -> void:
	item_activated.emit(item_type, item_id)


func _on_item_list_item_focused(item_type: int, item_id: int) -> void:
	item_focused.emit(item_type, item_id)


func _on_item_list_close_requested() -> void:
	end()
